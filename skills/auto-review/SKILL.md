---
name: auto-review
description: >
  One-shot "review, post, and maybe approve" pipeline for a PR. Runs the
  `panel-review` skill (called as-is, kept separate), then runs the
  `auto-post-panel-review-comments` flow to post the legitimate findings
  straight to the PR, then — only when the PR comes back clean enough
  (every panelist returned and the findings are LOW/polish only, no
  must-fix or should-fix, approach sound) — approves the PR via
  `approve-pr` with a short LGTM-style body. The approval step only runs
  when the invocation actually asks for it — "auto-review this PR", "auto
  review", "review it and approve if it's clean", "review, comment, and
  stamp it if clean". A post-only request ("review and post the comments",
  "panel-review then auto-post") runs the review + post and **skips
  approval**; when intent is ambiguous it defaults to post-only. (Posting
  findings you already have in hand, with no review to run, is
  `auto-post-panel-review-comments`, not this skill.) Honors the auto-post routing overrides (e.g. "send LOW/polish
  to Linear"). Do NOT use when the user only wants the review
  (`panel-review`), only wants to post findings already in hand
  (`auto-post-panel-review-comments` / `post-panel-review-comments`), wants
  to iterate fix-and-rereview to convergence (`panel-review-loop`), or just
  wants to approve (`approve-pr`).
---

# auto-review

A thin orchestrator that chains three existing skills into one
hands-off pass over a PR:

```
panel-review  →  auto-post-panel-review-comments  →  approve-pr (only if clean)
```

It **does not reimplement** any of them — it calls each in turn and adds
one new piece of logic: the **approval gate** that decides whether the PR
is clean enough to stamp. Everything about how reviews run, how comments
are shaped/posted/deduped, and how approvals are submitted lives in those
three skills; this file owns only the wiring and the gate.

## Prerequisite

This skill orchestrates `panel-review` and
`auto-post-panel-review-comments` (always needed), and `approve-pr` (only
when the invocation includes approval intent — see "Autonomy"). A
post-only run needs just the first two. If a required skill is missing,
stop and tell the user to install it rather than hand-rolling its
behavior — the value here is composing the real skills, not duplicating
them.

## Target

`auto-review` operates on **a PR** — it posts comments to it and may
approve it. Resolve the PR the way `panel-review` does (named PR, or the
current branch's PR). Capture **both the PR ref and its head SHA**
(`headRefOid`) once, up front, and reuse the **same** PR for the posting
and approval steps.

The head SHA matters because a panel review takes minutes — long enough
for the author to push during it. Pin the SHA you reviewed: post comments
against that `commit_id`, and **before approving, re-fetch the PR head and
confirm it still matches** the reviewed SHA. If it changed, the current
head was never reviewed — withhold approval and report that a re-run is
needed (this is gate condition #7 below).

If the review ends up running against a non-PR target (`--uncommitted`,
`--base`, a bare `--commit` with no PR), there's nothing to post to or
approve: run the review, report its synthesis, and stop — note that
posting/approval were skipped because the target isn't a PR.

Pass the user's `panel-review` options through (panelist selection,
`--focus`, deep mode if they asked for a "deep auto-review"). Default to
the standard multi-panelist run — the approval gate leans on having
several independent reviewers (see the gate).

## The pipeline

### 1. Review — run `panel-review` (kept separate)

Invoke the `panel-review` skill and let it run end to end: it launches
`panel-review.sh`, streams per-panelist progress, and produces the
synthesis (Risk, Goal/Approach checks, must-fix / should-fix / polish
buckets, disagreements). Don't reimplement its fan-out.

**Reuse a review that already ran.** If a fresh `panel-review` for this
exact PR/SHA is already available in context (the user just ran it, or
supplied its synthesis + per-panelist outcomes), use that instead of
re-running — re-running wastes a multi-minute fan-out. Only re-run when no
current review is in hand. Either way you need the same two captures below;
a reused review must include the **per-panelist exit statuses AND the
launched panelist set** (the `exit N` markers / `## <name> (exit N)`
headers, and the panelist list / any `--panelist` flags) — coverage
(gate #1) needs the exit statuses and the narrowing check (gate #2) needs
the launched set. If a supplied review lacks either, treat that property
as not established and **don't approve** on it.

Capture two things for later steps:

- **Per-panelist outcome** — which panelists returned a verdict vs.
  failed/timed out. `panel-review` surfaces this two ways: a
  `panel-review: <name> (<model>) done (exit N)` heartbeat per panelist,
  and a `## <name> / <model> (exit N)` section header in its combined
  output. `exit 0` (including a `NO_FINDINGS` verdict) counts as
  **returned**; a non-zero exit (crash, timeout, the flaky `database is
locked`, etc.) counts as **missing**. **Cross-check the count**: the
  number of `exit 0` panelists must equal the number launched. If you
  can't establish per-panelist exit status for every launched panelist
  (e.g. the output was truncated), treat coverage as **not** established
  and don't approve — never infer a clean full run from the synthesis
  alone. Coverage is the gate's central safety property.
- **The synthesized findings** — the buckets and the approach verdict.

### 2. Post — run `auto-post-panel-review-comments`

Hand the synthesized findings, the PR ref, **and the head SHA you captured
before the review** to the `auto-post-panel-review-comments` flow, and tell
it to post against that pinned `commit_id` instead of re-resolving the
head (it accepts a caller-pinned commit_id; see its "Posting" section).
Pinning matters: a push during the review would otherwise make auto-post
re-resolve to the new head and anchor your comments to code no panelist
saw. With the SHA pinned, comments anchor to exactly what was reviewed
(GitHub marks them outdated if the author has since moved the lines), and
gate #7 separately withholds the approval. It posts the legitimate findings
to the PR (mergeable suggestion / prose / body-only), `+1`s anything a bot
already raised, routes uncertain / out-of-PR-scope findings to Linear, and
honors routing overrides. All of that — the bar, dedupe, fallback, Linear
rules, zero-touch behavior — is defined in that skill; use it verbatim.

Posting happens **regardless** of whether the PR will be approved: clean
PRs may still have polish comments worth leaving, and non-clean PRs need
their comments posted so the author can act.

**Every finding-based blocker must leave a PR comment.** If a
finding-based gate failure — a must-fix/should-fix (#3) or a substantiated
`Approach (questionable)` flag (#4) — would withhold approval but isn't
already in the PR-bound posting set, add it before posting: at its
root-cause `file:line` when it has one, otherwise as a top-level PR
comment. (This is only about findings; the structural blockers — draft
#5, self-authored #6, head-moved #7 — have no finding to post and are
explained in the report, not as PR comments.) A withheld approval whose
finding the author can't see on the PR is a silent block; never withhold
on a finding you didn't post.

If the posting step itself fails (GitHub API errors, or a routing override
sends findings to an unreachable Linear), **surface the failure and do not
approve** — an approval implies the review actually landed on the PR. Post
what you can, report what didn't, and skip step 3.

### 3. Approve — only when the gate passes

After comments are posted, evaluate the **approval gate** (below). If it
passes, approve via the `approve-pr` skill, passing a short LGTM body
(see "Approval body") so `approve-pr` uses it verbatim. If it fails,
**do not approve** — skip to the report and say why.

### 4. Report

One consolidated report: the review summary (Risk + bucket counts), what
auto-post did (posted / `+1`'d / filed to Linear / dropped / needs
attention), and the **approval decision** — approved (with the body used
and the PR URL) or not approved (with the specific gate condition that
failed).

## The approval gate

Approve **only if every one** of these holds. If any fails, post the
comments (step 2 already did) and stop without approving.

1. **Full reviewer coverage.** Every panelist that was launched **returned
   a verdict** (`exit 0`) — concretely, `count(exit 0) == count(launched)`.
   Any non-zero exit (crash, timeout) fails this condition; "returned a
   verdict" means a clean exit, not merely "produced some output." If any
   panelist failed/timed out, you don't have the coverage the approval
   implies — **don't approve.** (A run that silently lost a panelist is not
   a clean run.)
2. **Enough independent reviewers — at least two, not narrowed.** Two
   things must both hold: (a) a hard floor of **≥ 2 distinct panelists
   returned `exit 0`** — one opinion is never enough to auto-stamp, even
   if it's the only supported CLI installed on the host; and (b) the panel
   wasn't **narrowed** below `panel-review`'s default via `--panelist`
   (you launched the review in step 1, so you know whether it was
   narrowed). A single-reviewer run — whether hand-picked with
   `--panelist` or just the only CLI on PATH — fails this: post comments
   and recommend, but leave approval to a human and say so. (This is the
   bar for the _approval_; the review and posting still run on whatever
   panel the user chose.)
3. **No blocking findings.** The synthesis has **zero must-fix
   (CRITICAL/HIGH)** and **zero should-fix (MEDIUM)** findings. Only
   **polish (LOW)** findings, or none at all.
4. **Sound approach.** No substantiated `Approach (questionable)` flag —
   an independent invariant: a wrong-layer change must not be stamped even
   if every line-level finding is LOW, regardless of how that flag's
   severity happens to be bucketed. (It usually also lands in must-fix, so
   #3 often catches it too — but don't rely on that mapping; check the
   approach verdict directly.)
5. **Not a draft.** The PR is **not** a draft. `gh pr review --approve`
   succeeds on draft PRs, but a draft is the author explicitly saying
   "not ready" — check `gh pr view <ref> --json isDraft --jq '.isDraft'`
   and **don't approve** when `true` (report the draft state; comments
   still posted).
6. **Not your own PR.** GitHub rejects an approving review from the PR
   author. Compare the authenticated user (`gh api user --jq '.login'`)
   against the PR author (`gh pr view <ref> --json author --jq
'.author.login'`); if they match, **don't approve** — report that it
   can't be self-approved (per `approve-pr`); the comments still posted.
7. **Head unchanged since review.** Re-fetch the PR head SHA and confirm
   it still equals the `headRefOid` you captured before the review (see
   "Target"). If the author pushed during the run, the current head was
   never reviewed — **don't approve**; report that a re-run is needed (the
   comments still posted, anchored to the reviewed SHA).

When the gate passes, Risk will be LOW by construction. When it fails on
#3/#4 (real findings), the PR genuinely needs work — **don't** leave a
`request-changes` review by default (the inline comments are enough, and a
blocking review from an automated pass is heavy-handed); just report the
recommendation and, if the user wants iteration, point them at
`panel-review-loop`.

## Approval body

Short, ASCII, no emoji (repo convention), no review summary dump — one
line, handed to `approve-pr` verbatim. Pick by what was posted:

- **No findings at all** → `LGTM`
- **Only LOW/polish findings posted** → `LGTM, just some small comments, nothing blocking`

Use those two canonical bodies as-is (don't vary the wording — a stable
body keeps the approval auditable). A user-supplied explicit approval
message is passed through verbatim **only when the gate passes** (it's
the approval body); on gate failure there is no approval and the body is
null regardless of any supplied message.

Keep it to that one line. `approve-pr` submits `gh pr review --approve
--body "<line>"`; because a body is supplied, it uses it verbatim and adds
no emoji of its own.

## Autonomy

`auto-review` is automatic by design: once started it reviews, posts, and
(if the gate passes) approves without stopping for confirmation, then
reports once. The approval is gated by the strict conditions above — that
gate, plus an invocation that asked for approval, is the authorization.
Three honest limits on that autonomy:

- **Approval needs an approval intent.** Step 3 runs only when the
  invocation actually asks for the full review→post→**approve** pipeline —
  "auto-review", "review and approve if clean", "stamp it if clean",
  "approve when ready", or an explicit approval cue. When the user asked
  only to **review and post** ("review and post the comments",
  "panel-review then auto-post", "post the findings"), treat it as
  post-only: run steps 1–2 and **skip approval**, reporting the decision
  you _would_ have made. When the intent is ambiguous, default to
  post-only — an unrequested approval is the costlier mistake. (The
  opt-out phrases "don't approve" / "no auto-approve" force post-only
  regardless.)
- **Surface the PR before approving.** Even though it's automatic, name
  the PR (`PR #N — title — url`) in the flow so a wrong target is visible
  before the approval notification goes out.
- **Never approve an unreviewed head.** If the PR head moved between the
  review and the approval (see "Target"), withhold approval — the
  comments still posted, but the stamp would cover code no panelist saw.

## Gotchas

- **Don't reimplement the sub-skills.** Call `panel-review`,
  `auto-post-panel-review-comments`, and `approve-pr`. The wiring + the
  gate are the only things this skill adds.
- **A lost panelist blocks approval.** The flaky local CLIs sometimes exit
  non-zero (`database is locked`, timeouts). That's missing coverage, not
  a clean bill of health — post the comments but don't auto-approve;
  report which panelist was missing so the user can re-run.
- **Polish still gets posted.** A clean-enough-to-approve PR can still have
  LOW comments worth leaving; post them, then approve with the "small
  comments, nothing blocking" body. Approval and polish comments are not
  mutually exclusive.
- **No `request-changes` by default.** When findings block approval, the
  inline comments carry the signal; this skill doesn't submit a blocking
  review unless the user explicitly asks.
- **Same PR throughout.** Resolve the PR once and reuse it for review,
  posting, and approval — don't re-detect per step (the branch could be
  read differently, or drift).

## Dry-run mode

If the user asks for a dry run, or sets `AUTO_REVIEW_DRY_RUN=1`, run the
review for real (it's read-only) but don't post or approve. Write:

- the `auto-post-panel-review-comments` dry-run artifacts for the posting
  step: `./comments.json`, `./reactions.json`, `./linear_tickets.json`.
  Note that auto-post's dry-run **also writes a `./report.md` by default**
  (and an abort `./report.md`), which would clobber auto-review's
  consolidated report — so **pass the auto-post step `./post-report.md` as
  its report path** (its dry-run honors caller-supplied paths). That keeps
  `./report.md` free for auto-review's own consolidated report below; fold
  auto-post's `./post-report.md` disposition into it.
- `./approval.json` — the approval decision. Example:
  `{ "approve": false, "reason": "1 should-fix (MEDIUM) finding", "body": null, "coverage": "3/3" }`
  (on a pass: `{ "approve": true, "reason": "clean: LOW/polish only", "body": "LGTM, just some small comments, nothing blocking", "coverage": "3/3" }`).
- `./report.md` — auto-review's **final consolidated** report (review
  summary + posting disposition + approval decision). The single
  authoritative report; auto-post's posting detail lives in
  `./post-report.md` and is summarized here.

Honor user-supplied paths if provided.
