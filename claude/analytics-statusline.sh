#!/bin/bash

# Analytics repository status line for Claude Code
# Shows: dir | git branch | dbt target | AWS profile | model | context %

# Read JSON input from stdin
input=$(cat)

# Extract fields from JSON input
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')
model_name=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

status_parts=()

# 1. Working directory (short: last 2 path components)
if [[ -n "$cwd" ]]; then
    short_dir=$(echo "$cwd" | awk -F'/' '{
        n=NF
        if (n>=2) printf "%s/%s", $(n-1), $n
        else print $n
    }')
    status_parts+=("$(printf '\033[36m%s\033[0m' "$short_dir")")
fi

# 2. Git branch (fast — no network, no locks)
if [[ -n "$cwd" ]]; then
    git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$git_branch" ]]; then
        # Worktree branch gets cyan, feature branches get yellow, main/dev get green
        case "$git_branch" in
            main|dev|master)
                status_parts+=("$(printf '\033[32m%s\033[0m' "$git_branch")") ;;
            feature/*|feat/*)
                status_parts+=("$(printf '\033[33m%s\033[0m' "$git_branch")") ;;
            *)
                status_parts+=("$(printf '\033[36m%s\033[0m' "$git_branch")") ;;
        esac
    fi
fi

# 3. DBT target (env var only — no slow file I/O)
dbt_target="${DBT_TARGET:-}"
if [[ -z "$dbt_target" ]]; then
    # Check profiles.yml for target: line under the blues profile only
    if [[ -f "$HOME/.dbt/profiles.yml" ]]; then
        dbt_target=$(awk '/^blues:/{found=1} found && /^  target:/{print $2; exit}' "$HOME/.dbt/profiles.yml" 2>/dev/null)
    fi
    dbt_target="${dbt_target:-dev}"
fi
case "$dbt_target" in
    prod) status_parts+=("$(printf '\033[31mdbt:%s\033[0m' "$dbt_target")") ;;
    dev)  status_parts+=("$(printf '\033[32mdbt:%s\033[0m' "$dbt_target")") ;;
    *)    status_parts+=("$(printf '\033[33mdbt:%s\033[0m' "$dbt_target")") ;;
esac

# 4. AWS profile (env var only — no slow CLI calls)
aws_profile="${AWS_PROFILE:-}"
if [[ -n "$aws_profile" ]]; then
    case "$aws_profile" in
        *prod*) status_parts+=("$(printf '\033[31maws:%s\033[0m' "$aws_profile")") ;;
        *dev*)  status_parts+=("$(printf '\033[32maws:%s\033[0m' "$aws_profile")") ;;
        *)      status_parts+=("$(printf '\033[36maws:%s\033[0m' "$aws_profile")") ;;
    esac
fi

# 5. Claude model (short form)
if [[ -n "$model_name" ]]; then
    status_parts+=("$(printf '\033[90m%s\033[0m' "$model_name")")
fi

# 6. Context window usage
if [[ -n "$used_pct" ]]; then
    pct_int=${used_pct%.*}
    if (( pct_int >= 80 )); then
        status_parts+=("$(printf '\033[31mctx:%s%%\033[0m' "$pct_int")")
    elif (( pct_int >= 50 )); then
        status_parts+=("$(printf '\033[33mctx:%s%%\033[0m' "$pct_int")")
    else
        status_parts+=("$(printf '\033[32mctx:%s%%\033[0m' "$pct_int")")
    fi
fi

# Output: join with " | " separator
printf "%s" "$(IFS='|'; echo "${status_parts[*]}")" | sed 's/|/ | /g'