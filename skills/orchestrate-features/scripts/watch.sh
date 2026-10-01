#!/usr/bin/env bash
# watch.sh — block until a feature worker needs the orchestrator.
#
# Polls each named Herdr agent. Returns when one or more of them is no longer
# "working" on two polls in a row (so a worker that has not started its turn
# yet does not end the watch), or when the timeout ends.
#
# Output (stdout, one JSON object):
#   {
#     "timed_out": false,
#     "agents": [ { "agent", "status" } ]
#   }
#
# Status is the Herdr agent status: working, idle, done, blocked, unknown, or
# "gone" when Herdr has no live agent with that name.
#
# Usage:
#   watch.sh [--timeout <seconds>] [--interval <seconds>] <agent> [...]
#
# Defaults: --timeout 1500, --interval 15.
# Exit codes: 0 ok (read "timed_out"), 2 bad args, 3 not inside Herdr.
# Requires: herdr, jq, and HERDR_ENV=1.
set -uo pipefail

usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "watch.sh: $2" >&2; exit "$1"; }

TIMEOUT=1500
INTERVAL=15
AGENTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) [[ "${2:-}" =~ ^[0-9]+$ ]] || die 2 "--timeout requires seconds"; TIMEOUT="$2"; shift 2 ;;
    --interval) [[ "${2:-}" =~ ^[0-9]+$ ]] || die 2 "--interval requires seconds"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die 2 "unknown arg: $1" ;;
    *) AGENTS+=("$1"); shift ;;
  esac
done

[[ ${#AGENTS[@]} -gt 0 ]] || die 2 "give at least one agent name"
for bin in herdr jq; do
  command -v "$bin" >/dev/null 2>&1 || die 3 "need '$bin' on PATH"
done
[[ "${HERDR_ENV:-}" == "1" ]] || die 3 "not inside a Herdr pane"

agent_status() { # <agent> -> status
  local status
  status="$(herdr agent get "$1" 2>/dev/null | jq -r '.result.agent.agent_status // empty' 2>/dev/null)"
  echo "${status:-gone}"
}

snapshot() { # -> JSON array of {agent, status}
  for agent in "${AGENTS[@]}"; do
    jq -n --arg agent "$agent" --arg status "$(agent_status "$agent")" '{agent: $agent, status: $status}'
  done | jq -s .
}

needs_attention() { jq -e 'any(.[]; .status != "working")' >/dev/null <<<"$1"; }

report() { jq -n --argjson timed_out "$1" --argjson agents "$2" '{timed_out: $timed_out, agents: $agents}'; }

deadline=$((SECONDS + TIMEOUT))
previous_hit=false
while true; do
  current="$(snapshot)"
  if needs_attention "$current"; then
    [[ "$previous_hit" == true ]] && { report false "$current"; exit 0; }
    previous_hit=true
  else
    previous_hit=false
  fi
  [[ $SECONDS -ge $deadline ]] && { report true "$current"; exit 0; }
  sleep "$INTERVAL"
done
