# orchestrate-features

Build one or more features with an orchestrator pattern in
Herdr. The session you talk to becomes the
orchestrator and stays alone in its tab. Each feature gets a Claude worker
in its own Herdr pane and its own git worktree. The orchestrator writes
the briefs, watches the workers, coordinates overlap, and brings major
architecture decisions and scope growth to you.

This is not the Anthropic `feature-dev` plugin. `/feature-dev` is a
single-session workflow, and this skill leaves it alone.

## Install

```
npx skills add venables/skills --skill orchestrate-features
```

## How to use it

From inside the repo, in a Herdr pane, ask Claude Code in plain English:

- "feature dev: add CSV export and rate limits"
- "lets build these three features"
- "new feature: webhooks for payouts"

One feature is enough.

## What it does

1. **Plans.** Splits the request into features (one branch and one PR
   each), reads the code, finds the files and contracts that features
   share, and asks you only what it cannot decide.
2. **Makes the worktrees.** One worktree (using `wt`) per feature, on branch
   `feat/<slug>`, made one at a time.
3. **Writes a brief per feature.** Goal, scope, out of scope, starting
   points, shared contracts, and the standing rules.
4. **Starts the workers.** Feature 1 gets a new tab, feature 2 splits it,
   feature 3 gets a new tab. A tab never holds more than 2 panes. The
   orchestrator tab is never split.
5. **Watches and coordinates.** A background watcher returns when a worker
   stops. The orchestrator reads the worker's status file, answers what it
   can, and tells other workers about changes that affect them.
6. **Escalates.** A new dependency, a schema or public API change, a new
   pattern, a security-sensitive change, or scope growth comes to you with
   options and a recommendation.
7. **Reports.** Per feature: the branch, the PR, the decisions, and
   anything that needs you.

Each worker follows the [`ship`](../ship) playbook and opens a PR. Nothing
merges without you.

## Gotchas

- **Needs Herdr.** `HERDR_ENV=1`, plus `herdr`, `jq`, and `wt` on PATH.
  Outside Herdr the skill stops and says so.
- **Workers run with `--dangerously-skip-permissions`** so they work
  unattended. Each one works only in its own worktree.
- **Panes and worktrees stay** after the run. Review comments are handled
  in the same worktree. Remove a worktree (using `wt`) after its PR merges.
- **Briefs and status files** live in
  `~/.cache/orchestrate-features/<repo-name>/`.

## Scripts

- `scripts/herdr-fanout.sh --repo-name <name> --briefs <dir>
<slug>=<worktree-path> ...` builds the tabs and splits, starts a Claude
  agent `feat-<slug>` in each pane, and points it at its brief.
- `scripts/watch.sh <agent> ...` blocks until a worker is no longer
  working, or 25 minutes pass.
- `tests/fanout-layout.sh` checks the layout rules against a stub `herdr`.
