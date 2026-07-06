# Dotfiles management recipes

nvim_socket := env("HOME") / ".cache/nvim-claude/nvim-claude.sock"
os := if os() == "macos" { "macos" } else if os() == "windows" { error("Windows is not supported. Use WSL.") } else { `cat /etc/os-release 2>/dev/null | grep ^ID= | cut -d= -f2 | tr -d '"'` }

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
claude-deploy: (check-deps "rsync" "uv") claude-register-mcp
    @echo "Deploying dotfiles → ~/.claude/"
    rsync -a --exclude '.venv' --exclude '__pycache__' claude/ ~/.claude/
    cd ~/.claude/mcp-nvim-server && uv sync

# Register the neovim MCP server (user scope) — idempotent
claude-register-mcp: (check-deps "claude")
    #!/usr/bin/env bash
    set -euo pipefail
    # Re-register so the command path/args stay in sync with this repo.
    claude mcp remove neovim -s user 2>/dev/null || true
    claude mcp add neovim -s user -- "$HOME/.claude/mcp-nvim-server/start-server.sh"
    echo "Registered neovim MCP server (user scope)"

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

# --- Bootstrap recipes ---

# Bootstrap a new machine from scratch
bootstrap: install-packages setup-shell setup-pyenv setup-python setup-nvm setup-uv stow-all setup-claude
    @echo "Bootstrap complete!"

# Install system packages via OS package manager
install-packages:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname)" != "Darwin" ]]; then
        sudo -v || { echo "Error: bootstrap requires sudo on Linux for package installation." >&2; exit 1; }
    fi
    case "{{ os }}" in
        macos)
            brew bundle --file=Brewfile
            ;;
        ubuntu|debian)
            sudo apt update
            sudo apt install -y \
                stow git gh just eza ripgrep fd-find fzf jq curl wget zsh rsync \
                golang podman fuse \
                build-essential libssl-dev libbz2-dev libreadline-dev libsqlite3-dev \
                libffi-dev liblzma-dev zlib1g-dev tk-dev
            # fd-find installs as fdfind on Debian/Ubuntu
            if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
                mkdir -p "$HOME/.local/bin"
                ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
            fi
            ;;
        fedora)
            sudo dnf install -y \
                stow git gh just eza ripgrep fd-find fzf jq curl wget zsh rsync \
                golang podman fuse \
                gcc make zlib-devel bzip2-devel readline-devel sqlite-devel \
                openssl-devel libffi-devel xz-devel tk-devel
            ;;
        arch)
            sudo pacman -S --needed --noconfirm \
                stow neovim git github-cli just eza ripgrep fd fzf jq curl wget zsh rsync \
                go podman fuse2 \
                base-devel openssl zlib xz tk
            ;;
        *)
            echo "Error: unsupported OS '{{ os }}'. Supported: macos, ubuntu, debian, fedora, arch" >&2
            exit 1
            ;;
    esac
    # Install latest stable Neovim via AppImage on Linux (distro packages are too old for 0.11+ APIs)
    if [[ "$(uname)" != "Darwin" ]] && ! nvim --version 2>/dev/null | head -1 | grep -qE 'v0\.(1[1-9]|[2-9][0-9])'; then
        echo "Installing Neovim via AppImage..."
        curl -Lo /tmp/nvim.appimage "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$(uname -m).appimage"
        chmod +x /tmp/nvim.appimage
        sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
    fi
    echo "Packages installed for {{ os }}"

# Install oh-my-zsh and set zsh as default shell
setup-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        # Remove OMZ's default .zshrc — stow-all will provide ours
        rm -f "$HOME/.zshrc"
    else
        echo "Oh My Zsh already installed"
    fi
    if [[ "$(uname)" != "Darwin" ]] && [[ "$SHELL" != */zsh ]]; then
        echo "Setting zsh as default shell..."
        sudo chsh -s "$(which zsh)" "$(whoami)"
    fi

# Install pyenv and pyenv-virtualenv
setup-pyenv:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v pyenv >/dev/null 2>&1; then
        echo "pyenv already installed: $(pyenv --version)"
    else
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
        echo "pyenv installed: $(pyenv --version)"
    fi

# Install latest stable Python + create neovim venv (bootstrap; keeps an existing venv)
setup-python: (_neovim-python "keep")

# Upgrade to the latest stable Python and rebuild the neovim venv fresh (pynvim only)
upgrade-python: (_neovim-python "rebuild")

# Ensure latest stable Python is installed/global and the neovim venv exists with pynvim.
# mode="keep" preserves an existing venv; mode="rebuild" deletes and recreates it.
[private]
_neovim-python mode="keep":
    #!/usr/bin/env bash
    set -euo pipefail
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"

    # Find latest stable Python (not dev/alpha/beta/rc)
    latest=$(pyenv install --list | grep -E '^\s+[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
    echo "Latest stable Python: $latest"

    # Install if not present
    if pyenv versions --bare | grep -Fqx "$latest"; then
        echo "Python $latest already installed"
    else
        echo "Installing Python $latest..."
        pyenv install -s "$latest"
    fi
    pyenv global "$latest"

    # In rebuild mode, drop any existing neovim venv so it is recreated on $latest
    if [[ "{{ mode }}" == "rebuild" ]] && pyenv virtualenvs --bare | grep -Fqx neovim; then
        echo "Removing existing neovim virtualenv for rebuild..."
        pyenv virtualenv-delete -f neovim
    fi

    # Create neovim venv if not present
    if pyenv virtualenvs --bare | grep -Fqx neovim; then
        echo "neovim virtualenv already exists"
    else
        echo "Creating neovim virtualenv on $latest..."
        pyenv virtualenv "$latest" neovim
    fi

    # Install/upgrade pynvim
    echo "Installing pynvim in neovim venv..."
    PYENV_VERSION=neovim pyenv exec pip install --upgrade pip pynvim

# Install nvm and latest LTS Node
setup-nvm:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "${XDG_CONFIG_HOME-}" ]]; then
        export NVM_DIR="$HOME/.nvm"
    else
        export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
    fi
    if [[ -d "$NVM_DIR" ]]; then
        echo "nvm already installed"
    else
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    fi
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    echo "Installing latest LTS Node..."
    nvm install --lts

# Install uv (Python package manager)
setup-uv:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v uv >/dev/null 2>&1; then
        echo "uv already installed: $(uv --version)"
    else
        echo "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

# Stow dotfiles packages (OS-aware)
stow-all: (check-deps "stow")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Stowing universal packages..."
    stow --restow zsh nvim git sqlfluff pylint
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "Stowing macOS packages..."
        stow --restow wezterm aerospace
    fi
    echo "Stow complete"

# Install Claude Code CLI, deploy config, start headless nvim
setup-claude: (check-deps "rsync" "uv")
    #!/usr/bin/env bash
    set -euo pipefail
    # Install Claude Code CLI
    if command -v claude >/dev/null 2>&1; then
        echo "Claude Code already installed: $(claude --version)"
    else
        echo "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
    fi
    # Deploy config
    echo "Deploying Claude Code config..."
    rsync -a --exclude '.venv' --exclude '__pycache__' claude/ ~/.claude/
    cd ~/.claude/mcp-nvim-server && uv sync
    # Register the neovim MCP server (user scope, idempotent)
    echo "Registering neovim MCP server..."
    claude mcp remove neovim -s user 2>/dev/null || true
    claude mcp add neovim -s user -- "$HOME/.claude/mcp-nvim-server/start-server.sh"
    # Start headless nvim
    echo "Starting headless nvim..."
    nvim --server {{ nvim_socket }} --remote-send ':qa!<CR>' 2>/dev/null || true
    rm -f {{ nvim_socket }}
    mkdir -p "$(dirname {{ nvim_socket }})" && chmod 700 "$(dirname {{ nvim_socket }})"
    nvim --headless --listen {{ nvim_socket }} -c 'set noswapfile' &
    echo "Claude Code setup complete"

# Test bootstrap in a clean Linux container
test-bootstrap distro="ubuntu": (check-deps "podman")
    podman build -f test/Dockerfile.{{ distro }} -t dotfiles-test-{{ distro }} .
