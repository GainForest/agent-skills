# Troubleshooting & Security

## Common Errors

### "COOKIE_SECRET environment variable is required"

The `COOKIE_SECRET` env var is missing or empty. Add it to `.env.local`:

```env
COOKIE_SECRET=your-secret-key-at-least-32-characters-long
```

It must be at least 32 characters. iron-session will throw if it's shorter.

### "Session expired or not found"

The OAuth session in Supabase was deleted or the tokens expired. The user needs to re-authenticate. This can happen when:

- The Supabase `atproto_oauth_session` row was manually deleted
- The refresh token expired (long inactivity)
- The `APP_ID` changed between deployments

### "Failed to initiate authorization"

Check that:

1. The `client-metadata.json` route is accessible at `${NEXT_PUBLIC_APP_URL}/client-metadata.json`
2. The `.well-known/jwks.json` route is serving the public key at `${NEXT_PUBLIC_APP_URL}/.well-known/jwks.json`
3. The PDS URL in `servers.pds` is correct and reachable
4. The `OAUTH_PRIVATE_KEY` is valid JSON and contains a proper ES256 JWK

### Callback redirects to error page

Check the server logs for the specific error. Common causes:

- **State mismatch**: The user took too long to authenticate (state expires after 1 hour)
- **Invalid authorization code**: The code was already used or is malformed
- **PKCE verifier mismatch**: The state store returned incorrect data (check `APP_ID` consistency)
- **Supabase connection error**: Verify `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`

### "handle" is undefined after callback

The `OAuthSession` returned by `callback()` only has `sub` (the DID), not a `handle`. You must resolve the handle separately:

```typescript
const agent = new Agent(oauthSession);
const { data: profile } = await agent.com.atproto.repo.describeRepo({
  repo: oauthSession.did,
});
const handle = profile.handle;
```

See Critical API Rule #2 in the main SKILL.md.

### "Cannot read properties of undefined (reading 'sessionStore')"

The `sessionStore` and `stateStore` must be nested under `storage: { ... }`:

```typescript
// WRONG -- will fail
createATProtoSDK({
  sessionStore: createSupabaseSessionStore(supabase, APP_ID),
  stateStore: createSupabaseStateStore(supabase, APP_ID),
  // ...
});

// CORRECT
createATProtoSDK({
  storage: {
    sessionStore: createSupabaseSessionStore(supabase, APP_ID),
    stateStore: createSupabaseStateStore(supabase, APP_ID),
  },
  // ...
});
```

### Logout doesn't fully sign out

Logout requires two steps in order:

1. `atprotoSDK.revokeSession(did)` -- invalidates OAuth tokens in Supabase
2. `clearAppSession()` -- clears the encrypted cookie

If you only call `clearAppSession()`, the cookie is cleared but the OAuth tokens remain valid in the `atproto_oauth_session` table. A restored session would still work.

### Cookies not being set / session not persisting

- Ensure your OAuth helpers (`getAppSession`, `saveAppSession`, `clearAppSession`) are only called in **server-side code** (API routes, Server Components, Server Actions). They use `cookies()` from `next/headers` which is not available on the client.
- Check that `COOKIE_NAME` is consistent across all server files. If different files use different cookie names, sessions won't persist.

## Security Checklist

Before deploying to production, verify:

- [ ] `COOKIE_SECRET` is at least 32 characters and kept secret
- [ ] `OAUTH_PRIVATE_KEY` is never committed to version control
- [ ] `SUPABASE_SERVICE_ROLE_KEY` is only used server-side (never in client code or `NEXT_PUBLIC_` prefixed)
- [ ] Production URLs use HTTPS
- [ ] `COOKIE_NAME` is unique per app to avoid cookie conflicts when multiple apps share a domain
- [ ] Database tables have appropriate access controls (service role key bypasses RLS by default)

## Cleaning Up Expired OAuth States

OAuth state rows in `atproto_oauth_state` expire after 1 hour but are not automatically deleted. Over time, these accumulate. Clean them up periodically:

```typescript
import { cleanupExpiredStates } from "gainforest-sdk-nextjs/oauth";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const deletedCount = await cleanupExpiredStates(supabase);
console.log(`Cleaned up ${deletedCount} expired OAuth states`);
```

Options for scheduling:

- **Supabase Edge Function** with a cron trigger
- **Supabase database function** with `pg_cron` extension
- **API route** called by an external cron service (e.g., Vercel Cron)
- **Manual** cleanup as part of a maintenance script

### Example: Supabase pg_cron

If you have the `pg_cron` extension enabled:

```sql
-- Delete expired states every hour
SELECT cron.schedule(
  'cleanup-oauth-states',
  '0 * * * *',
  $$DELETE FROM atproto_oauth_state WHERE expires_at < NOW()$$
);
```
