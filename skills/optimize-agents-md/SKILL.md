---
name: optimize-agents-md
description:
  Create, audit, or prune AGENTS.md and CLAUDE.md files following current best
  practices. Use this whenever the user asks to set up, create, add, update,
  fix, clean up, shrink, restructure, or audit an AGENTS.md or CLAUDE.md, or
  uses casual phrasings like "set this up for Claude", "set this up for agents",
  "make a claude.md", "add agent instructions", "onboard this for Claude Code /
  Cursor / Codex / Copilot / Gemini / Windsurf", "make Claude follow my
  conventions", "my CLAUDE.md is too long", "we upgraded to Opus 5 / Fable, what
  can I cut", or "should I delete my CLAUDE.md". Covers the AGENTS.md open
  standard, Claude Code's native AGENTS.md support, cross-tool setups, monorepo
  nesting, and model-upgrade audits. Also use it proactively when you notice an
  existing CLAUDE.md / AGENTS.md is long, repetitive, contradictory, or full of
  advice the model no longer needs.
---

# optimize-agents-md

Write one lean `AGENTS.md` that every AI coding tool reads, including Claude
Code, which reads it natively since v2.1.277. Keep only two kinds of content:
facts about this repo the model cannot derive, and conventions that differ from
what the model would do on its own.

## Core philosophy

Every line in an instruction file is one of two things:

- **Context.** Facts about this repo the model cannot get from the code: the
  exact test command, the package manager, the decision that contradicts what
  the code implies, the gotcha that cost someone an afternoon. These lines
  survive model upgrades.
- **Compensation.** Lines that patch a weakness of the model you had last year:
  "always run the tests", "double-check your work", "be thorough", "do not use
  bullet points", "act like a senior engineer", "CRITICAL: you MUST". These
  lines rot on every model release. On Claude 5 generation models (Opus 5 and
  5.5, Sonnet 5, Fable 5 and 5.1) they cause over-verification, literal
  over-compliance, and contradictions with the model's own system prompt.

Anthropic removed over 80% of Claude Code's system prompt for Opus 5 and Fable 5
with no measured loss on coding evals, and said the same overconstraint lives in
most CLAUDE.md files. Their guidance: keep the file lightweight, say in a
sentence what the repo is for, spend the rest on gotchas, and push procedures
into skills.

Two tests for every line:

1. **Would removing this line cause Claude to make a mistake it would not
   otherwise make?** If no, cut it.
2. **Is this line here because of the repo, or because of a model?** Repo: keep
   it if it passes test 1. Model: cut it, or move it to that tool's own config
   file if a weaker model in another tool still needs it.

Contradictions cost more than length. Two rules that disagree get resolved
arbitrarily, and Anthropic found its own transcripts full of "leave
documentation as appropriate" fighting "DO NOT add comments". Hunt for these
before counting lines.

The line count matters less than which lines. The one controlled study of
CLAUDE.md structure found no effect from file size up to 500 lines or from rule
position, on Claude 4.6 models. The harm comes from wrong lines, contradictory
lines, and lines that tell a strong model to do what it already does. Cut for
those reasons. Keep the file short as a consequence.

## Workflow

Run these stages in order. Stages 1 to 3 are autonomous discovery. Stage 4 is
interactive but adaptive: do not pepper the user with questions the repo can
answer.

### 1. Survey the existing state

Read whatever exists:

- `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`
- `.claude/` (rules, skills, settings, hooks)
- `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`
- `README.md` and `CONTRIBUTING.md`, where commands and conventions often live

Also check these, because they change the wiring decision in stage 7:

- **Ancestor directories.** A `CLAUDE.md` or `CLAUDE.local.md` anywhere above
  the repo (for example `~/dev/CLAUDE.md`) makes Claude Code skip the repo's
  `AGENTS.md`. Run `ls` up the tree.
- **Old workarounds.** A `SessionStart` hook that prints `AGENTS.md`, a
  `CLAUDE.md` that says "read AGENTS.md" in prose, a `CLAUDE.md` that duplicates
  `AGENTS.md` verbatim (what `/import` produces), or a symlink.
- **Claude Code version and provider.** `claude --version` below 2.1.277, Amazon
  Bedrock, Vertex, Foundry, or telemetry disabled all mean Claude Code cannot
  read `AGENTS.md` directly.

Note the current line count and how much is context versus compensation versus
filler.

**Treat existing content as hypotheses, not ground truth.** Bloated files
routinely describe a stack that drifted: libraries that were removed,
conventions that were abandoned, patterns that never shipped. Before carrying
any stack claim forward ("uses Zustand", "uses MSW"), verify it against
`package.json`, the lockfile, and the source. A file full of phantom
dependencies misleads every agent that reads it.

### 2. Discover objective facts

These are the highest-value lines in any `AGENTS.md`. Detect them from the repo
rather than asking:

- **Package manager.** Inspect lockfiles: `pnpm-lock.yaml`, `bun.lockb` or
  `bun.lock`, `yarn.lock`, `package-lock.json`, `uv.lock`, `poetry.lock`,
  `Cargo.lock`, `go.sum`. Naming the tool (`bun`, `uv`) makes agents use it more
  than 100x as often as leaving it implicit.
- **Test, lint, format, typecheck commands.** From `package.json` scripts,
  `Makefile`, `justfile`, `pyproject.toml`, `Cargo.toml`. Prefer the exact
  invocation with flags.
- **Unusual tooling.** `just`, `mise`, `nix`, `devbox`, `turbo`, `nx`, custom
  wrappers.
- **Framework, only when it informs a non-obvious convention.** "Uses Next.js"
  is noise. "App Router, not Pages Router" may earn a line.
- **Monorepo layout.** Workspace files (`pnpm-workspace.yaml`, `turbo.json`,
  `nx.json`, `go.work`, Cargo workspace) and top-level `apps/`, `packages/`,
  `services/`, `infra/`.

### 3. Classify every existing line

When a file already exists, sort each line into one bucket and give it a
destination. Show this table to the user in stage 6.

| Bucket        | Example                                                                                            | Destination                                             |
| ------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Context       | `pnpm test --filter=api`; "auth is session-based, not the JWT code in src/auth-legacy"             | Keep in `AGENTS.md`                                     |
| Gotcha        | "the dev DB seed script drops the `events` table"                                                  | Keep in `AGENTS.md`                                     |
| Compensation  | "always run tests"; "double-check"; "be thorough"; "no bullet points"; "you are a senior engineer" | Delete, or the other tool's file                        |
| Derivable     | directory trees; dependency lists; architecture overviews the code shows                           | Delete                                                  |
| Procedure     | a 20-line deploy or release checklist                                                              | Skill                                                   |
| Path-specific | rules that only apply under `apps/billing/`                                                        | `.claude/rules/` with `paths:`, or a nested `AGENTS.md` |
| Enforcement   | "never edit `.env`"; "never push to main"                                                          | Hook or permission deny rule                            |
| Personal      | "I prefer tabs"; "call me Matt"                                                                    | Auto memory or `~/.claude/CLAUDE.md`                    |
| Linter's job  | semicolons, import order, naming case                                                              | ESLint, Prettier, Ruff, rustfmt                         |

Keep failure-driven rules even when they look odd. A specific line like "do not
add event handlers when the framework handles reactivity" usually exists because
of a real incident. Keep it unless the user confirms it is obsolete.

### 4. Interview the user (only when needed)

- **If the user said "ask me" or "interview me":** walk through each proposed
  section before writing.
- **If the user said "just do it":** draft from discovery and present the
  result.
- **Default:** ask only when the repo cannot resolve the question.

Questions that pay for themselves:

- "What has Claude (or Cursor, Codex) been getting wrong in this project?"
- "Which conventions here go against the common pattern for this stack?"
- "Which model generation does the team run?" Claude 5 generation means cut
  compensation lines hard. Mixed tools on older models means those lines move to
  that tool's file rather than staying in `AGENTS.md`.
- "Does anyone work on Windows, on Bedrock, Vertex, or Foundry, or keep a
  `CLAUDE.local.md`?" These decide the wiring in stage 7.

### 5. Decide on structure

Single-package project: one root `AGENTS.md`. Monorepo: see the Monorepo section
before drafting.

### 6. Draft and propose

Use the skeleton in the Output format section and the Writing patterns. For an
existing file, show what is kept, what is cut, and why, before writing. The user
may rescue a line you flagged because of context you lack. Skip the proposal
only when the user said "just do it".

### 7. Wire it up for Claude Code

See the next section. Decide, state the one-line reason, and apply.

### 8. Verify

Tell the user how to confirm the file loads: run `/context` or `/memory` in the
repo and look for the file under Memory files (Claude Code 2.1.280 or later
lists a directly-read `AGENTS.md`). Suggest `/doctor`, which proposes trims for
a checked-in CLAUDE.md, and the delete-and-observe check from the Model upgrade
section when the team has just moved to a newer model.

## Wiring: AGENTS.md alone, or an import

`AGENTS.md` is the source of truth. Codex, Cursor, Copilot, Gemini CLI,
Windsurf, and about two dozen other tools read it natively. Claude Code reads it
natively since v2.1.277 when there is no `CLAUDE.md`, `.claude/CLAUDE.md`, or
`CLAUDE.local.md` in the working directory or any directory above it.

**Default: `AGENTS.md` only. No `CLAUDE.md`.** One file, zero drift, nothing to
keep in sync.

**Add a `CLAUDE.md` that imports it when any of these hold:**

- There is Claude-only content with no better home (see below).
- Someone runs Claude Code on Bedrock, Vertex, or Foundry, with telemetry
  disabled, or on a version below 2.1.277.
- Someone keeps a `CLAUDE.local.md`, or a `CLAUDE.md` exists in an ancestor
  directory that cannot be removed. Either one switches Claude Code to
  CLAUDE.md-only mode and hides `AGENTS.md`.
- An `InstructionsLoaded` hook must fire for the file. It does not fire for a
  directly-read `AGENTS.md`.

The import form never double-loads: Claude Code skips an `AGENTS.md` it already
read through an import, whatever the Project instructions setting.

```markdown
@AGENTS.md

## Claude Code

- Use plan mode for changes under `src/billing/`.
```

**Symlink (`ln -s AGENTS.md CLAUDE.md`)** is documented but not recommended. The
Edit and Write tools refuse to write through a symlink, and a Windows checkout
turns a committed symlink into a one-line text file. Leave an existing symlink
alone or delete it; do not create new ones.

**Remove old workarounds** when you find them:

- A `SessionStart` hook that prints `AGENTS.md`: delete it, or Claude gets two
  copies.
- A `CLAUDE.md` that says "read AGENTS.md" in prose: delete it, or replace the
  sentence with `@AGENTS.md`.
- A `CLAUDE.md` that duplicates `AGENTS.md` verbatim: delete it.

**What counts as Claude-only content.** A behavior other tools do not share
_and_ that has no deterministic or on-demand venue. Compaction instructions
qualify. Plan-mode preferences qualify. Most other candidates belong in subagent
frontmatter, hooks, `settings.json`, or a skill. Compensation lines that another
tool's older model still needs go in that tool's own file (`.cursor/rules/`,
`.github/copilot-instructions.md`), not in `AGENTS.md`, because model families
are not interchangeable and `AGENTS.md` is read by all of them.

## Monorepo handling

Claude Code and similar tools load every instruction file from the working
directory up to the root at session start. Files in child directories load
lazily, when the agent reads a file in that subtree. Siblings never
cross-contaminate. Nested files scope themselves with no extra wiring.

**One rule that changes the wiring decision:** under Claude Code's default
setting, nested `AGENTS.md` files load only when no `CLAUDE.md` exists in the
working directory or above it. A root `CLAUDE.md` of any size, including a
one-line `@AGENTS.md` import, turns nested `AGENTS.md` discovery off. Each
nested `AGENTS.md` then needs its own sibling `CLAUDE.md` with `@AGENTS.md`. The
`claude-md-and-agents-md` setting fixes this per user but is ignored in project
settings, so a repo cannot commit the fix. In monorepos, prefer `AGENTS.md`
only, at every level.

**Root file rule:** include a rule at the root only if it applies to roughly 30%
or more of the codebase. Everything else belongs in a nested file.

**Create a nested `AGENTS.md`** in `apps/web/`, `services/api/`, `infra/`, and
similar when:

- The package has a distinct stack (Next.js here, Go there, Expo over there).
- The package has commands or conventions that differ from the rest.
- The package has domain concepts that would confuse an agent working elsewhere.
- It is `infra/`. Terraform, CDK, and Pulumi conventions rarely apply to app
  code.

**Do not** create a 10-line nested file for one rule. Put that rule in the root.

**The root file** holds workspace-level commands (`pnpm -r test`,
`turbo run build`, `cargo test --workspace`), cross-cutting conventions, and a
short map of which subdirectories have their own file. Use prose for the map,
not `@` imports; the nested files load on their own.

```markdown
## Package-specific rules

Each directory below has its own `AGENTS.md`, loaded when you work there:

- `apps/web/` — Next.js App Router conventions and component patterns
- `services/ingest/` — Go style and error handling
- `infra/` — Terraform module conventions
```

Nested files follow the same rules as the root and contain only what is specific
to that subtree. Never repeat root rules in nested files; the loader
concatenates them.

## Pushing content out of the always-loaded file

`AGENTS.md` loads every session. Anything that does not need to be in every
session goes to a venue that loads on demand or enforces deterministically:

- **`.claude/rules/*.md` with `paths:` frontmatter.** Loads when Claude reads a
  matching file (`paths: ["apps/billing/**"]`). `paths` is the only frontmatter
  field; there is no `priority`. Rules without `paths` load at startup like
  CLAUDE.md. User-level `~/.claude/rules/` with `paths` works.
- **Skills.** Anything that is a procedure rather than a fact: deploy runbooks,
  release checklists, verification steps, migration guides, niche API patterns.
  Anthropic's own advice: put the verification procedure in a skill and
  reference it from the instruction file. Keep the exact build and test commands
  in `AGENTS.md`; move the checklist out.
- **Subagents.** Rules that bind one worker ("review runs on Haiku", "research
  is read-only"). Declare them in frontmatter (`model`, `tools`,
  `permissionMode`, `omitClaudeMd`). The built-in Explore and Plan agents skip
  CLAUDE.md, so a rule that must reach them goes in the delegating prompt.
- **Hooks** for anything that must happen every time, and **permission deny
  rules** for anything that must never happen. "Never edit `.env`" in prose is a
  request. A `PreToolUse` hook is enforcement.
- **`settings.json`** for deterministic behavior, not guidance.
- **Auto memory** for personal preferences and corrections. It is on by default,
  per repo, machine-local, and Claude skips anything the instruction files
  already say. "I prefer tabs" belongs there or in `~/.claude/CLAUDE.md`, not in
  a committed file. When auditing, skim `MEMORY.md` for entries that became team
  conventions and should graduate into `AGENTS.md`.

## What earns its place

- **Exact commands with flags.** `pnpm test --filter=api` beats "run the api
  tests".
- **Non-obvious tool choices.** "This repo uses `bun` for install, scripts, and
  tests."
- **Gotchas.** Non-obvious behaviors, required env vars, the seed script that
  drops a table, the flaky test that needs `--runInBand`.
- **Decisions that contradict what the code implies.** "Auth uses session tokens
  in Redis. The JWT code in `src/auth-legacy/` is dead."
- **Conventions that differ from the tool's defaults.** "Imports use `@/`
  aliases across module boundaries."
- **Repository etiquette.** Branch naming, PR conventions, commit format.
- **Domain concepts Claude keeps rediscovering.** Describe the concept, not the
  path. Paths change; concepts survive refactors.
- **An exemplar to copy.** "New route handlers follow
  `src/api/handlers/users.ts`." A pointer to real code beats a prose description
  of the pattern. Use it only for stable, well-known files.
- **Failure-driven rules.** Added because Claude failed at something specific,
  with a short reason.

## What wastes the budget

Cut these, especially when auditing an existing file:

- **Compensation for older models.** "Always run the tests", "verify your work",
  "double-check", "be thorough", "don't be lazy", "hold findings for the final
  response", "do not use bullet points or bold". Claude 5 generation models
  verify on their own and over-verify when told to. Anthropic's model pages say
  to remove these.
- **Personality and role-play.** "Act like a senior engineer." Changes nothing.
- **Shouting.** `CRITICAL`, `MUST`, `NEVER` on many lines. If everything is
  important, nothing is.
- **Examples of ordinary behavior.** Examples anchor the model to the example.
  Removing them was one of the largest wins in Claude Code's own prompt.
- **Style guides.** Semicolons, tabs, import order, naming. A linter's job.
- **Directory trees, dependency lists, architecture overviews.** Claude reads
  the repo. `/doctor` cuts exactly these.
- **Code snippets.** They go stale and cost tokens every session.
- **Self-evident practices.** "Write clean code", "handle errors", "add tests",
  "follow DRY".
- **Duplicates of README, package.json, tsconfig, or CI config.**
- **Contradictions.** Two rules that disagree, or a rule that fights the model's
  own defaults. Resolve or delete.

When in doubt, cut it and let the user ask for it back.

## Writing patterns

- **Describe the target and the reason; let the model judge.** Anthropic
  replaced "Never write multi-paragraph docstrings" with "Write code that reads
  like the surrounding code: match its comment density, naming, and idiom." A
  reason lets the model generalize to cases you did not list.
- **Positive over negative.** "Use the logger in `src/lib/logger.ts`" beats
  "Never use console.log". Keep a negative only for a concrete failure mode, and
  give it three parts: the construct to use, one line of reasoning, then the
  category to avoid.
- **Imperative for behaviors, declarative for facts.** "Use named exports."
  "This repo uses bun." Not "YOU MUST use bun."
- **Commands in code fences with exact flags.**
- **One instruction per bullet.**
- **No emphasis by default.** Add `IMPORTANT` to one line only after Claude has
  skipped that line repeatedly. Never to more than a few lines.
- **No duplication, no anchoring blocks.** Do not repeat rules at the top and
  bottom. Order sections by value: commands and gotchas first.
- **Concepts over paths for architecture; exemplars for conventions.**
- **HTML comments for maintainer notes.** `<!-- why this rule exists -->` is
  stripped before the model sees it. Use them to record the incident behind a
  rule so humans can audit it later at zero context cost.
- **Say what the repo is for in one or two sentences.** Then stop describing and
  start listing what the model needs.

## Output format

```markdown
# <repo name>

One or two sentences on what this repo is and who uses it.

## Commands

- `pnpm test --filter=api` — unit tests for the API package
- `pnpm typecheck` — run before opening a PR

## Gotchas

- The dev seed script drops the `events` table. Run it only on a fresh DB.
- Integration tests need a local Redis on 6380, not the default 6379.

## Conventions that differ from defaults

- Imports use `@/` aliases across module boundaries.
- New route handlers follow `src/api/handlers/users.ts`.

## Architecture decisions

Auth uses session tokens stored in Redis. The JWT code in `src/auth-legacy/` is
dead and scheduled for removal. Deeper docs: see `docs/api-guide.md`.
```

Drop any section that would be empty. Add a `## Package-specific rules` map in a
monorepo root. Reference deeper docs in prose, not with `@`, which expands the
file into context every session.

**Length.** Target 30 to 60 lines for a typical project. 80 is fine when the
gotchas are real. Over 120 is a red flag. Anthropic's ceiling is 200 lines per
file; its own docs example is seven lines.

Headings: H1 for the title, H2 for sections, H3 rarely, never deeper. Keep
Markdown structure; headers and bullets are parsing landmarks.

## Model upgrade audit

When the team moves to a Claude 5 generation model, or a model release makes
Claude "surprisingly good" at something the file nags about, run this pass:

1. Classify the file with the stage 3 table.
2. Delete every compensation line. Start with verification reminders, self-check
   lines, "be thorough", anti-formatting rules, "hold findings", role-play, and
   `CRITICAL`/`MUST` emphasis.
3. Keep every context, gotcha, and failure-driven line.
4. If another tool on an older model still needs a deleted line, move it to that
   tool's own config file.
5. Run a few real tasks. Add a line back only when the model repeatedly stumbles
   on the same thing, and add the reason with it.

This is the Claude Code team's own method: delete, use it, add back what the
model demonstrably needs. Boris Cherny's advice is to do it every six months.
The classification step is what makes it safe: project context does not come
back by observation, so sort before you delete.

## Handling an existing bloated file

1. Read the whole file and classify each line (stage 3).
2. Verify every stack claim against the lockfile and source.
3. Propose the pruned version before writing, unless told to just do it.
4. Preserve failure-driven rules unless the user confirms they are obsolete.
5. Merge `CLAUDE.md` into `AGENTS.md` and wire per the Wiring section. The
   default is to delete `CLAUDE.md`. Keep a one-line `@AGENTS.md` import only
   for the reasons listed there.
6. Flag graduation candidates and their venues: hooks, rules, skills, subagent
   frontmatter, settings, auto memory. Note them for the user even if this skill
   does not implement them.
7. Remove old workarounds: `SessionStart` hooks that print `AGENTS.md`, prose
   pointers, verbatim duplicates, symlinks.

## Final checks

Re-read the draft against this list before writing:

- [ ] Every line passes both tests: removal would cause a mistake, and it is
      here because of the repo, not a model.
- [ ] No verification reminders, self-check lines, role-play, anti-formatting
      rules, or `MUST`/`CRITICAL` shouting.
- [ ] No two lines contradict each other or the tool's defaults.
- [ ] Stack claims verified against the lockfile and source.
- [ ] Commands in code fences with exact flags.
- [ ] Prohibitions carry a reason and an alternative.
- [ ] No directory trees, dependency lists, style-guide content, or code
      snippets a linter or the repo already covers.
- [ ] No duplicated rules at the top and bottom.
- [ ] Under 120 lines, target 30 to 60.
- [ ] Monorepo: root has only cross-cutting rules; nested files hold the rest;
      no root `CLAUDE.md` unless every nested `AGENTS.md` has its own import.
- [ ] Wiring decided and stated: `AGENTS.md` only, or `@AGENTS.md` import with
      the reason. No new symlinks. Old workarounds removed.
- [ ] User told how to verify with `/context` or `/memory`.
