# @venables/skills

A collection of useful skills. By by [@venables](https://github.com/venables).

## Install

Install every skill in the repo:

```
npx skills add venables/skills
```

Or install a specific skill:

```
npx skills add venables/skills --skill optimize-agents-md
```

## Skills

| Skill                                             | Description                                                                                          |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [optimize-agents-md](./skills/optimize-agents-md) | Optimize your AGENTS.md (and CLAUDE.md) files according to best practices. Works with monorepos, too |

## Developing

Each skill lives at `skills/<name>/` with its `SKILL.md`. Example prompts the skill is known to handle are documented in `skills/<name>/evals/evals.json` as lightweight scenario notes.

## License

MIT
