---
name: orchestrate-features
description: >
  Build one or more new features with an orchestrator pattern in Herdr.
  This session stays alone in its tab as the orchestrator. Each feature
  gets its own Claude worker in its own Herdr pane (2 panes per tab at
  most) and its own git worktree. The orchestrator writes each brief,
  watches the workers, coordinates work that overlaps, and brings major
  architecture decisions and scope growth to the user. Use by default
  whenever the user asks for feature work in plain language: "feature
  dev", "build this feature", "new feature", "add these features", "lets
  build X and Y", "orchestrate these", "fan these features out", "spin up
  workers for these". One feature is enough to trigger it. Do NOT use
  when the user types `/feature-dev` or names the feature-dev plugin
  (that is the single-session Anthropic workflow, and it stays as it is),
  for a bug fix or a small edit this session can do in place, or to work
  existing PRs (`babysit-my-prs`). Requires Herdr (`HERDR_ENV=1`), `jq`,
  and the `wt` CLI.
---

# orchestrate-features

You are the **orchestrator**. You do not write feature code. You split the
request into features, give each feature to a worker, watch the workers, and
keep the user informed. Each worker is a Claude agent in its own Herdr pane and
its own git worktree.

Two rules shape every decision:

- **Minimal now.** Each feature is the smallest change that meets its goal.
- **Open later.** Do not build for a future need. Do not close the door on one
  either. When the two rules conflict, that is a decision for the user.

## 0. Check the environment

```bash
[[ "${HERDR_ENV:-}" == "1" ]] && command -v herdr jq wt >/dev/null && echo ok
```

If this does not print `ok`, stop and tell the user what is missing. Do not
build the features in this session as a fallback unless the user asks for that.

## 1. Plan before you spawn

Do this work yourself, in this pane. It is the part that workers cannot do,
because no worker sees the other features.

1. **Split the request into features.** One feature is one branch and one PR. If
   two items cannot merge independently, make them one feature.
2. **Read enough code to write a good brief.** Find the files and patterns each
   feature touches. Use an `Explore` agent for a wide search.
3. **Find the overlap.** List the files, types, schemas, and migrations that two
   or more features touch. For each overlap, choose one:
   - One feature owns it, and the other feature waits or consumes it.
   - You set the shared contract now (name, shape, location) and put it in both
     briefs.
   - The features are not independent. Merge them, or run them in sequence.
4. **Ask the user only what you cannot decide.** A major architecture choice or
   an unclear goal goes to the user now, with `AskUserQuestion`, before any
   worker starts. Do not ask about things the code or a sensible default answers.
5. **Give each feature a slug.** Lowercase letters, digits, and hyphens, 27
   characters or fewer (`rate-limits`, `csv-export`). The branch is
   `feat/<slug>`. The worker agent is `feat-<slug>`.

Tell the user the plan in a short list (feature, branch, one-line scope, shared
contracts) and continue. Do not wait for approval unless you asked a question.

## 2. Make the worktrees

Make one worktree (using `wt`) per feature, on branch `feat/<slug>`, from a
fresh `origin/main`. Make them from this pane, one at a time. Git locks the repo
while it adds a worktree, so workers that make their own in parallel can fail.

Keep each worktree path. The workers start there.

## 3. Write the briefs

Each worker starts with no context. The brief is all it knows. Write one file
per feature:

```
~/.cache/orchestrate-features/<repo-name>/<slug>.md
```

Fill in `references/worker-brief.md` for each feature. The template carries the
standing rules (minimal scope, escalation, status file, finish steps). You add
the goal, the scope, the starting points in the code, and the shared contracts.
Be specific: name files, name the pattern to follow, and name what is out of
scope.

`<repo-name>` is the repo name from `git remote get-url origin`, not the
directory name.

## 4. Start the workers

One call for all features:

```bash
skills/orchestrate-features/scripts/herdr-fanout.sh \
  --repo-name "<repo-name>" --briefs ~/.cache/orchestrate-features/<repo-name> \
  "<slug>=<worktree-path>" "<slug>=<worktree-path>" ...
```

The script owns the layout:

- Your tab is never split. You stay alone in it.
- Feature 1 gets a new tab. Feature 2 splits that tab. Feature 3 gets a new tab.
  A tab never holds more than 2 panes.
- A feature tab from an earlier run with 1 pane is filled first, so a feature
  added later joins the open slot.
- Each pane starts in its worktree and runs a Claude agent `feat-<slug>` with
  `--dangerously-skip-permissions`, so it works unattended.
- The prompt tells the worker to read its brief.

The script prints JSON with `tab`, `pane`, `agent`, and `status` per feature. A
`start_failed` pane usually shows a Claude startup dialog. Tell the user which
pane needs them. Exit code `3` means this is not a Herdr pane.

## 5. Watch and coordinate

Run the watcher in the background (`run_in_background: true`) with the agents
that you expect to be working:

```bash
skills/orchestrate-features/scripts/watch.sh feat-<slug> feat-<slug> ...
```

It returns when a worker is no longer `working`, or after 25 minutes
(`timed_out: true`). You are free while it runs. When it returns:

1. For each agent that is not `working`, read its status file
   `~/.cache/orchestrate-features/<repo-name>/<slug>.status.md`. If the file is
   missing or old, read the pane:
   `herdr agent read feat-<slug> --source recent-unwrapped --lines 200`.
2. Act on the state (table below).
3. Start the watcher again with the agents that are still working. Stop when no
   agent is left.

On `timed_out`, read each status file, give the user a short progress note if
something changed, and start the watcher again.

| Worker state                               | What you do                                                         |
| ------------------------------------------ | ------------------------------------------------------------------- |
| `ESCALATION`                               | Decide or bubble up (section 6), then send the answer               |
| `DONE`                                     | Check the PR exists and the summary matches the brief. Record it    |
| `BLOCKED` (tooling, access, failing setup) | Fix what you can from here. If not, tell the user                   |
| Herdr status `blocked`                     | The pane shows a dialog. Read it. Ask the user before you answer it |
| No status file, agent idle                 | Read the pane. Ask the worker for its status file                   |

Send an answer or an instruction to a worker with:

```bash
herdr agent prompt feat-<slug> "<message>"
```

**Coordinate between workers.** You are the only one who sees every feature.
When one worker changes a shared contract, or finishes something another
worker waits for, tell the other worker. When two workers start to solve the
same problem, stop one of them and give the problem one owner.

## 6. Escalations

A worker escalates when its work needs one of these. You apply the same list to
your own choices.

- A new dependency, service, or piece of infrastructure
- A change to a schema, a migration, a public API, or a shared type
- A new pattern or abstraction where the codebase already has one
- Work outside the brief's scope, or a scope that grew
- A change to auth, secrets, money movement, or data deletion
- A choice between a minimal change now and a larger change that a known future
  need would want

**You decide** when the answer follows from the plan, the user's request, or the
code, and it stays inside the feature's scope. Tell the worker, and include the
decision in your next note to the user.

**The user decides** all major architecture decisions and all scope growth.
Bring it to them with `AskUserQuestion`: the feature, the question, the options
with their cost, and your recommendation first. Keep the other workers running
while you wait. Send the answer to the worker when you have it.

Default recommendation: the minimal option, unless it makes a known future need
expensive. Out-of-scope work that is worth doing becomes a Linear ticket (no
priority set), not more scope.

## 7. Finish

When every worker is `DONE` or stopped, report:

- **Features:** per feature, the branch, the PR link, and a one-line result.
- **Decisions:** what you decided, and what the user decided.
- **Needs a human:** any worker that stopped, with its pane id and the reason.
- **Deferred:** Linear tickets filed for out-of-scope work.
- **Worktrees:** each path. They stay until the PR merges. The user removes each
  worktree (using `wt`) after that.

Do not close the panes or remove the worktrees. The user reads the panes, and
review comments are handled in the same worktree. Do not merge a PR.

## Common mistakes

| Mistake                                         | Reality                                                                   |
| ----------------------------------------------- | ------------------------------------------------------------------------- |
| Writing feature code in the orchestrator pane   | You plan, brief, watch, and coordinate. Workers write the code            |
| Starting workers before you look for overlap    | Two workers then edit the same file. Find the overlap in section 1        |
| A thin brief ("add CSV export")                 | The worker has no context. Name files, patterns, scope, and contracts     |
| Splitting your own tab                          | You stay alone. `herdr-fanout.sh` puts workers in other tabs              |
| Hand-building tabs and splits                   | Run `herdr-fanout.sh` once with every feature. It owns the 2-per-tab rule |
| Letting workers make their own worktrees        | Git locks the repo for each add. Make them serially in section 2          |
| Polling the panes in a loop                     | Run `watch.sh` in the background. It returns when a worker needs you      |
| Deciding a schema or dependency change yourself | That is the user's decision. Ask, with a recommendation                   |
| Asking the user about every small choice        | Decide what the plan and the code already answer. Report it               |
| Answering a worker's permission dialog          | Read it, then ask the user                                                |
| Using this for `/feature-dev`                   | That is the Anthropic plugin. Leave it alone                              |
| Pinning a cheaper model on workers              | Feature work is judgment work. Use the default model                      |
