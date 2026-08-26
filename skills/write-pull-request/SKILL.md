---
name: write-pull-request
description: Write and open a GitHub pull request for the current work. The title is one plain-language imperative line; the body is one a reviewer can skim (a Changes list, then Why, How to verify, and Risk), derived from the real diff and commits, not from memory of the conversation. Use whenever the user says "open a PR", "PR this", "write the PR", "raise a pull request", "put up a PR for this", "ship this as a PR", "rewrite this PR description", or the work is committed and it is time to open one. Auto-detects the base branch, honors a repo's `.github/pull_request_template.md`, gates the title and body through `scripts/pr-lint.sh` before `gh pr create`, and updates the existing PR with `gh pr edit` when the branch already has one. The procedure the `ship` playbook delegates to; use it directly for a PR without the whole build-and-ship loop. Do NOT use to answer review comments on an existing PR (`pr-comment-handler`), to get a PR mergeable (`babysit-pr`), or to review a diff (`panel-review`).
---

# write-pull-request

Write one pull request that a reviewer can read under the worst conditions: tired, on a phone, months later, with no author to ask. The diff is the *how*. The title and body hold what the diff cannot: the change in one line, the problem, the reason for this solution, the proof that it works, and the risk.

Language contract: [references/language.md](references/language.md). Before and after: [references/examples.md](references/examples.md). Mechanical gate: `scripts/pr-lint.sh`.

**These are requirements, not preferences.** A title or body that breaks one gets rewritten, not shipped.

## Operating order

### 1. Confirm the branch

```bash
git branch --show-current
git status --short
```

- **On `main`/`master`:** stop. Create a branch first (`git switch -c <type>/<short-slug>`) or ask which branch to use. Never push work to the default branch to open a PR.
- **Uncommitted work you intend to include:** commit it first, in logical commits. If the tree carries work that should not ship, stop and ask rather than sweeping it in.
- **Someone else's branch:** do not push to it without explicit approval.

### 2. Read the diff, then the commits

```bash
base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git log --oneline "origin/$base..HEAD"
git diff "origin/$base...HEAD" --stat
git diff "origin/$base...HEAD"
```

Derive everything from the real work. A body written from memory of the conversation drifts from what shipped. If you cannot state *why* the change exists after reading the diff, you do not understand it yet. Read it again; do not write a longer body.

### 3. Push

```bash
git push -u origin HEAD
```

A plain `git push` is enough when the branch already exists on the remote. Never `--force` a branch that has a PR with reviewers on it.

### 4. Check for a PR template

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

When the repo ships a template, its sections win over the body shape in step 6. The title rules and the language contract still apply. Never let a template placeholder or HTML comment survive into the published body.

### 5. Write the title

One line that tells someone scanning a list of PRs what changed, without opening it.

- Keep the repo's conventional-commit prefix when it uses one (`feat:`, `fix:`, `refactor:`, ...). The text after the prefix reads like a sentence a person would say.
- Test it: **"If applied, this PR will ___."** If the sentence breaks, the title is wrong.
- Target 50 characters after the prefix. Hard limit 72 for the whole line; a squash merge makes it the commit subject.
- Say what changed and, where it fits, the effect. Do not describe the implementation.
- Banned: a trailing period, emoji, `[tags]`, and a ticket ID, codename, or file path carrying the meaning.
- Banned first words: `Added`, `Adds`, `Fixed`, `Fixes`, `Updated`, `Updates`, `Changes`, `WIP`, `Misc`, `Various`, `Cleanup`.

| Instead of                       | Write                                                  |
| -------------------------------- | ------------------------------------------------------ |
| `fix: CHK-1042`                  | `fix: stop double-charging cards on retried checkouts` |
| `fix: patch the retry handler`   | `fix: stop double-charging cards on retried checkouts` |
| `refactor: update auth.ts`       | `refactor: move session checks into one middleware`    |
| `feat: wire up the new endpoint` | `feat: let admins export a team's invoices as CSV`     |

### 6. Write the body

Four sections, in this order. `Changes` comes first because it is what a reviewer reads before deciding whether to read the rest.

```markdown
## Changes

- <One short line per change, under ten words>

## Why

<The problem, or the goal for a net-new feature. The reason for this
solution over the obvious alternative. The rejected alternative, in one
sentence. The cost.>

## How to verify

1. <One action.>
2. <One action, then the concrete expected result.>

## Risk

<What breaks if this is wrong. How to roll back.>

Closes ABC-123
```

- **Changes.** One line per change, under about ten words. Lead with the thing that changed, not with "Added" or "Updated". No paragraphs, no nested bullets, no trailing prose. Group by what a reader cares about, not by file. If a line needs a subordinate clause, it belongs in `Why`.
- **Why.** The problem that existed, or the goal when nothing was broken. Why this shape and not the obvious alternative. The rejected alternative, one sentence: it is the highest-value line in most PRs. What this makes worse, slower, or harder. Never a file list, a restatement of the diff in English, or a log of your working session.
- **How to verify.** Numbered steps, one action each, with the concrete expected result. Name what you actually ran. Screenshots for UI states, with alt text, using the repo's screenshot convention when one exists.
- **Risk.** The failure mode if this is wrong, and the rollback. When there is none, say so: `Risk: none, docs only.`
- Delete a heading rather than leave it empty.
- A stacked PR states its base branch in the first line of the body, above `Changes`.
- Reference the tracker ticket (Linear, etc.) when one exists. When the work came from a written plan, fold the plan's findings into `Why`; never commit a `plans/` folder.

### 7. Lint before you open

Write the body to a file, then gate it. Pass `--repo-template` when step 4 found a template.

```bash
bash scripts/pr-lint.sh "<title>" body.md
```

Exit non-zero means fix the title or body. Do not run `gh pr create` on a failing message.

### 8. Open the PR, or update the one that exists

```bash
gh pr view --json url -q .url 2>/dev/null
```

- **No PR yet:** `gh pr create --base <base> --head "$(git branch --show-current)" --title "<title>" --body-file body.md`. Add `--draft` when the user asked for a draft or the work is not ready for review.
- **A PR exists for this branch:** `gh pr edit --title "<title>" --body-file body.md`. Never open a second PR for the same branch.
- One PR per independent change. A branch that carries several unrelated changes is a sign to split them, not to write one omnibus PR.

### 9. Report

Give the user the PR URL and a one-line summary. If CI runs on the repo, note that checks have started. Do not merge; the author merges manually unless they say otherwise.

## Non-negotiables

1. Read the diff before you write one word. Memory of the conversation is not a source.
2. The title passes the imperative test and fits 72 characters.
3. `Why` states the problem or goal and the reason for this solution. A PR with no why is not ready.
4. `How to verify` names what you ran and what a reviewer should see. Unverified work is not a contribution.
5. Never let a template heading survive with placeholder text under it.
6. Pass the body with `--body-file` or a heredoc, never inline, so the formatting survives.

## Common mistakes

| Mistake                                     | Reality                                                              |
| ------------------------------------------- | -------------------------------------------------------------------- |
| Writing the body from memory                | Read the diff and commits; memory drifts from what shipped           |
| Opening the PR from `main`                  | Stop and branch first; never push to the default branch to open a PR |
| Title names a ticket or file                | Say what changed and its effect in plain language                    |
| Title opens with `This PR ...`              | Do not pre-announce; say what changed                                |
| Leading the body with `Why`                 | `Changes` comes first, so a reviewer sees the diff shape immediately |
| A `Changes` list of long paragraphs         | One short line per change; the prose belongs in `Why`                |
| `Why` that lists files                      | `git show --stat` already does that; state the problem and reason    |
| `Testing: works locally`                    | Numbered steps with the concrete expected result                     |
| Ignoring `.github/pull_request_template.md` | The repo's template wins over this skill's default structure         |
| A second PR for a branch that has one       | `gh pr edit` the existing PR                                         |
| One omnibus PR for unrelated changes        | Split into one PR per independent change                             |
| Force-pushing a branch with an open PR      | Append only; never rewrite history reviewers can see                 |
