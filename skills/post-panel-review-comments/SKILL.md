---
name: post-panel-review-comments
description: >
  Interactively triage code review findings (typically from a prior
  `panel-review`) via a two-stage select list: first pick which to post
  as standalone inline PR comments, then pick which of the leftovers to
  file as Linear tickets (when Linear is reachable from the session).
  Anything not selected in either stage is dropped. Use any time the
  user has review findings with `file:line` references in conversation
  context and wants to selectively act on them — phrasings include
  "post these comments", "post the panel review comments", "triage these
  findings", "let me triage and post", "comment these on the PR", "file
  these as tickets", "open a review on PR <N> with these", or casual asks
  like "let's get these onto the PR". Pairs naturally with `panel-review`
  but works on any structured findings list with file:line refs. Do NOT
  use when the user wants you to *generate* the findings (run a review
  skill first), or when they want a single bulk summary comment instead
  of inline ones.
---

# post-panel-review-comments

Shows the user the full finding list, then asks once which to post as
standalone PR comments and once which of the leftovers to file as Linear
tickets (when Linear is reachable). Anything not selected in either
stage is dropped.

The mechanics of the GitHub or Linear APIs are not the point — you
already know those (or your runtime exposes them). The point is the
triage UX, the wrapper formatting, and a few sharp gotchas.

**No rewrite step.** The skill posts the finding prose as the panelist
wrote it (it does strip the panel's severity/recommendation/attribution
and add a polish prefix for LOW findings — see "Comment body shape" —
but never paraphrases the body). If the user wants softer wording on a
specific finding, they should ask the agent to rewrite it before
triggering this skill.

## Detecting the Linear option

Before triaging, decide whether you can actually create Linear tickets
from this session — through whatever mechanism your runtime exposes
(an MCP server, a CLI like `linear`, a configured API token, etc.). If
you can, run Stage 2 of the triage flow. If you can't, **skip Stage 2
entirely** — don't show it disabled, don't suggest installing anything.
With no Stage 2, anything not picked in Stage 1 is implicitly dropped.

If Linear is available and the user picks anything to file, ask **once
upfront** which Linear team and project tickets should land in. Don't
re-ask per finding.

## Inputs

1. **Findings** — usually from a prior `panel-review`. Each needs a
   file path, line (or range), and body. Severity (HIGH/MEDIUM/LOW) and
   panelist, when present, are used internally only — to order the
   posting sequence and to flag LOW/polish findings — and are **never
   written into the posted comment** (see "Comment body shape").
2. **PR ref** — number or URL. Take it from the caller's context (e.g.
   the review's scope). **Do not auto-detect from the current branch** —
   the user may have switched branches between review and post. If no
   PR ref is in the caller's context, ask once before doing anything
   else.

If a finding lacks a file/line, ask before triaging — inline comments
need a concrete location.

## Triage flow

Before triaging, resolve and surface the PR back to the user
(`PR #N: <title> — <url>`) — cheap sanity check you're targeting the
right PR. Use `gh pr view <ref> --json number,url,title,headRefOid,nameWithOwner`;
`headRefOid` becomes `commit_id` when posting and `nameWithOwner` is
the `{owner}/{repo}` for the comments endpoint.

Sort findings HIGH → MEDIUM → LOW (within a severity, group by file).
Build a deep-link for every finding before showing the list — using
`scripts/pr-line-url.sh <pr-url> <path> <line-or-range>` for lines
inside the PR diff, or the blob fallback
`https://github.com/<OWNER>/<REPO>/blob/<HEAD_SHA>/<PATH>#L<LINE>` for
lines outside the diff hunk.

### 1. Print the full finding list in chat

Numbered `1..N`. Each entry shows:

- panelist + severity tag
- `file:line`
- deep-link **as a plain URL on its own line** (markdown link syntax
  hides the preview)
- the finding body verbatim
- suggested fix if any

The select-list options that follow are terse references to these
numbers — the chat list is where the user actually reads the findings.
**Don't paraphrase** — show the panelist's raw output.

### 2. Stage 1 — which to post as PR comments?

Ask via `AskUserQuestion` with `multiSelect: true`. Option labels:
`#<N>: <panelist> <severity> <path>:<line>` (terse — the chat list above
has the prose).

- **≤ 4 findings:** one question, all findings as options.
- **> 4 findings:** chunk into multiple questions of ≤ 4 options each.
  Use a single `AskUserQuestion` call's `questions[]` array when the
  chunks fit (max 4 questions × 4 options = 16 findings). For larger
  lists, send sequential `AskUserQuestion` calls. Group chunks by
  severity (all HIGHs first, then MEDIUMs, then LOWs) so the question
  headers stay meaningful. **`AskUserQuestion` requires ≥ 2 options per
  question** — if grouping by severity would produce a 1-finding chunk,
  merge it into the adjacent chunk (preserving HIGH → LOW order) rather
  than emitting a single-option question.

### 3. Stage 2 — which leftovers to file as Linear tickets?

Skip Stage 2 entirely if:

- Linear isn't reachable from this session (see "Detecting the Linear
  option"), or
- Stage 1 selected everything.

Otherwise, ask via `AskUserQuestion` with `multiSelect: true`, listing
only the findings **not** selected in Stage 1. Same chunking rules.

If the user picks anything to file, ask **once upfront** for the Linear
team and project before filing the first ticket.

### 4. Drop the rest

Anything still unselected is dropped. Confirm the drop count to the
user before posting/filing: e.g. `Posting 3, filing 1, dropping 2 — go?`

### Bulk shortcuts

If the user gives a bulk instruction upfront ("post all HIGH/MEDIUM,
file LOWs in Linear", "drop everything below HIGH"), honor it and skip
the corresponding select stage. Still surface the planned dispositions
in chat and confirm before acting.

If nothing was selected to post, skip the posting step entirely. Linear
filings are independent — file them anyway.

## Comment body shape

Each selected finding becomes one inline comment. Keep it minimal — just
the finding, and a possible solution when one exists:

```markdown
<finding body verbatim>

**Possible Solution:** <fix>
```

For **LOW / polish findings only**, prefix the body so the reader knows
it's non-blocking:

```markdown
Small / Optional polish: <finding body verbatim>

**Possible Solution:** <fix>
```

(`Small / Optional polish:` is the suggested phrasing — any equivalent
soft, clearly-optional framing is fine.)

Hard rules for the posted comment:

- **No severity.** Don't write `Severity:`, `HIGH`/`MEDIUM`/`LOW`, or any
  `Recommendation:` / `Must fix` line. The reader doesn't need the
  panel's grading on the PR.
- **No priority.** Don't add a priority label or line.
- **No provenance.** Don't name the panelist(s) or agent(s) that found
  it — no "Codex flagged…", no `<sub>` footer. Attribution stays in the
  triage transcript / chat, not on the PR.
- **`Possible Solution:` only when there is one.** If the finding has no
  suggested fix, omit the line entirely — don't invent one.
- The finding prose itself is posted **verbatim** (minus the polish
  prefix). Don't paraphrase or re-grade it.

## Posting (standalone PR comments)

Post each selected finding as an **independent inline comment** via
`POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` with `body`,
`commit_id` (head SHA), `path`, and the line targeting fields. **No
review wrapper, no batched review.** GitHub does not surface a "left a
review" timeline entry for standalone comments, which is the point.

Line targeting:

- Single-line: `line`, `side: "RIGHT"`.
- Multi-line: `start_line`, `start_side: "RIGHT"`, `line` (the **end**
  of the range), `side: "RIGHT"`. `line` is always the last line in
  the range, not the first — easy to flip and end up commenting on the
  wrong hunk.

Sequence the calls HIGH → MEDIUM → LOW (within severity, group by file)
so the email notifications arrive in priority order. One HTTP call per
comment.

The tradeoff is one notification per posted comment instead of one for
the batch. For finding lists of 10+, mention the notification count to
the user before posting.

## Filing (Linear tickets)

Only available when Linear is reachable from this session — see
"Detecting the Linear option" at the top.

- **Ask for team and project once**, before filing the first ticket.
  Don't re-ask per finding.
- **Title:** derive from the finding's first sentence or, if the
  panelist supplied a one-line summary, use that. Keep it under ~80
  chars.
- **Description:** include in this order — PR link with the file:line
  deep-link, `File: <path>:<line>`, `Severity: <High|Medium|Low>`, blank
  line, then the finding body, then the fix line if any.
- **Do not set priority.** Triage priority is the issue owner's call,
  not ours.
- **No severity → priority mapping.** Don't sneak it in as a label
  either unless the user explicitly asks.

## Reporting back

After posting and filing, report:

- The list of posted comment URLs (one per comment), grouped together
- The Linear ticket URLs (if any tickets were filed), grouped together
- One-line summary: `Posted N comments to PR #X, filed M Linear tickets, dropped K`
- Any per-comment errors GitHub returned (typically: line outside the
  diff hunk) so the user can post those manually

## Gotchas

- **Inline comments only work on lines inside the PR diff.** If a
  panelist flags unchanged context, the API rejects just that comment
  (the rest still post). Surface the rejection — don't silently swallow.
- **One notification per posted comment.** Standalone comments don't
  batch. For very large lists (10+), warn the user before posting so
  they can route some to Linear or drop them instead.
- **Don't auto-detect the PR from the current branch.** Pass the ref
  through from the caller's context.

## Dry-run mode

If the user asks for a dry run ("don't actually post", "just show me the
payload") or sets `POST_REVIEW_COMMENTS_DRY_RUN=1`, do everything
normally but write:

- `./comments.json` — array of per-comment payloads (each as it would be
  POSTed to `/pulls/{N}/comments`), instead of calling the API
- `./linear_tickets.json` — array of `{team, project, title, description}`
  objects, instead of filing tickets
- `./triage_transcript.md` — the full finding list (with deep-links),
  the exact option labels shown in each `AskUserQuestion` (so the modal
  text is auditable without an interactive user), and the final
  disposition per finding (posted to PR / filed to Linear / dropped).
  If Stage 2 was skipped because Linear wasn't reachable, record that
  explicitly — distinguish from a user-declined Stage 2.

Honor user-supplied paths if provided (e.g. "write to /tmp/comments.json").
