---
name: update-deps
description: >
  Update the dependencies of a project to their latest safe versions. In a
  monorepo, do every workspace package and every nested project. Obey the
  rules the project sets (pnpm-workspace.yaml minimumReleaseAge and its
  excludes, catalogs, overrides, .npmrc min-release-age, .yarnrc.yml
  npmMinimalAgeGate, bunfig.toml, Renovate and Dependabot config, engines,
  pins). Verify each upgrade with the project's own checks. Apply small
  fixes (types, imports, renamed options) automatically. Flag upgrades that
  need significant code changes for the user to decide, and do not
  implement them. Use whenever the user says "update dependencies", "update
  deps", "bump deps", "upgrade packages", "bring deps up to date", "upgrade
  everything to latest", "what's outdated", or "update X to latest". Do NOT
  use to add a new dependency, to fix a red CI run on an existing Renovate
  or Dependabot PR (`fix-ci`), or to merge main into a branch (`sync-main`).
---

# update-deps

Bring each dependency to the newest version that is safe. A version is safe
when it obeys the project rules, passes the project checks, and needs no
significant code change. Do the safe upgrades. Report the rest.

Two rules control every decision:

- **The project rules win.** When the project sets a rule (age gate, pin,
  ignore list, catalog), obey it. Do not loosen a rule to get an upgrade in.
- **Significant code change is the user's decision.** Small mechanical fixes
  are yours. Anything larger goes in the report, and the upgrade stays out.

## 0. Prepare

1. Make sure the working tree is clean (`git status --porcelain`). If it is
   not clean, stop and tell the user.
2. If you are on the default branch, make a branch:
   `chore/update-deps-<YYYY-MM-DD>`.
3. Find the checks that CI runs. Read `.github/workflows/*` and the root and
   workspace `package.json` scripts. Usually these are install, typecheck,
   lint, test, and build. Use the same commands that CI uses.
4. **Record a baseline.** Install, then run every check before you change
   anything. Write down each check that already fails. Do not blame an upgrade
   for a failure that was there before. If the baseline is very red (for
   example, the build does not compile), stop and ask the user.

## 1. Find the projects

- Identify the package manager from the lockfile and the `packageManager`
  field. See [references/package-managers.md](references/package-managers.md).
- List the workspace packages (`pnpm-workspace.yaml` `packages`, or
  `workspaces` in the root `package.json`).
- Find nested projects that are not workspace members: other `package.json`
  files with their own lockfile, outside `node_modules`. Treat each one as a
  separate project with its own rules and its own checks.
- For other ecosystems (Python, Rust, Go), see
  [references/other-ecosystems.md](references/other-ecosystems.md).

## 2. Read the project rules

Collect every rule before you pick a version. See
[references/project-rules.md](references/project-rules.md) for where each rule
lives and its units. The minimum list:

- **Age gate.** Convert each source to minutes and use the **strictest** one.
  If the project sets no gate, use 4320 minutes (3 days) and say so in the
  report.
- **Age-gate excludes.** A package on an exclude list uses a gate of 0.
- **Ignored or held packages.** Renovate `ignoreDeps`, `packageRules` with
  `enabled: false` or `allowedVersions`, Dependabot `ignore`. Skip these and
  list them in the report.
- **Catalogs.** In a pnpm workspace, a dependency with a `catalog:` specifier
  gets its version from `pnpm-workspace.yaml`. Change the catalog, not the
  `package.json`.
- **Overrides and resolutions.** Do not remove or change an override unless
  the upgrade makes it unnecessary. If so, flag it. Do not remove it yourself.
- **Engines and runtime.** `engines`, `.nvmrc`, `.node-version`,
  `packageManager`. A target that needs a newer runtime is a flagged upgrade.
- **Range style.** Keep the operator the project uses (`^`, `~`, or exact).
  An exact pin with a comment, or a Renovate pin rule, means "do not move".
- **Project instructions.** Read `AGENTS.md` / `CLAUDE.md` for dependency
  notes (for example, "stay on React 18").

Skip `workspace:`, `link:`, `file:`, `git`, and URL specifiers. List them in
the report.

## 3. Pick a target for each dependency

1. List outdated direct dependencies for every project
   (`pnpm outdated -r --format json`, or the package-manager equivalent).
2. For each one, run `scripts/pick-version.mjs` (in this skill's directory)
   by its absolute path, from the project directory, so the project's
   `.npmrc` applies:

   ```bash
   node <this-skill>/scripts/pick-version.mjs <name> \
     --current <installed version> --min-age-minutes <gate>
   ```

   It returns `target`, `bump` (`major` / `minor` / `patch`; a 0.x minor bump
   counts as major), and `heldBack` (a newer version that the gate blocks, with
   the date it becomes eligible). It never picks a prerelease or a version
   above the `latest` dist-tag. It reads the registry with `npm view`. For a
   private registry that only `.yarnrc.yml` knows, save
   `yarn npm info <name> --fields time,dist-tags --json` to a file and pass
   `--input <file>`.

3. Run the safety checks on each target. A failed check moves the upgrade to
   the report:
   - `npm view <name>@<target> deprecated` is empty.
   - Provenance did not disappear. If `npm view <name>@<current> dist --json`
     has `attestations` and the target does not, flag it. This can be a sign of
     a compromised publish account.
   - No new install scripts. Compare `npm view <name>@<version> scripts --json`
     for `preinstall`, `install`, and `postinstall`. A new script is flagged.
     Do not add it to `allowBuilds` / `onlyBuiltDependencies` yourself.
4. **Group packages that move together.** Upgrade a group as one unit:
   - A package and its `@types/*` package.
   - Scope families that release together (`@tanstack/*`, `@vitest/*` with
     `vitest`, `@babel/*`, `@prisma/client` with `prisma`, `@types/react`
     with `react` and `react-dom`).
   - A package and the plugins that have a peer range on it
     (`typescript` with `typescript-eslint`).
   - The same package across every workspace. One version for the whole
     repo, unless the project already uses different versions on purpose.

## 4. Upgrade in batches

Do the safest batch first. Make one commit for each batch that passes.

1. **Batch A: all patch and minor upgrades** (not 0.x) in one step.
2. **Batch B: each major group, one at a time.** Do dev-only tooling first,
   then runtime dependencies.

For each batch:

1. **Edit the specifiers.** Change `package.json` files or the catalog. Keep
   the range operator. Then run the install command. Editing the specifier
   directly works the same way for every package manager, and gives you
   control of the exact version.
2. **Read the install output.** A new unmet-peer warning or an ignored build
   script is a failure for this batch.
3. **For a major group, read the changes before you fix anything.** Find the
   release notes or the migration guide: `gh release list` / `gh release view`
   on the source repo, `CHANGELOG.md` in the installed package, or `ctx7` docs.
   Search the code for each removed or changed API you find
   (`rg <api-name>`).
4. **Run the checks.** Use the checks from step 0, and compare the results to
   the baseline.
5. **On a new failure, decide: fix or flag.** Use
   [references/fix-or-flag.md](references/fix-or-flag.md).
   - A small fix: apply it, run the checks again, and continue.
   - A significant change: revert this batch to the last commit. Use
     `git restore --staged --worktree .`, and delete any new file the batch
     made. Then run the install again. Record the upgrade for the report and
     continue with the next batch.
   - If Batch A fails and the cause is not clear, split it. Bisect by group
     until you find the upgrade that fails. Flag or fix that one, and commit
     the rest.
6. **Commit** when all checks are back to baseline. Put the upgrade and its
   small fixes in the same commit, so that each commit builds and each commit
   can be reverted. Examples:
   - `chore(deps): update patch and minor dependencies`
   - `chore(deps): update vitest to v4`
   - `chore(deps): update typescript to v6 and typescript-eslint to v9`

   List the small fixes in the commit body.

## 5. Final checks

1. Do a clean, frozen install (`pnpm install --frozen-lockfile`, `npm ci`,
   `yarn install --immutable`, `bun install --frozen-lockfile`). The lockfile
   must agree with the manifests.
2. Run every check one more time.
3. Run the package-manager audit (`pnpm audit`, `npm audit`, `yarn npm audit`,
   `bun audit`). Report new advisories. Do not run `audit --fix`, because it
   can ignore the age gate and the batches.
4. Do not push and do not open a PR unless the user asked for it. If they ask,
   use the `write-pull-request` skill.

## 6. Report and ask

Write the report from
[references/report-template.md](references/report-template.md). It must
contain: what changed, what the gate held back (with the dates), what needs a
decision, what the project rules skipped, and the checks that failed before
you started.

Then, if there are flagged upgrades, ask the user with `AskUserQuestion`
(multi-select) which ones to do now. Put each flagged upgrade in one option.
Include its scope in the description (files, approximate lines, and the main
risk). For each one the user selects, do it as a separate batch. Use the same
loop. You can now make the significant change, but stay inside the scope that
you reported.

## Do not

- Do not loosen an age gate, remove an exclude, or add to an exclude list to
  get an upgrade in.
- Do not add `as` casts, `any`, `@ts-ignore`, `@ts-expect-error`, or
  lint-disable comments to make an upgrade pass.
- Do not skip, delete, or weaken a test. Do not change an expected value in
  an assertion. A changed expected value is a behavior change, so flag it.
- Do not update a snapshot without reading the diff. A snapshot diff that is
  more than formatting is a behavior change.
- Do not use `--force`, `--legacy-peer-deps`, or a new override to hide a
  peer conflict. Report the conflict.
- Do not approve new build scripts.
- Do not refresh transitive dependencies in the lockfile only (for example,
  `pnpm update` with no `--latest`) unless the user asks. It makes large
  lockfile diffs that are difficult to review.
