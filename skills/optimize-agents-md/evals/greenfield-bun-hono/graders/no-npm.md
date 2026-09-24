---
type: regex
target: { source: file, path: AGENTS.md }
pattern: '\bnpm (install|run|test|ci)\b'
match: not_contains
---
