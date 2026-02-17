# Agent Skills

A collection of agent skills — structured instruction bundles that extend AI coding
assistants (Claude Code, Cursor, Copilot, etc.) with domain-specific knowledge.

Skills are loaded on-demand into the agent's context when the agent determines the
skill is relevant based on its name and description.

## Quick Start

```bash
npx skills add https://github.com/gainforest/agent-skills --skill gainforest-oauth-setup
```

Replace `gainforest-oauth-setup` with the name of the skill you want to install.

## Available Skills

| Skill | Description |
|-------|-------------|
| [gainforest-oauth-setup](skills/gainforest-oauth-setup/SKILL.md) | Implement ATProto OAuth in a Next.js App Router app using gainforest-sdk-nextjs |
| [coderabbit-review-resolver](skills/coderabbit-review-resolver/SKILL.md) | Fetch open CodeRabbit AI review comments from a GitHub PR, plan fixes as beads tasks, and dispatch workers to resolve them |

## How Skills Work

Each skill is a self-contained package containing:

- **SKILL.md** — The main instruction file with YAML frontmatter (name, description,
  compatibility, metadata). This is what gets loaded into the agent's context.
- **references/** — Supplementary docs (setup guides, troubleshooting) loaded only
  when needed.
- **scripts/** — Utility scripts the agent can run on behalf of the user.

Only the skill `name` and `description` are loaded at startup. The full content loads
only when the agent decides the skill is relevant, keeping context usage minimal.

## Installation

**Claude Code:**
```bash
cp -r skills/{skill-name} ~/.claude/skills/
```

**claude.ai:**
Add the skill's `SKILL.md` to project knowledge, or paste its contents into the
conversation.

## Creating a New Skill

See [AGENTS.md](AGENTS.md) for the full guide on directory structure, naming
conventions, SKILL.md format, and code style for embedded snippets.
