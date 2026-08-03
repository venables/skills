---
name: branch-review
description: Review all changes between the current branch and origin/main, including staged, unstaged, and untracked files, and report findings in the session only, never on the PR. Use whenever the user asks to "review all changes between this branch and origin/main", "review my working changes", "review this branch locally", "look over what i have so far", or wants a pre-PR sanity review kept out of GitHub. Do NOT use when he asks for a panel review (multi-agent) or a PR review on GitHub.
---

# Branch review (local, in-session)

A single-session review of everything on this branch versus origin/main. Findings stay in the conversation; nothing gets posted to GitHub or Linear.

## Scope

```bash
git fetch origin
git diff origin/main...HEAD        # committed changes
git diff HEAD                      # staged + unstaged
git status --porcelain             # untracked files
```

Review all three: committed, dirty, and untracked. Untracked files are part of the change; do not skip them.

## How to review

Read the full diff, then read enough surrounding code to judge correctness in context, not just the changed lines. Prioritize:

1. Correctness bugs: wrong logic, broken edge cases, race conditions, unhandled errors that will fail in production.
2. Security: input validation, secrets, authz gaps. Money paths and auth paths get extra scrutiny.
3. Data safety: anything that deletes or mutates persistent data gets challenged explicitly.
4. Convention drift: block comments not stacked `//`, immutability, no `any`, project AGENTS.md rules.
5. Simplifications only when they are clearly better, not stylistic churn.

## Output format

For each finding: severity (must-fix / should-fix / nit), `file:line`, one-sentence issue, and a concrete suggested fix (code when short). End with a verdict: ready to PR, or what blocks it. No filler praise; if it is clean, say so in one line.

## Language

Write every finding in ASD-STE100 Simplified Technical English. These findings often become PR comments later, so write them as if the author will read them.

- Write short sentences. Keep an instruction to 20 words. Keep a statement to 25 words.
- Put one idea in each sentence.
- Use the active voice. Write "the retry path bypasses the guard", not "the guard is bypassed by the retry path".
- Use simple tenses. Write "the test fails", not "the test has been failing".
- Use one word for one meaning. Do not change "function" to "method" to "routine" in the same text.
- Use the simplest word that is correct. Remove jargon, idioms, metaphors, and figures of speech.
- Do not make a noun out of a verb. Write "when the job starts", not "at job initiation".
