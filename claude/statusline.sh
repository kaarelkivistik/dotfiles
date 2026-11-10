#!/usr/bin/env bash
# Claude Code status line: model and directory on the left; context window,
# 5-hour session and 7-day usage as bars, right-aligned. Claude Code pipes
# session JSON on stdin and sets COLUMNS; rate_limits only appears for
# claude.ai subscribers after the first response.

# ${#var} must count characters, not bytes, for the alignment maths.
export LC_ALL=C.UTF-8

BAR_WIDTH=10
# Columns kept free on the right for Claude Code's own padding.
MARGIN=4

input=$(cat)

model=$(jq -r '.model.display_name // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")

# bar <label> <used_percentage> [suffix]: e.g. "ctx ████░░░░░░ 42%", coloured
# green < 50, yellow < 80, red. Appends to $right and its plain text to $plain.
bar() {
  local n=${2%.*} color=32 filled empty fill="" rest="" text
  [ "$n" -gt 100 ] && n=100
  [ "$n" -ge 50 ] && color=33
  [ "$n" -ge 80 ] && color=31
  filled=$(((n * BAR_WIDTH + 50) / 100))
  empty=$((BAR_WIDTH - filled))
  for ((i = 0; i < filled; i++)); do fill+="█"; done
  for ((i = 0; i < empty; i++)); do rest+="░"; done
  text="$1 $fill$rest $n%${3:+ $3}"
  [ -n "$plain" ] && { right+="  "; plain+="  "; }
  right+=$(printf '%s \033[%sm%s\033[2m%s\033[0m %s%%%s' \
    "$1" "$color" "$fill" "$rest" "$n" "${3:+ $3}")
  plain+="$text"
}

# fmt_time <epoch> <format>: portable across BSD and GNU date.
fmt_time() {
  date -r "$1" +"$2" 2>/dev/null || date -d "@$1" +"$2"
}

# remaining <epoch>: time remaining as e.g. 2h14m or 37m.
remaining() {
  local s=$(($1 - $(date +%s)))
  [ "$s" -lt 0 ] && s=0
  if [ "$s" -ge 3600 ]; then
    printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  else
    printf '%dm' $((s / 60))
  fi
}

left="$model"
[ -n "$dir" ] && left+=" · ${dir/#$HOME/~}"
right=""
plain=""

# Older versions lack used_percentage; derive it from the last request's usage.
ctx=$(jq -r '.context_window // empty
  | .used_percentage // (
      (.current_usage // empty) as $u | (.context_window_size // empty) as $size
      | ($u.input_tokens + $u.cache_creation_input_tokens + $u.cache_read_input_tokens) * 100 / $size
    ) // empty' <<<"$input")
[ -n "$ctx" ] && bar ctx "$ctx"

read -r s_used s_reset w_used w_reset < <(jq -r '[
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.five_hour.resets_at // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.seven_day.resets_at // ""
] | map(tostring | if . == "" then "-" else . end) | join(" ")' <<<"$input")

if [ "$s_used" != - ]; then
  suffix=""
  [ "$s_reset" != - ] && suffix=$(remaining "$s_reset")
  bar session "$s_used" "$suffix"
fi
if [ "$w_used" != - ]; then
  suffix=""
  [ "$w_reset" != - ] && suffix=$(fmt_time "$w_reset" '%a %H:%M')
  bar week "$w_used" "$suffix"
fi

# Pad so the bars end at the right edge; fall back to a single gap when the
# terminal is too narrow or COLUMNS is unset.
gap=$((${COLUMNS:-0} - MARGIN - ${#left} - ${#plain}))
[ "$gap" -lt 2 ] && gap=2
[ -z "$right" ] && gap=0
printf '%s%*s%s\n' "$left" "$gap" "" "$right"
