# Supabase Table Setup

The SDK's OAuth system stores data in two Supabase tables. **Both tables must exist before the OAuth flow will work.**

## Required SQL

Run this SQL in your Supabase SQL Editor (Dashboard > SQL Editor > New query):

```sql
-- =============================================================
-- Table 1: atproto_oauth_session
-- Stores long-lived OAuth tokens (access + refresh tokens).
-- One row per app-user combination.
-- =============================================================
CREATE TABLE atproto_oauth_session (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL,
    did TEXT NOT NULL,
    value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(app_id, did)
);

CREATE INDEX idx_oauth_session_app_did
  ON atproto_oauth_session(app_id, did);

-- =============================================================
-- Table 2: atproto_oauth_state
-- Stores temporary OAuth authorization state.
-- Rows auto-expire after 1 hour.
-- =============================================================
CREATE TABLE atproto_oauth_state (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL,
    value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 hour')
);

CREATE INDEX idx_oauth_state_app_expires
  ON atproto_oauth_state(app_id, expires_at);
```

## Column Reference

### `atproto_oauth_session`

| Column | Type | Purpose |
|---|---|---|
| `id` | `TEXT` | Composite key: `${appId}:${did}` |
| `app_id` | `TEXT` | Identifies which app owns this session (e.g., `"greenglobe"`) |
| `did` | `TEXT` | The user's ATProto DID (e.g., `did:plc:abc123...`) |
| `value` | `JSONB` | Full `NodeSavedSession` object from `@atproto/oauth-client-node` (contains access token, refresh token, DPoP keys, etc.) |
| `created_at` | `TIMESTAMPTZ` | When the session was first created |
| `updated_at` | `TIMESTAMPTZ` | When the session was last refreshed |

### `atproto_oauth_state`

| Column | Type | Purpose |
|---|---|---|
| `id` | `TEXT` | Composite key: `${appId}:${stateKey}` |
| `app_id` | `TEXT` | Identifies which app created this state |
| `value` | `JSONB` | Full `NodeSavedState` object (PKCE verifier, redirect URI, etc.) |
| `created_at` | `TIMESTAMPTZ` | When the state was created |
| `expires_at` | `TIMESTAMPTZ` | Auto-set to 1 hour from creation. Used by cleanup. |

## How the Composite Key Works

The SDK's session and state stores prefix all keys with the `APP_ID` you provide when calling `createSupabaseSessionStore(supabase, APP_ID)`. This means multiple apps can safely share the same Supabase tables without key collisions:

```
App "greenglobe" + DID "did:plc:abc" → key: "greenglobe:did:plc:abc"
App "bumicerts"  + DID "did:plc:abc" → key: "bumicerts:did:plc:abc"
```

## Row-Level Security (RLS)

These tables are accessed using the **Supabase service role key** (server-side only), which bypasses RLS. If you enable RLS on these tables, ensure:

- The service role key is used (it bypasses RLS by default)
- OR you create appropriate policies for the `service_role`

For most setups, leaving RLS **disabled** on these two tables is fine since they are only accessed server-side and the service role key is never exposed to the client.

## Cleanup

OAuth state rows expire after 1 hour but are not automatically deleted. To clean up expired rows, call `cleanupExpiredStates` periodically:

```typescript
import { cleanupExpiredStates } from "gainforest-sdk-nextjs/oauth";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
const deletedCount = await cleanupExpiredStates(supabase);
```

You can run this in a cron job, a Supabase Edge Function, or a scheduled database function.
