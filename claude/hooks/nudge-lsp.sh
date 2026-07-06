#!/usr/bin/env bash
# PreToolUse hook: soft-nudge Claude from text search toward the semantic nvim
# LSP tools when it looks like a code-symbol lookup.
#
# NON-BLOCKING by design: it never denies the call. It emits
# hookSpecificOutput.additionalContext (exit 0) so Claude sees a reminder while
# the Grep/rg still runs. Grep stays first-class for prose, logs, config, SQL,
# and non-symbol text.
#
# Fires only when the search term is a bare code identifier
# (^[A-Za-z_][A-Za-z0-9_]*$) targeting code files. Fails open on any error.

set -uo pipefail

INPUT=$(cat 2>/dev/null) || exit 0

# Tool name: prefer stdin (current format), fall back to the env var.
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || true
[[ -n "$TOOL_NAME" ]] || TOOL_NAME="${TOOL_NAME:-}"

# A bare code identifier — no regex metachars, no spaces, no dots.
is_identifier() { [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]+$ ]]; }

# Paths/types that are clearly NOT code — never nudge for these.
looks_noncode() {
    [[ "$1" =~ \.(md|markdown|txt|log|json|ya?ml|toml|csv|tsv|sql|rst|lock|env)([[:space:]]|$|\") ]] \
        || [[ "$1" =~ (^|/)(docs?|logs?|fixtures?|node_modules|\.git)(/|[[:space:]]|$) ]]
}

# Code-language Grep `type` values worth nudging on.
is_code_type() {
    case "$1" in
    py | python | go | ts | typescript | js | javascript | tsx | jsx | lua | rust | rs | java | c | cpp | h | hpp) return 0 ;;
    *) return 1 ;;
    esac
}

NUDGE=0

case "$TOOL_NAME" in
Grep)
    PATTERN=$(printf '%s' "$INPUT" | jq -r '(.tool_input.pattern // .pattern) // empty' 2>/dev/null) || true
    GTYPE=$(printf '%s' "$INPUT" | jq -r '(.tool_input.type // .type) // empty' 2>/dev/null) || true
    GLOB=$(printf '%s' "$INPUT" | jq -r '(.tool_input.glob // .glob) // empty' 2>/dev/null) || true

    if is_identifier "$PATTERN"; then
        # Skip when explicitly scoped to non-code files/types.
        if [[ -n "$GTYPE" ]] && ! is_code_type "$GTYPE"; then
            NUDGE=0
        elif { [[ -n "$GLOB" ]] && looks_noncode "$GLOB"; }; then
            NUDGE=0
        else
            NUDGE=1
        fi
    fi
    ;;
Bash)
    COMMAND=$(printf '%s' "$INPUT" | jq -r '(.tool_input.command // .command) // empty' 2>/dev/null) || true
    # Only a bare grep/rg/ag/ack search (not piped into from another command).
    if [[ "$COMMAND" =~ ^[[:space:]]*(grep|rg|ag|ack)[[:space:]] ]] && ! looks_noncode "$COMMAND"; then
        # Grab the first non-flag token as the candidate search term.
        TERM=$(printf '%s' "$COMMAND" | tr -d "\"'" \
            | awk '{for (i=2;i<=NF;i++){if ($i !~ /^-/){print $i; exit}}}') || true
        if is_identifier "$TERM"; then
            NUDGE=1
        fi
    fi
    ;;
esac

[[ "$NUDGE" -eq 1 ]] || exit 0

read -r -d '' MSG <<'EOF'
Searching for a code symbol? Prefer the semantic nvim tools over text search:
- name -> location: nvim_workspace_symbols
- all usages:       nvim_references
- definition:       nvim_definition
- one function:     nvim_get_node
They avoid false hits in comments/strings and use ~80% fewer tokens. (Grep is still right for prose, logs, config, SQL, or non-symbol text.)
EOF

jq -n --arg ctx "$MSG" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}' 2>/dev/null \
    || true
exit 0
