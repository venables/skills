# security-review

A comprehensive security checklist and set of secure-coding patterns that Claude Code pulls in when you touch security-sensitive code (auth, user input, secrets, API endpoints, payments). It steers you toward the safe pattern and away from the common footgun, with copy-ready TypeScript examples.

## Install

```
npx skills add venables/skills --skill security-review
```

## How to use it

Mention the sensitive work you're doing and Claude Code activates it:

- "I'm adding login and JWT handling to this app"
- "validate this file upload / user input"
- "wiring up a new API endpoint"
- "where should I store these secrets / API keys?"
- "add a payment flow"
- "review this for SQL injection / XSS / CSRF"

## What it does

- **Secrets and input:** Flags hardcoded keys, pushes everything into env vars, and validates all user input with schemas (Zod), including size, type, and extension checks on file uploads.
- **Injection and XSS:** Requires parameterized queries (no string-concatenated SQL), sanitizes user-provided HTML (DOMPurify), and configures CSP headers.
- **Auth and access:** Prefers httpOnly cookies over localStorage for tokens, enforces authorization checks before sensitive operations, and covers Supabase Row Level Security and role-based access.
- **CSRF and rate limiting:** Adds CSRF tokens plus SameSite cookies on state-changing routes, and rate limits API endpoints (stricter on expensive operations).
- **Data exposure:** Keeps secrets out of logs, returns generic error messages to users, and reserves stack traces for server logs only.
- **Deploy gate:** Provides a pre-deployment security checklist (HTTPS, security headers, CORS, dependency audit, RLS) to run before shipping to production.

## Gotchas

- **It's guidance, not a scanner.** This skill supplies checklists and secure patterns for Claude Code to apply while writing code. It does not scan a diff and report vulnerabilities on its own. For an actual review pass over pending changes, use the built-in `/security-review` command, which is a separate thing.
- **Stack-specific examples.** The patterns lean on a Next.js / Supabase / Zod / Node stack, and one section covers Solana wallet and transaction verification. The principles are general, but you'll adapt the snippets if your stack differs.
- **Activation is heuristic.** It keys off security-sensitive topics (auth, input, secrets, endpoints, payments). If your task doesn't obviously mention those, name the concern explicitly so it kicks in.
