- Use git switch to make new branches or switch branches
- Use a functional paradigm
- Use eza -ahl instead of ls
- Use uv run for any python command
- Use uv sync --all-packages from workspace root for dependencies
- Commit uv.lock to version control

## Skills (always use — never skip)

| Trigger | Skill | Instead of |
|---------|-------|------------|
| Committing changes | `/commit` | `git add` / `git commit` |
| Creating a pull request | `/pr` | `gh pr create` |
| Deleting a branch | `/delete-branch` | `git branch -d` / `git push --delete` |
| Addressing PR review comments | `/review-pr-comments` | manual `gh api` calls |
| Updating a plan after work | `/update-plan` | manually editing plan files |
| Creating a worktree | `/create_new_worktree` | `EnterWorktree` / `git worktree add` |

## Git Safety (enforced by hooks)

| Blocked | Alternative |
|---------|-------------|
| Push to main/dev | `/pr` skill |
| Merge while on main/dev | GitHub PR |
| Force push | Ask user to confirm and run manually |
| Hard reset | `git stash` or `git-expert` agent |

## Agents

| Agent | Use For |
|-------|---------|
| `git-expert` | Conflict resolution, history recovery, complex interactive rebase |
| `web-researcher` | Web research, current information, documentation lookup |
