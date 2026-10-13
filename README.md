# @venables/skills

Matt Venables' Claude Code / agent skills, grouped by what they're for.

## Reviewing code

The skills that review a PR and post the result (`panel-review`, `auto-review`,
`auto-post-panel-review-comments`, `recheck-pr`, and `approve-pr`) are in
[venabots/autoreview](https://github.com/venabots/autoreview), versioned with
the tool that runs them. Install them from there:

```sh
npx skills add venabots/autoreview --skill '*' --global
```

| Skill                                           | Description                                                                                                                                                                                                                                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [panel-review-loop](./skills/panel-review-loop) | Autonomously loop the review-fix-rereview cycle around `panel-review` — judge which findings are worth fixing, fix them, re-review, repeat until clean, then report what was fixed, what was left alone (and why), and any goal deviations                                           |
| [branch-review](./skills/branch-review)         | Review everything on the current branch against `origin/main`, staged, unstaged, and untracked alike. Findings stay in the session and never reach GitHub                                                                                                                            |

## Posting review findings

| Skill                                                                       | Description                                                                                                                                                                                                                                                                                 |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [post-panel-review-comments](./skills/post-panel-review-comments)           | Triage findings from a `panel-review` into PR inline comments and Linear tickets via a two-stage select list (auto-falls back to a top-level comment when GitHub rejects an inline)                                                                                                         |

## Keeping PRs alive

| Skill                                             | Description                                                                                                                                                                                                                                                     |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [babysit-pr](./skills/babysit-pr)                 | Babysit one PR into a mergeable state — resolve its conflicts by merging `origin/main`, hand its comments to `pr-comment-handler`, fix failing CI via `fix-ci`, and push, working in place and auto-detecting the PR from the current branch                    |
| [babysit-my-prs](./skills/babysit-my-prs)         | Sweep every open PR you authored — run `babysit-pr` on each that needs it, one dedicated `wt` worktree per branch (via `git-worktree`), all in parallel (a 2x2 Herdr pane grid inside Herdr), skipping any PR with no conflicts, no comments, and no failing CI |
| [pr-comment-handler](./skills/pr-comment-handler) | Read every open review comment on a PR, classify each as fix / push-back / defer-to-Linear, drive the work, then post the right reply on each thread (including `Fixed in <sha>` replies on push)                                                               |
| [fix-ci](./skills/fix-ci)                         | Diagnose and fix a failing CI check, on a PR or on main. Distinguishes "this branch broke it" from "main is already red" and fixes the root cause rather than the symptom                                                                                       |
| [sync-main](./skills/sync-main)                   | Bring a long-lived branch up to date with `origin/main` the same way every time: merge rather than rebase once a PR exists, resolve conflicts, and re-run the checks CI runs before pushing                                                                     |
| [git-worktree](./skills/git-worktree)             | Create, reuse, or remove a git worktree via the `wt` CLI so every worktree lands in one consistent place — `<repo-parent>/<repo-name>-<branch-slug>`, flat alongside the repo. The single source of truth other skills delegate to for "make a worktree"        |

## Building and shipping

| Skill                                                 | Description                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [ship](./skills/ship)                                 | The standing build-to-merged-PR playbook: fresh branch, small commits, a panel review after each phase, sync with main, then a PR with a real body (Problem / Solution, or a Goal for a net-new feature) and Testing                                                                                                                                                                                                                   |
| [orchestrate-features](./skills/orchestrate-features) | Build one or more features with an orchestrator pattern in Herdr: this session plans, briefs, and watches; each feature gets a Claude worker in its own pane (2 per tab) and its own `wt` worktree; major architecture decisions and scope growth come back to you                                                                                                                                                                     |
| [write-pull-request](./skills/write-pull-request)     | Write and open a PR a reviewer can skim: an imperative plain-language title and a scannable one-screen body (a one-line overview, Why, a short Changes list, Decisions, How to verify, Risk). Derives both from the diff and commits, honors a repo PR template, lints the result with `pr-lint.sh`, and is what `ship` delegates PR-writing to. Adapted from [tjcages/skills](https://github.com/tjcages/skills/tree/main/pr-writing) |
| [tdd-workflow](./skills/tdd-workflow)                 | Enforce test-driven development on new features, bug fixes, and refactors, aiming at 80%+ coverage across unit, integration, and E2E tests                                                                                                                                                                                                                                                                                             |
| [verify](./skills/verify)                             | Run the verification loop after a feature or any significant change, checking code quality and conformance before you call it done                                                                                                                                                                                                                                                                                                     |
| [startkit](./skills/startkit)                         | Scaffold a new strict-TypeScript project from the baseline standard — pnpm, native-TS Node, oxlint (type-aware) + oxfmt, vitest, ultra-strict tsconfig, kebab-case filenames, and a GitHub Actions check on PRs and main. Monorepo/CLI/web variants stubbed in `references/`                                                                                                                                                           |
| [update-deps](./skills/update-deps)                   | Bring every dependency (and every monorepo package) to its newest safe version — obey the project's age gates, catalogs, overrides, and Renovate/Dependabot rules, verify each batch with CI's checks, apply small fixes, run `fix-audit`, and flag upgrades that need significant code changes for you to decide                                                                                                                      |
| [fix-audit](./skills/fix-audit)                       | Fix what `pnpm audit` / `bun audit` reports with the smallest change — a lockfile update, then a direct or parent upgrade, and an override only as the last choice. Merges a new override into the entries already there and removes entries that are covered or unused, so the list never grows one line per advisory                                                                                                                 |

## Working the Linear backlog

| Skill                           | Description                                                                                                                                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [find-work](./skills/find-work) | Sweep the Linear backlog and act on it — close tickets that already shipped (with evidence and PR links) and pick up small well-specified ones as one branch + reviewed PR each. Grooming is `backlog-sweep` |

## Standards and reference

| Skill                                             | Description                                                                                                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [coding-standards](./skills/coding-standards)     | Universal coding standards and patterns for TypeScript, JavaScript, React, and Node.js                                                                 |
| [backend-patterns](./skills/backend-patterns)     | Backend architecture, API design, database optimization, and server-side practice for Node.js, Express, and Next.js API routes                         |
| [frontend-patterns](./skills/frontend-patterns)   | Frontend patterns for React and Next.js: state management, performance, and UI practice                                                                |
| [security-review](./skills/security-review)       | The checklist and patterns to reach for when adding auth, handling user input, working with secrets, creating API endpoints, or touching payment paths |
| [optimize-agents-md](./skills/optimize-agents-md) | Create, audit, or prune `AGENTS.md` / `CLAUDE.md` so every AI coding tool reads one lean source of truth. Handles monorepos, too                       |

## Utilities

| Skill               | Description                                                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [bro](./skills/bro) | Restate the last message in plain human language, no jargon — one human talking to another. User-invoked only. Credit: [Dillon Mulroy](https://github.com/dmmulroy) |

## License

MIT
