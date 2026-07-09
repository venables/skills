# swarm-pr-review

Team-based PR review that spawns three specialized reviewers inside a single Claude Code swarm. They review the diff from their own angle, discuss each other's findings to reach consensus, then post a summary with a merge verdict plus inline comments for the real issues.

## Install

```
npx skills add venables/skills --skill swarm-pr-review
```

Uses the `gh` CLI to fetch the diff and post comments.

## How to use it

Ask Claude Code in plain English, naming a PR or letting it infer one from your branch:

- "swarm review this PR"
- "run a team review on PR 27"
- "have the review team look at this PR"
- "get correctness, code health, and UX takes on this PR"
- "review this PR and post a merge verdict"

## What it does

- **Fetches the PR:** pulls the diff, metadata, and existing comments via `gh`, saving files to the repo working directory so it also works in CI.
- **Spawns three personas:** a correctness expert (bugs, edge cases, control flow, security), a code health expert (dead code, duplication, complexity, meaningful comments), and a UX wizard (consistency, accessibility, error states, delight), each running as a teammate in the swarm.
- **Discusses to consensus:** every teammate reviews independently, then sees all findings and endorses, challenges, or adds context; an issue is confirmed when a second reviewer endorses it and dropped when two reviewers challenge it with reason.
- **Classifies by severity:** findings are graded HIGH, MEDIUM, or LOW, with challenged issues downgraded or dropped during discussion.
- **Posts a verdict and comments:** a summary comment with a merge verdict (ready / not sure / do not merge) and an issues table, plus inline review comments for each HIGH and MEDIUM issue. LOW and dropped issues go in collapsible sections.
- **Deduplicates and cleans up:** filters out issues already raised in existing PR comments, and shuts down and deletes the team when finished.

## Gotchas

- **One swarm, not separate CLIs.** All three reviewers are teammates inside a single Claude Code swarm sharing this session's model and context. This differs from `panel-review`, which fans a diff out to separate external CLI agents (codex, claude, opencode) each in a fresh isolated subprocess.
- **Teammates only see what they are handed.** Reviewers cannot read files from the lead's scratchpad, so the full diff, PR description, and existing comments are passed inline in each prompt. Very large diffs mean very large prompts.
- **Only HIGH and MEDIUM get inline comments.** LOW findings are collected in a collapsible section of the summary, never posted at the line.
- **It always posts a summary.** Even a clean review or one where every finding was challenged away still leaves a summary comment on the PR.
- **Requires `gh` and PR write access.** It reads the diff and posts a review with inline comments through the GitHub API, so it needs a working `gh` auth with permission to comment on the PR.
