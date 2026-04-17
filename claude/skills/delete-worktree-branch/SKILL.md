---
name: delete-worktree-branch
description: ALWAYS use this skill when deleting a branch or worktree. Removes the worktree, prunes, and deletes the branch locally and remotely.
allowed-tools: Bash, Read
argument-hint: "[branch name]"
---

# Delete Worktree & Branch

## Key Rules

- **Never delete `main` or `dev`**
- Always remove the associated worktree first (if one exists), then prune, then delete the branch
- Never ask whether to delete the worktree — always delete it
- Use `git branch -d` (safe delete, requires merged), not `-D` unless the user explicitly asks
- GitHub auto-deletes remote branches on PR merge — if remote delete fails with "does not exist", report success
- Use `git switch` not `git checkout`

## Workflow

### 1. Identify target branch

Use `$ARGUMENTS` as the branch to delete. If no argument was given, ask which branch to delete.

### 2. Safety check

- If the target branch is `main` or `dev`, refuse and explain why.
- **Validate**: branch name must match `[a-zA-Z0-9._/-]+` — reject anything else.

### 3. Remove worktree (if any)

Check for a worktree on the target branch and remove it:

```bash
# Find worktree path for the branch (empty if none)
worktree_path=$(git worktree list --porcelain | awk -v branch="$BRANCH" '
    /^worktree / { wt=$2 }
    /^branch refs\/heads\// { if ($2 == "refs/heads/" branch) print wt }
')

if [ -n "$worktree_path" ]; then
    git worktree remove "$worktree_path"
fi

git worktree prune
```

### 4. Switch away

If currently on the target branch, switch to `dev`:

```bash
git switch dev
```

### 5. Update dev and delete local branch

Fetch and fast-forward `dev` so the merge check reflects the remote state:

```bash
git pull --ff-only origin dev
git branch -d <branch>
```

This is a safe delete that fails if the branch is not fully merged. Only use `-D` if the user explicitly requests a force delete.

### 6. Delete remote branch

```bash
git push origin --delete <branch>
```

**Handle gracefully:** If this fails with "remote ref does not exist" or similar, that means GitHub already auto-deleted the remote branch when the PR was merged. Report this as a success, not an error.

### 7. Confirm

Report what was cleaned up (worktree, local branch, remote branch).
