#!/usr/bin/env bash
# herdr-fanout.sh — start one Claude worker per feature in Herdr panes.
#
# The orchestrator keeps its own tab. Feature panes go in other tabs of the same
# workspace, at most 2 panes per tab:
#
#   tab "feat: a + b"      tab "feat: c"
#   +-------+-------+      +---------------+
#   |   a   |   b   |      |       c       |   feature 4 splits this tab
#   +-------+-------+      +---------------+
#
# A feature tab from an earlier run that still has 1 pane is filled first.
#
# Each pane starts in its feature's worktree, starts a Claude agent named
# "feat-<slug>", and gets one prompt that points at the brief file
# "<briefs-dir>/<slug>.md". The script does not wait for the agents to finish.
#
# Output (stdout, one JSON object):
#   {
#     "workspace": "w1",
#     "features": [
#       { "slug", "worktree", "tab", "pane", "agent",
#         "status": "started" | "start_failed" | "prompt_failed" }
#     ]
#   }
#
# A "start_failed" pane usually shows a Claude startup dialog (for example
# folder trust). The script does not answer it; the user does, in that pane.
#
# Usage:
#   herdr-fanout.sh --repo-name <name> --briefs <dir> <slug>=<worktree-path> [...]
#
# Exit codes: 0 ok, 1 Herdr call failed, 2 bad args, 3 not inside Herdr.
# Requires: herdr, jq, and HERDR_ENV=1 (a Herdr-managed pane).
set -uo pipefail

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "herdr-fanout.sh: $2" >&2; exit "$1"; }

TAB_PREFIX="feat: "
REPO_NAME=""
BRIEFS=""
ENTRIES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-name) [[ $# -ge 2 && -n "${2:-}" ]] || die 2 "--repo-name requires a value"; REPO_NAME="$2"; shift 2 ;;
    --briefs) [[ $# -ge 2 && -n "${2:-}" ]] || die 2 "--briefs requires a value"; BRIEFS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *=*) ENTRIES+=("$1"); shift ;;
    *) die 2 "unknown arg: $1" ;;
  esac
done

[[ -n "$REPO_NAME" ]] || die 2 "--repo-name is required"
[[ -n "$BRIEFS" ]] || die 2 "--briefs is required"
[[ ${#ENTRIES[@]} -gt 0 ]] || die 2 "give at least one <slug>=<worktree-path>"
for e in "${ENTRIES[@]}"; do
  [[ "${e%%=*}" =~ ^[a-z][a-z0-9-]{0,26}$ ]] || die 2 "bad slug '${e%%=*}': use [a-z][a-z0-9-], 27 chars or fewer"
  [[ -f "$BRIEFS/${e%%=*}.md" ]] || die 2 "no brief at $BRIEFS/${e%%=*}.md"
done
for bin in herdr jq; do
  command -v "$bin" >/dev/null 2>&1 || die 3 "need '$bin' on PATH"
done
[[ "${HERDR_ENV:-}" == "1" && -n "${HERDR_WORKSPACE_ID:-}" ]] || die 3 "not inside a Herdr pane"

WS="$HERDR_WORKSPACE_ID"

# Prints "<tab_id> <label>" for a feature tab that has room, or nothing.
open_feature_tab() {
  herdr tab list --workspace "$WS" | jq -r --arg prefix "$TAB_PREFIX" --arg own "${HERDR_TAB_ID:-}" '
    [.result.tabs[]
      | select(.tab_id != $own and .pane_count == 1)
      | select((.label // "") | contains($prefix))][0]
    | select(. != null) | "\(.tab_id) \(.label)"'
}

first_pane_of_tab() { # <tab_id> -> pane id
  herdr pane list --workspace "$WS" | jq -r --arg tab "$1" \
    '[.result.panes[] | select(.tab_id == $tab)][0].pane_id'
}

start_agent() { # <pane> <slug> -> status
  herdr pane rename "$1" "$2" >/dev/null 2>&1 || true
  herdr agent start "feat-$2" --kind claude --pane "$1" -- --dangerously-skip-permissions >/dev/null 2>&1 \
    || { echo start_failed; return; }
  herdr agent prompt "feat-$2" "Read $BRIEFS/$2.md and do the work it describes. It is your full brief for this session." \
    >/dev/null 2>&1 || { echo prompt_failed; return; }
  echo started
}

# The tab that still has room for one more pane, with its first pane and label.
open_tab=""; open_pane=""; open_label=""
open="$(open_feature_tab)"
if [[ -n "$open" ]]; then
  open_tab="${open%% *}"
  open_label="${open#* }"
  open_label="$TAB_PREFIX${open_label#*"$TAB_PREFIX"}"
  open_pane="$(first_pane_of_tab "$open_tab")"
fi

results=()
for e in "${ENTRIES[@]}"; do
  slug="${e%%=*}"; path="${e#*=}"

  if [[ -n "$open_tab" ]]; then
    tab="$open_tab"
    pane="$(herdr pane split "$open_pane" --direction right --cwd "$path" --no-focus | jq -r '.result.pane.pane_id')"
    [[ -n "$pane" && "$pane" != "null" ]] || die 1 "pane split failed for $slug"
    herdr tab rename "$tab" "$open_label + $slug" >/dev/null 2>&1 || true
    open_tab=""; open_pane=""; open_label=""
  else
    created="$(herdr tab create --workspace "$WS" --cwd "$path" --label "$TAB_PREFIX$slug" --no-focus)" \
      || die 1 "tab create failed for $slug"
    tab="$(jq -r '.result.tab.tab_id' <<<"$created")"
    pane="$(jq -r '.result.root_pane.pane_id' <<<"$created")"
    open_tab="$tab"; open_pane="$pane"; open_label="$TAB_PREFIX$slug"
  fi

  status="$(start_agent "$pane" "$slug")"
  results+=("$(jq -n --arg slug "$slug" --arg worktree "$path" --arg tab "$tab" --arg pane "$pane" \
    --arg agent "feat-$slug" --arg status "$status" \
    '{slug: $slug, worktree: $worktree, tab: $tab, pane: $pane, agent: $agent, status: $status}')")
done

printf '%s\n' "${results[@]}" | jq -s --arg ws "$WS" '{workspace: $ws, features: .}'
