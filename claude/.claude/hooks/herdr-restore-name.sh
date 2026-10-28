#!/bin/bash
# SessionStart hook: reapply a Herdr agent name saved by ~/.local/bin/herdr-name.
# Herdr does not persist agent names across server restarts, so this restores
# them when Claude sessions are resumed.

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0

names_file="$HOME/.config/herdr/agent-names.tsv"
[ -f "$names_file" ] || exit 0

session_id="$(jq -r '.session_id // empty' 2>/dev/null)"
[ -n "$session_id" ] || exit 0

name="$(awk -F'\t' -v s="$session_id" '$1 == s { print $2; exit }' "$names_file")"
[ -n "$name" ] || exit 0

herdr_bin="$(command -v herdr || echo /opt/homebrew/bin/herdr)"
pane="$HERDR_PANE_ID"

# Herdr may not have recognised the agent yet when this hook runs, so retry
# in the background for up to a minute without blocking Claude's startup.
(
  for _ in $(seq 1 60); do
    current="$("$herdr_bin" agent get "$pane" 2>/dev/null)"
    if [ "$(jq -r '.result.agent.agent_session.value // empty' <<<"$current")" = "$session_id" ]; then
      [ "$(jq -r '.result.agent.name // empty' <<<"$current")" = "$name" ] && exit 0
      "$herdr_bin" agent rename "$pane" "$name" >/dev/null 2>&1 && exit 0
    fi
    sleep 1
  done
) </dev/null >/dev/null 2>&1 &
disown

exit 0
