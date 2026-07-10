---
name: create-pull-request
description: Open a GitHub pull request for the current work, with a plain-language title and a body a human can skim (a Changes list, then Problem, Solution, Testing). Use whenever the user says "open a PR", "PR this", "raise a pull request", "put up a PR for this", "ship this as a PR", or the work is committed and it is time to open one. Auto-detects the base branch and derives the title and body from the actual diff and commits, not from memory of the conversation. Honors a repo's `.github/pull_request_template.md` when present. This is the reusable PR-opening procedure the `ship` playbook delegates to; use it directly when you just want a PR opened without running the whole build-and-ship loop. Do NOT use to update review comments on an existing PR (`pr-comment-handler`), to get a PR mergeable (`babysit-pr`), or to review a diff (`panel-review`).
---

# create-pull-request

Open one pull request that a human can read. The title says what changed, and the body leads with a scannable list, so a reviewer knows what they are looking at before they open the diff. The steps below cover the mechanics: branch, push, write the title and body, `gh pr create`.

Derive everything from the real work, not from your memory of the conversation. Read the diff and the commit messages; a summary written from memory drifts from what actually shipped.

## 1. Confirm the branch

Never open a PR from the default branch.

```bash
git branch --show-current
git status --short
```

- **On `main`/`master`:** stop. Create a branch first (`git switch -c <type>/<short-slug>`) or ask which branch to use. Do not push work to the default branch to open a PR.
- **Uncommitted work you intend to include:** commit it first, in logical commits. If the tree is dirty with work that should not ship, stop and ask rather than sweeping it in.
- **Someone else's branch:** if this is not your branch, do not push to it without explicit approval.

## 2. Push the branch

```bash
git push -u origin HEAD
```

If the branch already exists on the remote, a plain `git push` is enough. Never `--force` a branch that already has a PR with reviewers on it.

## 3. Check for a PR template

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

If the repo ships a template, it wins: fill in its sections rather than imposing the structure below. Repo conventions beat this skill's defaults. When there is no template, use the title and body format below.

## 4. Write the title

Plain language, so someone scanning a list of PRs understands what changed without opening it. Keep the repo's conventional-commit prefix when it uses one (`feat:`, `fix:`, `refactor:`, ...); everything after the prefix reads like a sentence a person would say out loud.

Say what changed and, where it fits, the effect. Do not describe the implementation, and never lean on a ticket ID, a codename, or a file path to carry the meaning.

| Instead of                       | Write                                                  |
| -------------------------------- | ------------------------------------------------------ |
| `fix: CHK-1042`                  | `fix: stop double-charging cards on retried checkouts` |
| `fix: patch the retry handler`   | `fix: stop double-charging cards on retried checkouts` |
| `refactor: update auth.ts`       | `refactor: move session checks into one middleware`    |
| `feat: wire up the new endpoint` | `feat: let admins export a team's invoices as CSV`     |

## 5. Write the body

Four sections, in this order. `Changes` comes first because it is what a reviewer reads before deciding whether to read the rest.

### Changes

An unordered list of what changed, one short line each, so the whole diff is legible in a few seconds.

- One line per change, and keep it under about ten words.
- Lead with the thing that changed, not with "Added" or "Updated".
- No paragraphs, no nested bullets, no trailing prose. If a line needs a subordinate clause, it belongs in `Solution`.
- Group by what a reader cares about, not by file.

```markdown
## Changes

- Retried checkouts no longer double-charge
- `charge()` deduplicates on idempotency key
- Failed retries now surface to the user
- Regression test for the retry path
```

### Problem

What was wrong or missing.

### Solution

What was done, why this approach was chosen, and how it works. This is where the reasoning and any longer prose go, not in `Changes`.

### Testing

How to validate, plus screenshots for UI states when applicable (use the repo's screenshot convention if one exists in AGENTS.md).

Reference the tracker ticket (Linear, etc.) when one exists. When the work came from a written plan, fold the plan's findings into the body itself; never commit a `plans/` folder.

## 6. Open the PR

Pass the body as a file or heredoc so the formatting survives.

```bash
gh pr create --base <default-branch> --head "$(git branch --show-current)" \
  --title "<title>" --body "$(cat <<'EOF'
## Changes

- ...

## Problem
...

## Solution
...

## Testing
...
EOF
)"
```

- Use `--draft` when the user asked for a draft, or when the work is not ready for review.
- One PR per independent change. If the branch carries several unrelated changes, that is a sign to split them, not to write one omnibus PR.

## 7. Report

Give the user the PR URL and a one-line summary. If CI runs on the repo, note that checks have started; do not merge (the author merges manually unless they say otherwise).

## Common mistakes

| Mistake                                     | Reality                                                              |
| ------------------------------------------- | -------------------------------------------------------------------- |
| Writing the body from memory                | Read the diff and commits; memory drifts from what shipped           |
| Opening the PR from `main`                  | Stop and branch first; never push to the default branch to open a PR |
| Title names a ticket or file                | Say what changed and its effect in plain language                    |
| Leading the body with Problem               | `Changes` comes first, so a reviewer sees the diff shape immediately |
| A `Changes` list of long paragraphs         | One short line per change; the prose belongs in `Solution`           |
| Ignoring `.github/pull_request_template.md` | The repo's template wins over this skill's default structure         |
| One omnibus PR for unrelated changes        | Split into one PR per independent change                             |
| Force-pushing a branch with an open PR      | Append only; never rewrite history reviewers can see                 |
