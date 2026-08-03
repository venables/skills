---
name: babysit-pr
description: >
  Babysit a single GitHub pull request into a mergeable state: resolve
  its merge conflicts by merging `origin/main`, hand its review comments
  to the `pr-comment-handler` skill, fix any failing CI via the `fix-ci`
  skill, and push — leaving the PR conflict-free, green, and with every
  comment answered. Works in place on the current checkout and
  auto-detects the PR from the current branch when the user doesn't name
  one. Use whenever the user says things like "babysit this PR", "babysit
  PR 27", "get this PR mergeable", "fix the conflicts and handle the
  comments on this one", "keep this PR green", or points at a single PR
  and asks you to nurse it to a clean state. Different from
  `babysit-my-prs` (many authored PRs, one worktree each, in parallel —
  it fans out to THIS skill) and from `pr-comment-handler` (comments
  only, no conflict resolution): this skill does conflicts, comments, AND
  CI for exactly one PR. Delegates the comment work to
  `pr-comment-handler` and the CI work to `fix-ci`.
---

# babysit-pr

Take one PR and leave it mergeable: no conflicts, every review comment
answered, CI green, everything pushed. Three pieces of work, in this
order — **resolve conflicts, handle comments, then fix CI** — each
skipped when there's nothing to do. Comment work is delegated wholesale
to the `pr-comment-handler` skill and CI work to the `fix-ci` skill;
don't re-derive either.

You work **in place**, on the current checkout (a normal clone or a git
worktree — `babysit-my-prs` calls this skill once per branch inside a
dedicated worktree). You never create or switch worktrees yourself.

## Language

`pr-comment-handler` writes the thread replies and holds itself to
ASD-STE100 Simplified Technical English; let it. Write the same way for
anything **this** skill puts on GitHub — a merge commit message, a
`fix:` commit, or a comment explaining a conflict you resolved: short
sentences (20 words for an instruction, 25 for a statement), one idea
per sentence, active voice, simple tenses, one word for one meaning, and
no jargon, idioms, or metaphors.

## 1. Find the PR and confirm the tree

Usually the PR is unstated — auto-detect it from the current branch:

```bash
gh pr view --json number,title,url,headRefName,state,isDraft,mergeable,mergeStateStatus
```

If the user named a PR, use that number instead. If detection is
ambiguous (no PR for this branch, or several), ask once rather than
guessing.

Before changing anything, confirm you're on the PR's head branch with a
**clean tree** (`git status`). If the tree is dirty from prior
uncommitted work, **stop and report** — do not stash, discard, or
`gh pr checkout`, all of which can silently lose the user's work.

## 2. Resolve conflicts first (only if the PR conflicts)

The `gh pr view` above tells you: `mergeable == "CONFLICTING"` or
`mergeStateStatus == "DIRTY"` means there's a conflict. If it's clean,
skip to step 3.

```bash
git fetch origin           # never `git fetch origin <branch>` — stale refs bite
git merge origin/main
```

Resolve conflicts **semantically** — understand both sides, keep the
intent of each — then commit the merge and push. Rules:

- **Never rebase or force-push a non-draft PR.** Reviewers lose their
  place and inline comments detach. Merge `origin/main` and append.
- **Divergent intent = stop, don't guess.** A mechanical overlap (both
  sides touched adjacent lines) you resolve. A genuine two-intent
  conflict — where picking a side changes behavior and you can't tell
  which the author wants — you **report up** rather than pushing a
  guess.

Do the merge before the comments so comment fixes apply on top of an
up-to-date base and land in a clean tree.

## 3. Handle the review comments (only if there are any)

Invoke the **`pr-comment-handler`** skill. It auto-detects the PR from
the current branch, so from this checkout it targets the right one. It
owns the entire comment engine — the fix / defer-to-Linear / decline
judgment, the replies, and the thread resolution — and commits and
pushes its own fixes. Run the skill; do not reimplement any of that here.

If the PR carries no open review comments, `pr-comment-handler` has
nothing to do — you can skip this step outright.

## 4. Fix failing CI (only if checks are red)

Do this **after** the conflict merge and comment fixes are pushed, so CI
reflects the PR's real final state — comment fixes can turn a red check
green or a green one red, and you want to react to the end result, not a
stale run. Check the current status:

```bash
gh pr checks         # add the PR number if you're not on its branch
```

If every check is passing (or the only non-green ones are pending), skip
this step. If any required check has **failed**, invoke the **`fix-ci`**
skill. It owns the whole CI engine — pull the failing run's logs,
distinguish "this branch broke it" from "main is already red" from a
flake, make the smallest correct fix, verify locally, commit (`fix:` /
`ci:`), push, and confirm the checks go green. Run the skill; don't
re-derive that here.

Two things `fix-ci` will not do without a human's nod, and neither should
you: **never** disable a test, add a lint-ignore, or loosen a config just
to get green; and if the failure is actually **main being broken** (not
this branch), that's a separate fix on its own branch — surface it rather
than burying it here. Both are stop-and-ask cases.

If `fix-ci` isn't available in this environment, don't guess at a CI fix
— report the failing check (name + the first real error from
`gh pr checks` / the run log) under **Needs a human** and move on.

## 5. Ensure everything is pushed

After all three steps, `git status` should be clean and
`git log origin/<branch>..HEAD` should show nothing unpushed. Push
anything left with a plain `git push` (appends only — never `--force` on
a non-draft PR).

## 6. Report

A compact summary of this PR:

- **Conflicts:** what the merge resolution did, or "no conflicts".
- **Comments:** what `pr-comment-handler` reported — fixed / deferred /
  declined counts, the commit range, any Linear links — or "no comments".
- **CI:** what `fix-ci` reported — what failed, the root cause, the fix,
  and the final check status — or "CI green".
- **Needs a human:** anything you stopped on (divergent conflict, dirty
  tree, a comment needing a design call, a CI fix that would need
  disabling a test or is really a main breakage, a failed push/reply),
  with the PR link.

## Stop-and-ask triggers (report up, don't guess)

- A merge conflict with genuinely divergent semantics (not a mechanical
  overlap).
- A dirty tree from prior uncommitted work.
- Anything that would require rewriting history on a non-draft PR.
- A CI failure whose only fix is disabling a test / adding a lint-ignore
  / loosening a config, or one that's actually **main** being broken
  rather than this branch.
- A push, reply, or resolve that fails partway.

`pr-comment-handler` handles its own comment-level judgment (including
deferring out-of-scope work to Linear) and `fix-ci` its own CI-level
judgment — let them. Escalate only the PR-level blockers above.

## Common mistakes

| Mistake                                         | Reality                                                                 |
| ----------------------------------------------- | ----------------------------------------------------------------------- |
| Re-deriving the comment fix/reply/resolve logic | That is `pr-comment-handler`'s job — invoke it                          |
| Re-deriving the CI diagnose/fix logic           | That is `fix-ci`'s job — invoke it                                      |
| Checking CI before pushing comment fixes        | Fix CI last, so it reflects the PR's real final state                   |
| Disabling a test / lint-ignore to get CI green  | Stop and ask — never loosen config to pass a check                      |
| Rebasing or force-pushing a non-draft PR        | Merge `origin/main` and append; never rewrite history reviewers can see |
| Pushing a guessed conflict resolution           | Divergent intent = stop and report up, don't guess                      |
| Running comment handling before merging main    | Merge first so fixes apply on an up-to-date base and a clean tree       |
| `gh pr checkout` / stashing in a dirty tree     | Bail and report — both can silently discard uncommitted work            |
| `git fetch origin <branch>`                     | Fetch all of `origin`; a scoped fetch leaves stale refs in worktrees    |
