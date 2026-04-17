---
name: review-pr-comments
description: Fetch, analyze, and address code review comments on pull requests. Researches code context, presents recommendations, implements approved fixes, and resolves threads.
allowed-tools: Bash, Read, Glob, Grep
---

# Review PR Comments

## Rules

- Never address comments or resolve threads without user confirmation
- Research git history before recommending -- do not guess
- Use `/commit` for committing, never `git commit` directly

## Workflow

### 1. Get unresolved comments

Get the PR for the current branch, then fetch review threads. Stop if no PR exists.

```bash
gh pr view --json number,url,headRefName,headRepository
```

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 10) {
              nodes { databaseId body path line author { login } diffHunk }
            }
          }
        }
      }
    }
  }
' -F owner="{owner}" -F repo="{repo}" -F number={number}
```

Filter to threads where `isResolved == false`. Stop if none found.

### 2. Research and present each comment

For each comment, read the file around the target line, run `git blame` and `git log` on the originating commit, then present:

```
### Comment {N}: {path}:{line}
**Reviewer says:** {summary}
**Why it was written this way:** {from blame/log}
**Recommendation:** VALID | LIKELY INVALID -- {rationale}
```

After all comments, prompt the user for decisions:

```
- address = fix the code
- ignore = reply with rationale and resolve
- skip = leave thread open
```

Wait for user response.

### 3. Implement, commit, and resolve

1. Apply fixes for **address** comments, then tell the user to review and `/commit`
2. After commit, reply and resolve **address** threads:
   ```bash
   gh api /repos/{owner}/{repo}/pulls/{number}/comments/{id}/replies -f body='Fixed in {sha}'
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "{id}"}) { thread { isResolved } } }'
   ```
3. Reply and resolve **ignore** threads with the rationale
4. Leave **skip** threads untouched
