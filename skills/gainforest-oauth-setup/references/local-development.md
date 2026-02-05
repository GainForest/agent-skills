# Local Development Setup

ATProto OAuth has specific requirements for local development per RFC 8252 Section 7.3. This guide explains the correct configuration for loopback clients.

## What is Loopback?

"Loopback" refers to OAuth clients running on the developer's local machine (e.g., localhost or 127.0.0.1). These have special security requirements to prevent DNS rebinding attacks.

## localhost vs 127.0.0.1

| Aspect | localhost | 127.0.0.1 |
|--------|-------------|-------------|
| Type | Hostname | IP Address |
| DNS Resolution | Can be hijacked | Direct IP (safe) |
| RFC 8252 Requirement | ❌ Not allowed for redirect URIs | ✅ Required for redirect URIs |
| Client ID | ✅ Allowed | ✅ Allowed |

**Key Rule**: Client IDs can use localhost, but redirect URIs must use the IP address 127.0.0.1.

## Configuration Structure

### ATProto Loopback Client ID Format

The client ID for loopback includes metadata as URL parameters:

```
http://localhost?scope=<scopes>&redirect_uri=<redirect_uri>
```

Example:

```
http://localhost?scope=atproto%20transition%3Ageneric&redirect_uri=http%3A%2F%2F127.0.0.1%3A3000%2Fapi%2Fauth%2Fcallback
```

**Important:**
- Client ID uses `localhost` (no port)
- Redirect URI uses `127.0.0.1` (with port)
- Scopes are URL-encoded and embedded in the client ID

## Configuration Variables

### Recommended Approach (Simplified)

Use a single environment variable:

```env
# .env.local
NEXT_PUBLIC_APP_URL=http://127.0.0.1:3000
```

Then derive all other URLs from this:

```typescript
const baseUrl = process.env.NEXT_PUBLIC_APP_URL // http://127.0.0.1:3000
const redirectUri = `${baseUrl}/api/auth/callback` // http://127.0.0.1:3000/api/auth/callback
const jwksUri = `${baseUrl}/.well-known/jwks.json` // http://127.0.0.1:3000/.well-known/jwks.json

// Client ID embeds scope and redirect URI
const scope = "atproto transition:generic";
const clientId = `http://localhost?scope=${encodeURIComponent(scope)}&redirect_uri=${encodeURIComponent(redirectUri)}`;
```

### Legacy Approach (Discouraged)

```env
# Don't do this - confusing and error-prone
NEXT_PUBLIC_APP_URL=http://localhost
NEXT_PUBLIC_REDIRECT_BASE_URL=http://127.0.0.1:3000
```

## Complete OAuth Configuration

### Local Development

```javascript
{
  // Client ID: uses localhost, embeds scopes and redirect URI
  clientId: "http://localhost?scope=atproto%20transition%3Ageneric&redirect_uri=http%3A%2F%2F127.0.0.1%3A3000%2Fapi%2Fauth%2Fcallback",
  
  // Redirect URI: MUST use IP address (RFC 8252)
  redirectUri: "http://127.0.0.1:3000/api/auth/callback",
  
  // JWKS URI: MUST match redirect URI origin
  jwksUri: "http://127.0.0.1:3000/.well-known/jwks.json",
  
  // Scopes
  scope: "atproto transition:generic",
  
  // OAuth settings
  grant_types: ["authorization_code", "refresh_token"],
  response_types: ["code"],
  token_endpoint_auth_method: "none",
  application_type: "native",  // ← Important for loopback
  dpop_bound_access_tokens: true
}
```

### Production

```javascript
{
  // Client ID: URL to metadata endpoint
  clientId: "https://yourdomain.com/client-metadata.json",
  
  // Redirect URI: Same origin as client ID
  redirectUri: "https://yourdomain.com/api/auth/callback",
  
  // JWKS URI
  jwksUri: "https://yourdomain.com/.well-known/jwks.json",
  
  // Scopes
  scope: "atproto",
  
  // OAuth settings
  grant_types: ["authorization_code", "refresh_token"],
  response_types: ["code"],
  token_endpoint_auth_method: "private_key_jwt",
  token_endpoint_auth_signing_alg: "ES256",
  application_type: "web",  // ← Different from loopback
  dpop_bound_access_tokens: true
}
```

## Client Metadata Endpoint

Your app must serve OAuth client metadata at `/client-metadata.json`.

### Loopback Response

```json
{
  "client_id": "http://localhost?scope=atproto%20transition%3Ageneric&redirect_uri=http%3A%2F%2F127.0.0.1%3A3000%2Fapi%2Fauth%2Fcallback",
  "client_name": "Your App Name",
  "client_uri": "http://127.0.0.1:3000",
  "redirect_uris": ["http://127.0.0.1:3000/api/auth/callback"],
  "scope": "atproto transition:generic",
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none",
  "application_type": "native",
  "dpop_bound_access_tokens": true
}
```

### Production Response

```json
{
  "client_id": "https://yourdomain.com/client-metadata.json",
  "client_name": "Your App Name",
  "client_uri": "https://yourdomain.com",
  "redirect_uris": ["https://yourdomain.com/api/auth/callback"],
  "scope": "atproto",
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "private_key_jwt",
  "token_endpoint_auth_signing_alg": "ES256",
  "application_type": "web",
  "dpop_bound_access_tokens": true,
  "jwks_uri": "https://yourdomain.com/.well-known/jwks.json"
}
```

## Common Pitfalls & Solutions

### ❌ Problem: Using localhost for redirect URI

```typescript
// WRONG - will fail OAuth validation
redirectUri: "http://localhost:3000/api/auth/callback"
```

**Solution**: Use 127.0.0.1

```typescript
// CORRECT
redirectUri: "http://127.0.0.1:3000/api/auth/callback"
```

### ❌ Problem: Scopes not in client ID

```typescript
// WRONG - scopes missing from loopback client ID
clientId: "http://localhost"
```

**Solution**: Embed scopes in query params

```typescript
// CORRECT
clientId: "http://localhost?scope=atproto%20transition%3Ageneric&redirect_uri=..."
```

### ❌ Problem: Port in client ID

```typescript
// WRONG - client ID should not have port for loopback
clientId: "http://localhost:3000?scope=..."
```

**Solution**: No port in loopback client ID

```typescript
// CORRECT
clientId: "http://localhost?scope=..."
```

### ❌ Problem: Using hostname instead of IP

```typescript
// WRONG - can be hijacked
redirectUri: "http://localhost:3000/callback"
```

**Solution**: Use IP address

```typescript
// CORRECT
redirectUri: "http://127.0.0.1:3000/callback"
```

## Environment Configuration Examples

### Local Development

```env
# .env.local
NEXT_PUBLIC_APP_URL=http://127.0.0.1:3000
ATPROTO_JWK_PRIVATE='{"keys":[...]}'
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
NEXT_PUBLIC_PDS_URL=https://pds.example.com
NEXT_PUBLIC_SDS_URL=https://sds.example.com
```

### ngrok Testing

```env
# .env.local (ngrok)
NEXT_PUBLIC_APP_URL=https://abc123.ngrok.io
ATPROTO_JWK_PRIVATE='{"keys":[...]}'
# ... rest same as local
```

### Production (Vercel)

```env
# Leave NEXT_PUBLIC_APP_URL unset - auto-detected from VERCEL_URL
# Or set explicitly:
NEXT_PUBLIC_APP_URL=https://yourdomain.com
ATPROTO_JWK_PRIVATE='{"keys":[...]}'
REDIS_HOST=your-redis.cloud
REDIS_PORT=6379
REDIS_PASSWORD=secure-password
NEXT_PUBLIC_PDS_URL=https://pds.example.com
NEXT_PUBLIC_SDS_URL=https://sds.example.com
```

## Conditional Configuration Pattern

To switch between dev and production automatically:

```typescript
const isDev = process.env.NODE_ENV === "development";
const PUBLIC_URL = process.env.NEXT_PUBLIC_APP_URL!;
const scope = isDev ? "atproto transition:generic" : "atproto";

export const atprotoSDK = createATProtoSDK({
  oauth: {
    clientId: isDev 
      ? `http://localhost?scope=${encodeURIComponent(scope)}&redirect_uri=${encodeURIComponent(`${PUBLIC_URL}/api/oauth/callback`)}`
      : `${PUBLIC_URL}/client-metadata.json`,
    redirectUri: `${PUBLIC_URL}/api/oauth/callback`,
    jwksUri: `${PUBLIC_URL}/.well-known/jwks.json`,
    jwkPrivate: process.env.OAUTH_PRIVATE_KEY!,
    scope,
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

## JWKS Endpoint Requirements

The JWKS endpoint must serve public keys with `key_ops: ["verify"]`:

```typescript
// app/.well-known/jwks.json/route.ts
export async function GET() {
  const privateKey = JSON.parse(process.env.OAUTH_PRIVATE_KEY!);
  const { d, ...publicKey } = privateKey;
  
  // Add key_ops for public key verification
  const jwk = {
    ...publicKey,
    key_ops: ["verify"],
  };
  
  // Remove deprecated "use" field if present
  delete jwk.use;

  return NextResponse.json({ keys: [jwk] });
}
```

## HTTPS in Development

ATProto OAuth works over HTTP for loopback clients. You do **not** need HTTPS for local development. The `http://localhost` client ID is specifically designed to allow this.

For production, always use HTTPS. The `client-metadata.json` route and JWKS endpoint must be served over HTTPS.

## Validation Checklist

Before deploying, verify:

- [ ] Local dev uses `NEXT_PUBLIC_APP_URL=http://127.0.0.1:3000`
- [ ] Client ID for loopback is `http://localhost?scope=...&redirect_uri=...`
- [ ] Redirect URI uses `127.0.0.1`, not `localhost`
- [ ] JWKS URI uses same origin as redirect URI
- [ ] Client metadata endpoint returns correct `application_type` ("native" for loopback, "web" for production)
- [ ] Scopes are embedded in loopback client ID
- [ ] Port is included in redirect URI but not in client ID
- [ ] JWKS endpoint includes `key_ops: ["verify"]` in public keys

## Testing

### Test Loopback Configuration

```bash
# 1. Check client metadata
curl http://127.0.0.1:3000/client-metadata.json | jq .

# Expected: client_id should be "http://localhost?scope=..."
# Expected: redirect_uris should use "http://127.0.0.1:3000"

# 2. Check JWKS endpoint
curl http://127.0.0.1:3000/.well-known/jwks.json | jq .

# Expected: Should return public keys with key_ops: ["verify"]

# 3. Test OAuth flow
# Navigate to http://127.0.0.1:3000
# Click login, enter handle
# Should redirect to PDS, then back to 127.0.0.1:3000
```

## Quick Reference

```typescript
// Environment Detection
const isLoopback = baseUrl.includes('127.0.0.1') || baseUrl.includes('localhost');

// Build Client ID
const scope = isLoopback ? "atproto transition:generic" : "atproto";
const clientId = isLoopback
  ? `http://localhost?scope=${encodeURIComponent(scope)}&redirect_uri=${encodeURIComponent(redirectUri)}`
  : `${baseUrl}/client-metadata.json`;

// Build Redirect URI (MUST use IP for loopback)
const redirectUri = `${baseUrl}/api/auth/callback`;
// Ensure baseUrl uses 127.0.0.1 for loopback, not localhost
```

## References

- [RFC 8252: OAuth 2.0 for Native Apps](https://datatracker.ietf.org/doc/html/rfc8252)
  - Section 7.3: Loopback Interface Redirection
- [ATProto OAuth Spec](https://github.com/bluesky-social/atproto/tree/main/packages/oauth)
  - Loopback client implementation
- [RFC 7591: OAuth 2.0 Dynamic Client Registration](https://datatracker.ietf.org/doc/html/rfc7591)

---

**Last Updated**: February 2026  
**Spec Version**: ATProto OAuth (Next.js App Router compatible)
