---
name: babysit-my-prs
description: >
  Sweep every open PR you authored in a repo and, for each one that
  actually needs it, resolve merge conflicts, handle the review comments,
  and fix failing CI, working on a dedicated git worktree per branch and
  pushing the result. Each PR is worked in parallel via its own subagent.
  A PR with no conflicts, no review comments, and no failing checks is
  skipped untouched. Use
  whenever the user says things like "babysit my PRs", "sweep my open
  PRs", "go handle all my PRs", "fix conflicts and comments across my
  PRs", "keep my PRs mergeable", or asks to fan work out across every PR
  they created. Auto-detects the repo from the current directory.
  Different from `babysit-pr` (one PR, in place) and `pr-comment-handler`
  (one PR, comments only): this skill discovers many authored PRs,
  filters to the ones that need work, and works each in its own worktree
  in parallel. Delegates the per-PR work to `babysit-pr`.
---

# babysit-my-prs

One invocation = one sweep over **every open PR you authored** in the repo. For
each PR that genuinely needs attention — a merge conflict, unhandled review
comments, failing CI, or any mix — run the **`babysit-pr`** skill on it (resolve
the conflict, hand the comments to `pr-comment-handler`, fix CI via `fix-ci`,
push). Each PR is worked **in its own git worktree**, and the PRs are worked **in
parallel** (one subagent each).

This skill is the outer layer: it **discovers** authored PRs, **filters** to the
ones that need work, sets up a **worktree per PR**, and fans out subagents that
each run `babysit-pr`. The per-PR conflict-and-comment engine lives in
`babysit-pr` — don't re-derive it here.

**The skip rule is firm:** a PR with no merge conflicts, no review comments, AND
no failing CI gets no work done on it. The scanner already filters these out —
you act only on the `actionable` list.

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
agents can fail. The bundled helper does the fiddly part and prints the path:

```bash
skills/babysit-my-prs/scripts/ensure_worktree.sh "<branch>"
```

It reuses an existing worktree already checked out to that branch (including the
main working copy) and otherwise creates one under
`<repo-parent>/<repo-name>-worktrees/<branch-slug>`. Capture the printed path for
each PR; that path is where its subagent will work.

## 3. Fan out — one subagent per actionable PR

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

Aggregate the subagent summaries into one report:

- **Worked:** per PR — number, title, what was done (conflicts resolved, comments
  handled with counts, CI fixed), and the pushed commit range.
- **Skipped:** the `skipped` list — PR numbers and that they were clean.
- **Needs a human:** any PR where a subagent stopped (divergent conflict, dirty
  tree, a comment needing a design decision, a CI failure needing a test disabled
  or that's really main being broken, a failed push/reply). Surface these clearly
  with the PR link.

## 5. Clean up the worktrees

Once the sweep is done, remove the worktrees it created — one call per worktree
path you captured in step 2:

```bash
skills/babysit-my-prs/scripts/cleanup_worktree.sh "<worktree-path>"
```

The helper only removes a worktree when it's safe: never the main working copy,
never a path outside `<repo-parent>/<repo-name>-worktrees/`, and never one with
uncommitted changes (it declines rather than forcing). Removing a worktree keeps
its branch and any committed work — only the directory goes, so the next sweep
just recreates it.

**Only clean up worktrees for PRs that completed cleanly.** For any PR that
landed in **Needs a human**, leave its worktree in place so the human can pick
up the work where the subagent left it — say so in the report. A worktree the
helper declines to remove (exit 3) stays put; list it under "kept" so nothing is
silently left behind.

## Stop-and-ask triggers

`babysit-pr` owns the per-PR blockers — a genuinely divergent merge conflict, a
dirty worktree, anything that would rewrite history on a non-draft PR, a CI fix
that would need a test disabled or is really main being broken, a failed
push/reply. Each subagent surfaces those in its summary; you collect them under
**Needs a human** and pass them up, un-guessed. At the sweep level, the one thing
you decide is which PRs are actionable — and the scanner already did that.

## Mechanics

- Worktrees are sweep scratch: created under `<repo-parent>/<repo-name>-worktrees/`
  in step 2, torn down in step 5. `cleanup_worktree.sh` protects the main working
  copy and anything with uncommitted work, so a stopped PR keeps its checkout.
  Within a run, `ensure_worktree.sh` still reuses an existing worktree for a
  branch if one is present (e.g. a prior sweep that left one behind).
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
| Duplicating a worktree that already exists    | `ensure_worktree.sh` reuses the branch's existing checkout             |
| Removing a stopped PR's worktree              | Clean up only clean, completed PRs; leave a needs-a-human checkout     |
| `rm -rf`-ing a worktree dir                   | Use `cleanup_worktree.sh` — it guards the main copy and dirty trees    |
| Pinning a cheaper model on the subagents      | Conflict + comment work is judgment; inherit the session model         |
