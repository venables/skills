#!/usr/bin/env bash
# panel-review.sh — fan a code review out to multiple local CLI agents in parallel
#                   and print their raw outputs for the coordinator to amalgamate.
#
# Each panelist runs in its own non-interactive subprocess with no shared state.
# Captured outputs land in a tempdir; the path is printed at the end.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_TEMPLATE="$SCRIPT_DIR/prompts/review.md"
PROMPT_TEMPLATE_DEEP="$SCRIPT_DIR/prompts/review-deep.md"

# ----- Defaults -----
TARGET="uncommitted"           # uncommitted | staged | base:<ref> | commit:<sha>
FOCUS=""
PANELISTS=()
OUT_DIR=""
TIMEOUT_SECS="${PANEL_REVIEW_TIMEOUT:-600}"
MAX_DIFF_BYTES="${PANEL_REVIEW_MAX_DIFF_BYTES:-200000}"
CHECKOUT_MODE=0
WORKTREE_DIR=""
PANEL_CWD="$PWD"

# ----- Per-panelist model overrides (env) -----
CODEX_MODEL="${CODEX_MODEL:-}"
CLAUDE_MODEL="${CLAUDE_MODEL:-}"
OPENCODE_MODEL="${OPENCODE_MODEL:-}"
OPENCODE_AGENT="${OPENCODE_AGENT:-plan}"
# Opencode has no read-only/write toggle equivalent to codex's --sandbox; the choice
# of agent decides what tools are available. In --checkout mode we swap to a writable
# agent so panelists can edit and exec; override with OPENCODE_AGENT_DEEP if you have
# a custom agent for this purpose.
OPENCODE_AGENT_DEEP="${OPENCODE_AGENT_DEEP:-build}"
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
  --checkout              DEEP MODE: git-worktree-checkout the target ref into a
                          tempdir and run panelists from inside it with WRITE/EXEC
                          permissions so they can grep callers, run tests, and
                          investigate downstream effects. Required for --pr/--base/
                          --commit only; incompatible with --uncommitted/--staged.
                          Strictly less safe than the default read-only fan-out:
                          panelists can run arbitrary commands (network, fs, CPU).
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
    --checkout)    CHECKOUT_MODE=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) die "unknown argument: $1 (use -h for help)" ;;
  esac
done

[[ -f "$PROMPT_TEMPLATE" ]] || die "missing prompt template at $PROMPT_TEMPLATE"

# --checkout requires a target with a real ref to materialize. uncommitted/staged
# already live in the user's working tree; the whole point of --checkout is to
# isolate panelists in a dedicated worktree of a *different* ref.
if (( CHECKOUT_MODE )); then
  [[ -f "$PROMPT_TEMPLATE_DEEP" ]] || die "missing deep prompt template at $PROMPT_TEMPLATE_DEEP"
  case "$TARGET" in
    pr:*|base:*|commit:*) ;;
    *) die "--checkout requires --pr, --base, or --commit (incompatible with --uncommitted/--staged)" ;;
  esac
  command -v git >/dev/null 2>&1 || die "--checkout requires git on PATH"
fi

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

# ----- Optional: materialize a worktree for deep-mode panelists -----
#
# Why: in default (read-only) mode, panelists see only a free-floating diff string
# from the user's CWD — fine for surface review, but they can't grep callers in the
# PR's actual file tree, and the read-only sandbox blocks `cargo test` / `pnpm test`
# anyway. --checkout flips both: a dedicated worktree of the target ref + write/exec
# panelist flags, so reviewers can investigate downstream effects and run the test
# suite. Cleanup runs on EXIT to avoid leaking worktrees if the script is killed.
if (( CHECKOUT_MODE )); then
  WORKTREE_DIR="$OUT_DIR/worktree"
  echo "panel-review: --checkout: materializing worktree at $WORKTREE_DIR" >&2
  case "$TARGET" in
    pr:*)
      pr_ref="${TARGET#pr:}"
      git worktree add --detach "$WORKTREE_DIR" HEAD >&2 \
        || die "git worktree add failed"
      # gh pr checkout creates/updates a local branch tracking the PR head and
      # switches to it. -f resets the branch if it already exists from a prior run.
      ( cd "$WORKTREE_DIR" && gh pr checkout "$pr_ref" -f >&2 ) \
        || die "gh pr checkout $pr_ref failed inside worktree"
      ;;
    base:*)
      # For --base, panelists need to inspect the *current* branch's tip (the diff
      # is BASE...HEAD), so we materialize HEAD into a clean worktree.
      git worktree add --detach "$WORKTREE_DIR" HEAD >&2 \
        || die "git worktree add HEAD failed"
      ;;
    commit:*)
      sha="${TARGET#commit:}"
      git worktree add --detach "$WORKTREE_DIR" "$sha" >&2 \
        || die "git worktree add $sha failed"
      ;;
  esac
  PANEL_CWD="$WORKTREE_DIR"
  trap 'git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true' EXIT
  echo "panel-review: --checkout: panelists will run with WRITE/EXEC permissions in $WORKTREE_DIR" >&2
fi

DIFF_BYTES=$(wc -c < "$DIFF_FILE" | tr -d ' ')
if (( DIFF_BYTES > MAX_DIFF_BYTES )); then
  die "diff is $DIFF_BYTES bytes, exceeds cap $MAX_DIFF_BYTES.
  Either narrow the scope (e.g. --commit, --staged, or a smaller --base range),
  or raise the cap, e.g.:  PANEL_REVIEW_MAX_DIFF_BYTES=$((DIFF_BYTES * 2)) bash $0 ...
  Caps exist because each panelist embeds the full diff in its prompt; very large
  diffs blow context windows and cost a lot."
fi

# ----- Compose the per-run prompt -----
ACTIVE_TEMPLATE="$PROMPT_TEMPLATE"
(( CHECKOUT_MODE )) && ACTIVE_TEMPLATE="$PROMPT_TEMPLATE_DEEP"
PROMPT_FILE="$OUT_DIR/prompt.md"
{
  cat "$ACTIVE_TEMPLATE"
  echo
  echo "## Review target"
  echo
  echo "$TARGET_LABEL"
  if (( CHECKOUT_MODE )); then
    echo
    echo "## Workspace"
    echo
    echo "You are running inside a dedicated git worktree at the path of your current working"
    echo "directory. This is the actual checkout of the target ref — not a free-floating diff."
    echo "You may read any file, grep across the tree, and execute build / test / lint commands"
    echo "to investigate downstream effects of the changes. Do not push, force-push, or perform"
    echo "any network write that affects shared infrastructure (GitHub, Slack, Linear, package"
    echo "registries, etc.). Local edits to the worktree are fine — the whole worktree is"
    echo "thrown away when this run exits."
  fi
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
#
# Default mode: lock each panelist down so the worst case is a panelist that read
# more files than it needed to. Deep mode (CHECKOUT_MODE=1): panelists need to run
# tests and edit files in the throwaway worktree, so each CLI's permission flag is
# swapped for its most permissive non-interactive equivalent. Network/destructive
# actions are gated by the prompt's hard constraints (see prompts/review-deep.md),
# not by sandbox flags — there's no portable "no-network-write" mode across all four
# CLIs.
build_argv() {
  local name="$1"
  case "$name" in
    codex)
      if (( CHECKOUT_MODE )); then
        argv=(codex exec --skip-git-repo-check --sandbox workspace-write --color=never)
      else
        argv=(codex exec --skip-git-repo-check --sandbox read-only --color=never)
      fi
      [[ -n "$CODEX_MODEL" ]] && argv+=(-m "$CODEX_MODEL")
      argv+=(-- "$PROMPT_CONTENT")
      ;;
    claude)
      if (( CHECKOUT_MODE )); then
        argv=(claude -p --permission-mode bypassPermissions --output-format text --no-session-persistence)
      else
        argv=(claude -p --permission-mode plan --output-format text --no-session-persistence)
      fi
      [[ -n "$CLAUDE_MODEL" ]] && argv+=(--model "$CLAUDE_MODEL")
      argv+=(-- "$PROMPT_CONTENT")
      ;;
    opencode)
      # `opencode run` takes the message positionally; --prompt is not a flag here
      # and would make opencode dump its --help and exit 1.
      local agent="$OPENCODE_AGENT"
      (( CHECKOUT_MODE )) && agent="$OPENCODE_AGENT_DEEP"
      argv=(opencode run --agent "$agent")
      (( CHECKOUT_MODE )) && argv+=(--dangerously-skip-permissions)
      [[ -n "$OPENCODE_MODEL" ]] && argv+=(--model "$OPENCODE_MODEL")
      argv+=(-- "$PROMPT_CONTENT")
      ;;
    gemini)
      if (( CHECKOUT_MODE )); then
        argv=(gemini --approval-mode yolo)
      else
        argv=(gemini --approval-mode plan)
      fi
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

  ( cd "$PANEL_CWD" && run_panelist "${argv[@]}" >"$out" 2>"$err"; echo $? >"$rc" ) &
  PIDS+=($!)
  echo "panel-review: ${p} started (pid=$!, cwd=$PANEL_CWD)" >&2
done

# ----- Stream combined results as each panelist finishes -----
#
# Why streaming: each panelist runs in parallel, but the slowest one (often codex)
# dominates wall clock. Printing sections only after `wait` returns means the
# coordinator (Claude or a human) sees nothing until the slowest finishes. Polling
# the per-panelist .rc files lets us print each section the moment it lands, and
# emit a stderr heartbeat so progress is visible when the script is run as a
# background Bash with BashOutput polling. stderr is unbuffered by libc; stdout
# may block-buffer when piped, so heartbeats go to stderr on purpose.
ANY_FAIL=0
echo "# Panel review"
echo
echo "- Target: $TARGET_LABEL"
echo "- Panelists: ${PANELISTS[*]}"
echo "- Outputs: \`$OUT_DIR\`"
[[ -n "$FOCUS" ]] && echo "- Focus: $FOCUS"
echo

print_section() {
  local p="$1"
  local rc_val
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
  echo "panel-review: ${p} done (exit ${rc_val})" >&2
}

# Track which panelists have already been printed. Bash 3.2 (macOS default) has
# no associative arrays, so we keep a parallel indexed array of names.
PRINTED=()
TOTAL=${#PANELISTS[@]}
DONE_COUNT=0
while (( DONE_COUNT < TOTAL )); do
  for p in "${PANELISTS[@]}"; do
    is_printed=0
    if [[ ${#PRINTED[@]} -gt 0 ]]; then
      for x in "${PRINTED[@]}"; do
        if [[ "$x" == "$p" ]]; then is_printed=1; break; fi
      done
    fi
    (( is_printed )) && continue
    [[ -s "$OUT_DIR/$p.rc" ]] || continue
    print_section "$p"
    PRINTED+=("$p")
    DONE_COUNT=$((DONE_COUNT + 1))
  done
  (( DONE_COUNT < TOTAL )) && sleep 1
done

# Reap any background PIDs that already exited; harmless if all are gone.
[[ ${#PIDS[@]} -gt 0 ]] && wait "${PIDS[@]}" 2>/dev/null || true

exit $(( ANY_FAIL ? 2 : 0 ))
