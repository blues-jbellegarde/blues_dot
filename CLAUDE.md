# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository named "blues_dot" designed to centralize and manage personal configuration files using GNU Stow for symlink management.

## Goals

Centralize personal configuration files using GNU Stow for symlink management and version control across machines.

Current status: Fully configured with 7 packages (zsh, nvim, git, wezterm, aerospace, sqlfluff, pylint)

## Development Context

This is an actively maintained dotfiles repository for a data engineer working primarily with:

- **Languages:** Python, Go, JavaScript/TypeScript, SQL (dbt + Redshift)
- **Tools:** Neovim, WezTerm, Aerospace WM
- **Version Managers:** pyenv, nvm
- **Focus:** Data engineering, analytics, dbt development

## Neovim Configuration

Located in `nvim/.config/nvim/` with lazy.nvim plugin manager.

**Structure:**

- `init.lua` - Entry point
- `lua/blues-nvim/config/` - Settings, keymaps, options
- `lua/blues-nvim/plugins/` - Plugin configs (core, lsp, util, extras)

**Keymap Placement (IMPORTANT):**

- **Vim/general keymaps** → `lua/blues-nvim/config/keymaps.lua` (navigation, editing, windows, etc.)
- **Plugin-specific keymaps** → Plugin file's `keys` spec (lazy-loading triggers)
  - Example: DAP keymaps in `nvim-dap.lua`, not in `keymaps.lua`
  - Rationale: Ensures plugins load before keymaps execute (prevents lazy-loading delays)
  - Pattern: Use lazy.nvim's `keys = { ... }` spec in plugin definitions

**Language Support:**

- Python: pylsp, black (88-char), pylint, debugpy, venv-selector
- Go: gopls, gofumpt, golangci-lint, delve
- TypeScript/JavaScript: ts_ls, prettier, eslint_d
- SQL/dbt: sqlfluff (Jinja templater, Redshift dialect)
- Lua: lua_ls, stylua, selene
- Bash: bashls, beautysh, shellcheck

**Key Tools:**

- LSP: mason.nvim + nvim-lspconfig
- Formatting: conform.nvim
- Linting: nvim-lint (respects project configs)
- Completion: nvim-cmp
- Debugging: nvim-dap + nvim-dap-python (debugpy, UV workspace support)
- Git: neogit, diffview
- Database: vim-dadbod
- AI: copilot.vim, gen.nvim

**Common Commands:**

- `:Mason` - Manage LSP servers/tools
- `:Lazy` - Manage plugins
- `<leader>ng` - Open Neogit
- `<leader>ff` - Find files
- `<leader>fs` - Live grep
- `<leader>fw` - Format file
- `<leader>ll` - Lint file
- `<leader>vs` - Select Python venv

**Debugging (DAP):**

- `<F5>` - Start/Continue debugging
- `<F10>` - Step over
- `<F11>` - Step into
- `<F12>` - Step out
- `<leader>db` - Toggle breakpoint
- `<leader>du` - Toggle DAP UI
- `<leader>dtm` - Debug Python test method

Project-specific configs (`.golangci.yml`, `.eslintrc`, `.sqlfluff`, `.prettierrc`, `pyproject.toml`) are automatically respected.

**Python Debugging with UV:**

- Each UV project requires `debugpy` as a dev dependency: `uv add --dev debugpy`
- venv-selector automatically detects `.venv` directories in UV workspaces
- DAP configurations dynamically update when switching venvs via `<leader>vs`
- Supports pytest, Django, and remote debugging configurations

## Claude Code Configuration

The `claude/` directory contains all user-managed Claude Code config. It is NOT a Stow package — Claude Code does not resolve symlinks. Instead, config is deployed via rsync.

**Management (via justfile):**

- `just claude-deploy` — deploy all config (settings, hooks, agents, skills, MCP server) to `~/.claude/` (also registers the MCP server)
- `just claude-register-mcp` — (re)register the `neovim` MCP server at user scope (idempotent; reproduces the entry a fresh machine needs)
- `just claude-pull` — pull config changes from `~/.claude/` back to dotfiles repo
- `just claude-nvim-status` — check headless nvim status
- `just claude-nvim-restart` — restart headless nvim after config changes
- `just claude-nvim-stop` — stop headless nvim

## Neovim Headless MCP Server

A custom MCP server (`claude/mcp-nvim-server/`) bridges Claude Code to a persistent Neovim headless instance, exposing LSP + treesitter navigation over the socket.

**Navigating code? Default to the semantic tools, not text search.** For anything involving a code symbol (function/class/method/variable), reach for the nvim tools first — they are semantic (no false hits in comments/strings), return exact positions, and cost ~80% fewer tokens than a grep dump.

| Goal                                    | Use                      | Instead of             |
| --------------------------------------- | ------------------------ | ---------------------- |
| Find a symbol by **name** (entry point) | `nvim_workspace_symbols` | `Grep` / `rg`          |
| See what one file defines (outline)     | `nvim_document_symbols`  | reading the whole file |
| All usages of a symbol                  | `nvim_references`        | `Grep`                 |
| Jump to a definition                    | `nvim_definition`        | `Grep`                 |
| Read one function from a big file       | `nvim_get_node`          | `Read`                 |
| Rename across files                     | `nvim_rename`            | grep + multi-file Edit |
| Auto-fix imports / apply a quick fix    | `nvim_code_action`       | hand-editing imports   |
| Extract from a large JSON file          | `jq`                     | reading the whole file |

Typical flow: `nvim_workspace_symbols` (name → file/line/col) → feed that position into `nvim_references` / `nvim_definition` / `nvim_get_node`. `nvim_workspace_symbols` needs `file_path` set to any file in the target repo of the same language (it anchors the LSP root).

**`Grep` / `Read` remain correct** for prose, logs, config, SQL/dbt, non-symbol text, and quick one-off pattern checks. A PreToolUse hook (`nudge-lsp.sh`) reminds you when a grep looks like a symbol search — it never blocks.

**Handled automatically by PostToolUse hook (no action needed):**

- Formatting via conform.nvim (black, prettier, gofumpt, stylua, etc.)
- Linting via nvim-lint (pylint, eslint_d, golangci-lint, selene, sqlfluff)
- Lint diagnostics appear in context — fix them before moving on

## Documentation

- GNU Stow documentation: https://www.gnu.org/software/stow/manual/stow.html
