---
name: delete-worktree-branch
description: ALWAYS use this skill when deleting a branch or worktree. Removes the worktree, prunes, and deletes the branch locally and remotely.
allowed-tools: Bash, Read
argument-hint: "[branch name]"
---

# Delete Worktree & Branch

## Key Rules

- **Never delete the trunk (`main`/`master`)**
- Always remove the associated worktree first (if one exists), then prune, then delete the branch
- Never ask whether to delete the worktree — always delete it
- Prefer `git branch -d` (safe delete, requires merged). **Squash-merged** branches make `-d` fail (git doesn't see the squashed commit as containing the branch's commits) — verify the branch's content diff against the trunk is empty, then `-D` (see step 5). Only use `-D` directly when the user explicitly asks.
- GitHub auto-deletes remote branches on PR merge — if remote delete fails with "does not exist", report success
- Use `git switch` not `git checkout`

## Workflow

### 1. Identify target branch

Use `$ARGUMENTS` as the branch to delete. If no argument was given, ask which branch to delete.

### 2. Safety check

- If the target branch is the trunk (`main`/`master`), refuse and explain why.
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

If currently on the target branch, switch to the trunk:

```bash
git switch main
```

### 5. Update the trunk and delete local branch

Fetch and fast-forward the trunk so the merge check reflects the remote state:

```bash
git pull --ff-only origin main
git branch -d <branch>
```

`git branch -d` is a safe delete that fails if the branch isn't fully merged.

**Squash-merge fallback:** if the branch was merged via a squashed PR, `-d` fails because git doesn't recognize the squashed commit as containing the branch's commits. Confirm the branch adds nothing the trunk doesn't already have, then force-delete:

```bash
# Empty output = branch is fully represented in the trunk; safe to force-delete
git diff main...<branch>
git branch -D <branch>
```

Only use `-D` without this check if the user explicitly requests a force delete.

### 6. Delete remote branch

```bash
git push origin --delete <branch>
```

**Handle gracefully:** If this fails with "remote ref does not exist" or similar, that means GitHub already auto-deleted the remote branch when the PR was merged. Report this as a success, not an error.

### 7. Confirm

Report what was cleaned up (worktree, local branch, remote branch).
