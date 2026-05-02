#!/usr/bin/env bash
# panel-review.sh — fan a code review out to multiple local CLI agents in parallel
#                   and print their raw outputs for the coordinator to amalgamate.
#
# Each panelist runs in its own non-interactive subprocess with no shared state.
# Captured outputs land in a tempdir; the path is printed at the end.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_TEMPLATE="$SCRIPT_DIR/prompts/review.md"

# ----- Defaults -----
TARGET="uncommitted"           # uncommitted | staged | base:<ref> | commit:<sha>
FOCUS=""
PANELISTS=()
OUT_DIR=""
TIMEOUT_SECS="${PANEL_REVIEW_TIMEOUT:-600}"
MAX_DIFF_BYTES="${PANEL_REVIEW_MAX_DIFF_BYTES:-200000}"

# ----- Per-panelist model overrides (env) -----
CODEX_MODEL="${CODEX_MODEL:-}"
CLAUDE_MODEL="${CLAUDE_MODEL:-}"
OPENCODE_MODEL="${OPENCODE_MODEL:-}"
OPENCODE_AGENT="${OPENCODE_AGENT:-plan}"
GEMINI_MODEL="${GEMINI_MODEL:-}"

usage() {
  cat <<EOF
Usage: panel-review.sh [target] [options]

Targets (pick one, default --uncommitted):
  --uncommitted           Review staged + unstaged changes
  --staged                Review only staged changes
  --base BRANCH           Review BRANCH...HEAD
  --commit SHA            Review a single commit
  --pr NUMBER             Review a GitHub PR via 'gh pr diff' (requires gh CLI)

Options:
  --focus TEXT            Optional focus / context for the reviewers
  --panelist NAME         Add panelist (repeatable). Names: codex, claude, opencode, gemini.
                          If not given, auto-detects every supported CLI on PATH.
  --out-dir DIR           Where to write captured outputs (default: mktemp).
  --timeout SECS          Per-panelist timeout (default: \$PANEL_REVIEW_TIMEOUT or 600).
  -h, --help              Show this help.

Environment:
  CODEX_MODEL, CLAUDE_MODEL, OPENCODE_MODEL, GEMINI_MODEL
                          Pass through a model name to that panelist.
  OPENCODE_AGENT          opencode agent to use (default: plan, read-only).
  PANEL_REVIEW_MAX_DIFF_BYTES
                          Cap inline diff size (default 200000). If exceeded, the script
                          aborts and asks you to narrow scope.

Exit codes:
  0  every panelist returned successfully
  1  setup error (no diff, no panelists, missing template)
  2  one or more panelists failed; raw outputs still written
EOF
}

die() { echo "panel-review: $*" >&2; exit 1; }

# ----- Parse args -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --uncommitted) TARGET="uncommitted"; shift ;;
    --staged)      TARGET="staged"; shift ;;
    --base)        [[ $# -ge 2 ]] || die "--base needs a branch"; TARGET="base:$2"; shift 2 ;;
    --commit)      [[ $# -ge 2 ]] || die "--commit needs a SHA"; TARGET="commit:$2"; shift 2 ;;
    --pr)          [[ $# -ge 2 ]] || die "--pr needs a number or URL"; TARGET="pr:$2"; shift 2 ;;
    --focus)       [[ $# -ge 2 ]] || die "--focus needs text"; FOCUS="$2"; shift 2 ;;
    --panelist)    [[ $# -ge 2 ]] || die "--panelist needs a name"; PANELISTS+=("$2"); shift 2 ;;
    --out-dir)     [[ $# -ge 2 ]] || die "--out-dir needs a path"; OUT_DIR="$2"; shift 2 ;;
    --timeout)     [[ $# -ge 2 ]] || die "--timeout needs seconds"; TIMEOUT_SECS="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *) die "unknown argument: $1 (use -h for help)" ;;
  esac
done

[[ -f "$PROMPT_TEMPLATE" ]] || die "missing prompt template at $PROMPT_TEMPLATE"

# ----- Auto-detect panelists if none specified -----
if [[ ${#PANELISTS[@]} -eq 0 ]]; then
  for tool in codex claude opencode gemini; do
    command -v "$tool" >/dev/null 2>&1 && PANELISTS+=("$tool")
  done
fi
[[ ${#PANELISTS[@]} -gt 0 ]] || die "no panelists found on PATH (looked for codex, claude, opencode, gemini)"

# ----- Output dir -----
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(mktemp -d -t panel-review-XXXXXX)"
else
  mkdir -p "$OUT_DIR"
fi

# ----- Build the diff -----
DIFF_FILE="$OUT_DIR/diff.patch"
TARGET_LABEL=""
PR_BODY=""
case "$TARGET" in
  uncommitted)
    {
      git diff --cached --no-ext-diff
      git diff --no-ext-diff
    } > "$DIFF_FILE" || die "git diff failed"
    TARGET_LABEL="uncommitted changes (staged + unstaged)"
    ;;
  staged)
    git diff --cached --no-ext-diff > "$DIFF_FILE" || die "git diff --cached failed"
    TARGET_LABEL="staged changes"
    ;;
  base:*)
    base="${TARGET#base:}"
    git diff --no-ext-diff "$base"...HEAD > "$DIFF_FILE" || die "git diff $base...HEAD failed"
    TARGET_LABEL="changes vs base branch '$base'"
    ;;
  commit:*)
    sha="${TARGET#commit:}"
    git show --no-ext-diff "$sha" > "$DIFF_FILE" || die "git show $sha failed"
    TARGET_LABEL="commit $sha"
    ;;
  pr:*)
    pr_ref="${TARGET#pr:}"
    command -v gh >/dev/null 2>&1 || die "--pr requires the 'gh' CLI on PATH"
    gh pr diff "$pr_ref" > "$DIFF_FILE" 2>"$OUT_DIR/gh.err" \
      || die "gh pr diff $pr_ref failed: $(cat "$OUT_DIR/gh.err")"
    pr_num="$(gh pr view "$pr_ref" --json number      -q .number      2>/dev/null || true)"
    pr_title="$(gh pr view "$pr_ref" --json title     -q .title       2>/dev/null || true)"
    pr_base="$(gh pr view "$pr_ref" --json baseRefName -q .baseRefName 2>/dev/null || true)"
    PR_BODY="$(gh pr view "$pr_ref" --json body       -q .body        2>/dev/null || true)"
    TARGET_LABEL="PR #${pr_num:-$pr_ref}"
    [[ -n "$pr_title" ]] && TARGET_LABEL+=" — $pr_title"
    [[ -n "$pr_base"  ]] && TARGET_LABEL+=" (base: $pr_base)"
    ;;
esac

[[ -s "$DIFF_FILE" ]] || die "diff is empty for target: $TARGET"

DIFF_BYTES=$(wc -c < "$DIFF_FILE" | tr -d ' ')
if (( DIFF_BYTES > MAX_DIFF_BYTES )); then
  die "diff is $DIFF_BYTES bytes, exceeds cap $MAX_DIFF_BYTES.
  Either narrow the scope (e.g. --commit, --staged, or a smaller --base range),
  or raise the cap, e.g.:  PANEL_REVIEW_MAX_DIFF_BYTES=$((DIFF_BYTES * 2)) bash $0 ...
  Caps exist because each panelist embeds the full diff in its prompt; very large
  diffs blow context windows and cost a lot."
fi

# ----- Compose the per-run prompt -----
PROMPT_FILE="$OUT_DIR/prompt.md"
{
  cat "$PROMPT_TEMPLATE"
  echo
  echo "## Review target"
  echo
  echo "$TARGET_LABEL"
  if [[ -n "$PR_BODY" ]]; then
    echo
    echo "## PR description"
    echo
    echo "$PR_BODY"
  fi
  if [[ -n "$FOCUS" ]]; then
    echo
    echo "## Reviewer focus"
    echo
    echo "$FOCUS"
  fi
  echo
  echo "## Diff"
  echo
  echo '```diff'
  cat "$DIFF_FILE"
  echo '```'
} > "$PROMPT_FILE"

# Read prompt once into memory so each child reads from there.
PROMPT_CONTENT="$(cat "$PROMPT_FILE")"

# ----- Resolve a portable timeout binary (gtimeout on macOS via coreutils) -----
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi

# Wrapper that prepends a timeout if available. Avoids empty-array expansion under
# bash 3.2 + set -u.
run_panelist() {
  if [[ -n "$TIMEOUT_BIN" ]]; then
    "$TIMEOUT_BIN" "$TIMEOUT_SECS" "$@"
  else
    "$@"
  fi
}

# ----- Build each panelist's argv -----
build_argv() {
  local name="$1"
  case "$name" in
    codex)
      argv=(codex exec --skip-git-repo-check --sandbox read-only --color=never)
      [[ -n "$CODEX_MODEL" ]] && argv+=(-m "$CODEX_MODEL")
      argv+=(-- "$PROMPT_CONTENT")
      ;;
    claude)
      argv=(claude -p --permission-mode plan --output-format text --no-session-persistence)
      [[ -n "$CLAUDE_MODEL" ]] && argv+=(--model "$CLAUDE_MODEL")
      argv+=(-- "$PROMPT_CONTENT")
      ;;
    opencode)
      argv=(opencode run --agent "$OPENCODE_AGENT")
      [[ -n "$OPENCODE_MODEL" ]] && argv+=(--model "$OPENCODE_MODEL")
      argv+=(--prompt "$PROMPT_CONTENT")
      ;;
    gemini)
      argv=(gemini --approval-mode plan)
      [[ -n "$GEMINI_MODEL" ]] && argv+=(--model "$GEMINI_MODEL")
      argv+=(-p "$PROMPT_CONTENT")
      ;;
    *)
      argv=()
      return 1
      ;;
  esac
  return 0
}

# ----- Fan out -----
echo "panel-review: target=$TARGET_LABEL panelists=${PANELISTS[*]} out=$OUT_DIR" >&2

declare -a PIDS=()
for p in "${PANELISTS[@]}"; do
  out="$OUT_DIR/$p.out"
  err="$OUT_DIR/$p.err"
  rc="$OUT_DIR/$p.rc"

  if ! command -v "$p" >/dev/null 2>&1; then
    echo "panel-review: '$p' not on PATH — skipping" >&2
    : >"$out"
    echo "panelist '$p' not found on PATH" >"$err"
    echo "127" >"$rc"
    continue
  fi

  if ! build_argv "$p"; then
    echo "panel-review: unknown panelist '$p' — skipping" >&2
    : >"$out"
    echo "unknown panelist '$p'" >"$err"
    echo "127" >"$rc"
    continue
  fi

  ( run_panelist "${argv[@]}" >"$out" 2>"$err"; echo $? >"$rc" ) &
  PIDS+=($!)
done

# Wait for everything; ignore wait's exit code (children's rcs live in $OUT_DIR).
[[ ${#PIDS[@]} -gt 0 ]] && wait "${PIDS[@]}" 2>/dev/null || true

# ----- Print combined results -----
ANY_FAIL=0
echo "# Panel review"
echo
echo "- Target: $TARGET_LABEL"
echo "- Panelists: ${PANELISTS[*]}"
echo "- Outputs: \`$OUT_DIR\`"
[[ -n "$FOCUS" ]] && echo "- Focus: $FOCUS"
echo

for p in "${PANELISTS[@]}"; do
  rc_val="$(cat "$OUT_DIR/$p.rc" 2>/dev/null || echo "?")"
  echo "## ${p} (exit ${rc_val})"
  echo
  if [[ -s "$OUT_DIR/$p.out" ]]; then
    cat "$OUT_DIR/$p.out"
  else
    echo "_(no stdout)_"
  fi
  if [[ "$rc_val" != "0" ]]; then
    ANY_FAIL=1
    if [[ -s "$OUT_DIR/$p.err" ]]; then
      echo
      echo "<details><summary>stderr</summary>"
      echo
      echo '```'
      cat "$OUT_DIR/$p.err"
      echo '```'
      echo
      echo "</details>"
    fi
  fi
  echo
done

exit $(( ANY_FAIL ? 2 : 0 ))
