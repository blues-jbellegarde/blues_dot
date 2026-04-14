---
name: delete-branch
description: ALWAYS use this skill when deleting a git branch — never run git branch -d directly. Safely deletes locally and remotely with proper safety checks.
allowed-tools: Bash, Read
argument-hint: "[branch name]"
---

# Delete Branch

## Key Rules

- **Never delete `main` or `dev`**
- Use `git branch -d` (safe delete, requires merged), not `-D` (force) unless the user explicitly asks
- GitHub auto-deletes remote branches on PR merge — if remote delete fails with "does not exist", report success not error
- Always switch off the branch before deleting it
- Use `git switch` not `git checkout`

## Workflow

### 1. Identify target branch

Use `$ARGUMENTS` as the branch to delete. If no argument was given, ask which branch to delete.

### 2. Safety check

- If the target branch is `main` or `dev`, refuse and explain why.
- **Validate**: branch name must match `[a-zA-Z0-9._/-]+` — reject anything else.

### 3. Switch away

If currently on the target branch, switch to `dev`:

```bash
git switch dev
```

### 4. Update dev and delete local branch

Fetch and fast-forward `dev` so the merge check reflects the remote state:

```bash
git pull --ff-only origin dev
git branch -d <branch>
```

This is a safe delete that fails if the branch is not fully merged. Only use `-D` if the user explicitly requests a force delete.

### 5. Delete remote branch

```bash
git push origin --delete <branch>
```

**Handle gracefully:** If this fails with "remote ref does not exist" or similar, that means GitHub already auto-deleted the remote branch when the PR was merged. Report this as a success, not an error. Example message:

> Remote branch already deleted (GitHub auto-deletes on merge). Local branch deleted successfully.

### 6. Confirm

Report what was deleted (local, remote, or both).
