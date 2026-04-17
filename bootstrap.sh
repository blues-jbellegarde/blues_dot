#!/usr/bin/env bash
# Installs just, then hands off to `just bootstrap`
set -euo pipefail

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
        echo "Error: Windows is not supported. Use WSL." >&2
        exit 1
        ;;
esac

if command -v just >/dev/null 2>&1; then
    echo "just already installed"
elif [[ "$(uname)" == "Darwin" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    brew install just
else
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

just bootstrap
