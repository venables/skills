# bro

Restate the last message in plain human language, no jargon. When a reply came back dense, hedged, or full of terminology, invoke this to get the same thing said simply, like one human talking to another.

## Install

```
npx skills add venables/skills --skill bro
```

## How to use it

This skill is user-invoked only (`disable-model-invocation: true`), so call it explicitly after a reply you want in plainer terms:

- "/bro"
- "bro"

## What it does

- **Rewrites the previous message** in simple, concise, human language.
- **Strips the jargon** and any hedging, keeping the actual point.

## Credit

By [Dillon Mulroy](https://x.com/dillon_mulroy) ([@dmmulroy](https://github.com/dmmulroy)). Ported from [dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles/blob/main/home/.agents/skills/bro/SKILL.md).
