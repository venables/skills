---
name: backend-patterns
description: Backend architecture patterns, API design, database optimization, and
  server-side best practices for Node.js, Express, and Next.js API routes.
---

# Backend Development Patterns

Backend architecture patterns and best practices for scalable server-side
applications.

## API Design Patterns

### RESTful API Structure

```typescript
// ✅ Resource-based URLs
GET    /api/posts                   # List resources
GET    /api/posts/:id               # Get single resource
POST   /api/posts                   # Create resource
PUT    /api/posts/:id               # Replace resource
PATCH  /api/posts/:id               # Update resource
DELETE /api/posts/:id               # Delete resource

// ✅ Query parameters for filtering, sorting, pagination
GET /api/posts?status=published&sort=viewCount&limit=20&offset=0
```

### Repository Pattern

```typescript
// Abstract data access logic
interface PostRepository {
  findAll(filters?: PostFilters): Promise<Post[]>;
  findById(id: string): Promise<Post | null>;
  create(data: CreatePostDto): Promise<Post>;
  update(id: string, data: UpdatePostDto): Promise<Post>;
  delete(id: string): Promise<void>;
}

class SupabasePostRepository implements PostRepository {
  async findAll(filters?: PostFilters): Promise<Post[]> {
    let query = supabase.from("posts").select("*");

    if (filters?.status) {
      query = query.eq("status", filters.status);
    }

    if (filters?.limit) {
      query = query.limit(filters.limit);
    }

    const { data, error } = await query;

    if (error) throw new Error(error.message);
    return data;
  }

  // Other methods...
}
```

### Service Layer Pattern

```typescript
// Business logic separated from data access
class PostService {
  constructor(private postRepo: PostRepository) {}

  async searchPosts(query: string, limit: number = 10): Promise<Post[]> {
    // Business logic
    const embedding = await generateEmbedding(query);
    const results = await this.vectorSearch(embedding, limit);

    // Fetch full data
    const posts = await this.postRepo.findByIds(results.map((r) => r.id));

    // Sort by similarity
    return posts.sort((a, b) => {
      const scoreA = results.find((r) => r.id === a.id)?.score || 0;
      const scoreB = results.find((r) => r.id === b.id)?.score || 0;
      return scoreA - scoreB;
    });
  }

  private async vectorSearch(embedding: number[], limit: number) {
    // Vector search implementation
  }
}
```

### Middleware Pattern

```typescript
// Request/response processing pipeline
export function withAuth(handler: NextApiHandler): NextApiHandler {
  return async (req, res) => {
    const token = req.headers.authorization?.replace("Bearer ", "");

    if (!token) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    try {
      const user = await verifyToken(token);
      req.user = user;
      return handler(req, res);
    } catch (error) {
      return res.status(401).json({ error: "Invalid token" });
    }
  };
}

// Usage
export default withAuth(async (req, res) => {
  // Handler has access to req.user
});
```

## Database Patterns

### Query Optimization

```typescript
// ✅ GOOD: Select only needed columns
const { data } = await supabase
  .from("posts")
  .select("id, title, status, viewCount")
  .eq("status", "published")
  .order("viewCount", { ascending: false })
  .limit(10);

// ❌ BAD: Select everything
const { data } = await supabase.from("posts").select("*");
```

### N+1 Query Prevention

```typescript
// ❌ BAD: N+1 query problem
const posts = await getPosts();
for (const post of posts) {
  post.author = await getUser(post.author_id); // N queries
}

// ✅ GOOD: Batch fetch
const posts = await getPosts();
const authorIds = posts.map((p) => p.author_id);
const authors = await getUsers(authorIds); // 1 query
const authorMap = new Map(authors.map((a) => [a.id, a]));

posts.forEach((post) => {
  post.author = authorMap.get(post.author_id);
});
```

### Transaction Pattern

```typescript
async function createPostWithTag(
  postData: CreatePostDto,
  tagData: CreateTagDto
) {
  // Use Supabase transaction
  const { data, error } = await supabase.rpc('create_post_with_tag', {
    post_data: postData,
    tag_data: tagData
  })

  if (error) throw new Error('Transaction failed')
  return data
}

// SQL function in Supabase
CREATE OR REPLACE FUNCTION create_post_with_tag(
  post_data jsonb,
  tag_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  -- Start transaction automatically
  INSERT INTO posts VALUES (post_data);
  INSERT INTO tags VALUES (tag_data);
  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    -- Rollback happens automatically
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
```

## Caching Strategies

### Redis Caching Layer

```typescript
class CachedPostRepository implements PostRepository {
  constructor(
    private baseRepo: PostRepository,
    private redis: RedisClient,
  ) {}

  async findById(id: string): Promise<Post | null> {
    // Check cache first
    const cached = await this.redis.get(`post:${id}`);

    if (cached) {
      return JSON.parse(cached);
    }

    // Cache miss - fetch from database
    const post = await this.baseRepo.findById(id);

    if (post) {
      // Cache for 5 minutes
      await this.redis.setex(`post:${id}`, 300, JSON.stringify(post));
    }

    return post;
  }

  async invalidateCache(id: string): Promise<void> {
    await this.redis.del(`post:${id}`);
  }
}
```

### Cache-Aside Pattern

```typescript
async function getPostWithCache(id: string): Promise<Post> {
  const cacheKey = `post:${id}`;

  // Try cache
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  // Cache miss - fetch from DB
  const post = await db.posts.findUnique({ where: { id } });

  if (!post) throw new Error("Post not found");

  // Update cache
  await redis.setex(cacheKey, 300, JSON.stringify(post));

  return post;
}
```

## Error Handling Patterns

### Centralized Error Handler

```typescript
class ApiError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public isOperational = true,
  ) {
    super(message);
    Object.setPrototypeOf(this, ApiError.prototype);
  }
}

export function errorHandler(error: unknown, req: Request): Response {
  if (error instanceof ApiError) {
    return NextResponse.json(
      {
        success: false,
        error: error.message,
      },
      { status: error.statusCode },
    );
  }

  if (error instanceof z.ZodError) {
    return NextResponse.json(
      {
        success: false,
        error: "Validation failed",
        details: error.errors,
      },
      { status: 400 },
    );
  }

  // Log unexpected errors
  console.error("Unexpected error:", error);

  return NextResponse.json(
    {
      success: false,
      error: "Internal server error",
    },
    { status: 500 },
  );
}

// Usage
export async function GET(request: Request) {
  try {
    const data = await fetchData();
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return errorHandler(error, request);
  }
}
```

### Retry with Exponential Backoff

```typescript
async function fetchWithRetry<T>(fn: () => Promise<T>, maxRetries = 3): Promise<T> {
  let lastError: Error;

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (i < maxRetries - 1) {
        // Exponential backoff: 1s, 2s, 4s
        const delay = Math.pow(2, i) * 1000;
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError!;
}

// Usage
const data = await fetchWithRetry(() => fetchFromAPI());
```

## Authentication & Authorization

### JWT Token Validation

```typescript
import jwt from "jsonwebtoken";

interface JWTPayload {
  userId: string;
  email: string;
  role: "admin" | "user";
}

export function verifyToken(token: string): JWTPayload {
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as JWTPayload;
    return payload;
  } catch (error) {
    throw new ApiError(401, "Invalid token");
  }
}

export async function requireAuth(request: Request) {
  const token = request.headers.get("authorization")?.replace("Bearer ", "");

  if (!token) {
    throw new ApiError(401, "Missing authorization token");
  }

  return verifyToken(token);
}

// Usage in API route
export async function GET(request: Request) {
  const user = await requireAuth(request);

  const data = await getDataForUser(user.userId);

  return NextResponse.json({ success: true, data });
}
```

### Role-Based Access Control

```typescript
type Permission = "read" | "write" | "delete" | "admin";

interface User {
  id: string;
  role: "admin" | "moderator" | "user";
}

const rolePermissions: Record<User["role"], Permission[]> = {
  admin: ["read", "write", "delete", "admin"],
  moderator: ["read", "write", "delete"],
  user: ["read", "write"],
};

export function hasPermission(user: User, permission: Permission): boolean {
  return rolePermissions[user.role].includes(permission);
}

export function requirePermission(permission: Permission) {
  return async (request: Request) => {
    const user = await requireAuth(request);

    if (!hasPermission(user, permission)) {
      throw new ApiError(403, "Insufficient permissions");
    }

    return user;
  };
}

// Usage
export const DELETE = requirePermission("delete")(async (request: Request) => {
  // Handler with permission check
});
```

## Rate Limiting

### Simple In-Memory Rate Limiter

```typescript
class RateLimiter {
  private requests = new Map<string, number[]>();

  async checkLimit(identifier: string, maxRequests: number, windowMs: number): Promise<boolean> {
    const now = Date.now();
    const requests = this.requests.get(identifier) || [];

    // Remove old requests outside window
    const recentRequests = requests.filter((time) => now - time < windowMs);

    if (recentRequests.length >= maxRequests) {
      return false; // Rate limit exceeded
    }

    // Add current request
    recentRequests.push(now);
    this.requests.set(identifier, recentRequests);

    return true;
  }
}

const limiter = new RateLimiter();

export async function GET(request: Request) {
  const ip = request.headers.get("x-forwarded-for") || "unknown";

  const allowed = await limiter.checkLimit(ip, 100, 60000); // 100 req/min

  if (!allowed) {
    return NextResponse.json(
      {
        error: "Rate limit exceeded",
      },
      { status: 429 },
    );
  }

  // Continue with request
}
```

## Background Jobs & Queues

### Simple Queue Pattern

```typescript
class JobQueue<T> {
  private queue: T[] = [];
  private processing = false;

  async add(job: T): Promise<void> {
    this.queue.push(job);

    if (!this.processing) {
      this.process();
    }
  }

  private async process(): Promise<void> {
    this.processing = true;

    while (this.queue.length > 0) {
      const job = this.queue.shift()!;

      try {
        await this.execute(job);
      } catch (error) {
        console.error("Job failed:", error);
      }
    }

    this.processing = false;
  }

  private async execute(job: T): Promise<void> {
    // Job execution logic
  }
}

// Usage for indexing posts
interface IndexJob {
  postId: string;
}

const indexQueue = new JobQueue<IndexJob>();

export async function POST(request: Request) {
  const { postId } = await request.json();

  // Add to queue instead of blocking
  await indexQueue.add({ postId });

  return NextResponse.json({ success: true, message: "Job queued" });
}
```

## Logging & Monitoring

### Structured Logging

```typescript
interface LogContext {
  userId?: string;
  requestId?: string;
  method?: string;
  path?: string;
  [key: string]: unknown;
}

class Logger {
  log(level: "info" | "warn" | "error", message: string, context?: LogContext) {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...context,
    };

    console.log(JSON.stringify(entry));
  }

  info(message: string, context?: LogContext) {
    this.log("info", message, context);
  }

  warn(message: string, context?: LogContext) {
    this.log("warn", message, context);
  }

  error(message: string, error: Error, context?: LogContext) {
    this.log("error", message, {
      ...context,
      error: error.message,
      stack: error.stack,
    });
  }
}

const logger = new Logger();

// Usage
export async function GET(request: Request) {
  const requestId = crypto.randomUUID();

  logger.info("Fetching posts", {
    requestId,
    method: "GET",
    path: "/api/posts",
  });

  try {
    const posts = await fetchPosts();
    return NextResponse.json({ success: true, data: posts });
  } catch (error) {
    logger.error("Failed to fetch posts", error as Error, { requestId });
    return NextResponse.json({ error: "Internal error" }, { status: 500 });
  }
}
```

**Remember**: Backend patterns enable scalable, maintainable server-side
applications. Choose patterns that fit your complexity level.
