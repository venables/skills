# Fix or flag

After an upgrade breaks a check, decide whether to fix it now or flag it for
the user. Apply the fix yourself only when **every** item in "Fix it" is true.
If one item in "Flag it" is true, flag the upgrade.

## Fix it

All of these must be true:

- The change is mechanical. One correct answer exists, and the changelog,
  migration guide, or compiler error shows it.
- Runtime behavior does not change. Only names, paths, types, or config keys
  change.
- The change is small: about 10 files or fewer, and about 100 changed lines or
  fewer, not counting the lockfile.
- No test assertion changes. No expected value, snapshot content, or test
  count changes.
- The public API of the project does not change (its exports, its HTTP
  responses, its CLI flags, its peer ranges).

Typical small fixes:

- An import path or export name changed (`import { x } from "pkg/old"` to
  `"pkg/new"`).
- A type was renamed, or a type became stricter, and the fix is a correct
  type, not a cast.
- An `@types/*` update shows a real type error that the code can fix in
  place.
- A config option was renamed with the same meaning (`foo: true` to
  `fooEnabled: true`).
- A deprecated function has a drop-in replacement with the same behavior.
- A lint rule was renamed or moved to a different plugin namespace.
- An official codemod from the maintainer makes a small, mechanical change
  that obeys the size limit above. Read its diff before you keep it.
- A snapshot changed only in formatting (whitespace, a class-name hash, key
  order), and you read every line of the diff.

## Flag it

Any one of these is enough:

- **Behavior changes.** A default changed, a function returns a different
  shape, an error now throws where it did not before, the timing or ordering
  changed.
- **Large change.** More than about 10 files, more than about 100 lines, or a
  pattern you must change at many call sites by hand.
- **Design choice.** The migration has more than one correct path (for
  example, "replace X with Y or Z"), or it removes a feature the code uses
  and there is no direct replacement.
- **Config format migration.** For example, ESLint flat config, Tailwind v3 to
  v4 CSS config, a new bundler config format, or a new test-runner
  environment.
- **Runtime or platform.** It needs a newer Node, a new browser target, a new
  module system (CommonJS to ESM only), or a new build script.
- **Data or state.** It changes a database schema, a migration, a
  serialization format, a cache key, a URL, or stored data.
- **Security-sensitive area.** Auth, sessions, crypto, cookies, CORS, CSP,
  input validation. Even a small change in these areas goes to the user.
- **The check needs weakening.** The only way to pass is a cast, `any`,
  `@ts-ignore`, a lint-disable comment, a skipped test, a changed expected
  value, or a looser config.
- **Peer conflict.** Another package has a peer range that does not accept the
  new version yet.
- **Safety check failed.** The target is deprecated, lost provenance, or adds
  an install script.

## How to flag

1. Revert the batch: discard the manifest, lockfile, and code changes since the
   last commit.
2. Record:
   - The package or group, and `current -> target`.
   - What breaks, in one or two lines. Use the check output or the changelog
     entry.
   - The scope: the files and the approximate number of lines.
   - The migration guide or release-notes link.
   - Your recommendation: do it now, do it later, or wait for the ecosystem
     (for example, "wait for `typescript-eslint` to support TypeScript 7").
3. Continue with the next batch. A flagged upgrade does not stop the run.

## When you are not sure

Flag it. A flagged upgrade costs the user one decision. A wrong automatic
behavior change costs a bug in production.
