#!/bin/bash
# PostToolUse hook: auto-format and auto-lint files after Claude's Edit/Write.
# Reads the edited file path from hook input JSON, delegates to post_edit_hook.py.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

SOCKET="${NVIM_SOCKET:-${HOME}/.cache/nvim-claude/nvim-claude.sock}"

# Skip silently if headless nvim is not running
if ! nvim --server "$SOCKET" --remote-expr 'v:version' &>/dev/null; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

exec uv run --directory "$SCRIPT_DIR" python post_edit_hook.py "$SOCKET" "$FILE_PATH"
