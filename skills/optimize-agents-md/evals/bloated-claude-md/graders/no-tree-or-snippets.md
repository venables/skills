---
type: regex
target: { source: file, path: AGENTS.md }
pattern: "├──|└──|```"
match: not_contains
---
