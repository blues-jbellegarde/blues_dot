#!/usr/bin/env python3
"""
Neovim Headless MCP Server

Custom MCP server that bridges Claude Code to a persistent Neovim headless instance.
Exposes formatting (conform.nvim), linting (nvim-lint), LSP, and treesitter as MCP tools.
"""

import os
import sys
import json
import time
import asyncio
import subprocess
from dataclasses import dataclass
from typing import Any, Dict

import pynvim

SOCKET_PATH = os.environ.get(
    "NVIM_SOCKET",
    os.path.expanduser("~/.cache/nvim-claude/nvim-claude.sock"),
)
LSP_TIMEOUT_S = 10
LSP_REQUEST_TIMEOUT_MS = 5000
LINT_SETTLE_S = 1.0
DIAG_SETTLE_S = 0.5
# Symbol requests (workspace/documentSymbol) can return empty on a cold server
# that has attached but not finished indexing; poll a few times before giving up.
SYMBOL_RETRIES = 5
SYMBOL_SETTLE_S = 0.6
# workspace/symbol: how many times to poll for a capable language server to
# attach before concluding the language doesn't support it (× SYMBOL_SETTLE_S).
WS_CAPABILITY_RETRIES = 8


@dataclass
class MCPTool:
    """Represents an MCP tool definition."""

    name: str
    description: str
    inputSchema: Dict[str, Any]
    # When True, the tool is pinned into context at session start via
    # `_meta: {"anthropic/alwaysLoad": true}` instead of being deferred behind
    # Claude Code's tool search. Reserved for the semantic navigation/edit tools
    # so Claude reaches for them without a discover-then-load round trip.
    always_load: bool = False


class NvimMCPServer:
    """MCP server that delegates operations to a headless Neovim instance."""

    def __init__(self):
        self.nvim = None
        self.tools: Dict[str, MCPTool] = {}
        self._setup_tools()

    # ── connection ───────────────────────────────────────────────────────

    def _connect(self):
        """Connect to the headless Neovim instance via Unix socket."""
        if self.nvim is None:
            self.nvim = pynvim.attach("socket", path=SOCKET_PATH)

    # ── helpers ──────────────────────────────────────────────────────────

    def _open_file(self, filepath: str):
        """Open a file in the headless Neovim instance."""
        self._connect()
        escaped = self.nvim.funcs.fnameescape(filepath)
        self.nvim.command(f"edit {escaped}")

    def _close_buffer(self):
        """Close the current buffer to keep the instance stateless."""
        self.nvim.command("bdelete!")

    def _wait_for_lsp(self) -> bool:
        """Poll until at least one LSP client attaches to the buffer (max LSP_TIMEOUT_S)."""
        for _ in range(LSP_TIMEOUT_S * 10):
            count = self.nvim.exec_lua("return #vim.lsp.get_clients({bufnr = 0})")
            if count > 0:
                return True
            time.sleep(0.1)
        return False

    def _get_diagnostics_json(self) -> str:
        """Return buffer diagnostics as a JSON string."""
        return self.nvim.exec_lua("""
            local diags = vim.diagnostic.get(0)
            local results = {}
            for _, d in ipairs(diags) do
                table.insert(results, {
                    line     = d.lnum + 1,
                    col      = d.col + 1,
                    end_line = d.end_lnum and (d.end_lnum + 1) or nil,
                    end_col  = d.end_col and (d.end_col + 1) or nil,
                    message  = d.message,
                    severity = d.severity,
                    source   = d.source,
                })
            end
            return vim.json.encode(results)
            """)

    # ── tool registration ────────────────────────────────────────────────

    def _setup_tools(self):
        self.tools["nvim_format"] = MCPTool(
            name="nvim_format",
            description="Format a file using conform.nvim (same formatters as interactive Neovim: black, prettier, gofumpt, stylua, etc.). Respects project config (.prettierrc, pyproject.toml, .editorconfig). Note: files Claude edits are auto-formatted by the PostToolUse hook, so call this only for files changed outside that flow.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Absolute path to the file to format",
                    },
                },
                "required": ["file_path"],
            },
        )

        self.tools["nvim_lint"] = MCPTool(
            name="nvim_lint",
            description="Lint a file using nvim-lint and return structured diagnostics (pylint, eslint_d, golangci-lint, selene, sqlfluff). Respects project linter configs (.pylintrc, .eslintrc, .golangci.yml, .sqlfluff). Note: files Claude edits are auto-linted by the PostToolUse hook.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Absolute path to the file to lint",
                    },
                },
                "required": ["file_path"],
            },
        )

        self.tools["nvim_diagnostics"] = MCPTool(
            name="nvim_diagnostics",
            description="Get all diagnostics (LSP + linter) for a file as structured JSON",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Absolute path to the file",
                    },
                },
                "required": ["file_path"],
            },
        )

        self.tools["nvim_workspace_symbols"] = MCPTool(
            name="nvim_workspace_symbols",
            always_load=True,
            description="Find where a symbol (function/class/method/variable) is defined by NAME across the whole project using LSP. This is the semantic replacement for Grep/rg when searching for a code identifier: use it FIRST to go from a name to exact locations (file/line/col/kind) with no false hits in comments or strings, then feed a location into nvim_references / nvim_definition / nvim_get_node. Anchor the project + language with file_path (any file in the target repo of the same language).",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Symbol name or prefix to search for (e.g. 'process_order')",
                    },
                    "file_path": {
                        "type": "string",
                        "description": "Absolute path to any file in the target project of the same language as the symbol (anchors the LSP root and language server)",
                    },
                },
                "required": ["query", "file_path"],
            },
        )

        self.tools["nvim_document_symbols"] = MCPTool(
            name="nvim_document_symbols",
            always_load=True,
            description="List the symbol outline (functions/classes/methods/fields) of a single file using LSP. Use INSTEAD OF Read/Grep to see what a file defines and at which lines, without loading the whole file. Pair with nvim_get_node to pull one definition's source.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Absolute path to the file to outline",
                    },
                },
                "required": ["file_path"],
            },
        )

        self.tools["nvim_rename"] = MCPTool(
            name="nvim_rename",
            always_load=True,
            description="Rename a symbol across the whole project using LSP. Use INSTEAD OF grep + multi-file Edit: it renames every reference semantically (no missed usages, no false hits in comments/strings) and writes all files. Locate the symbol's line/col first with nvim_workspace_symbols if unknown.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "File containing the symbol",
                    },
                    "line": {
                        "type": "integer",
                        "description": "1-based line number of the symbol",
                    },
                    "col": {
                        "type": "integer",
                        "description": "1-based column number of the symbol",
                    },
                    "new_name": {
                        "type": "string",
                        "description": "New name for the symbol",
                    },
                },
                "required": ["file_path", "line", "col", "new_name"],
            },
        )

        self.tools["nvim_references"] = MCPTool(
            name="nvim_references",
            always_load=True,
            description="Find every usage of a symbol project-wide using LSP. Use INSTEAD OF Grep/rg when tracing where a function/class/variable is used: results are semantic (no false hits in comments, strings, or unrelated same-named symbols) and typically ~80% fewer tokens than a grep dump. Needs the symbol's line/col — get it from nvim_workspace_symbols if you only know the name.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "File containing the symbol",
                    },
                    "line": {
                        "type": "integer",
                        "description": "1-based line number of the symbol",
                    },
                    "col": {
                        "type": "integer",
                        "description": "1-based column number of the symbol",
                    },
                },
                "required": ["file_path", "line", "col"],
            },
        )

        self.tools["nvim_definition"] = MCPTool(
            name="nvim_definition",
            always_load=True,
            description="Jump to where a symbol is defined using LSP. Use INSTEAD OF Grep when you have a symbol usage and want its definition: returns the exact file/line/col, resolving imports and overloads (no guessing among same-named matches). Needs the usage's line/col.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "File containing the symbol",
                    },
                    "line": {
                        "type": "integer",
                        "description": "1-based line number of the symbol",
                    },
                    "col": {
                        "type": "integer",
                        "description": "1-based column number of the symbol",
                    },
                },
                "required": ["file_path", "line", "col"],
            },
        )

        self.tools["nvim_code_action"] = MCPTool(
            name="nvim_code_action",
            always_load=True,
            description="List and optionally execute LSP code actions (auto-import, quick fixes, missing-symbol fixes) at a position. Use INSTEAD OF hand-editing imports or manually applying a diagnostic's suggested fix. Call without execute_index to list actions, then again with the 1-based index to apply one.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "File to get code actions for",
                    },
                    "line": {"type": "integer", "description": "1-based line number"},
                    "col": {"type": "integer", "description": "1-based column number"},
                    "execute_index": {
                        "type": "integer",
                        "description": "1-based index of the action to execute (omit to list available actions)",
                    },
                },
                "required": ["file_path", "line", "col"],
            },
        )

        self.tools["nvim_get_node"] = MCPTool(
            name="nvim_get_node",
            always_load=True,
            description="Extract a single treesitter AST node (function, class, method) from a file. Use INSTEAD OF Read when you only need one function/class from a large file — returns just that node's source and range, not the whole file. Pair with nvim_workspace_symbols (name -> line) to pull a specific definition.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "File to extract from",
                    },
                    "line": {
                        "type": "integer",
                        "description": "1-based line number within the target node",
                    },
                    "node_type": {
                        "type": "string",
                        "description": "Treesitter node type to find (walks up from cursor). Common types: function_definition, class_definition, method_definition, function_declaration",
                        "default": "function_definition",
                    },
                },
                "required": ["file_path", "line"],
            },
        )

        self.tools["jq"] = MCPTool(
            name="jq",
            description="Run a jq query against a JSON file. Useful for extracting specific sections from large JSON files (e.g., Grafana dashboards). Returns the matched JSON.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Absolute path to the JSON file",
                    },
                    "query": {
                        "type": "string",
                        "description": "jq filter expression (e.g., '.panels[3]', '.panels[] | {title, type}', '.templating.list[] | .name')",
                    },
                },
                "required": ["file_path", "query"],
            },
        )

    # ── tool execution ───────────────────────────────────────────────────

    def _execute_tool_sync(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """Execute a tool synchronously (runs in thread executor)."""
        # jq doesn't need neovim
        if tool_name == "jq":
            return self._exec_jq(arguments["file_path"], arguments["query"])

        self._connect()

        if tool_name == "nvim_format":
            return self._exec_format(arguments["file_path"])

        if tool_name == "nvim_lint":
            return self._exec_lint(arguments["file_path"])

        if tool_name == "nvim_diagnostics":
            return self._exec_diagnostics(arguments["file_path"])

        if tool_name == "nvim_rename":
            return self._exec_rename(
                arguments["file_path"],
                arguments["line"],
                arguments["col"],
                arguments["new_name"],
            )

        if tool_name == "nvim_workspace_symbols":
            return self._exec_workspace_symbols(
                arguments["file_path"],
                arguments["query"],
            )

        if tool_name == "nvim_document_symbols":
            return self._exec_document_symbols(arguments["file_path"])

        if tool_name == "nvim_references":
            return self._exec_references(
                arguments["file_path"],
                arguments["line"],
                arguments["col"],
            )

        if tool_name == "nvim_definition":
            return self._exec_definition(
                arguments["file_path"],
                arguments["line"],
                arguments["col"],
            )

        if tool_name == "nvim_code_action":
            return self._exec_code_action(
                arguments["file_path"],
                arguments["line"],
                arguments["col"],
                arguments.get("execute_index"),
            )

        if tool_name == "nvim_get_node":
            return self._exec_get_node(
                arguments["file_path"],
                arguments["line"],
                arguments.get("node_type", "function_definition"),
            )

        return json.dumps({"error": f"Unknown tool: {tool_name}"})

    async def execute_tool(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """Async wrapper — runs synchronous pynvim calls in a thread executor."""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, self._execute_tool_sync, tool_name, arguments
        )

    # ── tool implementations ─────────────────────────────────────────────

    def _exec_format(self, file_path: str) -> str:
        try:
            self._open_file(file_path)
            self.nvim.exec_lua('require("conform").format({bufnr = 0, async = false})')
            self.nvim.command("write")
            return json.dumps({"formatted": True, "file": file_path})
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_lint(self, file_path: str) -> str:
        try:
            self._open_file(file_path)
            self.nvim.exec_lua('require("lint").try_lint()')
            time.sleep(LINT_SETTLE_S)
            diags_json = self._get_diagnostics_json()
            diagnostics = json.loads(diags_json)
            return json.dumps(
                {
                    "file": file_path,
                    "diagnostics": diagnostics,
                    "count": len(diagnostics),
                }
            )
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_diagnostics(self, file_path: str) -> str:
        try:
            self._open_file(file_path)
            if self._wait_for_lsp():
                time.sleep(DIAG_SETTLE_S)
            diags_json = self._get_diagnostics_json()
            diagnostics = json.loads(diags_json)
            return json.dumps(
                {
                    "file": file_path,
                    "diagnostics": diagnostics,
                    "count": len(diagnostics),
                }
            )
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_rename(self, file_path: str, line: int, col: int, new_name: str) -> str:
        try:
            self._open_file(file_path)
            if not self._wait_for_lsp():
                return json.dumps({"error": "LSP not available", "file": file_path})

            self.nvim.api.win_set_cursor(0, [line, col - 1])

            result = self.nvim.exec_lua(
                """
                local args = {...}
                local new_name = args[1]
                local timeout_ms = args[2]
                local params = vim.lsp.util.make_position_params(0)
                params.newName = new_name

                local results = vim.lsp.buf_request_sync(0, "textDocument/rename", params, timeout_ms)
                if not results or vim.tbl_isempty(results) then
                    return vim.json.encode({error = "No rename results from LSP"})
                end

                local changed_files = {}
                for client_id, resp in pairs(results) do
                    if resp.result then
                        vim.lsp.util.apply_workspace_edit(resp.result, "utf-8")
                        if resp.result.changes then
                            for uri, edits in pairs(resp.result.changes) do
                                table.insert(changed_files, {
                                    file = vim.uri_to_fname(uri),
                                    edit_count = #edits,
                                })
                            end
                        end
                        if resp.result.documentChanges then
                            for _, change in ipairs(resp.result.documentChanges) do
                                if change.textDocument then
                                    table.insert(changed_files, {
                                        file = vim.uri_to_fname(change.textDocument.uri),
                                        edit_count = change.edits and #change.edits or 0,
                                    })
                                end
                            end
                        end
                    end
                end

                -- Save all modified buffers
                vim.cmd("wall")

                return vim.json.encode({renamed = true, new_name = new_name, changed_files = changed_files})
                """,
                new_name,
                LSP_REQUEST_TIMEOUT_MS,
            )
            return result
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_workspace_symbols(self, file_path: str, query: str) -> str:
        try:
            self._open_file(file_path)
            if not self._wait_for_lsp():
                return json.dumps({"error": "LSP not available", "file": file_path})

            # Some servers (notably pylsp) don't support workspace/symbol. Detect
            # that so an empty result reads as "unsupported → fall back" rather
            # than "symbol not found". Poll for a capable client: _wait_for_lsp
            # returns as soon as ANY client attaches (e.g. Copilot), but the
            # primary language server may register a moment later.
            support = {"supported": False, "clients": []}
            for _ in range(WS_CAPABILITY_RETRIES):
                support = json.loads(self.nvim.exec_lua("""
                        local names = {}
                        local supported = false
                        for _, c in ipairs(vim.lsp.get_clients({bufnr = 0})) do
                            table.insert(names, c.name)
                            if c.server_capabilities.workspaceSymbolProvider then
                                supported = true
                            end
                        end
                        return vim.json.encode({supported = supported, clients = names})
                        """))
                if support.get("supported"):
                    break
                time.sleep(SYMBOL_SETTLE_S)
            if not support.get("supported"):
                clients = ", ".join(support.get("clients", [])) or "none"
                return json.dumps(
                    {
                        "symbols": [],
                        "count": 0,
                        "note": (
                            f"The attached LSP(s) ({clients}) do not support "
                            "workspace/symbol for this language. Fall back to "
                            "nvim_document_symbols on a known file, or Grep."
                        ),
                    }
                )

            lua = """
                local args = {...}
                local query = args[1]
                local timeout_ms = args[2]
                local params = {query = query}

                local results = vim.lsp.buf_request_sync(0, "workspace/symbol", params, timeout_ms)
                if not results or vim.tbl_isempty(results) then
                    return vim.json.encode({symbols = {}, count = 0})
                end

                local symbols = {}
                for _, resp in pairs(results) do
                    if resp.result then
                        for _, sym in ipairs(resp.result) do
                            local loc = sym.location
                            local uri = loc and (loc.uri or loc.targetUri)
                            local range = loc and (loc.range or loc.targetSelectionRange or loc.targetRange)
                            if uri and range then
                                table.insert(symbols, {
                                    name      = sym.name,
                                    kind      = vim.lsp.protocol.SymbolKind[sym.kind] or sym.kind,
                                    container = sym.containerName,
                                    file      = vim.uri_to_fname(uri),
                                    line      = range.start.line + 1,
                                    col       = range.start.character + 1,
                                })
                            end
                        end
                    end
                end

                return vim.json.encode({symbols = symbols, count = #symbols})
                """
            return self._poll_symbols(lua, query, LSP_REQUEST_TIMEOUT_MS)
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _poll_symbols(self, lua: str, *args) -> str:
        """Run a symbol request, retrying while it returns empty.

        A freshly attached language server may not have finished indexing, so
        the first request can come back with count 0 even when symbols exist.
        Retry a few times and return the first non-empty result (or the last
        empty one if the symbol genuinely doesn't exist).
        """
        result = self.nvim.exec_lua(lua, *args)
        for _ in range(SYMBOL_RETRIES - 1):
            try:
                if json.loads(result).get("count", 0) > 0:
                    break
            except (ValueError, TypeError):
                break
            time.sleep(SYMBOL_SETTLE_S)
            result = self.nvim.exec_lua(lua, *args)
        return result

    def _exec_document_symbols(self, file_path: str) -> str:
        try:
            self._open_file(file_path)
            if not self._wait_for_lsp():
                return json.dumps({"error": "LSP not available", "file": file_path})

            lua = """
                local timeout_ms = select(1, ...)
                local params = {textDocument = vim.lsp.util.make_text_document_params(0)}

                local results = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, timeout_ms)
                if not results or vim.tbl_isempty(results) then
                    return vim.json.encode({symbols = {}, count = 0})
                end

                local symbols = {}

                -- SymbolInformation ranges (e.g. pylsp) start at the def/class
                -- keyword, not the identifier — so a downstream references /
                -- definition call at that column finds nothing. Refine the
                -- column to the name's position on that line (current buffer).
                local function name_col(lnum0, start_char, name)
                    local lines = vim.api.nvim_buf_get_lines(0, lnum0, lnum0 + 1, false)
                    local line = lines[1]
                    if line and name then
                        local idx = line:find(name, 1, true)
                        if idx then return idx end
                    end
                    return start_char + 1
                end

                -- documentSymbol may return hierarchical DocumentSymbol[] (with
                -- .selectionRange/.children) or flat SymbolInformation[] (with
                -- .location); handle both and flatten nested nodes.
                local function add(sym, container)
                    if sym.location then
                        local range = sym.location.range
                        table.insert(symbols, {
                            name      = sym.name,
                            kind      = vim.lsp.protocol.SymbolKind[sym.kind] or sym.kind,
                            container = sym.containerName or container,
                            line      = range.start.line + 1,
                            col       = name_col(range.start.line, range.start.character, sym.name),
                        })
                    else
                        -- selectionRange already targets the identifier
                        local range = sym.selectionRange or sym.range
                        table.insert(symbols, {
                            name      = sym.name,
                            kind      = vim.lsp.protocol.SymbolKind[sym.kind] or sym.kind,
                            container = container,
                            line      = range.start.line + 1,
                            col       = range.start.character + 1,
                        })
                        if sym.children then
                            for _, child in ipairs(sym.children) do
                                add(child, sym.name)
                            end
                        end
                    end
                end

                for _, resp in pairs(results) do
                    if resp.result then
                        for _, sym in ipairs(resp.result) do
                            add(sym, nil)
                        end
                    end
                end

                return vim.json.encode({symbols = symbols, count = #symbols})
                """
            return self._poll_symbols(lua, LSP_REQUEST_TIMEOUT_MS)
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_references(self, file_path: str, line: int, col: int) -> str:
        try:
            self._open_file(file_path)
            if not self._wait_for_lsp():
                return json.dumps({"error": "LSP not available", "file": file_path})

            self.nvim.api.win_set_cursor(0, [line, col - 1])

            result = self.nvim.exec_lua(
                """
                local timeout_ms = select(1, ...)
                local params = vim.lsp.util.make_position_params(0)
                params.context = {includeDeclaration = true}

                local results = vim.lsp.buf_request_sync(0, "textDocument/references", params, timeout_ms)
                if not results or vim.tbl_isempty(results) then
                    return vim.json.encode({references = {}, count = 0})
                end

                local refs = {}
                for _, resp in pairs(results) do
                    if resp.result then
                        for _, loc in ipairs(resp.result) do
                            table.insert(refs, {
                                file = vim.uri_to_fname(loc.uri or loc.targetUri),
                                line = loc.range.start.line + 1,
                                col  = loc.range.start.character + 1,
                            })
                        end
                    end
                end

                return vim.json.encode({references = refs, count = #refs})
                """,
                LSP_REQUEST_TIMEOUT_MS,
            )
            return result
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_definition(self, file_path: str, line: int, col: int) -> str:
        try:
            self._open_file(file_path)
            if not self._wait_for_lsp():
                return json.dumps({"error": "LSP not available", "file": file_path})

            self.nvim.api.win_set_cursor(0, [line, col - 1])

            result = self.nvim.exec_lua(
                """
                local timeout_ms = select(1, ...)
                local params = vim.lsp.util.make_position_params(0)

                local results = vim.lsp.buf_request_sync(0, "textDocument/definition", params, timeout_ms)
                if not results or vim.tbl_isempty(results) then
                    return vim.json.encode({definitions = {}, count = 0})
                end

                local defs = {}
                for _, resp in pairs(results) do
                    if resp.result then
                        local locations = vim.islist(resp.result) and resp.result or {resp.result}
                        for _, loc in ipairs(locations) do
                            local uri = loc.uri or loc.targetUri
                            local range = loc.range or loc.targetSelectionRange or loc.targetRange
                            if uri and range then
                                table.insert(defs, {
                                    file = vim.uri_to_fname(uri),
                                    line = range.start.line + 1,
                                    col  = range.start.character + 1,
                                })
                            end
                        end
                    end
                end

                return vim.json.encode({definitions = defs, count = #defs})
                """,
                LSP_REQUEST_TIMEOUT_MS,
            )
            return result
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_code_action(
        self, file_path: str, line: int, col: int, execute_index: int = None
    ) -> str:
        try:
            self._open_file(file_path)
            if not self._wait_for_lsp():
                return json.dumps({"error": "LSP not available", "file": file_path})

            self.nvim.api.win_set_cursor(0, [line, col - 1])

            result = self.nvim.exec_lua(
                """
                local args = {...}
                local execute_index = args[1]
                local timeout_ms = args[2]
                local params = vim.lsp.util.make_range_params(0)
                params.context = {diagnostics = vim.diagnostic.get(0, {lnum = vim.api.nvim_win_get_cursor(0)[1] - 1})}

                local results = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, timeout_ms)
                if not results or vim.tbl_isempty(results) then
                    return vim.json.encode({actions = {}, count = 0})
                end

                -- Collect action objects once in a deterministic client-id order.
                -- results is keyed by client_id and pairs() order is not stable, so
                -- sort the keys to keep the display list and the execution list aligned
                -- (otherwise execute_index could apply a different action than shown).
                local client_ids = vim.tbl_keys(results)
                table.sort(client_ids)
                local all_actions = {}
                for _, cid in ipairs(client_ids) do
                    local resp = results[cid]
                    if resp.result then
                        for _, action in ipairs(resp.result) do
                            table.insert(all_actions, action)
                        end
                    end
                end

                -- Build the display list from that same ordered collection
                local actions = {}
                for _, action in ipairs(all_actions) do
                    table.insert(actions, {
                        title = action.title,
                        kind  = action.kind,
                    })
                end

                -- Execute a specific action if requested.
                -- NOTE: a nil execute_index arrives from pynvim as vim.NIL (userdata),
                -- which is truthy in Lua, so type-check rather than rely on truthiness.
                if type(execute_index) == "number" and execute_index >= 1 and execute_index <= #actions then
                    local chosen = all_actions[execute_index]
                    if chosen.edit then
                        vim.lsp.util.apply_workspace_edit(chosen.edit, "utf-8")
                    end
                    if chosen.command then
                        vim.lsp.buf.execute_command(chosen.command)
                    end
                    vim.cmd("wall")
                    return vim.json.encode({
                        executed = true,
                        action   = actions[execute_index],
                        all_actions = actions,
                    })
                end

                return vim.json.encode({actions = actions, count = #actions})
                """,
                execute_index,
                LSP_REQUEST_TIMEOUT_MS,
            )
            return result
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_get_node(self, file_path: str, line: int, node_type: str) -> str:
        try:
            self._open_file(file_path)
            # Force treesitter to parse the buffer (headless mode doesn't auto-parse)
            self.nvim.exec_lua("vim.treesitter.get_parser(0):parse(true)")
            self.nvim.api.win_set_cursor(0, [line, 0])

            result = self.nvim.exec_lua(
                """
                local target_type = select(1, ...)
                local node = vim.treesitter.get_node()

                if not node then
                    return vim.json.encode({error = "No treesitter node at cursor"})
                end

                -- Walk up to find the target node type
                while node do
                    if node:type() == target_type then
                        break
                    end
                    node = node:parent()
                end

                if not node then
                    return vim.json.encode({error = "No " .. target_type .. " node found at or above cursor"})
                end

                local text = vim.treesitter.get_node_text(node, 0)
                local start_row, start_col, end_row, end_col = node:range()

                return vim.json.encode({
                    node_type  = node:type(),
                    text       = text,
                    start_line = start_row + 1,
                    start_col  = start_col + 1,
                    end_line   = end_row + 1,
                    end_col    = end_col + 1,
                })
                """,
                node_type,
            )
            return result
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})
        finally:
            self._close_buffer()

    def _exec_jq(self, file_path: str, query: str) -> str:
        try:
            result = subprocess.run(
                ["jq", query, file_path],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode != 0:
                return json.dumps(
                    {"error": result.stderr.strip(), "file": file_path, "query": query}
                )
            return json.dumps(
                {"file": file_path, "query": query, "result": result.stdout.strip()}
            )
        except FileNotFoundError:
            return json.dumps({"error": "jq not found in PATH"})
        except subprocess.TimeoutExpired:
            return json.dumps(
                {"error": "jq timed out", "file": file_path, "query": query}
            )
        except Exception as exc:
            return json.dumps({"error": str(exc), "file": file_path})

    # ── MCP protocol ─────────────────────────────────────────────────────

    async def handle_message(self, message: Dict[str, Any]) -> Dict[str, Any]:
        """Handle incoming MCP JSON-RPC messages."""
        method = message.get("method")
        params = message.get("params", {})
        msg_id = message.get("id")

        if method == "initialize":
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "mcp-nvim-server", "version": "0.1.0"},
                },
            }

        if method == "notifications/initialized":
            # Acknowledgement — no response required for notifications
            return None

        if method == "tools/list":
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "tools": [
                        {
                            "name": t.name,
                            "description": t.description,
                            "inputSchema": t.inputSchema,
                            **(
                                {"_meta": {"anthropic/alwaysLoad": True}}
                                if t.always_load
                                else {}
                            ),
                        }
                        for t in self.tools.values()
                    ]
                },
            }

        if method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments", {})
            if tool_name in self.tools:
                result = await self.execute_tool(tool_name, arguments)
                return {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {"content": [{"type": "text", "text": result}]},
                }

        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "error": {"code": -32601, "message": f"Method not found: {method}"},
        }

    async def run(self):
        """Run the MCP server using stdio transport."""
        while True:
            try:
                line = await asyncio.get_running_loop().run_in_executor(
                    None, sys.stdin.readline
                )
                if not line:
                    break

                message = json.loads(line.strip())
                response = await self.handle_message(message)
                if response is not None:
                    print(json.dumps(response), flush=True)
            except json.JSONDecodeError:
                continue
            except Exception as exc:
                error_response = {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32603, "message": f"Internal error: {str(exc)}"},
                }
                print(json.dumps(error_response), flush=True)


if __name__ == "__main__":
    server = NvimMCPServer()
    asyncio.run(server.run())
