---
type: regex
target: { source: file, path: AGENTS.md }
pattern:
  "write clean code|follow DRY|SOLID|handle errors gracefully|consider
  (accessibility|performance|security)|meaningful (variable names|commit
  messages)|avoid premature optimization"
flags: i
match: not_contains
---
