# Version Controlling ~/.claude — Reference Guide

## Context

Research into best practices for version controlling the global Claude Code config directory (`~/.claude`), including symlink compatibility, the rules system, and dotfiles integration strategies.

---

## 1. What's in ~/.claude

### User-Created (safe to version control)

| File/Directory | Purpose |
|----------------|---------|
| `CLAUDE.md` | Global instructions applied to all projects |
| `settings.json` | Model preference (opus), statusline config |
| `agents/*.md` | Custom subagents (git-expert, web-researcher) |
| `skills/*/` | Custom skills (commit, pr, delete-branch) |
| `output-styles/*.md` | Custom output formatting templates |
| `analytics-statusline.sh` | Shell script for status line display |

### Auto-Generated / Sensitive (do NOT commit)

| File/Directory | Why exclude |
|----------------|-------------|
| `history.jsonl` | Conversation history (~299KB) |
| `backups/` | Full config snapshots, may contain secrets |
| `shell-snapshots/` | Zsh history dumps (~184KB each, 19+ files) |
| `todos/`, `tasks/` | Ephemeral session data |
| `session-env/` | Per-session environment snapshots |
| `telemetry/`, `debug/`, `statsig/` | Diagnostics/analytics |
| `plugins/` | Installed plugin data, may contain auth tokens |
| `cache/`, `paste-cache/`, `downloads/` | Temporary data |
| `projects/` | Project-specific context with encoded paths |
| `plans/` | Session-specific planning documents |
| `file-history/` | File change tracking |
| `mcp-needs-auth-cache.json` | MCP auth cache |
| `stats-cache.json` | Usage statistics |

### Critical: ~/.claude.json (NOT in ~/.claude/)

Located at `~/.claude.json` in the home directory. Contains OAuth tokens, API keys, MCP credentials. **Never commit this file.**

---

## 2. Symlink Compatibility

### Known Issues

| File/Directory | Symlink works? | Source |
|----------------|---------------|--------|
| `CLAUDE.md` | **No** | [GitHub #764](https://github.com/anthropics/claude-code/issues/764) (open, 55+ thumbs up) |
| `settings.json` | **No** | [GitHub #3575](https://github.com/anthropics/claude-code/issues/3575) — causes permission failures and performance degradation |
| `agents/` | **No** | No symlink resolution documented |
| `skills/` | **No** | [GitHub #10573](https://github.com/anthropics/claude-code/issues/10573) — broken in v2.0.28+ |
| `.claude/rules/` | **Yes** | Explicitly documented and supported |

### Rules Symlink Support (officially documented)

```bash
# Symlink a shared rules directory
ln -s ~/shared-claude-rules .claude/rules/shared

# Symlink individual rule files
ln -s ~/company-standards/security.md .claude/rules/security.md
```

Circular symlinks are detected and handled gracefully.

**Bottom line:** GNU Stow will only work reliably for `.claude/rules/`. All other config files fail when symlinked.

---

## 3. CLAUDE.md @import Directive

CLAUDE.md supports inline file imports using `@path/to/file` syntax.

```markdown
# ~/.claude/CLAUDE.md
@~/dotfiles/claude/instructions.md
@~/dotfiles/claude/git-workflow.md
```

**Key details:**
- Relative paths resolve relative to the file containing the import
- Absolute paths work (including `@~/...`)
- Recursive imports up to 5 levels deep
- First-time approval dialog per project
- Imports inside code blocks are ignored
- Use `/memory` to verify what's loaded

**Limitation:** `@import` is exclusive to CLAUDE.md. It does **not** work in agents, skills, rules, settings, or output-styles.

---

## 4. The Rules System

### What are rules?

Modular `.md` files in `.claude/rules/` that give Claude instructions — same purpose as CLAUDE.md but organized by topic.

### Locations

| Location | Scope | Shared? |
|----------|-------|---------|
| `~/.claude/rules/` | User (all projects) | No — personal |
| `.claude/rules/` (project) | Project | Yes — commit to git |

### Loading behavior

- All `.md` files discovered recursively at session start
- Subdirectories supported for organization
- User rules loaded before project rules (project rules take priority)

### Unconditional rules (always loaded)

```markdown
# tool-preferences.md
- Use git switch for branch operations
- Use eza -ahl instead of ls
```

### Conditional rules (loaded only for matching files)

```markdown
---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python Rules
- use uv run for any python command
- use uv sync --all-packages from workspace root
```

Supports glob patterns and brace expansion (`*.{ts,tsx}`).

### Rules vs CLAUDE.md

| Feature | CLAUDE.md | Rules |
|---------|-----------|-------|
| `@import` support | Yes | No |
| Symlink support | No | **Yes** |
| Conditional loading (path scoping) | No | Yes |
| Monolithic vs modular | Monolithic | Modular |
| Organization | Single file | Multiple files, subdirectories |

---

## 5. Current CLAUDE.md → Rules Migration Map

| Current content | Proposed rule file | Conditional? |
|----------------|--------------------|--------------|
| git switch, eza preferences | `rules/tool-preferences.md` | No |
| Functional paradigm, uv commands | `rules/python.md` | Yes — `**/*.py`, `**/pyproject.toml` |
| Required skills table | `rules/required-skills.md` | No |
| Global agents table | `rules/global-agents.md` | No |

After migration, CLAUDE.md could become empty or contain only `@import` references.

---

## 6. Configuration Hierarchy (precedence high → low)

```
1. Managed settings (managed-settings.json) — org IT, cannot override
2. Command line arguments — session overrides
3. Local project settings (.claude/settings.local.json) — personal, auto-gitignored
4. Shared project settings (.claude/settings.json) — team config
5. User settings (~/.claude/settings.json) — global defaults
```

For memory/instructions:
```
1. Project .claude/rules/ (conditional rules applied first)
2. Project CLAUDE.md / .claude/CLAUDE.md
3. User ~/.claude/rules/
4. User ~/.claude/CLAUDE.md
```

---

## 7. Approach Comparison

### Option A: Git repo directly in ~/.claude

**How:** `git init` in `~/.claude/` with a whitelist `.gitignore`.

```gitignore
# Ignore everything by default
*

# Whitelist user-created config
!.gitignore
!CLAUDE.md
!settings.json
!analytics-statusline.sh
!agents/
!agents/**
!skills/
!skills/**
!output-styles/
!output-styles/**
!rules/
!rules/**

# Re-ignore sensitive/generated files in whitelisted dirs
*.backup
*.cache
```

| Pros | Cons |
|------|------|
| Covers all files (agents, skills, settings, rules, output-styles) | ~/.claude is not a self-contained dotfiles package |
| No symlink issues | Separate repo from other dotfiles |
| Simple — no scripts or workarounds | Must maintain whitelist .gitignore as Claude adds new auto-generated dirs |
| Works today with no bugs | |

### Option B: Dotfiles repo + symlinked rules + @import + copy script

**How:** Store configs in dotfiles repo. Use Stow for rules (symlinks work). Use `@import` for CLAUDE.md content. Copy script for everything else.

```
dotfiles/
└── claude/
    ├── rules/           → symlinked via Stow to ~/.claude/rules/
    │   ├── tool-preferences.md
    │   ├── python.md
    │   ├── required-skills.md
    │   └── global-agents.md
    ├── CLAUDE.md        → imported via @import in ~/.claude/CLAUDE.md
    ├── agents/          → copied by script to ~/.claude/agents/
    ├── skills/          → copied by script to ~/.claude/skills/
    ├── settings.json    → copied by script to ~/.claude/settings.json
    └── output-styles/   → copied by script to ~/.claude/output-styles/
```

| Pros | Cons |
|------|------|
| Lives alongside other dotfiles | Mixed strategies (symlink + import + copy) |
| Rules benefit from symlinks | Copy script adds manual step after edits |
| CLAUDE.md uses native @import | Agents/skills/settings changes require re-running script |
| | More moving parts to maintain |

### Option C: Dotfiles repo + full copy script (no symlinks)

**How:** All configs in dotfiles repo, deploy script copies everything to `~/.claude/`.

```bash
#!/bin/bash
cp ~/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
cp ~/dotfiles/claude/settings.json ~/.claude/settings.json
cp -r ~/dotfiles/claude/agents/ ~/.claude/agents/
cp -r ~/dotfiles/claude/skills/ ~/.claude/skills/
cp -r ~/dotfiles/claude/output-styles/ ~/.claude/output-styles/
cp -r ~/dotfiles/claude/rules/ ~/.claude/rules/
```

| Pros | Cons |
|------|------|
| Lives alongside other dotfiles | Must run script after every edit |
| No symlink bugs | Two copies of every file (source + deployed) |
| Simple to understand | Easy to forget to run the script |
| Works with any dotfiles manager | Edits in ~/.claude/ aren't tracked unless copied back |

---

## 8. Official Guidance Summary

- Claude Code's config model is designed for **project-level sharing**, not global-level
- Commit project `.claude/settings.json`, `.claude/CLAUDE.md`, `.claude/agents/`, `.mcp.json`
- Never commit `~/.claude.json` (OAuth tokens, API keys)
- `settings.local.json` is auto-gitignored
- No official guidance exists for version-controlling the global `~/.claude/` directory

---

## Sources

- [Claude Code Settings](https://code.claude.com/docs/en/settings)
- [Claude Code Memory (CLAUDE.md, rules, imports)](https://code.claude.com/docs/en/memory)
- [Claude Code Security](https://code.claude.com/docs/en/security)
- [Claude Code MCP Configuration](https://code.claude.com/docs/en/mcp)
- [GitHub #764 — Symlink resolution failure](https://github.com/anthropics/claude-code/issues/764)
- [GitHub #3575 — Symlinked settings.json issues](https://github.com/anthropics/claude-code/issues/3575)
- [GitHub #10573 — Symlink support for slash commands broken](https://github.com/anthropics/claude-code/issues/10573)
- [GitHub #23960 — Sandbox allowlist doesn't resolve symlinks](https://github.com/anthropics/claude-code/issues/23960)
- [GitHub #26489 — Skills/agents parent directory traversal](https://github.com/anthropics/claude-code/issues/26489)
