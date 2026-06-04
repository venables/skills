---
name: panel-review-loop
description: >
  Drive an autonomous review-fix-rereview loop around the `panel-review` skill:
  do the task, run a `panel-review`, judge which findings are actually worth
  fixing, fix those, then run `panel-review` again — repeating until nothing
  worth fixing is left — and finally report what was fixed, what was deliberately
  left alone (and why), and any deviations from the original goal. Use whenever
  the user asks for a "panel review loop" / "panel-review loop", a "review loop",
  to "loop until it's clean" / "loop until green", "keep panel-reviewing until
  it's good", "iterate with panel reviews until there's nothing left to fix",
  a "review-and-fix loop", or "run a panel review, fix what matters, then
  re-review" — i.e. any phrasing that means *iterate* on panel reviews rather
  than run a single one. This skill orchestrates the `panel-review` skill; it
  does not replace it. For a SINGLE one-shot review with no fix/re-review cycle,
  use `panel-review` directly instead.
---

# panel-review-loop

Runs the review-fix-rereview cycle around the `panel-review` skill until the work is in
good shape, then reports back. You do the task, fan a panel review out to independent
agents, decide which findings are genuinely worth fixing, fix those, and review again —
looping until nothing worth fixing is left. The deliverable is a short report: what you
fixed, what you chose to leave alone (and why), and anywhere the implementation drifted
from the goal.

This is **autonomous by design**: once started, it runs the whole loop without stopping
for approval between rounds, and reports once at the end. You'll still see `panel-review`'s
own per-panelist progress stream each round — that's progress output, not a check-in; the
loop simply never pauses for your input until it's done.

## When to use

- The user asks for a "panel review loop", "review loop", to "loop until it's clean",
  "keep panel-reviewing until it's good", or to "review and fix what matters, then
  re-review".
- The work — code, a doc, a spec, a plan — is done or nearly done, and the user wants
  it hardened through repeated independent review rather than a single pass.

When _not_ to use:

- The user wants a single review with no fix/re-review cycle → use `panel-review`
  directly.
- The user wants _this_ session to review the code itself → use the code-reviewer agent.
- The user has findings that already exist and wants to post them as PR comments or file
  them as tickets → `post-panel-review-comments`. Comments already on a PR that need acting on
  → `pr-comment-handler`.

## Prerequisite

This skill orchestrates the `panel-review` skill — it must be installed and available in
this session. Skills have no formal dependency mechanism; this one simply invokes
`panel-review` by name at the review step. If `panel-review` isn't available, stop and
tell the user to install it
(`npx skills add catena-labs/dev-skills --skill panel-review`) rather than hand-rolling a
fan-out — the whole value of the loop is independent reviewers with fresh context.

## The loop

```
0. Anchor the goal        what does "done / good" mean for this task?
1. panel-review           invoke the skill (round 1)
2. Judge the findings     per finding: FIX or FOREGO, with a reason
3. anything worth fixing?
     yes -> fix in the working tree, then go to 1 (re-review)
     no  -> go to 4
4. Report                 fixed / left alone + why / deviations / notes
```

### 0. Anchor the goal

Before the first review, write down — one or two sentences, in your TodoWrite / working
notes — what the task was meant to achieve. This anchor matters because the two judgment
calls later in the loop both lean on it: deciding whether a finding is in-scope vs.
out-of-scope, and reporting at the end where the implementation drifted from intent.
`panel-review` does its own Goal check and Approach check, which you'll cross-reference
against this anchor.

If the task isn't actually done yet, finish it first — the loop reviews real work, not a
stub. Usually the work already exists in this session; just capture the goal and proceed.

### 1. Run panel-review

Invoke the `panel-review` skill and follow its steps end to end — it runs
`panel-review.sh` and streams the panelists' progress for you. Don't reimplement
its fan-out or drive that script yourself with ad-hoc orchestration in place of the skill;
you want its polling, per-panelist streaming, and synthesized output: the Risk rating,
Goal check, Approach check, Consensus / Unique findings, Disagreements, and Action list.
Those are the inputs to your judgment step.

- Let `panel-review` pick the target the way it normally does in round 1 (auto-detect, or
  the target the user named), and note which target it used. One wrinkle drives the rest:
  the loop's fixes live in your working tree, unpushed and uncommitted (see step 3), and
  only `--uncommitted` reflects them. So if round 1 ran against `--pr` / `--base` /
  `--commit`, switch to `--uncommitted` for every later round — otherwise the re-review
  re-reads stale committed/remote state and never sees your fixes. If round 1 was already
  `--uncommitted`, just hold it. From then on, keep `--uncommitted` every round so
  findings stay comparable across rounds. Be honest about what this scopes, though:
  `--uncommitted` shows only your working-tree fix-deltas, not the full committed
  PR/base diff round 1 reviewed — so in later rounds "clean" confirms the _fixes_ are
  clean, not that the originally committed code is. Re-checking the whole committed diff
  would require committing and pushing, which stays the user's end-of-loop call (step 3).
- Default to **standard mode**. Deep mode (per-finding verification) is token-expensive,
  and the loop already provides iteration — only pass deep through if the user explicitly
  asked for a "deep" loop.

### 2. Judge the findings — the heart of the loop

This is the subjective step, and it's where your judgment earns its keep. For each
finding in the synthesis, decide **FIX** or **FOREGO**, and record a one-line reason for
anything you forego — you'll need it for the report.

Lean on the signal `panel-review` already computed rather than re-deriving severity from
scratch:

- **Fix by default:** any CRITICAL finding; consensus findings raised by 2+ panelists
  (HIGH or MEDIUM); a substantiated `Approach (questionable)` flag. A wrong-layer fix is
  usually worth more than any line-level finding — if the approach is off, the smaller
  findings may not survive the rework anyway.
- **Judgment zone — verify, then decide:** single-panelist HIGHs and non-consensus MEDIUM
  findings. Open the code, confirm the issue is real, and fix it if it's a genuine,
  in-scope improvement that doesn't balloon the change. Forego it if it's speculative,
  marginal, or would expand scope.
- **Forego (and say why):** out-of-scope improvements that belong in a separate change;
  findings you tried to verify and couldn't substantiate; style nitpicks that conflict
  with the project's existing conventions; "nice to have" polish not worth another full
  review round. LOW-severity findings are polish by default — forego them even when
  raised by 2+ panelists, unless the fix is trivial and obviously worth it.

Two guardrails keep the autonomy honest:

- **Don't silently redesign away from the goal.** If a finding implies the _goal itself_
  is wrong (a panelist arguing the whole feature should work differently, say), that is
  not yours to decide unattended — forego the change and surface it under "deviations" in
  the report so the user can make the call.
- **Don't re-litigate.** Keep a running ledger (TodoWrite works well) of what you've
  already foregone and why. When a later round resurfaces it, keep your prior decision
  unless something actually changed — severity escalated, a new panelist now agrees, or
  one of your own fixes made it matter more.

### 3. Fix, then re-review

Apply every FIX you decided on this round _before_ re-reviewing — one review per round,
not one per fix. Each `panel-review` round is several CLI agents and minutes of wall
clock, so batching fixes is what keeps the loop affordable.

Make the fixes in the working tree. For the next round to actually see them, review
`--uncommitted` — it's the only target that includes unpushed, uncommitted edits. **Do not
commit or push on your own to make a `--base` / `--commit` / `--pr` re-review pick up the
fixes** — committing and pushing are outward, end-of-loop decisions for the user. Keep the
changes in the working tree and let the final report hand them a clean commit / push
decision.

Then go back to step 1.

### When to stop (judgment, no fixed cap)

Stop when nothing left is worth fixing — every remaining finding lands in FOREGO. That's
the normal exit: a round that surfaces only low-value or out-of-scope items you've
already reasoned through, with no CRITICAL / HIGH and no substantiated approach flag.

There's no hard round cap (you're trusted to judge), but watch for two non-convergence
signals and stop + report honestly if you hit them instead of looping indefinitely:

- **Diminishing returns** — rounds should trend toward fewer and lower-severity findings.
  If they flatten out without reaching clean, you've likely hit the floor; report what's
  left.
- **Oscillation** — if your fixes keep spawning fresh equivalent-severity findings, the
  change may be fighting the codebase or the goal. Stop and describe what's happening;
  that's more useful to the user than burning more rounds.

### 4. Report back

One report at the end — no per-round check-ins. Use this shape:

```
Panel review loop: <N> rounds, <converged | stopped: reason>.

Fixed (<count>):
  - [SEV] file:line — what you changed (round <n>)
  ...

Left alone (<count>):
  - [SEV] file:line — the finding — why you didn't fix it
  ...

Deviations from the goal (<count or "none">):
  - what drifted, or what a finding implies about the goal, surfaced for your call
  ...

Notes:
  - anything else worth knowing — unresolved panelist disagreements, non-convergence,
    a fix that turned out larger than expected, etc.

Changes are in the working tree (not committed / pushed). <Commit / push when ready.>
```

Keep "Left alone" specific — the reason is the whole point of reporting it. "Out of
scope: belongs in the auth refactor" beats "low priority". This section is how the user
audits your judgment, so make it easy to disagree with.

## Gotchas

- **Cost compounds.** Every round is a full `panel-review` fan-out. Batch all worthwhile
  fixes per round, and don't kick off a fresh round for a one-line tweak you're already
  certain about.
- **Hold `--uncommitted` across rounds.** The one allowed target switch is the initial
  one (step 1): a round-1 `--pr` / `--base` / `--commit` target moves to `--uncommitted`
  once you've made working-tree fixes, because only `--uncommitted` reflects unpushed
  changes. After that, stay on `--uncommitted` every round — switching back makes findings
  incomparable and can hide or re-introduce issues.
- **Don't commit or push to feed the loop.** If the work is a PR, resist committing or
  pushing each round just so a `--base` / `--commit` / `--pr` re-review sees the fixes;
  review `--uncommitted` instead. Committing and pushing stay the user's end-of-loop
  decision.
- **Autonomy is for the loop, not the goal.** You decide what's worth fixing; you don't
  decide to change what the user asked for. Goal-level disagreements go in the report,
  not into the code.
- **Invoke `panel-review`, don't reinvent it.** All the fan-out / polling / synthesis
  logic lives there. Following the skill runs `panel-review.sh` for you; driving that
  script yourself with ad-hoc orchestration instead of going through the skill loses the
  live progress UX and the synthesis the judgment step depends on.
