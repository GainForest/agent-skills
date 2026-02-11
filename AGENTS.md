# AGENTS.md

Guidance for AI coding agents (Claude Code, Cursor, Copilot, etc.) working in this repository.

## Repository Overview

A collection of agent skills — structured instruction bundles that extend AI coding assistants
with domain-specific knowledge. Each skill is a self-contained package of Markdown documentation,
reference material, and utility scripts. Skills are loaded on-demand into the agent's context
when the agent determines the skill is relevant based on its name and description.

This is **not** a traditional application codebase. There is no build system, package manager,
test framework, linter, or CI pipeline. The primary artifact is well-structured Markdown.

## Build / Lint / Test Commands

There are none. This repo contains only Markdown docs and utility scripts.

To run the single existing utility script:

```bash
# Requires: npm install jose (or bun add jose)
node skills/gainforest-oauth-setup/scripts/generate-oauth-key.js
```

To validate Markdown structure, manually check that every skill directory contains a `SKILL.md`
with valid YAML frontmatter (see format below).

## Directory Structure

```
skills/
  {skill-name}/                    # The skill directory (kebab-case)
    SKILL.md                       # Required: skill definition with YAML frontmatter
    references/                    # Optional: supplementary docs loaded on-demand
      {topic}.md
    scripts/                       # Optional: utility scripts bundled with the skill
      {script-name}.js
```

### Current Skills

```
skills/
  gainforest-oauth-setup/
    SKILL.md                       # ATProto OAuth implementation guide
    references/
      local-development.md         # Loopback URL setup for dev
      supabase-tables.md           # SQL DDL for required tables
      troubleshooting.md           # Common errors and fixes
    scripts/
      generate-oauth-key.js        # ES256 key generator (requires jose)
  gainforest-beads/
    SKILL.md                       # Beads planning workflow for all coding tasks
```

## Creating a New Skill

### Naming Conventions

- **Skill directory**: `kebab-case` (e.g., `gainforest-oauth-setup`)
- **SKILL.md**: Always uppercase, always this exact filename
- **Reference files**: `kebab-case.md` (e.g., `local-development.md`, `supabase-tables.md`)
- **Scripts**: `kebab-case.js` (e.g., `generate-oauth-key.js`)

### SKILL.md Format

Every `SKILL.md` must start with YAML frontmatter:

```markdown
---
name: {skill-name}
description: {One sentence. Include trigger phrases so agents know when to activate.}
compatibility: {Runtime/framework requirements}
metadata:
  author: {author}
  version: "{semver}"
---

# {Skill Title}

{Brief description of what the skill does.}

## When to Apply

Use this skill when:
- {Trigger condition 1}
- {Trigger condition 2}

## Prerequisites

Before starting, verify:
- {Requirement 1}
- {Requirement 2}

## Critical API Rules

{Non-obvious gotchas that cause runtime failures. Number them.}

## Implementation Steps

{Numbered steps. Each step produces one file. Include full code blocks.}

## Import Reference

{Table of import paths and their exports.}

## Expected File Structure

{Tree showing what the target project should look like after implementation.}
```

### Context Efficiency Best Practices

Only the skill `name` and `description` are loaded at startup. The full `SKILL.md` loads
into context only when the agent decides the skill is relevant. To minimize context usage:

- **Keep SKILL.md under 500 lines** — put detailed reference material in `references/`
- **Write specific descriptions** in frontmatter — helps agents activate the right skill
- **Use progressive disclosure** — link to `references/` files that load only when needed
- **Prefer scripts over inline code** — script execution doesn't consume context
- **Reference files with relative paths**: `[label](references/file.md)` or `[label](scripts/file.js)`

### Script Requirements

Scripts bundled with skills should:

- Include a descriptive JSDoc header explaining usage and prerequisites
- Declare dependencies explicitly in the header comment (no `package.json` exists)
- Use `console.error` for status messages, `console.log` for machine-readable output
- Handle errors with `.catch()` at the top level, calling `process.exit(1)` on failure

## Code Style for Embedded Snippets

Skills contain TypeScript/JavaScript code examples. Follow these conventions for consistency:

### Imports

- **Named imports only** — no default imports
- **Destructured**: `import { createATProtoSDK } from "gainforest-sdk-nextjs/oauth"`
- **Ordering**: Node.js built-ins, then third-party packages, then local (`@/lib/...`)
- **Path aliases**: Use `@/` for project-local imports in Next.js examples

### Naming

| Context            | Convention          | Example                          |
|--------------------|---------------------|----------------------------------|
| Variables          | camelCase           | `atprotoSDK`, `oauthSession`    |
| Functions          | camelCase           | `getAppSession`, `handleSubmit` |
| Components         | PascalCase          | `LoginForm`, `SessionProvider`  |
| Classes            | PascalCase          | `GainForestSDK`, `Agent`        |
| Constants (env)    | SCREAMING_SNAKE     | `APP_ID`, `PUBLIC_URL`          |
| Files/directories  | kebab-case          | `login-form.tsx`, `generate-oauth-key.js` |

### Functions

- **Named/exported functions**: use `function` keyword — `export async function GET()`
- **Callbacks and assigned functions**: use arrow syntax — `const handler = (req) => ...`
- **Re-exports**: `export { handler as GET, handler as POST }`

### Exports

- **Named exports only** — never use `export default`
- **`export const`** for SDK instances and configuration objects
- **`export async function`** for route handlers
- **`export function`** for React components

### Error Handling

- **try/catch** in every route handler and async function
- **Log with context**: `console.error("Authorization error:", error)`
- **Return structured errors**: `NextResponse.json({ error: "message" }, { status: 500 })`
- **Discriminate error types**: `err instanceof Error ? err.message : "An error occurred"`
- **Catch variables are untyped** (implicit `unknown`)

### Types

- **Non-null assertions** on `process.env` values: `process.env.NEXT_PUBLIC_APP_URL!`
- **Return types** only on helper functions: `Promise<Agent>` — route handlers omit them
- **No explicit interfaces/types** unless necessary — rely on library type inference
- **No `any`** — let TypeScript infer or use library-provided types

### Comments

- **JSDoc blocks** for file-level documentation (script headers)
- **Inline `//` comments** for single-line clarifications within code
- **`// WRONG` / `// CORRECT`** pattern for illustrating anti-patterns
- Keep comments terse and action-oriented

## File Conventions

- All Markdown files use `.md` extension
- All scripts use `.js` extension (CommonJS with dynamic ESM import where needed)
- Code blocks in Markdown specify the language: ` ```typescript `, ` ```bash `, ` ```sql `
- Tables use GitHub-flavored Markdown pipe syntax
- Environment variable examples use ` ```env ` code blocks
