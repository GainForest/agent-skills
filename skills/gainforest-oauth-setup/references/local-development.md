# Local Development Setup

ATProto OAuth has specific requirements for local development. The ATProto spec does not allow `localhost` as a production client ID, but it supports a special **loopback client** for development.

## Loopback Configuration

For local development, modify `lib/atproto.ts` to use loopback URLs:

```typescript
import {
  createATProtoSDK,
  createSupabaseSessionStore,
  createSupabaseStateStore,
} from "gainforest-sdk-nextjs/oauth";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const APP_ID = "your-app-name";

export const atprotoSDK = createATProtoSDK({
  oauth: {
    // Special loopback client ID recognized by ATProto
    clientId: "http://localhost/",
    // MUST use 127.0.0.1, not localhost
    redirectUri: "http://127.0.0.1:3000/api/oauth/callback",
    jwksUri: "http://127.0.0.1:3000/.well-known/jwks.json",
    jwkPrivate: process.env.OAUTH_PRIVATE_KEY!,
    scope: "atproto",
    // Suppresses development mode warnings
    developmentMode: true,
  },
  servers: {
    pds: "https://climateai.org",
  },
  storage: {
    sessionStore: createSupabaseSessionStore(supabase, APP_ID),
    stateStore: createSupabaseStateStore(supabase, APP_ID),
  },
});
```

## Key Differences from Production

| Setting | Production | Local Development |
|---|---|---|
| `clientId` | `${PUBLIC_URL}/client-metadata.json` | `"http://localhost/"` |
| `redirectUri` | `${PUBLIC_URL}/api/oauth/callback` | `"http://127.0.0.1:3000/api/oauth/callback"` |
| `jwksUri` | `${PUBLIC_URL}/.well-known/jwks.json` | `"http://127.0.0.1:3000/.well-known/jwks.json"` |
| `developmentMode` | Omitted or `false` | `true` |

## Environment Variables for Development

Update `.env.local`:

```env
NEXT_PUBLIC_APP_URL=http://127.0.0.1:3000
```

**Important**: Use `http://127.0.0.1:3000`, not `http://localhost:3000`. The ATProto loopback client spec requires `127.0.0.1` for redirect and JWKS URIs, even though the client ID uses `localhost`.

## localhost vs 127.0.0.1

This is a common source of confusion:

- **`clientId`** uses `http://localhost/` -- this is the special loopback identifier recognized by ATProto authorization servers
- **`redirectUri` and `jwksUri`** use `http://127.0.0.1:3000` -- the actual address where your dev server is running

These must be different. Using `localhost` for `redirectUri` will cause callback failures.

## Conditional Configuration Pattern

To switch between dev and production automatically:

```typescript
const isDev = process.env.NODE_ENV === "development";
const PUBLIC_URL = process.env.NEXT_PUBLIC_APP_URL!;

export const atprotoSDK = createATProtoSDK({
  oauth: {
    clientId: isDev ? "http://localhost/" : `${PUBLIC_URL}/client-metadata.json`,
    redirectUri: isDev
      ? "http://127.0.0.1:3000/api/oauth/callback"
      : `${PUBLIC_URL}/api/oauth/callback`,
    jwksUri: isDev
      ? "http://127.0.0.1:3000/.well-known/jwks.json"
      : `${PUBLIC_URL}/.well-known/jwks.json`,
    jwkPrivate: process.env.OAUTH_PRIVATE_KEY!,
    scope: "atproto",
    ...(isDev && { developmentMode: true }),
  },
  servers: {
    pds: "https://climateai.org",
  },
  storage: {
    sessionStore: createSupabaseSessionStore(supabase, APP_ID),
    stateStore: createSupabaseStateStore(supabase, APP_ID),
  },
});
```

## HTTPS in Development

ATProto OAuth works over HTTP for loopback clients. You do **not** need HTTPS for local development. The `http://localhost/` client ID is specifically designed to allow this.

For production, always use HTTPS. The `client-metadata.json` route and JWKS endpoint must be served over HTTPS.
