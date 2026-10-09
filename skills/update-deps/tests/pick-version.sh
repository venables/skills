#!/usr/bin/env bash
#
# pick-version.mjs decides which version an upgrade targets. It must never pick
# a version younger than the age gate, a prerelease, or a version above the
# `latest` dist-tag, and it must classify 0.x minor bumps as major.
#
# Runs against saved `npm view <pkg> time dist-tags --json` fixtures via
# `--input`: no network.

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
pick="$skill_dir/scripts/pick-version.mjs"
now="2026-10-09T00:00:00.000Z"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/pick-version.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
failures=0

check() {
  local name=$1 expected=$2 actual=$3
  if [[ "$actual" == "$expected" ]]; then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$name" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

field() {
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s)[process.argv[1]];console.log(v===null?"null":typeof v==="object"?JSON.stringify(v):v)})' "$1"
}

# Saves the registry fixture on stdin, then runs the script against it.
pick() {
  cat > "$tmp/registry.json"
  node "$pick" pkg --input "$tmp/registry.json" --now "$now" "$@"
}

registry='{
  "time": {
    "created": "2025-01-01T00:00:00.000Z",
    "modified": "2026-10-08T00:00:00.000Z",
    "1.0.0": "2025-01-01T00:00:00.000Z",
    "1.1.0": "2025-06-01T00:00:00.000Z",
    "1.1.1": "2026-09-01T00:00:00.000Z",
    "2.0.0": "2026-09-15T00:00:00.000Z",
    "2.1.0-beta.1": "2026-09-20T00:00:00.000Z",
    "2.1.0": "2026-10-08T00:00:00.000Z",
    "3.0.0": "2026-09-30T00:00:00.000Z"
  },
  "dist-tags": { "latest": "2.1.0", "next": "3.0.0" }
}'

out=$(pick --current 1.0.0 --min-age-minutes 0 <<<"$registry")
check "no age gate targets the latest dist-tag" "2.1.0" "$(field target <<<"$out")"
check "no age gate reports a major bump" "major" "$(field bump <<<"$out")"
check "no age gate holds nothing back" "null" "$(field heldBack <<<"$out")"

out=$(pick --current 1.0.0 --min-age-minutes 4320 <<<"$registry")
check "age gate skips a version younger than the gate" "2.0.0" "$(field target <<<"$out")"
check "age gate reports the held-back version" \
  '{"version":"2.1.0","eligibleAt":"2026-10-11T00:00:00.000Z"}' \
  "$(field heldBack <<<"$out")"
check "age gate still reports the latest dist-tag" "2.1.0" "$(field latest <<<"$out")"

out=$(pick --current 1.1.0 --min-age-minutes 0 <<<"$registry")
check "never targets above the latest dist-tag" "2.1.0" "$(field target <<<"$out")"

out=$(pick --current 1.0.0 --min-age-minutes 43200 <<<"$registry")
check "a long gate falls back to the newest old-enough version" "1.1.1" "$(field target <<<"$out")"
check "a long gate reports the bump on the old line" "minor" "$(field bump <<<"$out")"

out=$(pick --current 1.1.1 --min-age-minutes 43200 <<<"$registry")
check "nothing old enough has no target" "null" "$(field target <<<"$out")"
check "nothing old enough holds back the newest candidate" \
  '{"version":"2.1.0","eligibleAt":"2026-11-07T00:00:00.000Z"}' \
  "$(field heldBack <<<"$out")"

out=$(pick --current 2.1.0 --min-age-minutes 0 <<<"$registry")
check "up to date has no target" "null" "$(field target <<<"$out")"
check "up to date has no bump" "null" "$(field bump <<<"$out")"

out=$(pick --current 2.1.0-beta.1 --min-age-minutes 0 <<<"$registry")
check "a prerelease moves to its stable release" "2.1.0" "$(field target <<<"$out")"
check "prerelease to stable of the same version is a patch" "patch" "$(field bump <<<"$out")"

zero='{
  "time": {
    "0.4.2": "2025-01-01T00:00:00.000Z",
    "0.4.3": "2025-02-01T00:00:00.000Z",
    "0.5.0": "2025-03-01T00:00:00.000Z"
  },
  "dist-tags": { "latest": "0.5.0" }
}'
out=$(pick --current 0.4.2 --min-age-minutes 0 <<<"$zero")
check "a 0.x minor bump is major" "major" "$(field bump <<<"$out")"

zero_patch='{
  "time": { "0.4.2": "2025-01-01T00:00:00.000Z", "0.4.9": "2025-02-01T00:00:00.000Z" },
  "dist-tags": { "latest": "0.4.9" }
}'
out=$(pick --current 0.4.2 --min-age-minutes 0 <<<"$zero_patch")
check "a 0.x patch bump is a patch" "patch" "$(field bump <<<"$out")"

minor='{
  "time": { "1.2.3": "2025-01-01T00:00:00.000Z", "1.3.0": "2025-02-01T00:00:00.000Z" },
  "dist-tags": { "latest": "1.3.0" }
}'
out=$(pick --current 1.2.3 --min-age-minutes 0 <<<"$minor")
check "a 1.x minor bump is minor" "minor" "$(field bump <<<"$out")"

if pick --min-age-minutes 0 <<<"$minor" >/dev/null 2>&1; then
  check "a missing --current fails" "non-zero exit" "exit 0"
else
  check "a missing --current fails" "x" "x"
fi

if pick --current 1.2.3 <<<'not json' >/dev/null 2>&1; then
  check "invalid registry JSON fails" "non-zero exit" "exit 0"
else
  check "invalid registry JSON fails" "x" "x"
fi

if ((failures > 0)); then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
