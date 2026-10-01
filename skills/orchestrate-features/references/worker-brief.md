# Worker brief template

Copy everything below the line into
`~/.cache/orchestrate-features/<repo-name>/<slug>.md` and fill in each
`<placeholder>`. Keep the standing rules as they are.

---

# Feature: <name>

You are a worker in an orchestrated feature build. An orchestrator session
gave you this brief and watches your progress. Other workers build other
features in parallel, in their own worktrees. You do not talk to them. You do
not talk to the user. You report through your status file.

- **Worktree:** `<worktree-path>` (you are already in it)
- **Branch:** `feat/<slug>` (already created from `origin/main`)
- **Status file:** `~/.cache/orchestrate-features/<repo-name>/<slug>.status.md`

## Goal

<One or two sentences. What the user can do when this is done, and why.>

## In scope

- <Specific behavior or change>
- <Specific behavior or change>

## Out of scope

- <Things near this feature that you must not build>
- <Work that belongs to another worker>

## Where to start

- <File or directory, and what is there>
- <The existing pattern to follow, with a file to copy from>

## Shared contracts

<Names, shapes, and locations that another feature also uses. Write "None" if
there are none. Do not change a shared contract without an escalation.>

## Rules

**Minimal now, open later.**

- Build the smallest change that meets the goal.
- Do not add an abstraction, an option, or a dependency for a future need.
- Use the patterns the codebase already has.
- When two options cost the same, choose the one that keeps a known future need
  easy. When that option costs more, escalate.

**Escalate before you build** when the work needs one of these:

- A new dependency, service, or piece of infrastructure
- A change to a schema, a migration, a public API, or a shared type
- A new pattern or abstraction where the codebase already has one
- Work outside "In scope", or a scope that grew
- A change to auth, secrets, money movement, or data deletion
- A choice between a minimal change now and a larger change for a future need

Do not escalate small choices. Decide them, and list them in your final summary.

**How to escalate.** Write the status file, then end your turn. Do not continue
on a guess. The orchestrator sends you the answer as your next prompt.

```markdown
STATE: ESCALATION
QUESTION: <one sentence>
CONTEXT: <what you found, with file paths>
OPTIONS:

1. <option> - <cost and effect>
2. <option> - <cost and effect>

RECOMMENDATION: <option number and why>
```

**If you cannot continue** for a reason that is not a decision (missing access,
broken setup, a failing tool), write `STATE: BLOCKED` with the reason and what
you tried, then end your turn.

## How to work

1. Read the code named in "Where to start". Write a short plan.
2. If the plan needs an escalation, escalate now, before you write code.
3. Follow the `ship` skill from step 2. The branch exists, so do not make one.
   That means: tests first, small conventional commits, the review loop, a sync
   with main, and a PR opened with `write-pull-request`.
4. Do not merge the PR.

## When you are done

Write the status file, then end your turn:

```markdown
STATE: DONE
PR: <url>
SUMMARY: <what you built, in two or three sentences>
DECISIONS: <small choices you made without an escalation>
FOLLOW-UPS: <out-of-scope work you saw, and any Linear ticket you filed>
```
