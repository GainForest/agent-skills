# Comment Triage Guide

How to categorize, prioritize, and group CodeRabbit inline review comments into actionable beads tasks.

---

## 1. Comment Categories

| Category | Description | Example CodeRabbit Patterns |
|---|---|---|
| `bug` | Logic errors, null pointer risks, race conditions, incorrect return values | "This will throw if `user` is undefined", "Off-by-one error in loop bounds", "Return value is never checked" |
| `security` | Injection risks, auth bypasses, secret exposure, unsafe deserialization | "User input is passed directly to SQL query", "JWT is not verified before use", "API key is logged here" |
| `error-handling` | Missing try/catch, unhandled promise rejections, swallowed errors | "This `await` is not wrapped in try/catch", "Promise rejection is not handled", "Error is caught but not re-thrown or logged" |
| `type-safety` | Missing type annotations, unsafe casts, `any` usage, unjustified non-null assertions | "This is typed as `any`", "Non-null assertion `!` used without guard", "Return type is inferred as `unknown`" |
| `performance` | N+1 queries, unnecessary re-renders, missing memoization, large bundle imports | "This query runs inside a loop", "Component re-renders on every keystroke", "Entire lodash is imported instead of the single function" |
| `style` | Naming conventions, dead code, import ordering, formatting | "Variable name `d` is not descriptive", "This import is unused", "Prefer `const` over `let` here" |
| `nit` | Minor suggestions, alternative approaches, cosmetic preferences | "Consider using optional chaining here", "This could be written more concisely as…", "Minor: trailing whitespace" |

---

## 2. Priority Mapping

| Priority | Level | Categories |
|---|---|---|
| P1 | Critical — fix before merge | `bug`, `security` |
| P2 | Important — fix soon | `error-handling`, `type-safety` |
| P3 | Nice-to-have | `performance`, `style`, `nit` |

---

## 3. Grouping Strategy

Apply these rules in order. Stop at the first rule that matches.

1. **By file (same priority):** If 3 or more comments in the same file share the same priority level, group them into one task titled `Fix <category> issues in <filename>`.
2. **By theme (cross-file, same category):** If comments across different files share the same category (e.g., all are `error-handling`), group them into one task titled `Add <category> across <N> files`.
3. **Singleton:** If neither rule above applies, each comment becomes its own task.

**Hard constraints — never break these:**

- **Never group across priority levels.** A P1 bug and a P3 nit in the same file become two separate tasks.
- **Max 5–7 comments per task.** If a group exceeds this, split it into `Part 1`, `Part 2`, etc.
- **Each task must be completable independently.** If fixing comment B requires fixing comment A first, add a beads dependency.

---

## 4. When to Skip a Comment

Create no task for a comment if any of the following apply. Flag all skips to the user for confirmation.

| Skip Condition | Example |
|---|---|
| Comment is a question, not an actionable suggestion | "Why is this value hardcoded?" |
| Comment suggests an alternative that is equally valid | "You could also use `Array.from()` here" |
| Code was intentionally written that way | Non-null assertion on a value guaranteed by schema |
| Comment is a false positive (CodeRabbit misread the code) | Flagging a deliberate empty catch block that has a comment explaining why |

When skipping, note the reason so you can explain it to the user.

---

## 5. Example Triage

> **Comment 1** — `auth/session.ts:42`
> "This function returns `null` when the session is expired, but callers on lines 88 and 103 dereference the result without a null check."

- **Category:** `bug`
- **Priority:** P1
- **Decision:** Standalone task — critical, single file, single issue.

---

> **Comment 2** — `api/users.ts:17`
> "User-supplied `id` is interpolated directly into the SQL string. Use a parameterized query."

- **Category:** `security`
- **Priority:** P1
- **Decision:** Standalone task — security issues are always isolated for visibility.

---

> **Comment 3** — `api/posts.ts:55`, `api/comments.ts:30`, `api/likes.ts:12`
> All three: "This `await` call is not wrapped in try/catch."

- **Category:** `error-handling`
- **Priority:** P2
- **Decision:** Group by theme — same category, cross-file, same priority → one task: `Add error handling to API routes`.

---

> **Comment 4** — `utils/format.ts:8`
> "Consider renaming `fn` to something more descriptive."

- **Category:** `nit`
- **Priority:** P3
- **Decision:** Standalone task (only one comment in file at this priority).

---

> **Comment 5** — `components/Table.tsx:22`
> "Why is `pageSize` set to 50 here? Is this intentional?"

- **Category:** — (question, not actionable)
- **Priority:** —
- **Decision:** **Skip.** Flag to user: "CodeRabbit asked about `pageSize` on line 22 — confirm this is intentional so we can dismiss the comment."

---

> **Comment 6** — `lib/db.ts:10`, `lib/db.ts:34`, `lib/db.ts:67`
> All three: "This variable is typed as `any`."

- **Category:** `type-safety`
- **Priority:** P2
- **Decision:** Group by file — 3+ comments in the same file at the same priority → one task: `Fix type-safety issues in lib/db.ts`.
