#!/usr/bin/env bash
#
# consolidate-overrides.mjs removes an override only when another entry for
# the same package covers every version it matched, with a target at least as
# new on the same release line. Anything it cannot prove stays, with a warning.
#
# Runs against local fixtures: no network, no package manager.

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$skill_dir/scripts/consolidate-overrides.mjs"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/consolidate-overrides.XXXXXX")"
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

# Prints one field of the first source in the result, as compact JSON.
field() {
  node -e '
    const result = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    console.log(JSON.stringify(result.sources[0][process.argv[2]]));
  ' "$tmp/out.json" "$1"
}

# Saves the overrides map on stdin, then runs the script against it.
consolidate() {
  cat > "$tmp/in.json"
  node "$script" --input "$tmp/in.json" > "$tmp/out.json"
}

consolidate <<<'{"package@<10": "10.1", "package@<=10.1": "10.2"}'
check "a wider selector with a newer target replaces the narrow one" \
  '{"package@<=10.1":"10.2"}' "$(field overrides)"
check "the removed entry names what covers it" \
  '[{"key":"package@<10","value":"10.1","coveredBy":"package@<=10.1"}]' "$(field removed)"
check "a clean merge has no warnings" '[]' "$(field warnings)"

consolidate <<<'{"tar@<6.2.1": ">=6.2.1", "tar@<7.4.3": ">=7.4.3"}'
check "an open-ended target is covered by a newer one" '{"tar@<7.4.3":">=7.4.3"}' "$(field overrides)"

consolidate <<<'{"a@<1.1": "1.1.0", "a@<1.2": "1.2.0", "a@<1.3": ">=1.3.0", "a@<=1.3.0": "^1.3.1"}'
check "a chain collapses to the widest entry" '{"a@<=1.3.0":"^1.3.1"}' "$(field overrides)"

consolidate <<<'{"vite@>=5.0.0 <5.4.12": "^5.4.12", "vite@>=6.0.0 <6.0.9": "^6.0.9"}'
check "separate release lines both stay" \
  '{"vite@>=5.0.0 <5.4.12":"^5.4.12","vite@>=6.0.0 <6.0.9":"^6.0.9"}' "$(field overrides)"
check "separate release lines do not warn" '[]' "$(field warnings)"

consolidate <<<'{"pkg@<9.5.1": "^9.5.1", "pkg@<=10.1.0": "^10.2.0"}'
check "a pinned older line is not swallowed by a newer major" \
  '{"pkg@<9.5.1":"^9.5.1","pkg@<=10.1.0":"^10.2.0"}' "$(field overrides)"
check "an overlap that cannot be merged warns" \
  '[{"type":"overlap","keys":["pkg@<9.5.1","pkg@<=10.1.0"]}]' \
  "$(node -e '
    const result = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    console.log(JSON.stringify(result.sources[0].warnings.map(({ type, keys }) => ({ type, keys }))));
  ' "$tmp/out.json")"

consolidate <<<'{"lodash@<4.17.21": ">=4.17.21", "lodash": "4.17.21"}'
check "a bare key covers a selector for the same package" '{"lodash":"4.17.21"}' "$(field overrides)"

consolidate <<<'{"a>foo@<2": "2.0.1", "foo@<3": "3.0.0", "bar@<3": "3.0.0"}'
check "parent-scoped and other packages are left alone" \
  '{"a>foo@<2":"2.0.1","foo@<3":"3.0.0","bar@<3":"3.0.0"}' "$(field overrides)"

consolidate <<<'{"@scope/pkg@<1.2.3": "1.2.3", "@scope/pkg@<1.4.0": "1.4.0"}'
check "scoped package names are grouped" '{"@scope/pkg@<1.4.0":"1.4.0"}' "$(field overrides)"

consolidate <<<'{"pkg@<10": "10.1.0", "pkg@<10.0.0": "10.1.0"}'
check "two entries with the same meaning keep the later one" '{"pkg@<10.0.0":"10.1.0"}' "$(field overrides)"

consolidate <<<'{"pkg@<=10.1": "10.1"}'
check "a target that its own selector still matches warns" \
  '["self-match"]' \
  "$(node -e '
    const result = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    console.log(JSON.stringify(result.sources[0].warnings.map(({ type }) => type)));
  ' "$tmp/out.json")"
check "a self-matching entry is not removed" '{"pkg@<=10.1":"10.1"}' "$(field overrides)"

consolidate <<<'{"foo": "npm:bar@1", "baz@<1": "-", "qux@<1 || >3": "3.0.1", "dep@<2": "$dep", "qux@<2": "2.0.0"}'
check "entries it cannot read stay in place" \
  '{"foo":"npm:bar@1","baz@<1":"-","qux@<1 || >3":"3.0.1","dep@<2":"$dep","qux@<2":"2.0.0"}' \
  "$(field overrides)"
check "entries it cannot read are listed as skipped" \
  '["foo","baz@<1","qux@<1 || >3","dep@<2"]' \
  "$(node -e '
    const result = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    console.log(JSON.stringify(result.sources[0].skipped.map(({ key }) => key)));
  ' "$tmp/out.json")"

cat > "$tmp/pnpm-workspace.yaml" <<'YAML'
packages:
  - "apps/*"

minimumReleaseAge: 4320

overrides:
  # added by pnpm audit --fix
  "package@<10": "10.1"
  'package@<=10.1': '10.2' # newer advisory
  plain: ^2.0.0

catalog:
  zod: ^4.0.0
YAML
node "$script" --file "$tmp/pnpm-workspace.yaml" > "$tmp/out.json"
check "reads the overrides block of pnpm-workspace.yaml" \
  '{"package@<=10.1":"10.2","plain":"^2.0.0"}' "$(field overrides)"
check "names the yaml source" '"overrides"' "$(field source)"

cat > "$tmp/package.json" <<'JSON'
{
  "name": "fixture",
  "pnpm": { "overrides": { "package@<10": "10.1", "package@<=10.1": "10.2" } },
  "resolutions": { "left": "1.0.0" }
}
JSON
node "$script" --file "$tmp/package.json" > "$tmp/out.json"
check "reads pnpm.overrides from package.json" '{"package@<=10.1":"10.2"}' "$(field overrides)"
check "names each package.json source" \
  '["pnpm.overrides","resolutions"]' \
  "$(node -e '
    const result = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    console.log(JSON.stringify(result.sources.map(({ source }) => source)));
  ' "$tmp/out.json")"

cat > "$tmp/bad.yaml" <<'YAML'
overrides:
  foo:
    nested: 1
YAML
if node "$script" --file "$tmp/bad.yaml" > /dev/null 2>&1; then
  check "an overrides block it cannot parse fails" "non-zero exit" "exit 0"
else
  check "an overrides block it cannot parse fails" "x" "x"
fi

if node "$script" > /dev/null 2>&1; then
  check "no input fails" "non-zero exit" "exit 0"
else
  check "no input fails" "x" "x"
fi

if ((failures > 0)); then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
