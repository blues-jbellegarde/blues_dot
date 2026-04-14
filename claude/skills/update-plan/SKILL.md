---
name: update-plan
description: Update the active plan file after work is done. Marks completed sections, adds verification results, and updates remaining work. Use when the user says "update the plan", "mark as done", or "what's left".
allowed-tools: Bash, Read, Edit, Glob, Grep
argument-hint: "[plan filename]"
---

# Update Plan

## Workflow

### 1. Find the active plan

If `$ARGUMENTS` was provided, use it to match a plan filename in `~/.claude/plans/` (fuzzy match — e.g., `dragon` matches `declarative-prancing-dragon.md`).

If no argument, find the most recently modified plan:

```bash
eza -ahl --sort=modified ~/.claude/plans/*.md | tail -1
```

Tell the user which plan you selected. If no plans exist, stop.

### 2. Read the plan and detect changes

Read the plan file. Then check recent work:

```bash
git log --oneline -10
git diff --stat HEAD~5
git status
```

If not a git repo or no changes detected, ask the user what was completed.

### 3. Match changes to plan sections

For each work item in the plan:
- Check if referenced files were modified in recent commits or working tree
- If the section has verification steps, run them
- Cross-reference commit messages against section descriptions
- Classify: **Done** / **Partially done** / **Not started**

If you cannot determine whether a section is complete, ask the user.

### 4. Update the plan file

Use Edit to apply changes. Preserve the existing structure and writing style.

- Add `— DONE` to completed section headers (e.g., `### Step 3: Refactor client.py — DONE`). Skip if already marked.
- Add verification results inline (e.g., `- **Verified**: 51/51 tests passing`)
- Note partial progress on in-progress sections
- Update or create a `## What's Left` section at the bottom listing remaining work
- Add `Last updated: YYYY-MM-DD — X of Y sections complete` at end of What's Left

### 5. Summarize

Tell the user what was marked done, what remains, and any verification results.

## Rules

- **Never change plan structure** — only add markers, notes, and update What's Left
- **Never remove plan content**
- **Preserve writing style** — match narrative vs checkbox style already in the plan
- **Use `— DONE` exactly** — em dash, space, DONE
- **Run verification before marking done** — if tests fail, don't mark done
- **Ask if ambiguous** — don't guess on unclear sections
