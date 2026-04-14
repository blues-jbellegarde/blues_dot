---
name: create_new_worktree
description: Create a persistent git worktree with a new branch. Use this when the user asks for a worktree — never use EnterWorktree.
allowed-tools: Bash, Read
argument-hint: "<branch-name> (e.g. feature/build_design_wins)"
---

# Persistent Worktree

Create a worktree as a sibling directory that survives session exits.

1. Strip branch prefix (`feature/`, `fix/`, etc.) to get the suffix
2. Directory name is `<repo>-<suffix>` (e.g. `analytics-build_design_wins`)
3. `git worktree add ../<dir> -b <branch> HEAD` (or check out existing branch)
4. Run `just bootstrap` in the new worktree if a justfile exists
5. Report the path and branch
