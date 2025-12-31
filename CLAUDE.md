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

**Keymap Placement (IMPORTANT):**
- **Vim/general keymaps** → `lua/blues-nvim/config/keymaps.lua` (navigation, editing, windows, etc.)
- **Plugin-specific keymaps** → Plugin file's `keys` spec (lazy-loading triggers)
  - Example: DAP keymaps in `nvim-dap.lua`, not in `keymaps.lua`
  - Rationale: Ensures plugins load before keymaps execute (prevents lazy-loading delays)
  - Pattern: Use lazy.nvim's `keys = { ... }` spec in plugin definitions

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
- Debugging: nvim-dap + nvim-dap-python (debugpy, UV workspace support)
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

**Debugging (DAP):**
- `<F5>` - Start/Continue debugging
- `<F10>` - Step over
- `<F11>` - Step into
- `<F12>` - Step out
- `<leader>db` - Toggle breakpoint
- `<leader>du` - Toggle DAP UI
- `<leader>dtm` - Debug Python test method

Project-specific configs (`.golangci.yml`, `.eslintrc`, `.sqlfluff`, `.prettierrc`, `pyproject.toml`) are automatically respected.

**Python Debugging with UV:**
- Each UV project requires `debugpy` as a dev dependency: `uv add --dev debugpy`
- venv-selector automatically detects `.venv` directories in UV workspaces
- DAP configurations dynamically update when switching venvs via `<leader>vs`
- Supports pytest, Django, and remote debugging configurations

## Documentation

- GNU Stow documentation: https://www.gnu.org/software/stow/manual/stow.html