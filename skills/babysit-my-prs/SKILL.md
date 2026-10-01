---
name: babysit-my-prs
description: >
  Sweep every open PR you authored in a repo and, for each one that
  actually needs it, resolve merge conflicts, handle the review comments,
  and fix failing CI, working on a dedicated git worktree per branch and
  pushing the result. A PR with no conflicts, no review comments, and no
  failing checks is skipped untouched. Use whenever the user says things
  like "babysit my PRs", "sweep my open PRs", "go handle all my PRs",
  "fix conflicts and comments across my PRs", "keep my PRs mergeable", or
  asks to fan work out across every PR they created. Auto-detects the
  repo from the current directory. Different from `babysit-pr` (one PR,
  in place) and `pr-comment-handler` (one PR, comments only): this skill
  finds many authored PRs and works each in its own worktree in parallel.
  Inside Herdr, each PR runs in its own pane, 4 per tab in a 2x2 grid;
  outside Herdr, one subagent per PR. Delegates worktrees to the
  `git-worktree` skill (the `wt` CLI) and the per-PR work to `babysit-pr`.
---

# babysit-my-prs

One invocation = one sweep over **every open PR you authored** in the repo. For
each PR that genuinely needs attention — a merge conflict, unhandled review
comments, failing CI, or any mix — run the **`babysit-pr`** skill on it (resolve
the conflict, hand the comments to `pr-comment-handler`, fix CI via `fix-ci`,
push). Each PR is worked **in its own git worktree**, and the PRs are worked **in
parallel**:

- **Herdr mode** (inside Herdr — the normal case): one visible Herdr pane per PR,
  each a Claude agent running `/babysit-pr <N>`. See step 3a.
- **Subagent mode** (no Herdr): one background subagent per PR. See step 3b.

This skill is the outer layer: it **discovers** authored PRs, **filters** to the
ones that need work, sets up a **worktree per PR**, and fans out panes or
subagents that each run `babysit-pr`. The per-PR conflict-and-comment engine lives in
`babysit-pr` — don't re-derive it here.

**The skip rule is firm:** a PR with no merge conflicts, no review comments, AND
no failing CI gets no work done on it. The scanner already filters these out —
you act only on the `actionable` list.

**Language:** every word the sweep puts on GitHub or Linear is written in
ASD-STE100 Simplified Technical English — short sentences (20 words for an
instruction, 25 for a statement), one idea per sentence, active voice, simple
tenses, one word for one meaning, and no jargon, idioms, or metaphors.
`babysit-pr` and `pr-comment-handler` carry the full rule; pass it down to each
subagent so a parallel sweep reads as one voice.

## 1. Discover (one read-only command)

```bash
skills/babysit-my-prs/scripts/scan.sh        # add --repo owner/name to target another repo
```

It resolves the repo, finds your open PRs (`--author @me`), and for each reports
whether it has conflicts, how many review comments it carries, and how many
required checks are failing. It is strictly read-only. Output:

```jsonc
{
  "repo": "owner/name",
  "me": "login",
  "actionable": [                 // work these — in parallel
    { "number", "title", "branch", "url",
      "mergeable", "mergeState",
      "hasConflicts": true,
      "reviewComments": 3,        // unhandled review threads + review bodies
      "failingChecks": 1,         // required checks in a failing state
      "reason": "conflicts" | "comments" | "ci" | "multiple" }
  ],
  "skipped": [                    // report as skipped, touch nothing
    { "number", "branch", "url", "reason": "clean" }
  ]
}
```

If `actionable` is empty, say so and stop — nothing to do. Otherwise proceed.

## 2. Resolve a worktree per PR (serially, before fanning out)

Create or reuse one worktree per actionable PR **from the main repo, one at a
time** — `git worktree add` takes a repo-wide lock, so racing it across parallel
agents can fail. Worktree creation is delegated to the **`git-worktree`** skill,
which shells out to the `wt` CLI; do the branches serially:

```bash
git fetch origin                 # once — so origin/<branch> refs exist for wt
wt create "<branch>"             # per PR, serially; prints the worktree path to stdout
```

`wt create` reuses an existing worktree already checked out to that branch
(including the main working copy) and otherwise creates one at
`<repo-parent>/<repo-name>-<branch-slug>` — flat, alongside the repo. Capture the
printed stdout path for each PR; that path is where its pane or subagent will work. (If
`wt` isn't installed, the `git-worktree` skill says so — don't hand-roll
`git worktree add`.)

## 3. Fan out — pick the mode

Use **Herdr mode** when this session runs inside a Herdr pane and the CLI is on
PATH:

```bash
[[ "${HERDR_ENV:-}" == "1" ]] && command -v herdr >/dev/null && echo herdr || echo subagent
```

### 3a. Herdr mode — one pane per PR, 4 per tab

Hand every actionable PR and its worktree path (from step 2) to the grid script in
one call. `--repo-name` is the repo part of the scan's `repo` field (`owner/bank`
-> `bank`), not the directory name — a worktree directory is `bank.<slug>`.

```bash
skills/babysit-my-prs/scripts/herdr-grid.sh --repo-name "<name>" \
  "<number>=<worktree-path>" "<number>=<worktree-path>" ...
```

The script:

1. Renames the current Herdr workspace to `<name> (babysitting)`.
2. Opens a new tab per group of 4 PRs (label `PRs #12 #15 #18 #20`) and splits it
   into a 2x2 grid: top-left, top-right, bottom-left, bottom-right. A group of 2
   is left | right; a group of 3 leaves the right pane full height.
3. Starts each pane in its PR's worktree, starts a Claude agent (named
   `<name>-pr-<N>`, with `--dangerously-skip-permissions` so it runs
   unattended), and submits `/babysit-pr <N>`.
4. Prints JSON: the workspace, and per PR its `tab`, `pane`, `agent`, and
   `status` (`started`, `start_failed`, or `prompt_failed`).

It does not wait for the agents. Each pane runs `babysit-pr` on its own, and the
user watches the work in the grid. Do not prompt or answer the agents from here.
A `start_failed` or `prompt_failed` pane goes under **Needs a human** with its
pane id. If the script exits `3` (not inside Herdr after all), use step 3b.

Then go to step 4. Skip the teardown in step 5 for this mode.

### 3b. Subagent mode — one subagent per actionable PR

Spawn the subagents in a **single message** so they run concurrently. Give each
subagent its PR number, branch, worktree path, and the `reason` (conflicts /
comments / ci / multiple). Each subagent does, inside its worktree:

1. **`cd` into the worktree path** and confirm it is on the PR's branch with a
   clean tree (`git status`). If the tree is dirty from a prior run, stop and
   report — do not stash or discard.
2. **Run the `babysit-pr` skill.** That skill owns the whole per-PR engine —
   confirm the branch, resolve conflicts by merging `origin/main` (never a rebase
   or force-push on a non-draft PR), hand the comments to `pr-comment-handler`,
   fix any failing CI via `fix-ci`, push, and report. It auto-detects the PR from
   the branch, so from the worktree it targets the right one. Do not re-derive any
   of that here; run the skill.
3. **Return `babysit-pr`'s summary** for this PR verbatim — what the conflict
   resolution did (or "no conflicts"), what `pr-comment-handler` reported (fixed /
   deferred / declined counts, commit range, any Linear links), the CI outcome (or
   "CI green"), and anything that needs a human.

The `reason` from the scan is just a hint about why the PR is actionable;
`babysit-pr` re-checks conflict, comment, and CI state itself and skips whichever
of the three has nothing to do.

## 4. Report back here

**Herdr mode:** the agents are still running, so there are no results yet.
Report the workspace name and a table of PR number, title, tab, pane, and
status. Add the skipped list, and put any failed pane under **Needs a human**.

**Subagent mode:** aggregate the subagent summaries into one report:

- **Worked:** per PR — number, title, what was done (conflicts resolved, comments
  handled with counts, CI fixed), and the pushed commit range.
- **Skipped:** the `skipped` list — PR numbers and that they were clean.
- **Needs a human:** any PR where a subagent stopped (divergent conflict, dirty
  tree, a comment needing a design decision, a CI failure needing a test disabled
  or that's really main being broken, a failed push/reply). Surface these clearly
  with the PR link.

## 5. Clean up the worktrees

**Herdr mode: do not clean up.** The pane agents still work in the worktrees.
List each worktree path in the report, and tell the user to run
`wt rm "<branch>"` for a PR after its pane is done.

**Subagent mode:** once the sweep is done, remove the worktrees it created — one `wt rm` per branch
(or per path) you captured in step 2, via the **`git-worktree`** skill:

```bash
wt rm "<branch>"        # or: wt rm "<worktree-path>"
```

`wt rm` only removes a worktree when it's safe: it never touches the main working
copy, and it refuses one with uncommitted changes (it wraps `git worktree remove`
without `--force`, so nothing is lost). Removing a worktree keeps its branch and
any committed work — only the directory goes, so the next sweep just recreates
it. Never pass `-f` here — the refusal is the safety.

**Only clean up worktrees for PRs that completed cleanly.** For any PR that
landed in **Needs a human**, leave its worktree in place so the human can pick
up the work where the subagent left it — say so in the report. A worktree `wt rm`
declines to remove (dirty or busy) stays put; list it under "kept" so nothing is
silently left behind.

## Stop-and-ask triggers

`babysit-pr` owns the per-PR blockers — a genuinely divergent merge conflict, a
dirty worktree, anything that would rewrite history on a non-draft PR, a CI fix
that would need a test disabled or is really main being broken, a failed
push/reply. Each subagent surfaces those in its summary; you collect them under
**Needs a human** and pass them up, un-guessed. At the sweep level, the one thing
you decide is which PRs are actionable — and the scanner already did that.

## Mechanics

- Worktrees are sweep scratch: created at `<repo-parent>/<repo-name>-<branch-slug>`
  (flat, alongside the repo) via `wt create` in step 2, torn down with `wt rm` in
  step 5. Worktree mechanics are owned by the `git-worktree` skill / `wt` CLI, not
  re-derived here. `wt rm` protects the main working copy and anything with
  uncommitted work, so a stopped PR keeps its checkout. `wt create` reuses an
  existing worktree for a branch if one is present (e.g. a prior sweep that left
  one behind, or the branch checked out in the main copy).
- Herdr panes are Claude agents with the default model. Do not add a cheaper
  `--model` to the agent args — the judgment rule below applies to them too.
- Inherit the session model for subagents; conflict resolution and comment
  triage are judgment work, not grunt work — never pin a cheaper model.
- The per-PR git mechanics (fetch-all not scoped-fetch, merge-not-rebase, append
  don't force-push) live in `babysit-pr` — this skill doesn't re-specify them.

## Common mistakes

| Mistake                                       | Reality                                                                |
| --------------------------------------------- | ---------------------------------------------------------------------- |
| Working a clean PR                            | No conflicts and no comments = skip it; only `actionable` gets work    |
| Creating worktrees in parallel                | `git worktree add` locks the repo; resolve them serially, then fan out |
| Re-deriving the per-PR conflict/comment logic | That is `babysit-pr`'s job — run it from the worktree                  |
| Hand-rolling `git worktree add` into a path   | Use `wt create` (the `git-worktree` skill) so paths stay consistent    |
| Duplicating a worktree that already exists    | `wt create` reuses the branch's existing checkout                      |
| Removing a stopped PR's worktree              | Clean up only clean, completed PRs; leave a needs-a-human checkout     |
| `rm -rf`-ing a worktree dir                   | Use `wt rm` — it guards the main copy and refuses dirty trees          |
| Pinning a cheaper model on the subagents      | Conflict + comment work is judgment; inherit the session model         |
| Hand-building the Herdr grid                  | Run `herdr-grid.sh` once with every PR; it owns the 2x2 layout         |
| Naming the workspace from the directory       | Use the repo name from the scan; a worktree dir is not the repo name   |
| Removing worktrees in Herdr mode              | The pane agents still use them; leave them and tell the user           |
| Answering a blocked pane agent from here      | Report it under Needs a human; the user answers in the pane            |
