#!/usr/bin/env bash
#
# `--pr --since <sha>` must assign the exact snapshot transition and nothing
# wider. The failure this guards against is silent: a re-review that quietly
# falls back to the whole PR diff still "works", it just re-reports everything
# the previous round already handled.
#
# Runs against fake `gh` and fake `dash-p` binaries, so it needs no network, no
# GitHub auth, and no model call.

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
panel="$skill_dir/panel-review.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/panel-review-incremental.XXXXXX")"
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
old="$(git -C "$repo" rev-parse HEAD)"
printf 'new\n' > "$repo/file.txt"
git -C "$repo" commit -qam new
new="$(git -C "$repo" rev-parse HEAD)"

cat > "$fake_bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-} ${2:-}" == "pr view" ]] || { echo "unexpected gh call: $*" >&2; exit 97; }
fields=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) fields="$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$fields" in
  state,number)
    printf 'OPEN\n7\n'
    ;;
  number,title,baseRefName,url)
    printf '7\nincremental test\nmain\nhttps://github.com/venables/example/pull/7\n'
    ;;
  body) echo 'test body' ;;
  url,headRefOid,headRepository)
    printf 'https://github.com/venables/example/pull/7\n%s\nvenables/example\n' "$CURRENT_HEAD"
    ;;
  *) echo "unexpected gh fields: $fields" >&2; exit 98 ;;
esac
SH

# Stands in for dash-p: captures the prompt (arrives on stdin) and the worktree
# it was pointed at (--cwd), then emits a minimal well-formed panelist report.
cat > "$fake_bin/dash-p" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

cwd=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) cwd="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cat > "$PROMPT_CAPTURE"
printf '%s' "$cwd" > "$CWD_CAPTURE"
git -C "$cwd" rev-parse HEAD > "$HEAD_CAPTURE"
cat <<'OUT'
Model: fake
Goal (clear, matches description): exercise incremental scope.
Approach (sound): exact snapshot comparison.
Purpose (stated, served): verify the assigned delta.
Proof (not needed): test fixture.
NO_FINDINGS — backward-impact pass completed.
OUT
SH

# The script probes the backend CLI on PATH before launching dash-p.
printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin/codex"
chmod +x "$fake_bin/gh" "$fake_bin/dash-p" "$fake_bin/codex"

fail() { echo "FAIL: $*" >&2; exit 1; }
(
  cd "$repo"
  PATH="$fake_bin:$PATH" \
  CURRENT_HEAD="$new" \
  PROMPT_CAPTURE="$tmp/prompt" CWD_CAPTURE="$tmp/cwd" HEAD_CAPTURE="$tmp/head" \
    bash "$panel" --pr 7 --since "$old" --panelist codex:test --out-dir "$out" --timeout 20 >/dev/null
)

[[ "$(cat "$tmp/head")" == "$new" ]] || fail "panelist worktree was not pinned to current PR head"
grep -Fq "git diff --no-ext-diff $old..$new" "$tmp/prompt" \
  || fail "panelist prompt did not assign the exact snapshot delta"
grep -Fq "The assigned diff is the causal boundary, not" "$tmp/prompt" \
  || fail "incremental prompt did not define its causal boundary"
grep -Fq "do a mandatory bounded backward-impact pass" "$tmp/prompt" \
  || fail "incremental prompt did not require a backward-impact pass"
grep -Fq "prioritizing code changed earlier in this PR" "$tmp/prompt" \
  || fail "incremental prompt did not cover older PR code"
grep -Fq "State that causal link in the finding" "$tmp/prompt" \
  || fail "incremental prompt did not constrain older-line findings"
if grep -Fq 'gh pr diff 7' "$tmp/prompt"; then
  fail "incremental prompt still instructed the panelist to load the full PR diff"
fi

# A full PR review must keep pulling the live remote diff.
(
  cd "$repo"
  PATH="$fake_bin:$PATH" \
  CURRENT_HEAD="$new" \
  PROMPT_CAPTURE="$tmp/prompt-full" CWD_CAPTURE="$tmp/cwd-full" HEAD_CAPTURE="$tmp/head-full" \
    bash "$panel" --pr 7 --panelist codex:test --out-dir "$tmp/out-full" --timeout 20 >/dev/null
)
grep -Fq 'gh pr diff 7' "$tmp/prompt-full" \
  || fail "full PR review stopped assigning the live remote diff"

# --since only means something against a PR head.
if (
  cd "$repo"
  PATH="$fake_bin:$PATH" \
    bash "$panel" --uncommitted --since "$old" --panelist codex:test >/dev/null 2>&1
); then
  fail "--since was accepted without --pr"
fi

# A non-SHA argument must be rejected before any work starts.
if (
  cd "$repo"
  PATH="$fake_bin:$PATH" CURRENT_HEAD="$new" \
    bash "$panel" --pr 7 --since HEAD~1 --panelist codex:test >/dev/null 2>&1
); then
  fail "--since accepted a non-SHA revision"
fi

# Reviewing a snapshot against itself has nothing to assign.
if (
  cd "$repo"
  PATH="$fake_bin:$PATH" CURRENT_HEAD="$new" \
    bash "$panel" --pr 7 --since "$new" --panelist codex:test >/dev/null 2>&1
); then
  fail "--since accepted the current PR head as the previous snapshot"
fi

echo "PASS: panel-review assigns exact incremental PR scope"
