#!/usr/bin/env node

/**
 * Generate an ES256 (P-256) private key in JWK format for ATProto OAuth.
 *
 * Usage:
 *   node scripts/generate-oauth-key.js
 *
 * Prerequisites:
 *   npm install jose   (or bun add jose)
 *
 * Output:
 *   Prints the JWK as a single-line JSON string, ready to paste into .env.local
 *   as the OAUTH_PRIVATE_KEY value.
 */

const { generateKeyPairSync } = require("crypto");

async function main() {
  // Dynamic import because jose is ESM-only in newer versions
  const { exportJWK } = await import("jose");

  const { privateKey } = generateKeyPairSync("ec", {
    namedCurve: "P-256",
  });

  const jwk = await exportJWK(privateKey);
  jwk.kid = "key-1";
  jwk.alg = "ES256";
  // Note: key_ops is NOT added to private keys
  // The JWKS endpoint will add key_ops: ["verify"] when serving the public key

  const jwkString = JSON.stringify(jwk);

  console.log("");
  console.log("=== ES256 OAuth Private Key (JWK) ===");
  console.log("");
  console.log("Add this line to your .env.local:");
  console.log("");
  console.log(`OAUTH_PRIVATE_KEY='${jwkString}'`);
  console.log("");
  console.log("IMPORTANT: Never commit this key to version control.");
  console.log("NOTE: The JWKS endpoint will add key_ops: [\"verify\"] to the public key.");
  console.log("");
}

main().catch((err) => {
  console.error("Failed to generate key:", err);
  process.exit(1);
});
