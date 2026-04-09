#!/usr/bin/env bash
# Claude Code status line with ASCII context window chart

input=$(cat)

user=$(whoami)
host=$(hostname -s)
dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
timestamp=$(date '+%H:%M:%S')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

# ANSI color codes
C_RESET='\033[0m'
C_USER='\033[36m'       # Cyan   — user@host:dir
C_GIT='\033[33m'        # Yellow — git branch
C_MODEL='\033[35m'      # Magenta — model name
C_TIME='\033[37m'       # Light gray — timestamp
C_CTX_BAR='\033[32m'    # Green — context bar filled
C_CTX_EMPTY='\033[90m'  # Dark gray — context bar empty
C_CTX_LABEL='\033[32m'  # Green — ctx label/percentage
C_5H='\033[33m'         # Yellow — 5h rate limit
C_7D='\033[35m'         # Magenta — 7d rate limit
C_TOK='\033[96m'        # Cyan bright — token counts
C_SEP='\033[90m'        # Dark gray — separators
C_STAGED='\033[32m'     # Green — staged changes
C_UNSTAGED='\033[31m'   # Red — unstaged changes
C_PUSH='\033[33m'       # Yellow — commits to push
C_PULL='\033[36m'       # Cyan — commits to pull

# Git info
cd "$dir" 2>/dev/null
git_line=''
if git rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -c core.useReplaceRefs=false rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')

  # Staged / unstaged counts
  staged=$(git -c core.useReplaceRefs=false diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  unstaged=$(git -c core.useReplaceRefs=false diff --name-only 2>/dev/null | wc -l | tr -d ' ')

  # Commits ahead/behind remote
  remote=$(git -c core.useReplaceRefs=false rev-parse --abbrev-ref "@{upstream}" 2>/dev/null)
  ahead=0; behind=0
  if [ -n "$remote" ]; then
    ahead=$(git -c core.useReplaceRefs=false rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)
    behind=$(git -c core.useReplaceRefs=false rev-list --count "HEAD..@{upstream}" 2>/dev/null || echo 0)
  fi

  # Build line 3
  git_line="${C_GIT}branch:${branch}${C_RESET}"
  git_line="${git_line} ${C_SEP}|${C_RESET} ${C_STAGED}staged:${staged}${C_RESET}"
  git_line="${git_line} ${C_SEP}|${C_RESET} ${C_UNSTAGED}unstaged:${unstaged}${C_RESET}"
  git_line="${git_line} ${C_SEP}|${C_RESET} ${C_PUSH}push:${ahead}${C_RESET}"
  git_line="${git_line} ${C_SEP}|${C_RESET} ${C_PULL}pull:${behind}${C_RESET}"

fi

# Build a 10-char bar: make_bar <used_pct> <fill_color>
make_bar() {
  local pct="$1" fill_color="$2" filled empty bar i
  pct_int=$(printf "%.0f" "$pct")
  filled=$(( pct_int * 10 / 100 ))
  empty=$(( 10 - filled ))
  bar=''
  i=0
  while [ $i -lt $filled ]; do
    bar="${bar}${fill_color}▰"
    i=$(( i + 1 ))
  done
  i=0
  while [ $i -lt $empty ]; do
    bar="${bar}${C_CTX_EMPTY}▱"
    i=$(( i + 1 ))
  done
  printf '%s' "$bar"
}

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Line 1: user@host:dir | model | timestamp
printf '%b\n' "${C_USER}${user}@${host}:${dir}${C_RESET} ${C_SEP}|${C_RESET} ${C_MODEL}${model}${C_RESET} ${C_SEP}|${C_RESET} ${C_TIME}${timestamp}${C_RESET}"

# Line 2: ctx | 5h | 7d bars (only if context data is available)
if [ -n "$remaining" ] && [ -n "$used" ]; then
  ctx_bar=$(make_bar "$used" "$C_CTX_LABEL")
  line2="${C_CTX_LABEL}ctx:[${ctx_bar}${C_CTX_LABEL}] $(printf '%.0f' "$remaining")%${C_RESET}"

  if [ -n "$five_pct" ]; then
    bar5=$(make_bar "$five_pct" "$C_5H")
    line2="${line2} ${C_SEP}|${C_RESET} ${C_5H}5h:[${bar5}${C_5H}] $(printf '%.0f' "$five_pct")%${C_RESET}"
  fi
  if [ -n "$week_pct" ]; then
    bar7=$(make_bar "$week_pct" "$C_7D")
    line2="${line2} ${C_SEP}|${C_RESET} ${C_7D}7d:[${bar7}${C_7D}] $(printf '%.0f' "$week_pct")%${C_RESET}"
  fi

  if [ -n "$total_in" ] && [ -n "$total_out" ]; then
    fmt_tok() {
      local n="$1"
      if [ "$n" -ge 1000 ]; then
        printf '%.1fk' "$(echo "$n" | awk '{printf "%.1f", $1/1000}')"
      else
        printf '%s' "$n"
      fi
    }
    in_fmt=$(fmt_tok "$total_in")
    out_fmt=$(fmt_tok "$total_out")
    line2="${line2} ${C_SEP}|${C_RESET} ${C_TOK}in:${in_fmt} out:${out_fmt}${C_RESET}"
  fi

  printf '%b\n' "$line2"
fi

# Line 3: git status (only inside a git repo)
if [ -n "$git_line" ]; then
  printf '%b\n' "$git_line"
fi
