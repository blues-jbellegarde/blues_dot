#!/usr/bin/env python3
"""PostToolUse hook: format and lint a file via headless Neovim after Claude edits."""

import json
import sys
import time

import pynvim

LINT_SETTLE_S = 1.0


def main():
    if len(sys.argv) != 3:
        sys.exit(0)

    socket_path = sys.argv[1]
    file_path = sys.argv[2]

    try:
        nvim = pynvim.attach("socket", path=socket_path)
    except Exception:
        sys.exit(0)

    try:
        escaped = nvim.funcs.fnameescape(file_path)
        nvim.command(f"edit {escaped}")

        # Format via conform.nvim
        nvim.exec_lua('require("conform").format({bufnr = 0, async = false})')
        nvim.command("write")

        # Lint via nvim-lint
        nvim.exec_lua('require("lint").try_lint()')
        time.sleep(LINT_SETTLE_S)

        # Collect diagnostics (matches server's _get_diagnostics_json)
        diags_json = nvim.exec_lua("""
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

        diagnostics = json.loads(diags_json)
        if diagnostics:
            print(json.dumps({"file": file_path, "diagnostics": diagnostics}, indent=2))
    except Exception as exc:
        print(json.dumps({"error": str(exc), "file": file_path}), file=sys.stderr)
    finally:
        try:
            nvim.command("bdelete!")
        except Exception:
            pass


if __name__ == "__main__":
    main()
