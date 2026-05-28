# panel-review-loop

Autonomously loop the review-fix-rereview cycle around [`panel-review`](https://github.com/catena-labs/dev-skills/tree/main/skills/panel-review): do the task, run a panel review, judge which findings are worth fixing, fix them, re-review, and repeat until nothing worth fixing is left — then report what got fixed, what was left alone (and why), and anywhere the work drifted from the goal.

## A typical loop

You kick it off once and read one report at the end. In between, a run looks like this — severity trending down each round until nothing's left worth fixing:

- **Round 1.** The agent anchors the goal, runs `panel-review`, and gets back a spread of findings — say a HIGH all three panelists agree on, a couple of MEDIUMs, and some LOW nitpicks. It fixes the consensus HIGH, opens the code to verify the MEDIUMs (fixes the real ones, forgoes a speculative one and records why), batches those edits into the working tree, and re-reviews.
- **Round 2.** Fewer findings. One is a fresh issue that a round-1 fix introduced — it fixes that. A panelist's HIGH cites a line that doesn't actually do what's claimed; the agent reads the file, falsifies it, and drops it rather than acting on it. Re-review.
- **Round 3.** Down to single-panelist LOW polish and out-of-scope suggestions. The agent confirms every remaining item lands in FOREGO — no CRITICAL/HIGH, no substantiated approach flag — and stops.
- **Report.** One summary: what got fixed (with severity and the round it landed in), what was left alone and the reason for each, anything that drifted from the goal surfaced for your call, plus a clean commit/push decision left to you.

It re-reviews local working-tree state (`--uncommitted`) each round so it sees its own fixes without committing or pushing, and it stops on its own judgment — when the findings dry up, or honestly bails if it detects oscillation (fixes that keep spawning equivalent-severity findings) or flat non-convergence.

## Install

```
npx skills add venables/skills --skill panel-review-loop
```

Depends on the `panel-review` skill being installed too — this skill orchestrates it rather than reimplementing the fan-out:

```
npx skills add catena-labs/dev-skills --skill panel-review
```

## How to use it

Once the work is done (or nearly), just ask in plain English:

- "run a panel review loop on this"
- "panel review loop until it's clean"
- "keep panel-reviewing and fixing until there's nothing worth fixing"
- "do a review loop — fix what matters and re-review"
- "loop a panel review on the PR until it's green"

The agent anchors the goal, runs `panel-review`, decides per finding whether it's worth fixing, applies the worthwhile fixes, re-reviews, and keeps going until it judges the work is in good shape. It runs unattended and gives you one report at the end.

## What it does

- **Anchors the goal** up front so it can judge in-scope vs. out-of-scope findings and report deviations honestly.
- **Invokes `panel-review`** each round (standard mode by default) and consumes its synthesized output — Risk, Goal check, Approach check, Consensus / Unique findings, Disagreements, Action list.
- **Judges every finding** FIX or FOREGO, leaning on the panel's own severity and consensus signal: fixes any CRITICAL and consensus (2+ panelist) HIGH/MEDIUM findings by default, verifies the judgment-zone ones (single-panelist HIGHs, non-consensus MEDIUMs) against the code, and forgoes out-of-scope, speculative, or LOW-severity ones — recording a reason for each it skips.
- **Batches fixes per round** (one review per round, not one per fix) to keep the loop affordable, then re-reviews the updated local state.
- **Reports once at the end**: fixed items, items left alone with reasons, deviations from the goal surfaced for your call, and any notes (unresolved disagreements, non-convergence).

## What it does NOT do

- **No per-round check-ins.** It's autonomous by design — you get one loop report at the end and never a prompt for approval between rounds (though `panel-review` still streams its own per-panelist progress each round). (Want a checkpoint each round? Run `panel-review` yourself and decide between rounds.)
- **No committing or pushing.** Fixes land in the working tree; the loop never pushes to feed a `--pr` re-review. Committing and pushing stay your end-of-loop decision.
- **No redesigning the goal.** It decides what's worth fixing, not whether your task was the right task. A finding that implies the goal itself is wrong gets surfaced in the report, not acted on.
- **No reimplementing `panel-review`.** It invokes that skill as-is — if `panel-review` isn't installed, it stops and tells you, rather than hand-rolling a worse fan-out.

## Gotchas

- **Each round costs a full fan-out.** `panel-review` spawns multiple CLI agents per round (minutes of wall clock each). The loop batches fixes and stops on diminishing returns to keep that bounded — but a stubborn change can still run several rounds.
- **No hard round cap.** Stopping is pure judgment: it exits when nothing's worth fixing, and bails with an honest report if it detects oscillation (fixes spawning new equivalent-severity findings) or flat non-convergence.
- **Consistent target across rounds.** Round 1 uses whatever target fits (PR / base / commit / uncommitted); once it makes working-tree fixes it reviews `--uncommitted` from then on — the only target that reflects unpushed edits — and holds that. Those later rounds re-review the working-tree fix-deltas (not the full committed diff), and mixing target shapes for any other reason makes findings incomparable.
- **Trigger overlap with `panel-review`.** Say "loop" / "until it's clean" / "iterate" when you want the loop; say "panel review" alone for a single pass. The skill defers one-shot reviews back to `panel-review`.
