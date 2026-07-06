- Use git switch to make new branches or switch branches
- Use a functional paradigm
- Use eza -ahl instead of ls
- Use uv run for any python command
- Use uv sync --all-packages from workspace root for dependencies
- Commit uv.lock to version control

## Skills (always use — never skip)

| Trigger                       | Skill                     | Instead of                              |
| ----------------------------- | ------------------------- | --------------------------------------- |
| Committing changes            | `/commit`                 | `git add` / `git commit`                |
| Creating a pull request       | `/pr`                     | `gh pr create`                          |
| Deleting a branch/worktree    | `/delete-worktree-branch` | `git worktree remove` / `git branch -d` |
| Addressing PR review comments | `/review-pr-comments`     | manual `gh api` calls                   |
| Updating a plan after work    | `/update-plan`            | manually editing plan files             |
| Creating a worktree           | `/create_new_worktree`    | `EnterWorktree` / `git worktree add`    |

## Git Safety (enforced by hooks)

| Blocked                         | Alternative                          |
| ------------------------------- | ------------------------------------ |
| Push to the trunk (main/master) | `/pr` skill                          |
| Merge while on the trunk        | GitHub PR                            |
| Force push                      | Ask user to confirm and run manually |
| Hard reset                      | `git stash` or `git-expert` agent    |

## Agents

| Agent            | Use For                                                           |
| ---------------- | ----------------------------------------------------------------- |
| `git-expert`     | Conflict resolution, history recovery, complex interactive rebase |
| `web-researcher` | Web research, current information, documentation lookup           |

## Code Navigation (nvim LSP tools — prefer over text search)

The user-scoped `neovim` MCP server exposes LSP + treesitter navigation in every
project. For anything involving a code symbol, default to these semantic tools —
no false hits in comments/strings, exact positions, ~80% fewer tokens than grep.

| Goal                           | Use                      | Instead of             |
| ------------------------------ | ------------------------ | ---------------------- |
| Find a symbol by **name**      | `nvim_workspace_symbols` | `Grep` / `rg`          |
| File outline (what it defines) | `nvim_document_symbols`  | reading the whole file |
| All usages of a symbol         | `nvim_references`        | `Grep`                 |
| Jump to a definition           | `nvim_definition`        | `Grep`                 |
| Read one function/class        | `nvim_get_node`          | `Read` (whole file)    |
| Rename across files            | `nvim_rename`            | grep + multi-file Edit |
| Auto-fix imports / quick fix   | `nvim_code_action`       | hand-editing imports   |

Flow: `nvim_workspace_symbols` (name → file/line/col) → feed the position into
`nvim_references` / `nvim_definition` / `nvim_get_node`. `Grep`/`Read` stay
correct for prose, logs, config, SQL, and non-symbol text.
