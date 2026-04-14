# Dotfiles management recipes

nvim_socket := env("HOME") / ".cache/nvim-claude/nvim-claude.sock"

# Check that required tools are installed (platform-agnostic)
[private]
check-deps *deps:
    #!/usr/bin/env bash
    missing=()
    for cmd in {{ deps }}; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing required dependencies: ${missing[*]}"
        exit 1
    fi

# Deploy all Claude Code config to ~/.claude/
claude-deploy: (check-deps "rsync" "uv")
    @echo "Deploying dotfiles → ~/.claude/"
    rsync -a --exclude '.venv' --exclude '__pycache__' claude/ ~/.claude/
    cd ~/.claude/mcp-nvim-server && uv sync

# Pull Claude Code config changes back to dotfiles repo
claude-pull: (check-deps "rsync")
    @echo "Pulling ~/.claude/ → dotfiles"
    rsync -a ~/.claude/CLAUDE.md claude/CLAUDE.md
    rsync -a ~/.claude/settings.json claude/settings.json
    rsync -a ~/.claude/analytics-statusline.sh claude/analytics-statusline.sh
    rsync -a ~/.claude/hooks/ claude/hooks/
    rsync -a ~/.claude/agents/ claude/agents/
    rsync -a ~/.claude/skills/ claude/skills/
    rsync -a ~/.claude/reference/ claude/reference/
    rsync -a --exclude '.venv' --exclude '__pycache__' ~/.claude/mcp-nvim-server/ claude/mcp-nvim-server/

# Stop the headless nvim instance
claude-nvim-stop:
    nvim --server {{ nvim_socket }} --remote-send ':qa!<CR>' 2>/dev/null || true
    rm -f {{ nvim_socket }}

# Restart headless nvim (after config changes)
claude-nvim-restart: (check-deps "nvim") claude-nvim-stop
    mkdir -p "$(dirname {{ nvim_socket }})" && chmod 700 "$(dirname {{ nvim_socket }})"
    nvim --headless --listen {{ nvim_socket }} -c 'set noswapfile' &

# Check headless nvim status
claude-nvim-status: (check-deps "nvim")
    @nvim --server {{ nvim_socket }} --remote-expr 'v:version' 2>/dev/null \
        && echo "Headless nvim is running" \
        || echo "Headless nvim is not running"
