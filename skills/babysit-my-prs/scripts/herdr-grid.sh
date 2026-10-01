#!/usr/bin/env bash
# herdr-grid.sh — show a babysit-my-prs sweep in Herdr, one pane per PR.
#
# Renames the calling Herdr workspace to "<repo-name> (babysitting)", then opens
# new tabs in that workspace with at most 4 panes each, in a 2x2 grid:
#
#   +-------+-------+
#   | PR 1  | PR 2  |      1 PR  -> one full pane
#   +-------+-------+      2 PRs -> left | right
#   | PR 3  | PR 4  |      3 PRs -> left column split; right stays tall
#   +-------+-------+      5+    -> a new tab for each next group of 4
#
# Each pane starts in its PR's worktree, starts a Claude agent, and submits
# "/babysit-pr <N>". The script does not wait for the agents to finish.
#
# Output (stdout, one JSON object):
#   {
#     "workspace": "w1", "label": "bank (babysitting)",
#     "panes": [
#       { "number", "tab", "pane", "agent",
#         "status": "started" | "start_failed" | "prompt_failed" }
#     ]
#   }
#
# A "start_failed" pane usually shows a Claude startup dialog (for example
# folder trust). The script does not answer it; the user does, in that pane.
#
# Usage:
#   herdr-grid.sh --repo-name <name> <number>=<worktree-path> [...]
#
# Exit codes: 0 ok, 2 bad args, 3 not inside Herdr (use the subagent path).
# Requires: herdr, jq, and HERDR_ENV=1 (a Herdr-managed pane).
set -uo pipefail

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

REPO_NAME=""
ENTRIES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-name) [[ $# -ge 2 && -n "${2:-}" ]] || { echo "herdr-grid.sh: --repo-name requires a value" >&2; exit 2; }; REPO_NAME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *=*) ENTRIES+=("$1"); shift ;;
    *) echo "herdr-grid.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$REPO_NAME" ]] || { echo "herdr-grid.sh: --repo-name is required" >&2; exit 2; }
[[ ${#ENTRIES[@]} -gt 0 ]] || { echo "herdr-grid.sh: give at least one <number>=<worktree-path>" >&2; exit 2; }
for bin in herdr jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "herdr-grid.sh: need '$bin' on PATH" >&2; exit 3; }
done
[[ "${HERDR_ENV:-}" == "1" && -n "${HERDR_WORKSPACE_ID:-}" ]] || { echo "herdr-grid.sh: not inside a Herdr pane" >&2; exit 3; }

WS="$HERDR_WORKSPACE_ID"
LABEL="$REPO_NAME (babysitting)"

# Agent names must match [a-z][a-z0-9_-]{0,31} and be unique among live agents.
agent_name() {
  local slug
  slug="$(printf '%s' "$REPO_NAME" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | cut -c1-20)"
  [[ "$slug" =~ ^[a-z] ]] || slug="r$slug"
  printf '%s-pr-%s' "$slug" "$1"
}

split_pane() { # <target-pane> <right|down> <cwd> -> new pane id
  herdr pane split "$1" --direction "$2" --cwd "$3" --no-focus | jq -r '.result.pane.pane_id'
}

start_agent() { # <pane> <number> -> status
  local name
  name="$(agent_name "$2")"
  herdr pane rename "$1" "PR #$2" >/dev/null 2>&1 || true
  herdr agent start "$name" --kind claude --pane "$1" -- --dangerously-skip-permissions >/dev/null 2>&1 \
    || { echo start_failed; return; }
  herdr agent prompt "$name" "/babysit-pr $2" >/dev/null 2>&1 || { echo prompt_failed; return; }
  echo started
}

herdr workspace rename "$WS" "$LABEL" >/dev/null || { echo "herdr-grid.sh: workspace rename failed" >&2; exit 1; }

results=()
for ((start = 0; start < ${#ENTRIES[@]}; start += 4)); do
  group=("${ENTRIES[@]:start:4}")
  nums=(); paths=()
  for e in "${group[@]}"; do nums+=("${e%%=*}"); paths+=("${e#*=}"); done

  tab_label="PRs $(printf '#%s ' "${nums[@]}")"
  created="$(herdr tab create --workspace "$WS" --cwd "${paths[0]}" --label "${tab_label% }" --no-focus)" \
    || { echo "herdr-grid.sh: tab create failed" >&2; exit 1; }
  tab="$(printf '%s' "$created" | jq -r '.result.tab.tab_id')"

  # Grid slots: 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right.
  panes=("$(printf '%s' "$created" | jq -r '.result.root_pane.pane_id')")
  [[ ${#nums[@]} -ge 2 ]] && panes+=("$(split_pane "${panes[0]}" right "${paths[1]}")")
  [[ ${#nums[@]} -ge 3 ]] && panes+=("$(split_pane "${panes[0]}" down "${paths[2]}")")
  [[ ${#nums[@]} -ge 4 ]] && panes+=("$(split_pane "${panes[1]}" down "${paths[3]}")")

  for i in "${!nums[@]}"; do
    status="$(start_agent "${panes[$i]}" "${nums[$i]}")"
    results+=("$(jq -n --argjson number "${nums[$i]}" --arg tab "$tab" --arg pane "${panes[$i]}" \
      --arg agent "$(agent_name "${nums[$i]}")" --arg status "$status" \
      '{number: $number, tab: $tab, pane: $pane, agent: $agent, status: $status}')")
  done
done

printf '%s\n' "${results[@]}" | jq -s --arg ws "$WS" --arg label "$LABEL" \
  '{workspace: $ws, label: $label, panes: .}'
