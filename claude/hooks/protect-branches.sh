#!/usr/bin/env bash
# PreToolUse hook: block dangerous git operations on protected branches.
# Exit 0 = allow, exit 2 + stderr = block with message.
#
# Receives tool input as JSON on stdin. For Bash calls, the "command" field
# contains the shell command string.

set -euo pipefail

# Only inspect Bash tool calls
TOOL_NAME="${TOOL_NAME:-}"
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

# Read the tool input JSON and extract the command
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null) || exit 0
[[ -n "$COMMAND" ]] || exit 0

# Only inspect git commands
[[ "$COMMAND" =~ ^[[:space:]]*(git[[:space:]]) ]] || exit 0

# --- Push to protected branches ---
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*\b(main|dev)\b'; then
  # Allow push -u / --set-upstream for *other* branches that happen to be
  # typed before "main" in the arg list — but block explicit pushes to main/dev.
  # Also allow `git push --delete origin main` (branch deletion) — that's
  # handled by the /delete-branch skill separately.
  if ! echo "$COMMAND" | grep -qE 'git\s+push\s+--delete'; then
    echo "BLOCKED: Pushing directly to main/dev is not allowed." >&2
    echo "Use the /pr skill to create a pull request instead." >&2
    exit 2
  fi
fi

# --- Force push anywhere ---
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(-f|--force)\b'; then
  echo "BLOCKED: Force push detected." >&2
  echo "If you really need this, ask the user to confirm and run it manually." >&2
  exit 2
fi

# --- Merge while on a protected branch ---
if echo "$COMMAND" | grep -qE 'git\s+merge\b'; then
  # Check if we're currently on main or dev
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || true
  if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "dev" ]]; then
    echo "BLOCKED: Merging into $CURRENT_BRANCH is not allowed." >&2
    echo "Create a pull request on GitHub instead." >&2
    exit 2
  fi
fi

# --- Switch to protected branch then merge (chained command) ---
if echo "$COMMAND" | grep -qE 'git\s+switch\s+(main|dev)\b.*&&.*git\s+merge'; then
  echo "BLOCKED: Switching to a protected branch and merging is not allowed." >&2
  echo "Create a pull request on GitHub instead." >&2
  exit 2
fi

# --- Hard reset ---
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: Hard reset detected." >&2
  echo "Use 'git stash' to save changes, or delegate to the git-expert agent for history recovery." >&2
  exit 2
fi

# All checks passed
exit 0
