#!/bin/bash
# PostToolUse hook: auto-format and auto-lint files after Claude's Edit/Write.
# Reads the edited file path from hook input JSON, formats and lints via
# the headless Neovim instance, outputs lint diagnostics to stdout.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

SOCKET="${NVIM_SOCKET:-/tmp/nvim-claude.sock}"

# Skip silently if headless nvim is not running
if ! nvim --server "$SOCKET" --remote-expr 'v:version' &>/dev/null; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

exec uv run --directory "$SCRIPT_DIR" python -c "
import pynvim, json, sys, time

socket_path = '$SOCKET'
file_path = '$FILE_PATH'

try:
    nvim = pynvim.attach('socket', path=socket_path)
    nvim.command(f'edit {file_path}')

    # Format via conform.nvim
    nvim.exec_lua('require(\"conform\").format({bufnr = 0, async = false})')
    nvim.command('write')

    # Lint via nvim-lint
    nvim.exec_lua('require(\"lint\").try_lint()')
    time.sleep(1)  # Allow async linters to finish

    # Collect diagnostics
    diags_json = nvim.exec_lua('''
        local diags = vim.diagnostic.get(0)
        local results = {}
        for _, d in ipairs(diags) do
            table.insert(results, {
                line     = d.lnum + 1,
                col      = d.col + 1,
                message  = d.message,
                severity = d.severity,
                source   = d.source,
            })
        end
        return vim.json.encode(results)
    ''')

    nvim.command('bdelete!')

    diagnostics = json.loads(diags_json)
    if diagnostics:
        print(json.dumps({'file': file_path, 'diagnostics': diagnostics}, indent=2))
except Exception as exc:
    print(json.dumps({'error': str(exc), 'file': file_path}), file=sys.stderr)
"
