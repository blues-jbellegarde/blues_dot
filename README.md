# blues_dot

Personal dotfiles managed with GNU Stow and bootstrapped with just.

## Quick Start

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs `just` (and Homebrew on macOS if needed), then runs `just bootstrap`.

## Supported Platforms

- macOS (Homebrew)
- Ubuntu / Debian (apt)
- Fedora (dnf)
- Arch Linux (pacman)

## Bootstrap Steps

`just bootstrap` runs these in order:

1. `install-packages` — system packages via OS package manager
2. `setup-shell` — Oh My Zsh, set zsh as default shell
3. `setup-pyenv` — pyenv + pyenv-virtualenv
4. `setup-python` — latest stable Python, dedicated neovim virtualenv with pynvim
5. `setup-nvm` — nvm + latest LTS Node
6. `setup-uv` — uv package manager
7. `stow-all` — symlink dotfiles packages
8. `setup-claude` — Claude Code CLI, config deployment, headless nvim

Each recipe is idempotent and can be run independently.

## Packages

| Package   | Description                                       | Platform |
| --------- | ------------------------------------------------- | -------- |
| zsh       | Shell configuration with Oh My Zsh                | all      |
| nvim      | Neovim configuration (lazy.nvim)                  | all      |
| git       | Git configuration + global gitignore              | all      |
| sqlfluff  | SQL linting (dbt/Redshift)                        | all      |
| pylint    | Python linting                                    | all      |
| wezterm   | Terminal emulator                                 | macOS    |
| aerospace | Window manager                                    | macOS    |
| claude    | Claude Code config (deployed via rsync, not stow) | all      |

## Recipes

| Recipe                | Description                              |
| --------------------- | ---------------------------------------- |
| `bootstrap`           | Full machine setup                       |
| `install-packages`    | System packages via OS package manager   |
| `setup-shell`         | Oh My Zsh + set zsh as default           |
| `setup-pyenv`         | Install pyenv and pyenv-virtualenv       |
| `setup-python`        | Latest stable Python + neovim venv       |
| `setup-nvm`           | nvm + latest LTS Node                    |
| `setup-uv`            | uv package manager                       |
| `stow-all`            | Symlink dotfiles (OS-aware)              |
| `setup-claude`        | Claude Code CLI + config + headless nvim |
| `claude-deploy`       | Deploy Claude Code config to ~/.claude/  |
| `claude-pull`         | Pull Claude Code config back to repo     |
| `claude-nvim-restart` | Restart headless nvim                    |
| `claude-nvim-stop`    | Stop headless nvim                       |
| `claude-nvim-status`  | Check headless nvim status               |
| `test-bootstrap`      | Test bootstrap in a Linux container      |

## Testing

```bash
just test-bootstrap ubuntu
just test-bootstrap fedora
just test-bootstrap arch
```

Runs `podman build` against clean container images. Arch requires x86_64 (no ARM64 image available).

## Manual Stow

```bash
stow <package>          # symlink a package
stow -D <package>       # remove symlinks
stow -R <package>       # restow (remove + recreate)
```

## License

MIT
