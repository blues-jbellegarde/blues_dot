# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository named "blues_dot" designed to centralize and manage personal configuration files using GNU Stow for symlink management.

## Goals

Centralize personal configuration files using GNU Stow for symlink management and version control across machines.

Current status: Fully configured with 7 packages (zsh, nvim, git, wezterm, aerospace, sqlfluff, pylint)

## Development Context

This is an actively maintained dotfiles repository for a data engineer working primarily with:
- **Languages:** Python, Go, JavaScript/TypeScript, SQL (dbt + Redshift)
- **Tools:** Neovim, WezTerm, Aerospace WM
- **Version Managers:** pyenv, nvm, jenv, rbenv
- **Focus:** Data engineering, analytics, dbt development

## Neovim Configuration

Located in `nvim/.config/nvim/` with lazy.nvim plugin manager.

**Structure:**
- `init.lua` - Entry point
- `lua/blues-nvim/config/` - Settings, keymaps, options
- `lua/blues-nvim/plugins/` - Plugin configs (core, lsp, util, extras)

**Language Support:**
- Python: pylsp, black (88-char), pylint, debugpy, venv-selector
- Go: gopls, gofumpt, golangci-lint, delve
- TypeScript/JavaScript: ts_ls, prettier, eslint_d
- SQL/dbt: sqlls, sqlfluff (Jinja templater, Redshift dialect)
- Lua: lua_ls, stylua, selene
- Bash: bashls, beautysh, shellcheck

**Key Tools:**
- LSP: mason.nvim + nvim-lspconfig
- Formatting: conform.nvim
- Linting: nvim-lint (respects project configs)
- Completion: nvim-cmp
- Git: neogit, diffview
- Database: vim-dadbod
- AI: copilot.vim, gen.nvim

**Common Commands:**
- `:Mason` - Manage LSP servers/tools
- `:Lazy` - Manage plugins
- `<leader>ng` - Open Neogit
- `<leader>ff` - Find files
- `<leader>fs` - Live grep
- `<leader>fw` - Format file
- `<leader>ll` - Lint file
- `<leader>vs` - Select Python venv

Project-specific configs (`.golangci.yml`, `.eslintrc`, `.sqlfluff`, `.prettierrc`, `pyproject.toml`) are automatically respected.

## Documentation

- GNU Stow documentation: https://www.gnu.org/software/stow/manual/stow.html