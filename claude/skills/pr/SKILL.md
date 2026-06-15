---
name: pr
description: ALWAYS use this skill when creating a pull request — never run gh pr create directly. Pushes branch and creates PR targeting the trunk (main) with summary and test plan.
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[base branch]"
---

# Create Pull Request

## Key Rules

- **Default base branch is the trunk (`main`)** — trunk-based development: short-lived branches merge back to the trunk
- To target a different base, pass it as the argument
- PR title under 70 characters, plain English
- Use description/body for details, not the title
- Analyze ALL commits on the branch, not just the latest
- Never create a PR from the trunk (`main`/`master`) directly

## Workflow

### 1. Check current state

```bash
git status
git branch --show-current
git log --oneline -5
```

### 2. Validate branch

Refuse to create a PR if the current branch is the trunk (`main`/`master`). Tell the user to create a feature branch first.

### 3. Determine base branch

- Default: the trunk (`main`)
- If `$ARGUMENTS` was provided, use it as the base branch
- Otherwise default to `main`
- **Validate**: branch name must match `[a-zA-Z0-9._/-]+` — reject anything else

### 4. Analyze changes

Fetch the base branch first so comparisons reflect the remote state, then analyze:

```bash
git fetch origin <base>
git diff origin/<base>...HEAD
git log origin/<base>..HEAD --oneline
```

Review ALL commits, not just the latest. The PR summary must reflect the complete set of changes.

### 5. Push branch

```bash
git push -u origin <branch>
```

If the branch already tracks a remote and is up to date, skip pushing.

### 6. Create PR

Use a HEREDOC for the body to preserve formatting:

```bash
gh pr create --base <base> --title "short title" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points describing what changed and why>

## Test plan
<bulleted checklist of verification steps>
EOF
)"
```

### 7. Return the PR URL

Print the PR URL so the user can click through to it.
