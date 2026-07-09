# backend-patterns

A reference of backend architecture patterns for scalable server-side code: API design, database access and optimization, caching, error handling, auth, rate limiting, background jobs, and structured logging. Aimed at Node.js, Express, and Next.js API routes with TypeScript.

## Install

```
npx skills add venables/skills --skill backend-patterns
```

## How to use it

Bring it into a session when you're building or reviewing server-side code and want a consistent set of patterns to lean on:

- "design a REST API for this resource"
- "add a repository and service layer for markets"
- "this endpoint has an N+1 query, fix it"
- "add a Redis caching layer to this data access"
- "set up centralized error handling for my API routes"
- "add JWT auth and role-based access control to this endpoint"

## What it does

- **API design:** Shows resource-based RESTful URL conventions, query-parameter filtering/sorting/pagination, plus the repository, service-layer, and middleware patterns for separating data access from business logic.
- **Database access:** Covers selecting only needed columns, preventing N+1 queries with batch fetches and lookup maps, and running multi-step writes through a single transactional stored procedure.
- **Caching:** Provides a cache-first repository wrapper and a standalone cache-aside helper, both with TTL-based expiry and cache invalidation.
- **Error handling and resilience:** Includes a centralized error handler (custom `ApiError`, Zod validation, fallback 500) and a generic retry helper with exponential backoff.
- **Auth and access control:** Demonstrates JWT verification, an auth guard for request handlers, and role-to-permission mapping for role-based access control.
- **Operational patterns:** Adds a simple in-memory rate limiter, an in-process job queue for offloading work from request handlers, and a structured JSON logger.

## Gotchas

- **Reference, not a library:** This skill supplies patterns and example code you adapt into your own project, not an installable runtime module. You still wire the pieces in yourself.
- **Examples assume a specific stack:** Snippets use Supabase, Redis, `jsonwebtoken`, Zod, and Next.js route handlers. On a different stack you'll need to translate the approach, and the corresponding dependencies must be present.
- **In-memory pieces don't survive scale-out:** The rate limiter and job queue hold state in process memory, so they reset on restart and don't coordinate across multiple instances. Use a shared backend (Redis, a real queue) for production multi-node deployments.
- **Pick to fit complexity:** Not every pattern belongs in every app. Layering repositories, services, and caches onto a small project is overkill; choose the ones your complexity level actually warrants.
