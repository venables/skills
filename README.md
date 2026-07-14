# @venables/skills

Matt Venables' Claude Code / agent skills, grouped by what they're for.

## Reviewing code

| Skill                                           | Description                                                                                                                                                                                                                                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [panel-review](./skills/panel-review)           | Fan a code review out to multiple local CLI agents (codex, claude, opencode) in parallel — each driven through the `oneshot` CLI — and amalgamate their findings                                                                                                                     |
| [panel-review-loop](./skills/panel-review-loop) | Autonomously loop the review-fix-rereview cycle around `panel-review` — judge which findings are worth fixing, fix them, re-review, repeat until clean, then report what was fixed, what was left alone (and why), and any goal deviations                                           |
| [branch-review](./skills/branch-review)         | Review everything on the current branch against `origin/main`, staged, unstaged, and untracked alike. Findings stay in the session and never reach GitHub                                                                                                                            |
| [recheck-pr](./skills/recheck-pr)               | The second look after a `panel-review` — adjudicate each prior finding as remediated / explained / moot / outstanding by reading the new code, re-run the panel when the delta is significant, reply to and resolve the threads you're satisfied with, then approve via `approve-pr` |
| [approve-pr](./skills/approve-pr)               | Approve the GitHub PR you're discussing (usually after a `panel-review`) — auto-detect the PR from your branch and stamp it with a short fun body (LGTM or a silly emoji) when no message is given, or your message verbatim when one is                                             |

## Posting review findings

| Skill                                                                       | Description                                                                                                                                                                                                                                                                                 |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [post-panel-review-comments](./skills/post-panel-review-comments)           | Triage findings from a `panel-review` into PR inline comments and Linear tickets via a two-stage select list (auto-falls back to a top-level comment when GitHub rejects an inline)                                                                                                         |
| [auto-post-panel-review-comments](./skills/auto-post-panel-review-comments) | Zero-touch twin of `post-panel-review-comments` — post the legitimate findings straight to the PR (mergeable suggestion when the fix is a drop-in, a +1 reaction when a bot already raised it), routing uncertain / out-of-scope ones to Linear, no prompts                                 |
| [auto-review](./skills/auto-review)                                         | One-shot pipeline: run `panel-review`, post the findings via `auto-post-panel-review-comments`, then approve via `approve-pr` with a short LGTM — but only when the PR passes a strict approval gate (full coverage, LOW/polish-only, sound approach, not a draft, and more; see the skill) |

## Keeping PRs alive

| Skill                                             | Description                                                                                                                                                                                                                                              |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [babysit-pr](./skills/babysit-pr)                 | Babysit one PR into a mergeable state — resolve its conflicts by merging `origin/main`, hand its comments to `pr-comment-handler`, fix failing CI via `fix-ci`, and push, working in place and auto-detecting the PR from the current branch             |
| [babysit-my-prs](./skills/babysit-my-prs)         | Sweep every open PR you authored — run `babysit-pr` on each that needs it, one dedicated `wt` worktree per branch (via `git-worktree`), all in parallel, skipping any PR with no conflicts, no comments, and no failing CI                               |
| [pr-comment-handler](./skills/pr-comment-handler) | Read every open review comment on a PR, classify each as fix / push-back / defer-to-Linear, drive the work, then post the right reply on each thread (including `Fixed in <sha>` replies on push)                                                        |
| [fix-ci](./skills/fix-ci)                         | Diagnose and fix a failing CI check, on a PR or on main. Distinguishes "this branch broke it" from "main is already red" and fixes the root cause rather than the symptom                                                                                |
| [sync-main](./skills/sync-main)                   | Bring a long-lived branch up to date with `origin/main` the same way every time: merge rather than rebase once a PR exists, resolve conflicts, and re-run the checks CI runs before pushing                                                              |
| [git-worktree](./skills/git-worktree)             | Create, reuse, or remove a git worktree via the `wt` CLI so every worktree lands in one consistent place — `<repo-parent>/<repo-name>-<branch-slug>`, flat alongside the repo. The single source of truth other skills delegate to for "make a worktree" |

## Building and shipping

| Skill                                               | Description                                                                                                                                                                                                                                                                  |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [ship](./skills/ship)                               | The standing build-to-merged-PR playbook: fresh branch, small commits, a panel review after each phase, sync with main, then a PR with a real Problem / Solution / Testing body                                                                                              |
| [create-pull-request](./skills/create-pull-request) | Open a PR a human can skim: a plain-language title and a body that leads with a short Changes list before Problem / Solution / Testing. Derives both from the diff and commits, honors a repo PR template, and is what `ship` delegates PR-opening to                        |
| [tdd-workflow](./skills/tdd-workflow)               | Enforce test-driven development on new features, bug fixes, and refactors, aiming at 80%+ coverage across unit, integration, and E2E tests                                                                                                                                   |
| [verify](./skills/verify)                           | Run the verification loop after a feature or any significant change, checking code quality and conformance before you call it done                                                                                                                                           |
| [startkit](./skills/startkit)                       | Scaffold a new strict-TypeScript project from the baseline standard — pnpm, native-TS Node, oxlint (type-aware) + oxfmt, vitest, ultra-strict tsconfig, kebab-case filenames, and a GitHub Actions check on PRs and main. Monorepo/CLI/web variants stubbed in `references/` |

## Working the Linear backlog

| Skill                           | Description                                                                                                                                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [find-work](./skills/find-work) | Sweep the Linear backlog and act on it — close tickets that already shipped (with evidence and PR links) and pick up small well-specified ones as one branch + reviewed PR each. Grooming is `backlog-sweep` |

## Standards and reference

| Skill                                           | Description                                                                                                                                                                    |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [coding-standards](./skills/coding-standards)   | Universal coding standards and patterns for TypeScript, JavaScript, React, and Node.js                                                                                         |
| [backend-patterns](./skills/backend-patterns)   | Backend architecture, API design, database optimization, and server-side practice for Node.js, Express, and Next.js API routes                                                 |
| [frontend-patterns](./skills/frontend-patterns) | Frontend patterns for React and Next.js: state management, performance, and UI practice                                                                                        |
| [security-review](./skills/security-review)     | The checklist and patterns to reach for when adding auth, handling user input, working with secrets, creating API endpoints, or touching payment paths                         |
| [find-docs](./skills/find-docs)                 | Fetch current documentation, API references, and examples for any library, framework, SDK, or CLI tool, rather than trusting training data that may predate the latest release |

## Living elsewhere

| Skill                                                                                               | Description                                                                                          |
| --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [optimize-agents-md](https://github.com/catena-labs/dev-skills/tree/main/skills/optimize-agents-md) | Optimize your AGENTS.md (and CLAUDE.md) files according to best practices. Works with monorepos, too |

## License

MIT
