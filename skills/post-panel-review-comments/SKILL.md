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
right PR. Use `gh pr view <ref> --json number,url,title,headRefOid`;
`headRefOid` becomes `commit_id` when posting and the `{owner}/{repo}` for
the comments endpoint comes from the PR `url`
(`https://github.com/{owner}/{repo}/pull/N` — the base repo, where
comments are posted even for fork PRs).

Sort findings HIGH → MEDIUM → LOW (within a severity, group by file).
Build a deep-link for every finding before showing the list — using
`scripts/pr-line-url.sh <pr-url> <path> <line-or-range>` for lines
inside the PR diff, or the blob fallback
`https://github.com/<OWNER>/<REPO>/blob/<HEAD_SHA>/<PATH>#L<LINE>` for
lines outside the diff hunk.

Then, **before printing the list**, pull the PR's existing comments and
match each finding against them so the user triages with that context
(see "Deduplicating against existing comments" for the fetch, the
bot-only matching rule, and the match test). This is detection only — no
reactions or replies yet; you act on the matches at post time.

### 1. Print the full finding list in chat

Numbered `1..N`. Each entry shows:

- panelist + severity tag
- `file:line`
- deep-link **as a plain URL on its own line** (markdown link syntax
  hides the preview)
- the finding body verbatim
- suggested fix if any
- **a `↩ already raised by <bot> — <existing comment URL>` line** when the
  detection pass matched an existing automated comment, so the user can
  see at a glance it'll be a +1 reaction (not a fresh comment) if selected

The select-list options that follow are terse references to these
numbers — the chat list is where the user actually reads the findings.
**Don't paraphrase** — show the panelist's raw output.

### 2. Stage 1 — which to post as PR comments?

Ask via `AskUserQuestion` with `multiSelect: true`. Option labels:
`#<N>: <panelist> <severity> <path>:<line>` (terse — the chat list above
has the prose). Suffix matched findings with ` ↩dup` so the marker
carries into the select list. Selecting a matched finding means "+1 the
existing comment" (and reply only if there's serious added value), not
"post a duplicate".

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
the finding, and a possible solution when one exists. Prefer a
**mergeable suggestion** (a ` ```suggestion ` block) over prose whenever
the fix is a concrete drop-in replacement for the commented line(s) — see
"Mergeable suggestions" below for when it qualifies:

````markdown
<finding body verbatim>

```suggestion
<exact replacement for the commented line(s)>
```
````

When the fix exists but is **not** a clean line replacement (conceptual,
adds code elsewhere, spans beyond the anchored lines, or you can't render
it exactly), fall back to prose instead of a suggestion:

```markdown
<finding body verbatim>

**Possible Solution:** <fix>
```

For **LOW / polish findings only**, prefix the body so the reader knows
it's non-blocking (the suggestion or prose form still follows):

````markdown
Small / Optional polish: <finding body verbatim>

```suggestion
<exact replacement for the commented line(s)>
```
````

(`Small / Optional polish:` is the suggested phrasing — any equivalent
soft, clearly-optional framing is fine.) When a LOW finding's fix isn't a
clean drop-in, use the prose form instead — identical to the
`**Possible Solution:**` shape above, just with the `Small / Optional
polish:` prefix added.

Hard rules for the posted comment:

- **No severity.** Don't write `Severity:`, `HIGH`/`MEDIUM`/`LOW`, or any
  `Recommendation:` / `Must fix` line. The reader doesn't need the
  panel's grading on the PR.
- **No priority.** Don't add a priority label or line.
- **No provenance.** Don't name the panelist(s) or agent(s) that found
  it — no "Codex flagged…", no `<sub>` footer. Attribution stays in the
  triage transcript / chat, not on the PR.
- **A fix line only when there is one.** If the finding has no suggested
  fix, omit both the suggestion block and the `Possible Solution:` line —
  don't invent one.
- **One fix form, not both.** A finding gets either a ` ```suggestion `
  block or a `**Possible Solution:**` line — never both for the same fix.
- The finding prose itself is posted **verbatim** (minus the polish
  prefix). Don't paraphrase or re-grade it.

## Mergeable suggestions

A ` ```suggestion ` block renders a **"Commit suggestion"** button on the
PR — the author can apply the fix in one click. Use it whenever the fix
is a concrete replacement for the exact line(s) the comment is anchored
to. This is the preferred form; reach for `**Possible Solution:**` prose
only when a suggestion doesn't qualify.

How GitHub applies a suggestion: the block's contents **replace the
comment's anchored line range verbatim** — single-line comments replace
that one line, multi-line comments (`start_line`..`line`) replace that
whole span. So the suggestion only works when:

1. **It's an inline comment.** Suggestions do nothing in a top-level
   issue comment — the top-level fallback always uses prose (see "Falling
   back to a top-level comment").
2. **The anchored range covers exactly the lines being replaced, and
   still includes the finding's reported location.** Set the comment's
   line targeting to span exactly the lines the suggestion rewrites — a
   single line, or a contiguous `start_line`..`line` range that starts
   at (or contains) the `file:line` the finding was triaged under. **Don't
   move the anchor off that reported line** to chase a fix that rewrites
   different lines: the reported location is what the chat list showed,
   what the deep-link points at, and what the Pass-1 dedupe matched
   against — moving it silently desyncs the posted comment from all three.
   When the fix would touch lines that don't include the finding's
   location (or sit outside the diff hunk), use prose instead.
3. **The replacement is exact and complete.** The block holds the full
   new text for those lines, with **indentation matching the file** (GitHub
   substitutes it literally — leading whitespace is significant). Include
   every line in the range, even unchanged ones, since the whole span is
   replaced.

When in doubt whether a fix is a faithful drop-in (it's pseudo-code, omits
context, or you're inferring it rather than quoting the panelist), use
`**Possible Solution:**` prose — a wrong suggestion is worse than a prose
hint because it looks one-click-safe.

Suggestions compose with everything else: a suggestion comment still
dedupes against existing automated comments (a match → +1, no suggestion
posted) and still sequences HIGH → MEDIUM → LOW.

## Deduplicating against existing comments

Run in **two passes**: detect during triage (so the user picks with that
context), act at post time (so reactions land on the final selected set
and catch anything a bot posted mid-triage). The fetch and match logic
below is shared by both passes.

### The fetch + match (shared)

Fetch both comment surfaces:

- inline review comments: `gh api repos/{owner}/{repo}/pulls/{N}/comments --paginate`
- top-level issue comments: `gh api repos/{owner}/{repo}/issues/{N}/comments --paginate`

Each item gives you `id`, `user.login`, `user.type` (`"Bot"` for app
accounts), `path`, `line`/`original_line`, `body`, and `html_url`. Treat a
comment as a candidate duplicate only when it's from **another automated
reviewer** — `user.type == "Bot"`, or a login that's clearly a review bot
(`coderabbitai`, `copilot-pull-request-reviewer`, `cursor`, `greptile`,
`sourcery-ai`, a `github-actions` bot, etc.). Ignore human comments and
your own prior comments; don't dedupe against those.

A finding **matches** an existing automated comment when it's about the
same issue — same file, overlapping/adjacent line, and the _same
underlying problem_ (read both bodies and judge semantically; identical
wording is not required, and a different bot phrasing the same bug counts
as a match). Don't over-match: when in doubt whether two comments are
truly the same issue, treat it as no match and post your own — a missed
dedupe is cheaper than collapsing a real finding into a +1 reaction on an
unrelated comment.

### Pass 1 — detect during triage (read-only)

Before printing the finding list, run the fetch + match and annotate each
matched finding in the chat list and the Stage 1 option label (see
"Triage flow"). **No reactions or replies in this pass** — it only informs
the user's pick. Record the matched comment's `id`, author, and
`html_url` alongside the finding to reuse at post time.

### Pass 2 — act at post time

After triage, for each finding the user **selected to post**:

1. **Matched (from Pass 1, or newly matched on a quick re-fetch) → react,
   don't duplicate.** A bot may have commented during triage, so re-run
   the match for selected findings that weren't already flagged — cheap,
   and it prevents a duplicate slipping through. Add a +1 reaction to the existing
   comment instead of posting your own, and skip posting that finding:
   - inline review comment:
     `gh api -X POST repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions -f content=+1`
   - top-level issue comment:
     `gh api -X POST repos/{owner}/{repo}/issues/comments/{comment_id}/reactions -f content=+1`

2. **Matched _and_ you have materially new information** — a concrete
   repro, an additional affected location, a root cause the other bot
   missed, or a better fix — **also** reply in that comment's thread with
   just the delta. Still react with +1. Reply via
   `POST /pulls/{N}/comments` with `in_reply_to: <comment_id>` (for inline
   threads) or `gh pr comment` referencing the location (for top-level
   threads). Lead the reply with a short framing like `Some more info:`
   and include **only** the new detail — don't restate what they already
   said. Apply this sparingly: a +1 reaction alone is the default; reply only when
   there's serious added value.

3. **No match → post normally** per the section below.

Surface every dedupe decision in the report (see "Reporting back").

## Posting (standalone PR comments)

Post each finding that **wasn't deduped** as an **independent inline comment** via
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

When the comment carries a ` ```suggestion ` block, the anchored range
**must be exactly the lines the suggestion replaces** (single line, or
`start_line`..`line` for a multi-line rewrite) — GitHub substitutes the
block for that span. See "Mergeable suggestions".

Sequence the calls HIGH → MEDIUM → LOW (within severity, group by file)
so the email notifications arrive in priority order. One HTTP call per
comment.

The tradeoff is one notification per posted comment instead of one for
the batch. For finding lists of 10+, mention the notification count to
the user before posting.

### Falling back to a top-level comment when GitHub rejects the inline

GitHub only accepts inline comments on lines inside the PR diff hunks.
When a finding points at unchanged context, the `POST /pulls/{N}/comments`
call fails (HTTP 422, message like `line must be part of the diff`).
**Don't drop it and don't just report it — automatically re-post that
finding as a top-level PR issue comment** via
`POST /repos/{owner}/{repo}/issues/{pull_number}/comments` (equivalently
`gh pr comment <ref> --body ...`).

The fallback is per-comment and automatic: each inline rejection triggers
exactly one top-level repost. Comments that posted inline are unaffected.

A top-level comment isn't anchored to a line, so it needs the location in
the body. Prepend a `**Location:**` line with the `file:line` and the
blob deep-link (the diff anchor won't resolve outside the hunk — use the
`https://github.com/<OWNER>/<REPO>/blob/<HEAD_SHA>/<PATH>#L<LINE>` form),
then the **same body shape as inline**: finding prose verbatim, an
optional `**Possible Solution:**` line, and the `Small / Optional polish:`
prefix for LOW findings.

**A top-level comment can't be a mergeable suggestion** — ` ```suggestion `
only applies to anchored inline comments. If a finding that would have
carried a suggestion falls back here, **downgrade it to a
`**Possible Solution:**` prose line** (describe the same replacement in
words) rather than emitting a dead suggestion block.

```markdown
**Location:** `<path>:<line>` — <blob deep-link URL>

<finding body verbatim>

**Possible Solution:** <fix>
```

Same no-severity / no-priority / no-provenance rules as inline comments
(see "Comment body shape"). Track which findings fell back so you can
report them distinctly (see "Reporting back").

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
  line, then the finding body, then the fix line if any. Write the fix as
  a `**Possible Solution:**` prose line, **never a ` ```suggestion `
  block** — suggestions are GitHub-inline-only and render as dead code in
  a Linear ticket.
- **Do not set priority.** Triage priority is the issue owner's call,
  not ours.
- **No severity → priority mapping.** Don't sneak it in as a label
  either unless the user explicitly asks.

## Reporting back

After posting and filing, report:

- The list of posted comment URLs (one per comment), grouped together
- Which of those carried a mergeable ` ```suggestion ` block (one-click
  "Commit suggestion") versus a prose `Possible Solution:` line, so the
  user knows which can be applied directly
- Which of those fell back to a top-level comment (because GitHub
  rejected the inline) and why — call these out distinctly so the user
  knows they're not anchored to the line (and that any suggestion was
  downgraded to prose)
- **Which findings were deduped against an existing automated comment** —
  for each, the existing comment's `html_url`, the bot that authored it,
  and whether you reacted only (+1) or also replied with extra info. Call
  these out distinctly so the user knows they weren't posted fresh.
- The Linear ticket URLs (if any tickets were filed), grouped together
- One-line summary:
  `Posted N comments to PR #X (J as top-level fallbacks), +1'd D existing automated comments, filed M Linear tickets, dropped K`
- Any comment that failed _both_ inline and the top-level fallback (rare)
  so the user can handle it manually

## Gotchas

- **Inline comments only work on lines inside the PR diff.** If a
  panelist flags unchanged context, the API rejects just that comment
  (the rest still post). The skill auto-reposts the rejected one as a
  top-level PR comment (with the `file:line` in the body) rather than
  dropping it — see "Falling back to a top-level comment". Never silently
  swallow a rejection.
- **One notification per posted comment.** Standalone comments don't
  batch. For very large lists (10+), warn the user before posting so
  they can route some to Linear or drop them instead.
- **Suggestions are inline-only and anchor-exact.** A ` ```suggestion `
  block replaces the comment's anchored line range verbatim, so it needs
  an inline comment whose range matches the lines being rewritten, with
  indentation matching the file. It can't live in a top-level fallback
  (downgrade to prose there). When a fix isn't a faithful drop-in, use
  `**Possible Solution:**` prose — a wrong one-click suggestion is worse
  than a hint (see "Mergeable suggestions").
- **Don't auto-detect the PR from the current branch.** Pass the ref
  through from the caller's context.
- **Dedupe is two passes: detect during triage, act at post time.**
  Detecting during triage lets the user see a finding is already covered
  before they pick it; acting at post time keeps reactions on the final
  selected set and catches bot comments that landed mid-triage. Don't
  collapse it into one pass at either end (see "Deduplicating against
  existing comments").
- **Only dedupe against other automated reviewers.** Don't +1-and-skip a
  finding because a _human_ already mentioned it, and never dedupe
  against your own earlier comments. When unsure two comments are the
  same issue, post your own rather than collapsing it to a reaction.

## Dry-run mode

If the user asks for a dry run ("don't actually post", "just show me the
payload") or sets `POST_PANEL_REVIEW_COMMENTS_DRY_RUN=1`, do everything
normally but write:

- `./comments.json` — array of per-comment payloads (each as it would be
  POSTed to `/pulls/{N}/comments`), instead of calling the API. Dry-run
  can't observe which lines GitHub would reject, so it emits the inline
  payload for every selected finding. For any finding you can already
  tell sits outside the diff hunk, note in the transcript that it would
  fall back to a top-level comment on a real run. **Still run the
  triage-time detection pass** (it's read-only) and, for any finding that
  matches an existing automated comment, omit its payload from
  `comments.json` and record the planned +1 (and any reply body) in the
  transcript instead. Skip the post-time act pass — write no reactions or
  replies in a dry run.
- `./linear_tickets.json` — array of `{team, project, title, description}`
  objects, instead of filing tickets
- `./triage_transcript.md` — the full finding list (with deep-links),
  the exact option labels shown in each `AskUserQuestion` (so the modal
  text is auditable without an interactive user), and the final
  disposition per finding (posted to PR — note whether as a mergeable
  suggestion or prose / posted as top-level fallback / filed to Linear /
  dropped / deduped-to-+1 on an existing comment). For
  deduped findings, record the matched comment's URL and author. If
  Stage 2 was skipped because Linear wasn't reachable, record that
  explicitly — distinguish from a user-declined Stage 2.

Honor user-supplied paths if provided (e.g. "write to /tmp/comments.json").
