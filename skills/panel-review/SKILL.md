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
4. **Run the script** (path: `skills/panel-review/panel-review.sh`). Prefer running it
   as a **background Bash** (`run_in_background: true`) and poll progress with
   `BashOutput`. Reason: panelists run in parallel, but Codex is slow and dominates
   wall clock — without backgrounding, the foreground Bash call blocks silently for
   minutes. The script emits unbuffered stderr heartbeats (`panel-review: <name>
started (pid=…)` and `panel-review: <name> done (exit N)`) and streams each
   panelist's section to stdout the moment that panelist finishes, so polling
   `BashOutput` every 30–60 seconds yields real-time visibility. If you do run it in
   the foreground, pass `timeout: 600000` (10 min) since the default 2-minute Bash
   timeout will kill the call before Codex returns.
5. **Read the script's combined output** — it prints one section per panelist with their
   raw findings, plus a tempdir path containing each panelist's stdout/stderr. Wait for
   _all_ panelists to finish before amalgamating; partial output is fine to _show_ the
   user during the wait, but consensus / disagreement analysis needs every panelist's
   verdict.
6. **Amalgamate the findings** in your reply to the user:
   - **Consensus** — issues raised by 2+ panelists, deduplicated. List file:line + the
     core problem and a suggested fix.
   - **Unique findings** — per panelist, only the findings no one else mentioned that
     still pass the "would a competent reviewer ask for this change" bar.
   - **Action list** — must-fix → should-fix → optional polish.
   - **Disagreements** — if panelists contradict each other, surface that explicitly
     rather than picking a side.
7. **Don't paraphrase or invent.** Surface what the panelists actually said. If a
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
```

## Per-panelist tuning (env vars)

Pass through model selection without code changes:

- `CODEX_MODEL` — e.g. `gpt-5`
- `CLAUDE_MODEL` — e.g. `opus`, `sonnet`, full id like `claude-sonnet-4-6`
- `OPENCODE_MODEL` — e.g. `qwen/qwen-3.6` (run `opencode models` to list)
- `OPENCODE_AGENT` — opencode agent (default `plan`, read-only)
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
- Composes one prompt by prepending `prompts/review.md` to the diff (and optional focus).
- Spawns each panelist as a background subprocess with read-only / plan-mode flags so
  the reviewer can read repo files but cannot modify anything.
- Streams each panelist's section to stdout the moment that panelist completes, and
  emits unbuffered stderr heartbeats (`started` / `done`) so a coordinator polling
  `BashOutput` sees real-time progress instead of one big dump at the end.

## Notes

- Each panelist is a fresh process — that's the "no prior context" guarantee. They will
  still pick up the project's `AGENTS.md`/`CLAUDE.md`, which is intentional: those
  encode project conventions worth respecting in a review.
- The prompt explicitly forbids GitHub/Slack/Linear writes. Panelists are run in
  read-only / plan mode at the CLI level as a second line of defense.
- If a panelist times out or errors, the script keeps the others' output and exits 2.
  Surface the failure in your amalgamated report rather than silently dropping it.
- The combined output references a tempdir like `/tmp/panel-review-XXXXXX/` — re-read
  any panelist's raw output from there if you need more detail than the inline excerpt.
