---
name: gainforest-beads
description: GainForest beads (`bd`) planning workflow. Activates on ALL user work requests — task planning, epic management, claiming work, closing tasks with commit links, handling blockers. Use before writing any code.
compatibility: Requires bd CLI (npm install -g @beads/bd), git repository
metadata:
  author: gainforest
  version: "1.0"
---

# GainForest Beads Planning Workflow

Every user work request flows through beads (`bd`) — a git-backed graph issue tracker. This ensures that if you (the agent) lose all memory mid-task, any new agent can pick up exactly where you left off by reading the beads graph.

Run `bd onboard` and `bd prime` for full CLI documentation.

## When to Apply

**Every time a user asks you to do work.** Not just when they mention beads. This includes feature requests, bug fixes, refactors, investigations, and multi-step projects.

## Prerequisites

- `bd` CLI installed (`bd version` to check; install with `npm install -g @beads/bd`)
- Ask the user for their GitHub handle if you don't know it — you need it for every `create` and `claim`

## Critical Rules

1. **Sync first, always.** Start every session with:
   ```bash
   bd init --quiet
   bd sync
   ```
   This pulls the latest graph. Never work from stale state.

2. **Beads before code.** Plan in beads first. Check epics, create tasks, get user approval, claim — then write code.

3. **User owns everything.** Use `--assignee <user-github-handle>` on every `bd create`. The user is the creator and owner, not the agent.

4. **Tasks must survive memory loss.** Write each task so a fresh agent with zero context can execute it. Include:
   - **What** to change and **why**
   - **Where** in the codebase (file paths, component names)
   - **Acceptance criteria** (how to verify it's done)
   - **Dependencies** and why they exist

5. **Dependencies must be reasoned.** Don't add dependencies reflexively. Ask:
   - Does task B consume output from task A? → `bd dep add B A`
   - Must A be tested before B can integrate? → `bd dep add B A`
   - Same area but independent? → No dependency needed
   - Document the reasoning in the task description.

6. **Claim before working.** `bd update <id> --claim` before touching code.

7. **One task, then stop.** After closing a task, report to the user and STOP. Do not silently advance to the next task.

8. **Commit code before closing beads.** The git commit is proof of work. The beads close is bookkeeping. Never reverse this order.

9. **Always link the commit.** Close format: `bd close <id> --reason "Completed: <commit-hash>"`. No exceptions.

10. **Git commit the beads graph after every change.** After any `bd create`, `bd update`, or `bd close`:
    ```bash
    bd sync
    git add .beads/
    git commit -m "beads: <what changed>"
    ```
    This is how other agents and team members discover what you're working on.

11. **Blockers stop work.** If blocked, mark the task deferred and ask the user to file new tasks for the issue:
    ```bash
    bd update <id> --status deferred --notes "Blocked: <why>"
    ```

## Workflow

### Step 0: Sync

```bash
bd init --quiet
bd sync
```

### Step 1: Find or Create an Epic

```bash
bd list --type epic --json
```

If an epic matches the user's request, confirm with them. Otherwise:

```bash
bd create "Epic: <goal>" -t epic -p <priority> --assignee <handle> --json
bd sync && git add .beads/ && git commit -m "beads: create epic — <title>"
```

### Step 2: Plan Tasks with the User

Propose a task breakdown. Iterate until the user approves.

```bash
bd create "<task description>" -t task -p <priority> --parent <epic-id> --assignee <handle> --json
bd dep add <child-id> <parent-id>  # only when justified
```

After planning is finalized:

```bash
bd sync && git add .beads/ && git commit -m "beads: plan tasks for <epic-id>"
```

### Step 3: Claim and Execute

```bash
bd ready --json                    # see what's unblocked
bd update <task-id> --claim        # claim it
bd sync
```

Do the work.

### Step 4: Close the Task

```bash
# 1. Commit the code (include task ID)
git add <files>
git commit -m "<description> (<task-id>)"

# 2. Close with commit reference
bd close <task-id> --reason "Completed: <commit-hash>"

# 3. Sync the graph
bd sync
git add .beads/
git commit -m "beads: close <task-id>"
git push
```

**Then report to the user and stop.**

### Step 5: Handle Blockers

```bash
bd update <task-id> --status deferred --notes "Blocked: <description>"
bd sync && git add .beads/ && git commit -m "beads: defer <task-id> — <reason>"
```

Ask the user to file new tasks addressing the blocker.

## Resuming After Context Loss

```bash
bd init --quiet
bd sync
bd list --status open --status in_progress --json   # what's active?
bd ready --json                                      # what's unblocked?
bd show <id> --json                                  # read task details
```

In-progress tasks were claimed by someone (possibly you in a past session). Read their descriptions — they contain everything you need to continue.

## What Makes a Good Task Description

**Bad:**
> Fix the auth bug

**Good:**
> Fix OAuth callback race condition in `app/api/oauth/callback/route.ts`. When two callbacks arrive within 100ms, the second overwrites the first session in Supabase. Add a mutex or check-and-set pattern on the `atproto_oauth_session` table. Acceptance: concurrent callback test passes. Depends on bd-a3f8.1 (session store refactor) because the fix requires the new `upsert` method.
