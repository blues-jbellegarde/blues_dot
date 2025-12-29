# blues_dot

Personal dotfiles repository managed with GNU Stow for easy symlink management.

## Overview

This repository centralizes personal configuration files and provides version control for dotfiles across multiple machines. It uses GNU Stow to create symlinks from the repository to the appropriate locations in the home directory.

## Structure

The repository is organized into packages (subdirectories) that mirror the target directory structure:

```
~/.dotfiles/
├── package1/           # Configuration package
│   └── .config/        # Target: ~/.config/
│       └── .datefile   # Target: ~/.dotfile
└── package2/           # Another package
    └── .dotfile        # Target: ~/.dotfile
```

## Usage

### Installing dotfiles

```bash
# Navigate to the dotfiles directory
cd ~/.dotfiles

# Install a specific package
stow <package-name>

# Install all packages
stow */
```

### Managing packages

```bash
# Remove symlinks for a package
stow -D <package-name>

# Restow (remove then recreate) symlinks
stow -R <package-name>
```

## Current Packages

Currently configured packages:

- nvim - Neovim configuration
- zsh - Shell configuration with Oh My Zsh
- git - Git configuration
- wezterm - Terminal emulator configuration
- aerospace - Window manager configuration
- sqlfluff - SQL linting configuration (dbt-aware with Jinja templater)
- pylint - Python linting configuration

## Requirements

- GNU Stow (install with `brew install stow` on macOS)

## License

MIT

