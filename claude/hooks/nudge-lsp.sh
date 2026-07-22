#!/usr/bin/env bash
# PreToolUse hook: soft-nudge Claude (and subagents) from text search / whole-file
# reads toward the semantic nvim LSP tools when it looks like symbol work.
#
# NON-BLOCKING by design: it never denies the call. It emits
# hookSpecificOutput.additionalContext (exit 0) so the reminder is seen while the
# Grep/rg/Read still runs. Because PreToolUse hooks fire for EVERY tool call —
# including inside built-in subagents (Explore, general-purpose) whose prompts
# can't be edited — this is the one steering lever that reaches them.
#
# Fires on:
#   - Grep / Bash grep|rg|ag|ack for a bare code identifier of 2+ chars
#     (^[A-Za-z_][A-Za-z0-9_]+$) targeting code. Single-char terms (e.g. `i`,
#     `x`) are intentionally excluded — poor symbol searches, noisy nudges.
#   - Read of a WHOLE code file over READ_NUDGE_MIN_LINES lines (partial reads,
#     configs/docs, and small files are left alone).
# Grep/Read stay first-class for prose, logs, config, SQL, and non-symbol text.
# Fails open on any error.

set -uo pipefail

READ_NUDGE_MIN_LINES=200

INPUT=$(cat 2>/dev/null) || exit 0

# Tool name: prefer stdin (current format), fall back to the env var. Capture
# the stdin value separately so an empty jq result doesn't clobber $TOOL_NAME.
TOOL_NAME_STDIN=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || true
TOOL_NAME="${TOOL_NAME_STDIN:-${TOOL_NAME:-}}"

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

# A source file with a symbol-bearing extension.
is_code_file() {
    [[ "$1" =~ \.(py|go|ts|tsx|js|jsx|lua|rs|java|c|cc|cpp|h|hpp|rb|php|cs|kt|swift|scala)$ ]]
}

NUDGE=0
MSG=""

SEARCH_MSG="Searching for a code symbol? Prefer the semantic nvim tools over text search:
- name -> location: nvim_workspace_symbols
- all usages:       nvim_references
- definition:       nvim_definition
- one function:     nvim_get_node
They avoid false hits in comments/strings and use ~80% fewer tokens. (Grep is still right for prose, logs, config, SQL, or non-symbol text.)"

READ_MSG="Reading a whole code file to inspect a symbol? The semantic nvim tools return just what you need, with far fewer tokens:
- one function/class/method: nvim_get_node
- the file's symbol outline:  nvim_document_symbols
(A full-file Read is fine for configs, docs, or when you'll edit the whole file.)"

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
            MSG="$SEARCH_MSG"
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
            MSG="$SEARCH_MSG"
        fi
    fi
    ;;
Read)
    FILE=$(printf '%s' "$INPUT" | jq -r '(.tool_input.file_path // .file_path) // empty' 2>/dev/null) || true
    OFFSET=$(printf '%s' "$INPUT" | jq -r '(.tool_input.offset // .offset) // empty' 2>/dev/null) || true
    LIMIT=$(printf '%s' "$INPUT" | jq -r '(.tool_input.limit // .limit) // empty' 2>/dev/null) || true
    # Whole-file read (no offset/limit) of a code file large enough that a
    # targeted extract would clearly save tokens.
    if [[ -n "$FILE" && -z "$OFFSET" && -z "$LIMIT" ]] && is_code_file "$FILE"; then
        LINES=$(wc -l <"$FILE" 2>/dev/null | tr -d ' ') || true
        if [[ "${LINES:-0}" =~ ^[0-9]+$ ]] && [[ "${LINES:-0}" -gt "$READ_NUDGE_MIN_LINES" ]]; then
            NUDGE=1
            MSG="$READ_MSG"
        fi
    fi
    ;;
esac

[[ "$NUDGE" -eq 1 ]] || exit 0

jq -n --arg ctx "$MSG" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}' 2>/dev/null \
    || true
exit 0
