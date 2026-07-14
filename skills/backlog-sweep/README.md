# backlog-sweep

Keep the Linear board truthful: every ticket's state should match reality in the
repo. The sweep inventories every open ticket, cross-references git history and
GitHub PRs to find shipped-but-open work and state mismatches, verifies "maybe
already fixed" claims against the code, merges duplicate clusters, moves aging
tickets to Icebox, and triages the Triage queue. Hard-evidence actions apply
automatically with a dated evidence comment; judgment calls batch into one final
checkpoint, skipped when empty.

## Install

```bash
npx skills add venables/skills --skill backlog-sweep
```

## How to use it

Just ask Claude Code in plain English:

- "sweep the backlog"
- "triage the Linear queue"
- "which tickets can we close?"
- "clean up Linear"

Arguments: a team key (`ENG`) to override the inferred one, and a mode — `full`
(default), `triage` (Triage queue only), or `dry-run` (full disposition report,
writes nothing).

## What it does

- **Inventories** every open ticket via the Linear MCP into one TSV, then
  gathers evidence with a bundled script: ticket IDs in merged commits, merged
  PRs, and open PRs (always against a freshly fetched `origin/main`).
- **Classifies mismatches** — shipped-but-open, fixed under a sibling ticket ID,
  started-but-stalled, backlog tickets with an open PR — and verifies each
  candidate in the code with batched read-only subagents before acting.
- **Merges duplicates** by title scan then description confirmation, keeping the
  ticket with momentum as canonical.
- **Applies an Icebox policy** that is deliberately mechanical (age, no
  priority, no project, no momentum) with hard exclusions for security, money
  correctness, and data integrity.
- **Triages the Triage queue** dup-check first, verify-the-claim second,
  disposition third — every ticket leaves with a dated comment explaining the
  call.
- **Splits actions by confidence**: facts auto-apply; anything partial,
  circumstantial, or money/security-adjacent goes to a single batched human
  checkpoint.

## Gotchas

- **Requires the Linear MCP server** (list/get/save issue and comment tools) and
  the `gh` CLI authenticated against the repo.
- **Icebox and Triage assume Linear's standard state types.** Teams without an
  Icebox state should skip Phase 6 or map it to their parking state.
- **It never closes on a mention.** A PR referencing a ticket is not a PR
  implementing it; closures require a code-level verdict.
- **Priorities follow a fixed rubric** and are only set when accepting a ticket
  — confirm any deviation with the user first.
