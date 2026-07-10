# Variant: CLI

STATUS: stub. Not yet implemented. Build the base first, then note to the user
that the CLI variant is not filled in yet.

Intended deltas over the base (to implement later):

- `package.json` gains a `bin` entry pointing at the built output, a `build`
  script (tsdown), and a shebang'd entry.
- Arg parsing + prompts: `citty` + `@clack/prompts`, input validated with
  `valibot`/`zod`.
- `src/index.ts` becomes the CLI entry; commands live in `src/commands/*.ts`.
- `dev` runs the entry directly; `build` bundles to `dist/index.mjs`; `start`
  runs the built binary.
