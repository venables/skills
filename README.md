# @venables/skills

## Skills

| Skill                                                                                               | Description                                                                                                                                                                                                                                |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [panel-review-loop](./skills/panel-review-loop)                                                     | Autonomously loop the review-fix-rereview cycle around `panel-review` — judge which findings are worth fixing, fix them, re-review, repeat until clean, then report what was fixed, what was left alone (and why), and any goal deviations |
| [pr-comment-handler](./skills/pr-comment-handler)                                                   | Read every open review comment on a PR, classify each as fix / push-back / defer-to-Linear, drive the work, then post the right reply on each thread (including `Fixed in <sha>` replies on push)                                          |
| [post-panel-review-comments](./skills/post-panel-review-comments)                                   | Triage findings from a `panel-review` into PR inline comments and Linear tickets via a two-stage select list (auto-falls back to a top-level comment when GitHub rejects an inline)                                                        |
| [optimize-agents-md](https://github.com/catena-labs/dev-skills/tree/main/skills/optimize-agents-md) | Optimize your AGENTS.md (and CLAUDE.md) files according to best practices. Works with monorepos, too                                                                                                                                       |
| [panel-review](https://github.com/catena-labs/dev-skills/tree/main/skills/panel-review)             | Fan a code review out to multiple local CLI agents (codex, claude, opencode) in parallel and amalgamate their findings                                                                                                                     |

The catena-labs links above point to skills that have moved to [catena-labs/dev-skills](https://github.com/catena-labs/dev-skills).

## License

MIT
