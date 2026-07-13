# find-work

Sweep the Linear backlog for tickets an agent can act on now. Two outcomes per
sweep: tickets that already shipped get closed with evidence and PR links, and
small well-specified tickets get implemented end to end — one branch per ticket,
a review loop, then a PR with a problem / solution / testing body. Ends with a
report so the next sweep is incremental instead of a re-triage.

## Install

```bash
npx skills add venables/skills --skill find-work
```

## How to use it

Just ask Claude Code in plain English:

- "find work"
- "look through Linear for things you can handle"
- "pick up a ticket"
- "what can you knock out from the backlog?"

## What it does

- **Sweeps the team's Todo tickets** via the Linear MCP and builds two
  shortlists: proven-solved and actionable.
- **Closes with evidence only.** A ticket counts as solved when the code on
  `main` demonstrably does what it asks — not when a related PR touched the
  area. Otherwise it comments and leaves the ticket open.
- **Skips deliberately.** Assigned, decision-shaped, credential-gated, and
  multi-day tickets are skipped with a recorded reason, never silently.
- **Delivers per ticket**: Linear's `gitBranchName` branch off fresh `main`,
  frequent conventional commits, a review loop before the PR, and the ticket
  moved to In Review with the PR linked.
- **Reports** tickets closed, PRs opened, comments left, and the skip list — the
  contract with the next sweep.

## Gotchas

- **Requires the Linear MCP server** (list/get/save issue tools) and the `gh`
  CLI authenticated against the repo.
- **It never closes speculatively.** If it cannot prove a ticket shipped, it
  comments and asks the reporter to confirm.
- **Repo rules still apply.** It reads the target repo's CLAUDE.md / AGENTS.md
  and follows any required skills (security review, style, migration policy)
  while implementing.
