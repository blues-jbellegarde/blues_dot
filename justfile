# Dotfiles management recipes

nvim_socket := env("HOME") / ".cache/nvim-claude/nvim-claude.sock"

# Deploy nvim MCP server to ~/.claude/
claude-deploy:
    rm -rf ~/.claude/mcp-nvim-server
    rsync -a --exclude '.venv' claude/mcp-nvim-server/ ~/.claude/mcp-nvim-server/
    cd ~/.claude/mcp-nvim-server && uv sync

# Stop the headless nvim instance
claude-nvim-stop:
    nvim --server {{ nvim_socket }} --remote-send ':qa!<CR>' 2>/dev/null || true
    rm -f {{ nvim_socket }}

# Restart headless nvim (after config changes)
claude-nvim-restart: claude-nvim-stop
    mkdir -p "$(dirname {{ nvim_socket }})" && chmod 700 "$(dirname {{ nvim_socket }})"
    nvim --headless --listen {{ nvim_socket }} -c 'set noswapfile' &

# Check headless nvim status
claude-nvim-status:
    @nvim --server {{ nvim_socket }} --remote-expr 'v:version' 2>/dev/null \
        && echo "Headless nvim is running" \
        || echo "Headless nvim is not running"
