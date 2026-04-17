---
name: commit
description: ALWAYS use this skill when committing code — never run git commit directly. Stages specific files, commits with conventional message.
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[commit message]"
---

# Safe Commit Workflow

## Workflow

### 1. Review Changes

```bash
git status
git diff
```

### 2. Stage Specific Files

Stage files by name - avoid `git add -A` or `git add .`:

```bash
git add path/to/file1 path/to/file2
```

### 3. Commit

If `$ARGUMENTS` was provided, use it as the commit message. Otherwise, review the staged diff and write one.

Keep commit messages short and simple. One line, no body unless the user asks for one.

```bash
git commit -m "$(cat <<'EOF'
Short description of what changed
EOF
)"
```

**Message style**: Plain English, lowercase, no type prefixes. Describe the change in under 10 words.

- Good: `Add query_explain MCP tool`
- Good: `Fix null handling in customer_monthly`
- Bad: `feat(mcp): add query_explain tool for analyzing dbt model query plans via EXPLAIN`
- Bad: `Update promote-model skill to handle decomposition workflows for graduating models`

### 4. Verify

```bash
git status
git log --oneline -3
```

## Rules

- **Never commit** `.env`, `profiles.yml` (with real credentials), or secrets
- **Never amend** unless explicitly asked - always create new commits
