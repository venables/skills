---
type: regex
target: { source: file, path: AGENTS.md }
pattern:
  '^(?!-
  `(apps|packages|infra)/).*(useEffect|tailwind\.config|TypedResponse|drizzle-kit|db:(generate|migrate)|pulumi
  (destroy|up|preview|config)|--secret|5433|port 3000|port 5173|AppError)'
flags: im
match: not_contains
weight: 2
---
