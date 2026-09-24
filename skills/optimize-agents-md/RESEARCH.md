# Research notes for optimize-agents-md

_Last verified: 2026-09-23. Previous revision: 2026-05-11._

Background findings that inform the skill. Bullets are facts, not advice. The
SKILL.md is where advice lives. Sources are linked inline. Anthropic docs, blog
posts, and the Claude Code changelog are primary. Talks and posts by Anthropic
staff are primary for what they say and secondary for numbers reported by
others. Community posts (Medium, Substack, Dev.to, HN) vary in rigor; weight
them below primary sources.

## What changed between May and September 2026

- **Anthropic cut over 80% of Claude Code's system prompt for Claude 5
  generation models.** "We removed over 80% of Claude Code's system prompt for
  models like Claude Opus 5 and Claude Fable 5 with no measurable loss on our
  coding evaluations." "Overall, we found that we were overconstraining Claude
  Code, both through our system prompt and in our CLAUDE.md files and skills."
  The cut is to the system prompt. No one on the team has published a CLAUDE.md
  line count. (source: Thariq Shihipar,
  [The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models),
  Anthropic blog, 2026-07-24)
- **Claude Code reads AGENTS.md natively since v2.1.277 (2026-09-18).** "In a
  project with no CLAUDE.md, Claude Code reads AGENTS.md instead." (source:
  [Claude Code CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md),
  [memory docs, AGENTS.md section](https://code.claude.com/docs/en/memory#agents-md))
- **The official length ceiling is explicit: under 200 lines per file.** "Files
  over 200 lines consume more context and may reduce adherence." (source:
  [memory docs](https://code.claude.com/docs/en/memory))
- **`/doctor` proposes CLAUDE.md trims** (v2.1.206+, July 2026). It "cuts
  content Claude can derive from the codebase, such as directory layouts,
  dependency lists, and architecture overviews, and keeps pitfalls, rationale,
  and conventions that differ from tool defaults." (source:
  [memory docs](https://code.claude.com/docs/en/memory#my-claude-md-is-too-large),
  [Week 28](https://code.claude.com/docs/en/whats-new/2026-w28))
- **Auto memory is on by default** and Claude "skips anything your CLAUDE.md
  files already say." The `#` hotkey no longer writes to CLAUDE.md. (source:
  [memory docs](https://code.claude.com/docs/en/memory#auto-memory), Anthropic
  blog above)
- **Anthropic's model pages tell you to delete instructions written for older
  models.** Verification reminders, self-check lines, anti-formatting rules,
  anti-laziness prompting, and example lists now cause over-verification or
  literal over-compliance. See "Model-generation effects" below.

## Anthropic's six shifts (primary source)

All from
[The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models)
(Thariq Shihipar, 2026-07-24; announced on X at
[trq212/2080710971228918066](https://x.com/trq212/status/2080710971228918066)
and retweeted by Boris Cherny):

- **Rules become judgment.** Old system prompt: "In code: default to writing no
  comments. Never write multi-paragraph docstrings or multi-line comment blocks
  — one short line max." Replacement: "Write code that reads like the
  surrounding code: match its comment density, naming, and idiom." Rationale:
  "newer models have better judgement and can handle these decisions well
  without explicit rules." The old rule existed because "without these
  guardrails for older models, the comments Claude wrote would be incorrect in
  many cases."
- **Examples become interface design.** Usage examples constrained exploration;
  well-designed parameters guide behavior without limiting it.
- **Upfront information becomes progressive disclosure.** Detailed guidance
  moves into skills Claude retrieves when relevant, or deferred-loading tools.
- **Repetition becomes simple tool descriptions.** Instructions duplicated
  across the system prompt and tool descriptions get consolidated.
- **Manual CLAUDE.md memory becomes auto memory.** "We used to encourage users
  to save things to Claude's memory, by using the # hotkey to write to their
  CLAUDE.md automatically. Instead, Claude now automatically saves memories that
  are relevant to the work and to you."
- **Simple specs become rich references.** Code, test suites, HTML artifacts,
  and rubrics give clearer guidance than prose descriptions.
- **On CLAUDE.md:** "Keep your CLAUDE.md lightweight and briefly describe what
  your repo is for, but spend most of the tokens on gotchas inside of the
  codebase." "Avoid stating 'the obvious' things Claude should know by looking
  at your file system or your repo." "Use progressive disclosure heavily, for
  example if you have several unique instructions on how to verify your work,
  create a verification skill and reference it from your CLAUDE.md."
- **On skills:** "Think of skills as lightweight guides to let Claude find
  information when needed. Avoid making them overconstrained, except in highly
  important areas."
- **On contradictions:** reading internal transcripts, the team saw "conflicting
  messages in a single request like 'leave documentation as appropriate,' or 'DO
  NOT add comments' as our system prompt, skills, and user requests clash with
  each other."
- **Closing:** "Across your system prompt, skills, and CLAUDE.md files, you may
  need to simplify just like we did. We rolled out a new command called
  `claude doctor`, which will help you do this automatically as well."

## Claude Code team statements

- **Cat Wu and Thariq Shihipar, fireside chat with Simon Willison, AI Engineer
  World's Fair, 2026-07-21.** Thariq: "The system prompt for Claude Code has
  been reduced by 80% because of Claude Fable." "We were over-constraining
  Claude. The initial, maybe Opus 4-ish models wanted a lot of examples, and
  removing examples was extremely helpful." Fewer "do not do this" instructions,
  because such constraints "can be extremely confusing to Claude." Cat: the
  reduction applies only to frontier models; older models keep the full prompt.
  Cat: "we found a few cases where yes, this statement is 90% true, but there's
  a real 10% of cases where it's not true." Verification guidance moved from
  "always verify, verify, verify" to situational wording. Simon's summary:
  "Adding examples to a system prompt is no longer best practice for models like
  Fable 5 or even Opus 4.8... lists of 'don't do X and don't do Y' can reduce
  the quality of output." (source:
  [simonwillison.net](https://simonwillison.net/2026/Jul/21/cat-and-thariq/))
- **Boris Cherny, YC Startup School 2026 with Diana Hu, recorded the day after
  Opus 5 shipped (about 2026-07-25).** "Every time that a new model comes out,
  we delete a bunch of the system prompt." "Opus 5 is just really intelligent. A
  lot of the stuff in the system prompt was correcting for these behaviors that
  the model should have known, but it didn't. Now Opus 5 just does it." "For
  people that aren't building agentic products, but are using Claude Code, every
  six months, delete your CLAUDE.md, delete your skills, delete your hooks. See
  what the model does and it might surprise you." On rebuilding: "The first step
  is you delete. The next step is you use it. Only when you see it repeatedly
  stumble on the same thing, that's when you add it back. But you don't want to
  do it too early." "Remember, the model is going to read this instruction every
  single time you use it. You really want to make sure that the model needs this
  instruction." "Something that you did for one model maybe three months ago, it
  just might not translate at all to the next model." Method: "in research, we
  call this ablation." (source:
  [YouTube](https://www.youtube.com/watch?v=qyPCVqFUyDo),
  [YC library](https://www.ycombinator.com/library/UN-boris-cherny-building-claude-code);
  quotes from auto-transcripts at
  [ycrootaccess](https://www.ycrootaccess.com/p/boris-cherny-building-claude-code)
  and [Reporails](https://reporails.com/articles/opus-5-delete-your-claudemd))
- **Thariq Shihipar on Peter Yang's podcast, about 2026-07-19.** "As the models
  have gotten smarter, they need less direction, fewer constraints, and fewer
  examples. The examples are constraining it because now it's like, 'Oh, you
  want things like this example.'" Episode takeaway: "When a better AI model is
  released, the first thing you should try is to remove instructions." (source:
  [creatoreconomy.so](https://creatoreconomy.so/p/how-i-plan-build-and-run-loops-with-claude-code-thariq-shihipar))
- **Word counts, secondhand.** Reports from the July talks put the system prompt
  at roughly 2,686 words before and roughly 514 after with memory disabled, near
  830 with memory enabled; some instructions were made conditional rather than
  deleted. A third-party prompt tracker shows no single visible drop because
  Claude Code ships different system prompts per model. Treat the numbers as
  unverified. (source:
  [AgentConn](https://agentconn.com/blog/claude-code-system-prompt-reduction-harness-audit-2026/),
  [Piebald tracker](https://github.com/Piebald-AI/claude-code-system-prompts))
- **Why Anthropic held out on AGENTS.md (Thariq, 2026-08-25, replying to
  Shopify's CEO):** "we don't think that model families are interchangeable and
  the system prompt can have a big impact on performance... In Claude Code we
  have different system prompts per model." "In the immediate term, you can
  always @Agents.MD from your Claude.MD." Native support landed 24 days later.
  (source:
  [trq212/2092302273099796842](https://x.com/trq212/status/2092302273099796842),
  quoted in [HN 49760187](https://news.ycombinator.com/item?id=49760187))
- **AGENTS.md support announcement (Thariq, 2026-09-18):** "if there is no
  CLAUDE.md in a folder, Claude will check for and use AGENTS.md. You can toggle
  this behavior in /config." Built as a Claude Code "mod"; source at
  `mods/agents-md` in the claude-code repo. (source:
  [trq212/2101009392611278961](https://x.com/trq212/status/2101009392611278961),
  mirrored at
  [simonwillison.net](https://simonwillison.net/2026/Sep/18/thariq-shihipar/))
- **Boris Cherny, 2026-09-11:** "If Claude's code doesn't meet the bar, try:
  Using the latest frontier model (Opus 5 or Fable 5.1). Increase effort to high
  or xhigh. Invest in your CLAUDE.md and skills to succinctly teach Claude how
  to work in your codebase." (source:
  [bcherny/2098217573276131577](https://x.com/bcherny/status/2098217573276131577))
- **Not found:** any statement of the form "we cut our CLAUDE.md to N lines."
  Boris's last public CLAUDE.md size (about 2.5k tokens) is from January 2026.
- **Counter-evidence on the 80%, all secondhand.** One extraction of shipped
  prompt strings put the per-model system prompt at 15,225 characters for Opus
  4.7, 4,467 for Opus 4.8, and 7,694 for Opus 5, which would place most of the
  cut at the 4.7 to 4.8 step and show growth again for Opus 5. Another analysis
  argues Opus 5 "needs more instructions, not fewer." Anthropic has not
  published the evals behind "no measurable loss." (sources: Chen Cheng via
  [KuCoin](https://www.kucoin.com/news/flash/anthropic-adds-agents-md-support-to-claude-code),
  2026-07-27; Pawel Huryn, Product Compass, 2026-08-10, paywalled)

## Model-generation effects on instruction files

Anthropic's model pages say to remove instructions that compensated for older
models, and to add a few specific lines for newly observed behaviors.

- **Fable 5:** "Capability improvements at this level are also a good prompt to
  re-evaluate which instructions, tools, and guardrails are still needed."
  "Instruction-following is improved enough that you can steer most behaviors
  with a brief instruction rather than enumerating each behavior by name."
  "Skills developed for prior models are often too prescriptive for Claude Fable
  5 and can degrade output quality. Review and consider removing older
  instructions if default performance is better." "Give the reason, not only the
  request." (source:
  [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5))
- **Fable 5.1:** "Earlier models overused bullets and bold in chat, and many
  prompts carry anti-formatting rules written to hold that down. Claude Fable
  5.1 leans the other way... If your prompt contains anti-formatting language,
  remove it." "Some earlier models were eager to give updates while working,
  which led to system prompt lines such as 'hold all findings for the final
  response.' Remove lines like that before adding anything." The same page
  recommends adding short lines for tool-call batching, targeted edits, and
  scope. (source:
  [Prompting Claude Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1))
- **Opus 5:** "Claude Opus 5 verifies its own work without being told to. If
  your prompt contains explicit verification instructions... remove them:
  instructions like these cause over-verification." "Avoid instructing re-checks
  it already performs ('double-check your answer')." "If your review prompt says
  'only report high-severity issues' or 'be conservative,' the model may follow
  that instruction literally." "Positive examples of the communication style you
  want tend to be more effective than instructions about what not to do." Opus 5
  runs longer by default, so the guide says to add a conciseness line. (source:
  [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5),
  [Opus 5 migration guide](https://platform.claude.com/docs/en/models/opus-5/migration-guide):
  "remove verification and self-check instructions carried over from prompts
  tuned for earlier models")
- **Opus 5.5 (2026-09-22):** "Re-evaluate model-specific prompt instructions.
  Instructions tuned for Claude Opus 5's behavior may no longer be needed."
  "Remove instructions that stood in for thinking." (source:
  [Opus 5.5 migration guide](https://platform.claude.com/docs/en/models/opus-5-5/migration-guide))
- **Claude Code, "Work with Fable":** "Describe the outcome, not the steps."
  "Skip the verification reminders: it verifies its own work with less
  prompting, so reminders to test or check are usually unnecessary." (source:
  [Model configuration](https://code.claude.com/docs/en/model-config#work-with-fable))
- **All current models:** "Tune anti-laziness prompting: If your prompts
  previously encouraged the model to be more thorough or use tools more
  aggressively, dial back that guidance." "Where you might have said 'CRITICAL:
  You MUST use this tool when...', you can use more normal prompting like 'Use
  this tool when...'." (source:
  [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices))
- **Compensation vs context.** The clearest framing of what survives: the
  delete-and-observe test is "a sorting test." Lines that compensate for a
  weaker model (verification prompts, conservative hedges, coaching for basic
  behaviors) rot on each release. Lines that encode project context (protected
  paths, project-specific naming, deterministic gates, test patterns unique to
  the codebase) do not, and the model "will never independently learn your
  naming conventions or which of your three services owns billing." (source:
  Gábor Mészáros,
  [Opus 5: Delete your CLAUDE.md?](https://reporails.com/articles/opus-5-delete-your-claudemd),
  2026-08-06)

## Instruction budget and length

- **Official:** "target under 200 lines per CLAUDE.md file." "Keep it concise.
  For each line, ask: 'Would removing this cause Claude to make mistakes?' If
  not, cut it. Bloated CLAUDE.md files cause Claude to ignore your actual
  instructions!" "Shorter files produce better adherence." (source:
  [memory docs](https://code.claude.com/docs/en/memory#write-effective-instructions),
  [best practices](https://code.claude.com/docs/en/best-practices#write-an-effective-claude-md))
- **Named failure pattern:** "The over-specified CLAUDE.md. If your CLAUDE.md is
  too long, Claude ignores half of it because important rules get lost in the
  noise. Fix: Ruthlessly prune. If Claude already does something correctly
  without the instruction, delete it or convert it to a hook." (source:
  [best practices](https://code.claude.com/docs/en/best-practices#avoid-common-failure-patterns))
- **Anthropic's own example CLAUDE.md in the docs is seven lines.** (source:
  [best practices](https://code.claude.com/docs/en/best-practices#write-an-effective-claude-md))
- **Official include/exclude table.** Include: Bash commands Claude can't guess;
  code style rules that differ from defaults; testing instructions and preferred
  runners; repository etiquette; architectural decisions specific to the
  project; developer environment quirks; common gotchas. Exclude: anything
  Claude can figure out by reading code; standard language conventions; detailed
  API documentation; information that changes frequently; long explanations;
  file-by-file descriptions; self-evident practices. (source:
  [best practices](https://code.claude.com/docs/en/best-practices#write-an-effective-claude-md))
- **When to add a line:** "Claude makes the same mistake a second time. A code
  review catches something Claude should have known about this codebase. You
  type the same correction or clarification into chat that you typed last
  session." (source:
  [memory docs](https://code.claude.com/docs/en/memory#when-to-add-to-claude-md))
- **Emphasis:** "If Claude keeps skipping one instruction, add emphasis such as
  'IMPORTANT' to that line alone. If you emphasize many lines, none of them
  stands out." Claude Academy: "Treat emphasis like a budget. Spend it on the
  two or three rules that really hurt when they get broken." "The leaner the
  file, the more of it Claude actually follows." (source:
  [best practices](https://code.claude.com/docs/en/best-practices#write-an-effective-claude-md),
  [Claude Academy](https://academy.claude.com/courses/claude-code-in-action/a-claude-md-that-follows))
- **Adherence failure diagnosis:** "Adherence drops when an instruction is vague
  enough to interpret multiple ways, when two files give conflicting direction,
  or when the file has grown long enough that individual rules get less
  attention." (source:
  [Debug your configuration](https://code.claude.com/docs/en/debug-your-config))
- **The only controlled study of CLAUDE.md structure found no size effect.**
  1,650 Claude Code sessions and 16,050 function-level observations on Sonnet
  4.6 (primary), Opus 4.6, and Opus 4.7. File size at 25, 100, 250, and 500
  lines: no effect (Bayes factor 0.05-0.10 supports the null). Rule position
  (top, quarter, middle, three-quarter, bottom of a 250-line file): no
  detectable effect; structural effects above about 6 percentage points are
  ruled out. Single CLAUDE.md vs added AGENTS.md vs nested per-directory files:
  no effect. A conflicting AGENTS.md counter-instruction: no effect. What did
  show up: within-session decay, "each additional function the agent generates
  is associated with approximately 5.6% lower odds of compliance per step (OR =
  0.944)," non-monotonic, replicated on a second codebase. Identified during
  analysis, not pre-specified. Not run on Claude 5 models. (source: Damon
  McMillan, [arXiv 2605.10039](https://arxiv.org/abs/2605.10039), 2026-05-11)
- **What the size evidence supports.** Anthropic's 200-line ceiling and "shorter
  files produce better adherence" are stated without published data. McMillan
  found no size effect up to 500 lines on 4.6-generation models. The measured
  case for cutting rests on cost, on contradictions (which the Anthropic post
  and the memory docs both flag), and on compensation lines that mislead newer
  models, not on line count alone.
- **Practitioner claim, not measured:** frontier LLMs reliably follow about
  150-200 instructions per session, with Claude Code's system prompt consuming
  about 50. HumanLayer's reading of
  [arXiv 2507.11538](https://arxiv.org/abs/2507.11538), which reports 68%
  compliance at 500 instructions and a bias toward earlier instructions but
  never states 150-200. The post itself says the figure "hasn't been
  investigated in an incredibly rigorous manner." The 50-slot half predates the
  80% cut. (source:
  [HumanLayer](https://www.humanlayer.dev/blog/writing-a-good-claude-md),
  critique by [Zander Martineau](https://zander.wtf/blog/claude-md-agents-md/))
- **Anecdote, misattributed in the May revision:** "95%+ at messages 1-2, 20-60%
  by messages 6-10" originates in a July 2025 Dev.to post by Siddhant Khare with
  no method; Wiegold quoted it. Decay is real (McMillan above); the curve is not
  supported. (source:
  [Khare](https://dev.to/siddhantkcode/an-easy-way-to-stop-claude-code-from-forgetting-the-rules-h36),
  [Wiegold](https://thomas-wiegold.com/blog/claude-md-helpful-or-expensive-noise/))
- **Tool-specific instructions are followed far more often.** "uv is used 1.6
  times per instance on average when mentioned in the context files, compared to
  fewer than 0.01 times when it is not mentioned." The 160x figure is a derived
  lower bound. Repository-specific tools: 2.5 vs fewer than 0.05. (source:
  Gloaguen et al., ETH Zurich,
  [arXiv 2602.11988](https://arxiv.org/abs/2602.11988), v2 2026-06-23, benchmark
  renamed CTXbench)
- **Context files and task success: small or null.** Same ETH study, v2:
  LLM-generated files change resolve rate by -0.5% (SWE-bench) and -2%
  (CTXbench); developer-written files +2.4% on average (p=0.21, not
  significant); developer-written beats LLM-generated at p=0.038; cost +20% or
  more. An independent two-agent ablation (Claude Code and Codex, 17 real tasks,
  288 runs) found "context strategy does not measurably move correctness on
  either agent"; failures were "implementation gaps rather than missing
  repository knowledge." (sources: ETH v2 above; Prakhar Khatri,
  [arXiv 2607.27250](https://arxiv.org/abs/2607.27250), 2026-07-28)
- **Guidance quality moves the needle when it is tuned.** Probe-and-refine
  guidance reached 33.0% resolve rate vs 28.3% for a static knowledge base and
  25.5% unguided (p<0.001). (source: Shepard and Albrecht,
  [arXiv 2606.20512](https://arxiv.org/abs/2606.20512), 2026-06-18)
- **Observational, mixed:** across 15,549 agentic PRs in 148 projects, after
  adding instruction files "27.7% of the projects increased their merge rate by
  at least 20%, while 26.35% decreased it." Improvers "have substantially longer
  instruction files, which are also well structured." (source: Arabat and
  Sayagh, [arXiv 2606.13449](https://arxiv.org/abs/2606.13449), MSR 2026)
- **Efficiency:** with a context file, Codex runs took -28.64% median runtime
  and -16.58% output tokens at comparable completion. (source: Lulla et al.,
  [arXiv 2601.20404](https://arxiv.org/abs/2601.20404))
- **Specificity data:** across about 30,000 public repos, 27% of
  instruction-file content is actionable rules and 73% is scaffolding; 89.9% of
  configs carry at least one rule that never names its subject ("keep the code
  clean"). Specific rules ("Format with ruff format before committing") show
  about 11x the compliance odds of vague equivalents. (source:
  [Reporails](https://reporails.com/articles/opus-5-delete-your-claudemd))
- **Configuration smells:** in 100 repos with AGENTS.md or CLAUDE.md, "Lint
  Leakage was the most common smell, affecting 62% of the files, followed by
  Context Bloat (42%) and Skill Leakage (35%)"; 91 of 100 had at least one
  smell. (source: dos Santos et al.,
  [arXiv 2606.15828](https://arxiv.org/abs/2606.15828), SCAM 2026)
- **Cross-repo duplication, corrected:** the "28.7% duplicated lines" figure in
  arXiv 2512.18925 is copy-paste duplication across repositories (templates),
  not redundancy with the codebase. The May revision misread it. (source:
  [arXiv 2512.18925](https://arxiv.org/pdf/2512.18925))
- **Context files grow and are rarely pruned.** Claude Code files add a median
  57.0 words per commit with deletions under 15 words. A larger study of 247,694
  instruction lifetimes across 1,867 repos: prompts grow +226% over their
  lifetime, +4.9 net instructions per commit, and older instructions are less
  likely to be deleted. In controlled runs, annotating each rule with why it
  exists ("prompt comments") removed 99.3% of excess instructions and raised
  instruction-following by up to 23.1%. Stale code references appear in 23.0% of
  356 repos. (sources: [arXiv 2511.12884](https://arxiv.org/html/2511.12884v1);
  Kushal Chakrabarti, [arXiv 2608.11095](https://arxiv.org/abs/2608.11095),
  2026-08-11; Treude and Baltes,
  [arXiv 2606.09090](https://arxiv.org/abs/2606.09090))
- **TechLoom benchmark of 1,188 runs** (Haiku 4.5, Sonnet 4.6, Opus 4.6): "The
  quality spread across all five profiles is 0.6 points on a 100-point scale";
  model-to-model spread was 2.5 points. Instructions "act as guardrails, not
  boosters." Not re-run on Claude 5. (source:
  [TechLoom](https://techloom.it/blog/claudemd-benchmark-results), URL changed
  from the `.html` form)
- **Instruction files are the documentation agents actually read.** "Instruction
  files and working notes account for 60.5% of all documentation interactions,
  versus 10.6% for classical technical documentation." (source: Gao and Chen,
  [arXiv 2608.20195](https://arxiv.org/abs/2608.20195))

## Structure and formatting

- **Official:** "use markdown headers and bullets to group related instructions.
  Claude scans structure the same way readers do." Write instructions "concrete
  enough to verify": "Run `npm test` before committing" instead of "Test your
  changes." (source:
  [memory docs](https://code.claude.com/docs/en/memory#write-effective-instructions))
- **Consistency:** "if two rules contradict each other, Claude may pick one
  arbitrarily. Review your CLAUDE.md files, nested CLAUDE.md files in
  subdirectories, and .claude/rules/ periodically." (source: same)
- **End-of-prompt reminders are endorsed only for long system prompts.** "In a
  long system prompt, pair the instruction with a short reminder near the end of
  the prompt." This is the only primary support for recency anchoring. (source:
  [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5#response-length-and-verbosity))
- **Primacy/recency duplication (repeat the top rules at the start and end)**
  came from a Dev.to post by Shane Ho, not Anthropic, and is contradicted by the
  McMillan study above: rule position from line 2 to line 250 of a 250-line file
  made no detectable difference. Duplication inside a short file also conflicts
  with "emphasize that line alone." (sources:
  [docat0209](https://dev.to/docat0209/5-patterns-that-make-claude-code-actually-follow-your-rules-44dh);
  [arXiv 2605.10039](https://arxiv.org/abs/2605.10039))
- **Practitioner claims, not re-verified:** commands in code fences get followed
  and commands in prose get buried; one instruction per bullet; stripping
  Markdown decoration hurts smaller models. (sources:
  [cleverhoods](https://dev.to/cleverhoods/-claudemd-best-practices-7-formatting-rules-for-the-machine-3d3l),
  [TechLoom](https://techloom.it/blog/claudemd-benchmark-results.html))
- **Three-line constraint format** for a rule that must stay negative: an
  imperative naming the exact construct, one line of reasoning, then the
  prohibition phrased at category level with named APIs last, to avoid anchoring
  the model on the ban. (source:
  [Reporails](https://reporails.com/articles/opus-5-delete-your-claudemd))

## Tone

- **Give the reason.** "Providing context or motivation behind your
  instructions... can help Claude better understand your goals." "NEVER use
  ellipses" is less effective than explaining the text will be read aloud by a
  text-to-speech engine. "Claude is smart enough to generalize from the
  explanation." (source:
  [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices#add-context-to-improve-performance))
- **Positive examples beat prohibitions** for communication style on Opus 5, and
  "don't do X" lists "can be extremely confusing" per Thariq. (sources above)
- **Literal instruction following** is a documented risk: hedges like "be
  conservative" get followed literally. (source:
  [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5#capability-improvements))
- **Imperative for behaviors, declarative for facts.** Practitioner pattern. The
  earlier claim that imperative facts ("YOU MUST use bun") trip prompt-injection
  defenses was not re-verified in this pass. (source:
  [rahuulmiishra](https://rahuulmiishra.medium.com/your-claude-md-is-doing-too-much-heres-how-to-fix-it-2cc495ed3599))
- **Positive framing cut violations roughly in half** for one practitioner who
  flipped 10 negative rules. Anecdote with no method; no controlled test of
  framing in config files exists. (source:
  [docat0209](https://dev.to/docat0209/5-patterns-that-make-claude-code-actually-follow-your-rules-44dh))
- **Prose "do not" rules are a write-only channel for security.** Across 481
  config files, only 4-16% of security "do not" rules had a matching built-in
  control (4.4% under a strict match). (source: Ting Yan,
  [arXiv 2608.23550](https://arxiv.org/abs/2608.23550), 2026-08-24)
- **Rationale drives process compliance.** In a general (not repo-file) study
  across six models, process-instruction compliance was 0% by default and 97%
  when the rationale was rewarded. (source: Shin,
  [arXiv 2605.01771](https://arxiv.org/abs/2605.01771), 2026-05-03)

## How CLAUDE.md loads

- **Delivered as a user message, not the system prompt.** "CLAUDE.md content is
  delivered as a user message after the system prompt, not as part of the system
  prompt itself." (source:
  [memory docs](https://code.claude.com/docs/en/memory#claude-isnt-following-my-claude-md))
- **Wrapper text, observed in a live v2.1.280 session on 2026-09-23:** CLAUDE.md
  content arrives inside a `<system-reminder>` that reads "Codebase and user
  instructions are shown below. Be sure to adhere to these instructions.
  IMPORTANT: These instructions OVERRIDE any default behavior and you MUST
  follow them exactly as written." The phrase "this context may or may not be
  relevant to your tasks" wraps the git-status block, not the instruction files.
  Undocumented and may change. This corrects the earlier HumanLayer-sourced
  claim that CLAUDE.md is marked optional.
- **Hierarchy (load order, broadest to narrowest):** managed policy → user
  (`~/.claude/CLAUDE.md`) → project (`./CLAUDE.md` or `./.claude/CLAUDE.md`) →
  local (`./CLAUDE.local.md`, gitignored). All files concatenate; nothing
  overrides. (source: [memory docs](https://code.claude.com/docs/en/memory))
- **Subdirectory files load lazily:** "included when Claude reads files in those
  subdirectories." Not at launch, and not when writing or creating files there.
  (source:
  [Debug your configuration](https://code.claude.com/docs/en/debug-your-config))
- **Files over 4 MiB are skipped.** (source:
  [memory docs](https://code.claude.com/docs/en/memory))
- **`claudeMdExcludes`** skips files by absolute-path glob; settable at any
  settings layer; arrays merge. Managed policy files cannot be excluded.
  (source: [memory docs](https://code.claude.com/docs/en/memory))
- **Imports:** `@path` expands at launch, max depth four hops, relative to the
  importing file. Backticks around `@path` suppress the import. External imports
  prompt for approval once per project. "Splitting into @path imports helps
  organization but doesn't reduce context, since imported files load at launch."
  (source:
  [memory docs](https://code.claude.com/docs/en/memory#import-additional-files))
- **HTML comments are stripped.** "Block-level HTML comments in CLAUDE.md files
  are stripped before the content is injected into Claude's context... Comments
  inside code blocks are preserved." (source:
  [memory docs](https://code.claude.com/docs/en/memory#how-claude-md-files-load))
- **Compaction:** project-root CLAUDE.md and unscoped rules are re-injected from
  disk; nested files and path-scoped rules reload as matching files are read.
  Measured: facts held only in conversation "vanish at the first summary and
  stay absent from 106 of 108 compactions," while harness-injected facts "arrive
  intact through all 138 compact-resumes." (sources:
  [Context window](https://code.claude.com/docs/en/context-window#what-survives-compaction);
  Saha, [arXiv 2607.20972](https://arxiv.org/abs/2607.20972), 2026-07-23)
- **Built-in Explore and Plan subagents skip CLAUDE.md.** Custom subagents load
  it unless they set `omitClaudeMd`. (source:
  [Debug your configuration](https://code.claude.com/docs/en/debug-your-config))

## AGENTS.md in Claude Code (v2.1.277+)

All from the
[memory docs, AGENTS.md section](https://code.claude.com/docs/en/memory#agents-md)
unless noted.

- **Default rule:** Claude reads `AGENTS.md` only when there is no `CLAUDE.md`,
  `.claude/CLAUDE.md`, or `CLAUDE.local.md` in the working directory or any
  directory above it. `~/.claude/CLAUDE.md`, managed CLAUDE.md, and
  `.claude/rules/` do not count and keep loading alongside.
- **What loads when AGENTS.md is active:** every `AGENTS.md` and
  `.claude/AGENTS.md` in the working directory and above at session start; a
  subdirectory's `AGENTS.md` when Claude reads a file there and that
  subdirectory has no CLAUDE.md of its own. `@path` imports expand and
  `claudeMdExcludes` apply. Not read: `AGENTS.local.md`, `AGENTS.override.md`,
  anything under `.agents/`.
- **Nested-file gotcha:** the lazy loading of subdirectory `AGENTS.md` files is
  listed under "When none count," so a root `CLAUDE.md` of any size, including a
  one-line `@AGENTS.md` import, switches the whole tree to CLAUDE.md-only mode
  under the default setting. Nested `AGENTS.md` files are then skipped unless
  each has a sibling `CLAUDE.md` that imports it.
- **Project instructions setting** (`/config`): `claude-md-or-agents-md`
  (default), `claude-md-and-agents-md` (both, each directory's CLAUDE.md first;
  an AGENTS.md already imported or symlinked is not read twice), `claude-md`,
  `managed-only`. In settings files it lives under
  `pluginConfigs["agents-md@builtin"].options.instructionFiles` and is honored
  only in user, `--settings`, or managed settings. "Claude Code ignores it in
  project and local settings files." A repo cannot commit the both-files mode
  for its contributors.
- **Unavailable:** before v2.1.277; sessions that don't fetch feature flags
  (Amazon Bedrock, other third-party providers, telemetry disabled); the first
  session after install or upgrade; the built-in `agents-md` plugin disabled.
  Changelog adds: not yet on Bedrock, Vertex, or Foundry.
- **Differences from CLAUDE.md:** `InstructionsLoaded` hooks do not fire for a
  directly-read AGENTS.md (they do for one imported or symlinked from a
  CLAUDE.md); `--add-dir` directories' AGENTS.md don't load; external `@path`
  imports load without a prompt only if already approved.
- **Migrating earlier workarounds (official):** a `CLAUDE.md` containing
  `@AGENTS.md` can stay ("Keeping the import never makes Claude read AGENTS.md
  twice"); remove it if it holds nothing else, or keep it for sessions that
  can't load AGENTS.md directly. A `CLAUDE.md` that tells Claude in prose to
  read AGENTS.md should be deleted or replaced with the import. A symlinked
  `CLAUDE.md`: leave it or delete it. A `SessionStart` hook that prints
  AGENTS.md: remove it, or Claude gets a second copy.
- **Symlink constraints (official):** the Edit and Write tools refuse to write
  through a symlink and redirect Claude to the target; on Windows a committed
  symlink checks out as a one-line text file unless `core.symlinks` is on, and
  creating one needs Administrator or Developer Mode. The docs recommend the
  import form whenever anyone on the team uses Windows.
- **Verification:** `/memory` and `/context` list a directly-read AGENTS.md from
  v2.1.280. An interactive session prints
  `no CLAUDE.md found; AGENTS.md loaded: <path>`.
- **`/init` and `/import`:** with `CLAUDE_CODE_NEW_INIT=1`, `/init` reads
  AGENTS.md, `.devin/rules/`, `.windsurf/rules/`, and `.clinerules` into the
  generated CLAUDE.md. `/import` (v2.1.213+) "appends a one-time copy of
  instruction files such as AGENTS.md to the matching CLAUDE.md." Both can leave
  a CLAUDE.md that duplicates AGENTS.md verbatim. (source:
  [memory docs](https://code.claude.com/docs/en/memory#migrate-instructions-from-other-tools))
- **Community caveat:** native support does not cover `.agents/skills`. (source:
  [HN 49760187](https://news.ycombinator.com/item?id=49760187))

## The AGENTS.md standard

- Stewarded by the Agentic AI Foundation under the Linux Foundation (formed
  2025-12-09). The site lists about two dozen tools with native support and
  "over 60k open-source projects," a figure unchanged since late 2025. Claude
  Code is not yet listed on the site. Nested precedence: "the closest AGENTS.md
  to the edited file wins; explicit user chat prompts override everything." No
  content or length rules: "AGENTS.md is just standard Markdown." OpenAI's main
  repo has 88 AGENTS.md files. (source: [agents.md](https://agents.md/),
  [Linux Foundation](https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation))
- The Claude Code feature request for AGENTS.md
  ([gh #6235](https://github.com/anthropics/claude-code/issues/6235), opened
  2025-08-21, 5,182 thumbs-up) closed on 2026-08-17.
- **Adoption:** a September 2026 sample of active GitHub repos (pushed in the
  last 90 days) found 6.2% with AGENTS.md, 5.4% with CLAUDE.md, 1.1% with
  copilot-instructions, and 0.7% with cursor rules; 1.0% of all public repos
  have an AGENTS.md. Among the top 1,000 starred repos, 27% have a root
  AGENTS.md; the top-100 median is 1,198 words, 90% use must/always/never, 86%
  have explicit don't-rules, and 37% exceed 1,500 words. (sources:
  [Janz](https://dev.to/janzong/how-common-is-agentsmd-really-i-sampled-github-62-of-active-repos-10-of-all-repos-1175),
  2026-09-19;
  [Coldtea field study](https://www.coldtea.ai/blog/agents-md-field-study),
  2026-08-21)

## `.claude/rules/`

- **`paths` is the only frontmatter field.** "`paths` is the only field Claude
  Code reads from a rule; any other field is ignored without an error." The
  `priority:` field mentioned in earlier community posts does not exist. Rules
  without `paths` load at launch with the same priority as `.claude/CLAUDE.md`.
  (source:
  [memory docs](https://code.claude.com/docs/en/memory#rules-frontmatter-reference))
- **Path-scoped rules trigger on Read**, not on every tool use. Brace expansion
  shares a budget of 1,000 expanded patterns and 4 MiB per rule. (source:
  [memory docs](https://code.claude.com/docs/en/memory#path-specific-rules))
- **User-level `~/.claude/rules/` with `paths:` works.** The bug
  ([gh #21858](https://github.com/anthropics/claude-code/issues/21858)) was
  closed on 2026-03-24; root cause was a CSV parser applied to a YAML list. The
  "project level only" workaround is obsolete.
- **User rules load before project rules;** neither overrides the other.
  (source:
  [memory docs](https://code.claude.com/docs/en/memory#user-level-rules))
- **Official split:** rules for language- or directory-specific guidelines;
  CLAUDE.md for core conventions and build commands; skills for content needed
  only sometimes. (source:
  [Extend Claude Code](https://code.claude.com/docs/en/features-overview))

## Skills and progressive disclosure

- **When a CLAUDE.md section becomes a skill:** "when a section of CLAUDE.md has
  grown into a procedure rather than a fact. Unlike CLAUDE.md content, a skill's
  body loads only when it's used." (source:
  [Skills](https://code.claude.com/docs/en/skills))
- **Listing cost:** description plus `when_to_use` is truncated at 1,536
  characters in the skill listing, which loads every turn. `/skill-doctor`
  (v2.1.252+) shows each skill's context cost and usage. The earlier
  "15,000-character `SLASH_COMMAND_TOOL_CHAR_BUDGET`" claim is not in current
  docs; the 15,000 figure that does appear is a token cap on combined subagent
  descriptions. (source: [Skills](https://code.claude.com/docs/en/skills),
  [Subagents](https://code.claude.com/docs/en/sub-agents))
- **Agent Skills spec:** `description` max 1,024 characters; keep SKILL.md under
  500 lines. (source: [agentskills.io](https://agentskills.io/specification))
- **Verification belongs in a skill.** "A good practice is to list your exact
  build and test commands in CLAUDE.md so Claude doesn't have to infer them,"
  while the verification procedure itself becomes a skill. (source: Delba de
  Oliveira,
  [Building verification loops in Claude Code with skills](https://claude.com/blog/building-verification-loops-in-claude-code-with-skills),
  2026-07-22)
- **Use prose references, not `@` imports, for on-demand docs.** `@` expands at
  launch regardless of relevance. (source:
  [memory docs](https://code.claude.com/docs/en/memory#import-additional-files))

## Auto memory

- On by default (shipped v2.1.32, default-on from v2.1.59); toggle in `/memory`
  or `autoMemoryEnabled`; disable with `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.
  Stored per repository at `~/.claude/projects/<project>/memory/`, shared across
  worktrees, machine-local, never shared across machines or cloud environments.
  (source: [memory docs](https://code.claude.com/docs/en/memory#auto-memory))
- Four kinds: `user`, `feedback`, `project`, `reference`. "Claude skips anything
  it can derive from the codebase... It also skips anything your CLAUDE.md files
  already say." (source: same)
- `MEMORY.md` index: first 200 lines or 25 KB load every session; topic files
  load on demand. (source: same)
- "When you ask Claude to remember something... Claude saves it to auto memory.
  To add instructions to CLAUDE.md instead, ask Claude directly, like 'add this
  to CLAUDE.md.'" (source: same)
- Official table: CLAUDE.md is "Instructions and rules" written by you for
  "Coding standards, workflows, project architecture"; auto memory is "Learnings
  and patterns" written by Claude for "Your preferences, corrections you give
  Claude, project context Claude can't derive from the code." (source: same)
- Community pushback on the Anthropic post centered on auto memory ("I
  absolutely don't want things to get added to some memory behind my back") and
  on "give Claude judgment" being too vague for harness authors. (source:
  [Developers Digest HN analysis](https://www.developersdigest.tech/blog/claude-5-context-engineering-rules-hn-analysis))

## Hooks, settings, and where rules belong

- **Decision table (Anthropic):** "Claude gets a convention or command wrong
  twice" → CLAUDE.md. "You paste the same playbook or multi-step procedure into
  chat for the third time" → skill. "You want something to happen every time
  without asking" → hook. (source:
  [Extend Claude Code](https://code.claude.com/docs/en/features-overview#build-your-setup-over-time))
- **Guardrails are hooks.** "An instruction like 'never edit .env' in CLAUDE.md
  or a skill is a request, not a guarantee. A PreToolUse hook that blocks the
  edit is enforcement." (source: same)
- **Steering post (Michael Segner, Anthropic, 2026-06-18):** keep CLAUDE.md
  under 200 lines with a designated owner and review changes like code; "every
  time X, always do Y" → hooks; "never do this" → hooks and permissions; 30-line
  procedures → skills; path-specific rules → `.claude/rules/` with `paths`;
  personal preferences → user-level files. "Every line loads into every session
  for every engineer working in the repo, whether it's relevant to their task or
  not." "CLAUDE.md grows the way any unowned config file does: every team
  appends its own instructions and nothing gets deleted." (source:
  [Steering Claude Code](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more))
- **Managed CLAUDE.md** can be inlined in `managed-settings.json` under
  `claudeMd`. Settings enforce; CLAUDE.md guides. (source:
  [memory docs](https://code.claude.com/docs/en/memory#manage-claude-md-for-large-teams))
- **`InstructionsLoaded` hook** fires when a CLAUDE.md or rules file loads, with
  a `load_reason`; useful for auditing which rules ever fire. It does not fire
  for a directly-read AGENTS.md. The hooks reference lists 33 events. (source:
  [Hooks reference](https://code.claude.com/docs/en/hooks))

## Subagents

- Documented frontmatter: `tools`, `disallowedTools`, `model`, `permissionMode`,
  `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`,
  `omitClaudeMd`, `effort`, `isolation`, `color`, `initialPrompt`,
  `experimental`. Combined subagent descriptions are capped at 15,000 tokens.
  (source: [Subagents](https://code.claude.com/docs/en/sub-agents))
- Anthropic recommends delegating research to subagents so exploration doesn't
  fill the main context. (source:
  [best practices](https://code.claude.com/docs/en/best-practices#use-subagents-for-investigation))

## Diagnostics

- `/context` shows memory files loaded and their token cost. `/memory` lists
  CLAUDE.md, CLAUDE.local.md, and (from v2.1.280) a directly-read AGENTS.md.
  `/doctor` proposes trims for a checked-in CLAUDE.md. `/skill-doctor` shows
  skill context cost and usage. `claude --safe-mode` runs with all
  customizations off, which is the cheapest way to see what the model does
  without your instruction files. (source:
  [Debug your configuration](https://code.claude.com/docs/en/debug-your-config),
  [Week 36](https://code.claude.com/docs/en/whats-new/2026-w36))

## Patterns

- **Delete-and-observe (Boris Cherny).** See "Claude Code team statements."
  Reporails' caveat: the method finds load-bearing compensation lines but cannot
  surface project context the model will never rediscover, and it ships failures
  to production to learn what a classification pass reveals for free.
- **Failure-driven iteration.** Add a rule after a repeated failure, not before.
  Remove rules that address behaviors the model now has. A single deployment
  that accumulated behavioral rules (5 to 18) reported a 0% recurrence rate for
  ruled-against error classes. (source: Boris above;
  [HN](https://news.ycombinator.com/item?id=47034087); Aggarwal and Ghalaty,
  [arXiv 2607.13091](https://arxiv.org/abs/2607.13091))
- **Annotate why each rule exists.** "Prompt comments" removed 99.3% of excess
  instructions in controlled runs (Chakrabarti above). In CLAUDE.md, HTML
  comments carry the rationale for humans at zero context cost; a short in-line
  reason carries it for the model.
- **Periodic audit.** Addy Osmani recommends running `/doctor` every couple of
  weeks and notes files "routinely exceed the 200-line target." Zander
  Martineau: "Target under 200 lines (under 100 better; 60 achievable on
  frontier models)." (sources:
  [Addy Osmani](https://addyosmani.com/blog/audit-your-agent-files/),
  2026-08-27; [Zander Martineau](https://zander.wtf/blog/claude-md-agents-md/),
  2026-08-03)
- **Document concepts, not file paths**, for architecture. Paths change.
  (source: [AI Hero](https://www.aihero.dev/a-complete-guide-to-agents-md))
- **Rich references.** Point at an exemplar file, a test suite, or a rubric
  rather than describing the pattern in prose. (source: Anthropic blog, shift 6,
  above)
- **Compaction instruction.** "When compacting, always preserve the full list of
  modified files and any test commands" is still in the official best practices.
  (source:
  [best practices](https://code.claude.com/docs/en/best-practices#manage-context-aggressively))
- **Canary rule** (a trivial instruction whose violation signals attention
  drift). Community pattern, not re-verified. (source:
  [HN](https://news.ycombinator.com/item?id=45983698))

## Cost

- Opus 5.5 is the default Opus model in Claude Code v2.1.280 with 1M context at
  $4/$20 per Mtok and $0.20/Mtok cache reads. Per-line token cost of CLAUDE.md
  is lower than in spring 2026; attention dilution, not the token bill, is the
  main reason to cut. (source:
  [Claude Code CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))
- Spring 2026 history: tightened peak-hour limits, the Opus 4.7 tokenizer
  producing up to 35% more tokens, and the May 6 doubling of 5-hour limits.
  (sources:
  [DevOps.com](https://devops.com/claude-code-quota-limits-usage-problems/),
  [letsdatascience](https://letsdatascience.com/news/anthropic-increases-claude-code-and-api-usage-limits-735fd0ac))

## Key dates

- 2026-06-09: Fable 5 and Mythos 5 released.
- 2026-06-18: "Steering Claude Code" blog (200-line rule).
- 2026-07-06 to 07-10 (v2.1.205/206): `/doctor` CLAUDE.md trim pass ships.
- 2026-07-21: Cat Wu and Thariq fireside chat (80% cut first said publicly).
- 2026-07-24 (v2.1.219): Opus 5; context-engineering post; Opus 5 guide.
- About 2026-07-25: Boris at YC Startup School ("delete your CLAUDE.md").
- 2026-08-25: Thariq explains the AGENTS.md delay.
- About 2026-09-01 (v2.1.257): Fable 5.1.
- 2026-09-18 (v2.1.277): native AGENTS.md.
- 2026-09-22 (v2.1.280): Opus 5.5 default; `/memory` lists AGENTS.md.

## Corrections to the May 2026 revision

- **Symlink is no longer the recommended wiring.** Claude Code reads AGENTS.md
  natively, the Edit and Write tools refuse to write through a symlink, and
  Windows checkouts break it. The import form is the documented fallback.
- **A root CLAUDE.md suppresses nested AGENTS.md files** under the default
  setting. The May revision assumed nested files always load.
- **"CLAUDE.md is marked 'may or may not be relevant'"** was wrong for current
  versions; the wrapper says the instructions override default behavior.
- **`priority:` frontmatter on rules** does not exist.
- **gh #21858** (user-level path-scoped rules) is fixed.
- **The 15,000-character skill-description budget** is not in current docs. The
  listing truncates at 1,536 characters per skill; the spec caps descriptions at
  1,024.
- **"Claude Code's system prompt consumes about 50 instruction slots"** predates
  the 80% cut.
- **Primacy/recency duplication** has no primary-source support and conflicts
  with the official "emphasize one line only" guidance.
- **"Anthropic's official cross-tool pattern is `@AGENTS.md`"** is now the
  fallback, not the primary path.
- **"28.7% of cursor-rule lines duplicate info the AI can access"** misread the
  paper; the figure is cross-repository template duplication.
- **"95%+ at messages 1-2, 20-60% by messages 6-10"** was misattributed to
  Wiegold and has no method behind it.
- **No controlled evidence that file size or rule position matters** on
  4.6-generation models (McMillan). The case for cutting is about which lines,
  not how many.
- **TechLoom URL** lost its `.html` suffix.
- **The 20-file cap on rules** never existed (already walked back in May).
