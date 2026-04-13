#!/bin/bash
# Start the Neovim headless MCP server.
# Auto-starts a headless Neovim instance if one is not already listening.

SOCKET="${NVIM_SOCKET:-/tmp/nvim-claude.sock}"

# Start headless nvim if not already running
if ! nvim --server "$SOCKET" --remote-expr 'v:version' &>/dev/null; then
    rm -f "$SOCKET"
    nvim --headless --listen "$SOCKET" -c 'set noswapfile' &
    # Wait for socket to become available
    for _ in $(seq 1 30); do
        nvim --server "$SOCKET" --remote-expr 'v:version' &>/dev/null && break
        sleep 0.1
    done
fi

# Start MCP server
cd "$(dirname "$0")"
exec uv run python nvim_mcp_server.py
