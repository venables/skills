---
name: panel-review
description: >
  Run a parallel code review across multiple local CLI coding agents (codex, claude,
  opencode, gemini) and aggregate their findings. Use when the user asks for a "panel
  review", "panel-review", "/panel-review", "second opinions on this change",
  "multi-agent review", "get a panel of agents to review this", or similar phrasings
  asking for independent reviews from outside this conversation. Each panelist runs in
  a fresh non-interactive subprocess with no shared state — that is the point. Do NOT
  use when the user just wants the current Claude session to review code itself; use
  the regular code-reviewer agent for that.
---

# panel-review

Spawns multiple local CLI coding agents in parallel to review the same code change, then
amalgamates their findings into one report. Each panelist runs in its own subprocess with
no shared conversation state — they only see the prompt and the diff.

## When to use

- User says "panel review", types `/panel-review`, asks for "second opinions on this
  change", "get a panel to review this", "multi-agent review", or similar.
- User wants reviews from agents that don't share this conversation's biases or context.

When _not_ to use:

- User wants you (this session) to review code → use the project's code-reviewer agent.
- User wants a single second opinion → spawn one external CLI directly, no need to fan out.

## Steps

1. **Pick a target.** Default to `--uncommitted`. Map the user's phrasing to a flag:
   - "PR 27" / "pr #27" / "/panel-review pr 27" / a `github.com/<owner>/<repo>/pull/N`
     URL → `--pr <N or URL>` (requires the `gh` CLI).
   - "vs main" / "against develop" without a PR number → `--base <branch>`.
   - Specific SHA → `--commit <sha>`.
   - Otherwise → `--uncommitted`. Ask only if the intent is genuinely ambiguous.
2. **Pick panelists.** Default: every supported CLI on `PATH` (codex, claude, opencode,
   gemini). The user may name a subset.
3. **Capture optional focus.** If the user gave context ("look closely at the auth
   changes"), pass `--focus`.
4. **Decide if this needs deep mode.** Default is read-only fan-out — fast and safe.
   Pass `--checkout` if the user wants panelists to actually run tests, grep callers
   in the PR's checkout, and chase downstream effects (asks like "really dig in",
   "run the tests", "deep review", "check what this breaks downstream"). `--checkout`
   only works with `--pr` / `--base` / `--commit`, not `--uncommitted`/`--staged`,
   and it gives panelists write/exec access in a throwaway worktree — strictly less
   safe than the default. Surface that tradeoff briefly to the user before opting
   in if they didn't ask for it explicitly.
5. **Run the script** (path: `skills/panel-review/panel-review.sh`). Prefer running it
   as a **background Bash** (`run_in_background: true`) and poll progress with
   `BashOutput`. Reason: panelists run in parallel, but Codex is slow and dominates
   wall clock — without backgrounding, the foreground Bash call blocks silently for
   minutes. The script emits unbuffered stderr heartbeats (`panel-review: <name>
started (pid=…)` and `panel-review: <name> done (exit N)`) and streams each
   panelist's section to stdout the moment that panelist finishes, so polling
   `BashOutput` every 10–15 seconds yields real-time visibility. If you do run it in
   the foreground, pass `timeout: 600000` (10 min) since the default 2-minute Bash
   timeout will kill the call before Codex returns.
6. **Set up live progress UX.** Right before (or right after) launching the script:
   - Call `TodoWrite` with one todo per chosen panelist (`Review: codex`,
     `Review: claude`, …) plus a final `Amalgamate findings` todo. Initial
     statuses: the first panelist's `in_progress`, the rest `pending`. (Some
     harnesses expose this as `TaskCreate` / `TaskUpdate` instead — use whichever
     todo-list tool your environment provides.)
   - Each `BashOutput` poll: scan stderr for `panel-review: <name> started`
     and `panel-review: <name> done (exit N)`. On a `started`, set that
     panelist's todo to `in_progress` (re-call `TodoWrite` with the updated list).
     On a `done`, set it to `completed` and post a single-line user-visible
     status: `✓ <name> done — N findings, top severity <SEV>` (or `✓ <name> —
NO_FINDINGS` / `✗ <name> failed (exit N)`). One line per finish. Do not paste
     full panelist sections into chat as they arrive — that's noise; synthesis is
     step 8.
   - After the last `done` heartbeat, set `Amalgamate findings` to `in_progress`,
     proceed to steps 7–8, then mark it `completed`.
7. **Read the script's combined output** — it prints one section per panelist with their
   raw findings, plus a tempdir path containing each panelist's stdout/stderr. Wait for
   _all_ panelists to finish before amalgamating; partial output is fine to _show_ the
   user during the wait, but consensus / disagreement analysis needs every panelist's
   verdict.
8. **Amalgamate the findings** in your reply to the user:
   - **Consensus** — issues raised by 2+ panelists, deduplicated. List file:line + the
     core problem and a suggested fix.
   - **Unique findings** — per panelist, only the findings no one else mentioned that
     still pass the "would a competent reviewer ask for this change" bar.
   - **Action list** — must-fix → should-fix → optional polish.
   - **Disagreements** — if panelists contradict each other, surface that explicitly
     rather than picking a side.
9. **Don't paraphrase or invent.** Surface what the panelists actually said. If a
   panelist returned `NO_FINDINGS`, note it; don't drop the panelist from the report.

## Usage

```bash
bash skills/panel-review/panel-review.sh [target] [options]
```

Targets (pick one, default `--uncommitted`):

- `--uncommitted` — staged + unstaged changes
- `--staged` — staged only
- `--base BRANCH` — `BRANCH...HEAD`
- `--commit SHA` — a single commit
- `--pr NUMBER` — a GitHub PR (also accepts a full PR URL); requires `gh` CLI

Options:

- `--focus TEXT` — extra context for the reviewers
- `--panelist NAME` — repeatable; one of `codex`, `claude`, `opencode`, `gemini`
- `--out-dir DIR` — where to capture outputs (default: `mktemp -d`)
- `--timeout SECS` — per-panelist timeout (default 600)
- `--checkout` — deep mode: materialize the target ref into a throwaway git worktree
  and run panelists from inside it with write/exec permissions. Required for
  `--pr` / `--base` / `--commit` only. Strictly less safe than the default.

Examples:

```bash
# All available panelists, uncommitted changes
bash skills/panel-review/panel-review.sh

# Codex + Claude only, against main
bash skills/panel-review/panel-review.sh --base main --panelist codex --panelist claude

# With focus
bash skills/panel-review/panel-review.sh --uncommitted --focus "session-token handling"

# A GitHub PR
bash skills/panel-review/panel-review.sh --pr 27
bash skills/panel-review/panel-review.sh --pr https://github.com/owner/repo/pull/27

# Deep mode: panelists run tests + grep callers inside a real PR checkout.
# Each panelist gets write/exec access to a throwaway worktree; the worktree
# is git-worktree-removed on exit.
bash skills/panel-review/panel-review.sh --pr 27 --checkout
bash skills/panel-review/panel-review.sh --base main --checkout --panelist codex
```

## Per-panelist tuning (env vars)

Pass through model selection without code changes:

- `CODEX_MODEL` — e.g. `gpt-5`
- `CLAUDE_MODEL` — e.g. `opus`, `sonnet`, full id like `claude-sonnet-4-6`
- `OPENCODE_MODEL` — e.g. `qwen/qwen-3.6` (run `opencode models` to list)
- `OPENCODE_AGENT` — opencode agent in default (read-only) mode (default `plan`)
- `OPENCODE_AGENT_DEEP` — opencode agent in `--checkout` mode (default `build`)
- `GEMINI_MODEL` — e.g. `gemini-2.5-pro`

Other knobs:

- `PANEL_REVIEW_TIMEOUT` — seconds per panelist (default 600)
- `PANEL_REVIEW_MAX_DIFF_BYTES` — abort if the inline diff exceeds this (default 200000,
  ~200KB). Big rename / refactor PRs blow past this; just bump it
  (e.g. `PANEL_REVIEW_MAX_DIFF_BYTES=1000000`) when prompted. Each panelist embeds the
  full diff in its prompt, so the cap exists to protect context windows and cost — not
  to gate "real" reviews.

## How it works

- Builds a unified diff from the chosen target with `git`.
- Composes one prompt by prepending `prompts/review.md` (or `prompts/review-deep.md`
  in `--checkout` mode) to the diff (and optional focus).
- Spawns each panelist as a background subprocess with read-only / plan-mode flags so
  the reviewer can read repo files but cannot modify anything (default mode).
- Streams each panelist's section to stdout the moment that panelist completes, and
  emits unbuffered stderr heartbeats (`started` / `done`) so a coordinator polling
  `BashOutput` sees real-time progress instead of one big dump at the end.

### Deep mode (`--checkout`)

- `git worktree add --detach $OUT_DIR/worktree <ref>` materializes the target ref in
  isolation. For `--pr N`, follows up with `gh pr checkout N -f` inside the worktree;
  for `--base BRANCH`, materializes `HEAD`; for `--commit SHA`, materializes the SHA.
- Each panelist's CWD is the worktree. Per-panelist permission flags swap to their
  most permissive non-interactive equivalents:
  - codex: `--sandbox workspace-write`
  - claude: `--permission-mode bypassPermissions`
  - opencode: `--agent build --dangerously-skip-permissions`
  - gemini: `--approval-mode yolo`
- A `trap … EXIT` runs `git worktree remove --force` on script exit (including
  signals) so worktrees don't leak. The captured stdout/stderr/diff/prompt files in
  the parent `OUT_DIR` are kept for postmortem.
- The deep-mode prompt explicitly forbids destructive network actions (push,
  PR/issue writes, package publishes) since the sandbox flags no longer enforce
  that. This is a softer guard than read-only mode — treat panelists as untrusted
  code execution against your dev box.

## Notes

- Each panelist is a fresh process — that's the "no prior context" guarantee. They will
  still pick up the project's `AGENTS.md`/`CLAUDE.md`, which is intentional: those
  encode project conventions worth respecting in a review.
- The prompt explicitly forbids GitHub/Slack/Linear writes. In default mode,
  panelists are run in read-only / plan mode at the CLI level as a second line of
  defense; in `--checkout` mode, that second line is gone and the prompt is the
  only guard against destructive actions.
- `--checkout` panelists share the parent repo's `.git` object database via
  `git worktree`. A stray `git push` from a panelist would publish from your
  worktree, even though the worktree itself is throwaway. The deep-mode prompt
  explicitly forbids this; treat the prompt as a firewall, not a sandbox.
- If a panelist times out or errors, the script keeps the others' output and exits 2.
  Surface the failure in your amalgamated report rather than silently dropping it.
- The combined output references a tempdir like `/tmp/panel-review-XXXXXX/` — re-read
  any panelist's raw output from there if you need more detail than the inline excerpt.
