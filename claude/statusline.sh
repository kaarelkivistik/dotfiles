#!/usr/bin/env bash
# Claude Code status line: model, directory, and plan usage for the current
# 5-hour session and the 7-day window. Claude Code pipes session JSON on stdin;
# rate_limits only appears for claude.ai subscribers after the first response.

input=$(cat)

model=$(jq -r '.model.display_name // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")

# pct <used_percentage>: coloured percentage (green < 50, yellow < 80, red).
pct() {
  local n=${1%.*} color=32
  [ "$n" -ge 50 ] && color=33
  [ "$n" -ge 80 ] && color=31
  printf '\033[%sm%s%%\033[0m' "$color" "$n"
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

out="$model"
[ -n "$dir" ] && out+=" · ${dir/#$HOME/~}"

read -r s_used s_reset w_used w_reset < <(jq -r '[
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.five_hour.resets_at // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.seven_day.resets_at // ""
] | map(tostring | if . == "" then "-" else . end) | join(" ")' <<<"$input")

if [ "$s_used" != - ]; then
  out+=" · session $(pct "$s_used")"
  [ "$s_reset" != - ] && out+=" ($(remaining "$s_reset"))"
fi
if [ "$w_used" != - ]; then
  out+=" · week $(pct "$w_used")"
  [ "$w_reset" != - ] && out+=" ($(fmt_time "$w_reset" '%a %H:%M'))"
fi

printf '%s\n' "$out"
