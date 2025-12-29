# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository named "blues_dot" designed to centralize and manage personal configuration files using GNU Stow for symlink management.

## Goals

The primary goal of this repository is to:
1. Move dotfiles from the home directory (`~`) and config folder (`~/.config`) into this centralized repository
2. Use GNU Stow to create symlinks from this repository back to the appropriate locations in the home directory and config folder
3. Provide version control and backup for personal configuration files
4. Enable easy deployment of dotfiles across multiple machines

Current status: Fully configured with 7 packages (zsh, nvim, git, wezterm, aerospace, sqlfluff, pylint)

## Repository Structure

The repository contains 7 main packages, each organized to mirror the target directory structure:

### Packages

1. **zsh** - Shell configuration with Oh My Zsh, pyenv, nvm, jenv, rbenv, juliaup
2. **nvim** - Comprehensive Neovim configuration (see Neovim section below)
3. **git** - Git configuration and global gitignore
4. **wezterm** - Terminal emulator configuration with Solarized Osaka colorscheme
5. **aerospace** - i3-style tiling window manager for macOS
6. **sqlfluff** - SQL linting configuration (dbt-aware with Jinja templater, Redshift dialect)
7. **pylint** - Python linting configuration

## Development Context

This is an actively maintained dotfiles repository for a data engineer working primarily with:
- **Languages:** Python, Go, JavaScript/TypeScript, SQL (dbt + Redshift)
- **Tools:** Neovim, WezTerm, Aerospace WM
- **Version Managers:** pyenv, nvm, jenv, rbenv
- **Focus:** Data engineering, analytics, dbt development

## Neovim Configuration

Located in `nvim/.config/nvim/`, this repository includes a comprehensive Neovim configuration built with modern 2025 best practices.

### Structure
- **Entry Point**: `init.lua` loads config and plugins
- **Configuration**: `lua/blues-nvim/config/` - settings, keymaps, options
- **Plugin System**: lazy.nvim for plugin management
- **Plugin Organization**:
  - `lua/blues-nvim/plugins/core/` - Essential plugins (telescope, treesitter, colorscheme)
  - `lua/blues-nvim/plugins/lsp/` - LSP and language tooling
  - `lua/blues-nvim/plugins/util/` - Development utilities (cmp, conform, lualine)
  - `lua/blues-nvim/plugins/extras/` - Optional features

### Key Technologies
- **LSP**: mason.nvim + mason-lspconfig.nvim + nvim-lspconfig (mason handlers pattern)
- **Languages**:
  - Python (pylsp, black, pylint, debugpy)
  - Go (gopls, gofumpt, golangci-lint, delve)
  - TypeScript/JavaScript (ts_ls, eslint_d, prettier)
  - SQL (sqlls, sqlfluff with dbt Jinja templater, Redshift dialect)
  - Lua (lua_ls, stylua, selene)
  - Bash (bashls, beautysh, shellcheck)
- **Formatting**: conform.nvim with language-specific formatters
- **Linting**: nvim-lint with project-aware linters
- **Completion**: nvim-cmp with LSP, LuaSnip, buffer, path sources
- **Git**: neogit (primary), diffview
- **Database**: vim-dadbod + vim-dadbod-ui
- **AI Assistants**: copilot.vim, gen.nvim (local Ollama models)

### Python Configuration
- Uses venv-selector.nvim for virtual environment management (lazy-loaded)
- Python host: `/Users/jbellegarde/.pyenv/versions/neovim/bin/python`
- Formatter: black (88-char line length)
- Linter: pylint (88-char line length, local module support)
- LSP: pylsp with black/pylint integration

### dbt/SQL Configuration
- sqlfluff with Jinja templater for dbt syntax support
- Redshift dialect (primary), with ClickHouse support
- Real-time linting via nvim-lint
- Recognizes dbt functions: {{ ref() }}, {{ source() }}, {{ var() }}, etc.

### Go Configuration
- LSP: gopls with gofumpt integration
- Formatter: gofumpt
- Linter: golangci-lint (matches work repo configuration)
- Debugger: delve

### TypeScript/JavaScript Configuration
- LSP: ts_ls with inlay hints
- Formatter: prettier
- Linter: eslint_d (daemon mode for speed)

### Common Tasks
- **LSP Management**: `:Mason` - Install/manage LSP servers and tools
- **Plugin Management**: `:Lazy` - Update/manage plugins
- **Git Interface**: `<leader>ng` - Open Neogit
- **File Finding**: `<leader>ff` - Telescope file finder
- **Grep Search**: `<leader>fs` - Telescope live grep
- **Format File**: `<leader>fw` - Format current file
- **Lint File**: `<leader>ll` - Lint current file
- **Venv Selector**: `<leader>vs` - Select Python virtual environment

### Project-Specific Tooling
The Neovim configuration automatically respects project-level configurations:
- **golangci-lint**: Reads `.golangci.yml` from project root
- **eslint**: Reads `.eslintrc` from project root
- **sqlfluff**: Reads `.sqlfluff` from project root
- **prettier**: Reads `.prettierrc` from project root
- **black**: Reads `pyproject.toml` from project root

This ensures your editor shows the same linting/formatting errors as your project's CI/CD pipeline.

## Key Points for Future Development

- This is a personal dotfiles repository following standard dotfiles conventions with GNU Stow for symlink management
- Files should be organized in packages (subdirectories) that mirror the target directory structure
- Use `stow <package-name>` to create symlinks from the repository to the home directory
- Use `stow -D <package-name>` to remove symlinks
- No build tools, test frameworks, or package managers are currently configured
- Standard git workflow applies for version control

## Common Commands

- `stow <package>` - Create symlinks for a package
- `stow -D <package>` - Remove symlinks for a package  
- `stow -R <package>` - Restow (remove then recreate) symlinks for a package

## Documentation

- GNU Stow documentation: https://www.gnu.org/software/stow/manual/stow.html