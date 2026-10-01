#!/usr/bin/env bash
# fanout-layout.sh — check the tab and split layout that herdr-fanout.sh builds.
#
# Puts a stub `herdr` on PATH. The stub logs each call and returns canned JSON,
# so the test needs no Herdr server and starts no agents.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fanout="$here/../scripts/herdr-fanout.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/briefs"
cat >"$work/bin/herdr" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$STUB_LOG"
next_id() {
  local n
  n=$(($(cat "$STUB_COUNTER" 2>/dev/null || echo 0) + 1))
  echo "$n" >"$STUB_COUNTER"
  echo "$n"
}
case "$1 $2" in
  "tab list") cat "$STUB_TABS" ;;
  "pane list") cat "$STUB_PANES" ;;
  "tab create") n="$(next_id)"; echo "{\"result\":{\"tab\":{\"tab_id\":\"w1:t$n\"},\"root_pane\":{\"pane_id\":\"w1:p$n\"}}}" ;;
  "pane split") n="$(next_id)"; echo "{\"result\":{\"pane\":{\"pane_id\":\"w1:p$n\"}}}" ;;
  *) echo '{"result":{}}' ;;
esac
STUB
chmod +x "$work/bin/herdr"

export PATH="$work/bin:$PATH"
export HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t0 HERDR_PANE_ID=w1:p0
export STUB_LOG="$work/log" STUB_COUNTER="$work/counter"
export STUB_TABS="$work/tabs.json" STUB_PANES="$work/panes.json"

failures=0
check() { # <description> <actual> <expected>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (got '$2', want '$3')"
    failures=$((failures + 1))
  fi
}
calls() { grep -c "^$1" "$STUB_LOG" || true; }
reset() { : >"$STUB_LOG"; rm -f "$STUB_COUNTER"; }

for slug in alpha beta gamma delta; do echo "brief" >"$work/briefs/$slug.md"; done

# Case 1: three features, no feature tab open yet.
reset
echo '{"result":{"tabs":[{"tab_id":"w1:t0","label":"1 · main","pane_count":1}]}}' >"$STUB_TABS"
echo '{"result":{"panes":[{"pane_id":"w1:p0","tab_id":"w1:t0"}]}}' >"$STUB_PANES"
out="$("$fanout" --repo-name demo --briefs "$work/briefs" alpha=/tmp/a beta=/tmp/b gamma=/tmp/c)"
check "three features open two tabs" "$(calls 'tab create')" 2
check "three features make one split" "$(calls 'pane split')" 1
check "three features start three agents" "$(calls 'agent start')" 3
check "the orchestrator pane is never split" "$(grep -c 'pane split w1:p0' "$STUB_LOG" || true)" 0
check "alpha and beta share a tab" \
  "$(jq -r '[.features[] | select(.slug == "alpha" or .slug == "beta") | .tab] | unique | length' <<<"$out")" 1
check "gamma has its own tab" \
  "$(jq -r '[.features[] | select(.slug == "gamma") | .tab] == [.features[] | select(.slug == "alpha") | .tab]' <<<"$out")" false
check "agent names carry the feat prefix" "$(jq -r '.features[0].agent' <<<"$out")" feat-alpha
check "every feature reports started" "$(jq -r '[.features[].status] | unique | join(",")' <<<"$out")" started

# Case 2: a feature tab with one pane is open. The next feature fills it.
reset
echo '{"result":{"tabs":[{"tab_id":"w1:t0","label":"1 · main","pane_count":1},{"tab_id":"w1:t7","label":"feat: gamma","pane_count":1}]}}' >"$STUB_TABS"
echo '{"result":{"panes":[{"pane_id":"w1:p0","tab_id":"w1:t0"},{"pane_id":"w1:p7","tab_id":"w1:t7"}]}}' >"$STUB_PANES"
out="$("$fanout" --repo-name demo --briefs "$work/briefs" delta=/tmp/d)"
check "a half-full feature tab is filled first" "$(calls 'tab create')" 0
check "the fill splits the open feature pane" "$(grep -c 'pane split w1:p7 --direction right' "$STUB_LOG" || true)" 1
check "the filled feature reports the open tab" "$(jq -r '.features[0].tab' <<<"$out")" w1:t7

# Case 3: a missing brief stops the run before any layout change.
reset
"$fanout" --repo-name demo --briefs "$work/briefs" nobrief=/tmp/x >/dev/null 2>&1
check "a missing brief exits 2" "$?" 2
check "a missing brief makes no Herdr call" "$(wc -l <"$STUB_LOG" | tr -d ' ')" 0

# Case 4: outside Herdr the script exits 3.
reset
HERDR_ENV=0 "$fanout" --repo-name demo --briefs "$work/briefs" alpha=/tmp/a >/dev/null 2>&1
check "outside Herdr exits 3" "$?" 3

[[ $failures -eq 0 ]] || exit 1
