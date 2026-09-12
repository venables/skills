#!/usr/bin/env bash
#
# A panelist's model label drives every `Flagged by:` attribution in the
# synthesis, so it has to be the model that actually ran — not the one the model
# thinks it is. Ask two codex panelists pinned to different models what they are
# and both answer "gpt-5".
#
# This asserts dash-p's metadata envelope wins over the panelist's self-report,
# that the self-report is still preserved alongside it, that the manifest records
# which route produced the label, and that a harness which died before resolving
# a model is reported as unresolved rather than as a model literally named
# "unknown".
#
# Runs against fake `dash-p` and backend binaries: no network, no model call.

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
panel="$skill_dir/panel-review.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/panel-review-model.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
out="$tmp/out"
fake_bin="$tmp/bin"
mkdir -p "$repo" "$fake_bin"

git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name Test
printf 'old\n' > "$repo/file.txt"
git -C "$repo" add file.txt
git -C "$repo" commit -qm old
printf 'new\n' > "$repo/file.txt"

# Stands in for dash-p. Writes the metadata envelope the script reads for
# attribution, and deliberately self-reports a DIFFERENT model on stdout so the
# test can prove which one the script trusts. Three behaviours, keyed off argv:
#
#   -H claude       timed out before resolving anything: envelope carries the
#                   literal "unknown", no stdout, exit 20
#   --model nometa  no envelope at all, exercising the pinned-model fallback
#   otherwise       a normal envelope naming the model that ran
cat > "$fake_bin/dash-p" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

harness=""
model=""
meta=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -H) harness="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --meta-file) meta="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cat > /dev/null

if [[ "$harness" == "claude" ]]; then
  [[ -n "$meta" ]] && printf '{"harness":"claude","model_requested":"default","model_resolved":"unknown","exit_status":"timeout"}\n' > "$meta"
  exit 20
fi

if [[ -n "$meta" && "$model" != "nometa" ]]; then
  printf '{"harness":"codex","model_requested":"%s","model_resolved":"runtime-%s","exit_status":"ok"}\n' \
    "${model:-default}" "${model:-default}" > "$meta"
fi

cat <<'OUT'
Model: gpt-5
Goal (clear): exercise model attribution.
Approach (sound): compare the envelope against the self-report.
Purpose (stated, served): verify the resolved model wins.
Proof (not needed): test fixture.
NO_FINDINGS — attribution fixture.
OUT
SH

# The script probes each backend CLI on PATH before launching dash-p.
for b in codex opencode claude; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin/$b"
done
chmod +x "$fake_bin/dash-p" "$fake_bin/codex" "$fake_bin/opencode" "$fake_bin/claude"

fail() { echo "FAIL: $*" >&2; exit 1; }
(
  cd "$repo"
  PATH="$fake_bin:$PATH" \
    bash "$panel" --uncommitted \
      --panelist codex --panelist opencode:nometa \
      --out-dir "$out" --timeout 20 \
      >"$tmp/stdout" 2>"$tmp/stderr"
)

manifest="$out/panelists.tsv"
[[ -f "$manifest" ]] || fail "panel-review did not emit a panelist manifest"
head -n1 "$manifest" | grep -Eq $'^reviewer_id\tbackend\tmodel\tmodel_source\treported_model\tapproach\tstatus\texit_code\tstarted_at\tcompleted_at\tduration_ms$' \
  || fail "manifest header does not match the documented column contract"

# The envelope's model must beat the panelist's self-report everywhere.
grep -Fq "## codex / runtime-default (exit 0)" "$tmp/stdout" \
  || fail "section heading did not use the model from dash-p's envelope"
grep -Fq "panel-review: codex (runtime-default) done (exit 0)" "$tmp/stderr" \
  || fail "heartbeat did not use the model from dash-p's envelope"
grep -Eq $'^codex\tcodex\truntime-default\truntime\tgpt-5\tstandard\tcontributed\t0\t[0-9]+\t[0-9]+\t[0-9]+$' "$manifest" \
  || fail "manifest did not record the resolved model, its provenance, and the self-report"

# No envelope: fall back to the model pinned on the spec, and say so.
grep -Fq "## opencode-nometa / nometa (exit 0)" "$tmp/stdout" \
  || fail "heading did not fall back to the pinned model when no envelope was written"
grep -Eq $'^opencode-nometa\topencode\tnometa\texplicit\tgpt-5\tstandard\tcontributed\t0\t[0-9]+\t[0-9]+\t[0-9]+$' "$manifest" \
  || fail "manifest did not mark the fallback label as explicitly pinned"

# The manifest is announced so a consumer can find it without guessing.
grep -Fq "Panelist manifest:" "$tmp/stdout" \
  || fail "combined output did not announce the panelist manifest"

# A harness that died before resolving a model reports the literal "unknown" in
# its envelope. That is the absence of an answer: the panelist must come back
# unresolved ("?") with unknown provenance, never as a model named "unknown"
# carrying runtime provenance.
timeout_out="$tmp/timeout-out"
(
  cd "$repo"
  PATH="$fake_bin:$PATH" \
    bash "$panel" --uncommitted --panelist claude \
      --out-dir "$timeout_out" --timeout 20 \
      >"$tmp/timeout-stdout" 2>"$tmp/timeout-stderr"
) || true

grep -Fq "## claude / ? (exit 20)" "$tmp/timeout-stdout" \
  || fail "a harness that never resolved a model was not reported as unresolved"
grep -Eq $'^claude\tclaude\t[?]\tunknown\t[?]\tstandard\tfailed\t20\t[0-9]+\t[0-9]+\t[0-9]+$' "$timeout_out/panelists.tsv" \
  || fail "manifest claimed provenance for a model the harness never resolved"
if grep -Fq 'unknown	runtime' "$timeout_out/panelists.tsv"; then
  fail "manifest recorded the literal 'unknown' as a runtime-resolved model"
fi

echo "PASS: panel-review attributes panelists to the model that actually ran"
