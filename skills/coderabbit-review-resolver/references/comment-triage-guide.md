# Comment Triage Guide

How to classify and assess CodeRabbit inline review comments for practical decision-making.

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
| `nit` | Minor suggestions, alternative approaches, cosmetic preferences | "Consider using optional chaining here", "This could be written more concisely as...", "Minor: trailing whitespace" |

---

## 2. Priority Mapping

| Priority | Level | Categories |
|---|---|---|
| P1 | Critical - fix before merge when valid | `bug`, `security` |
| P2 | Important - fix soon when valid | `error-handling`, `type-safety` |
| P3 | Nice-to-have | `performance`, `style`, `nit` |

Priority signals urgency, not certainty. A P1 can still be a false positive.

---

## 3. Confidence and False-Positive Heuristics

Assign both fields independently.

| Dimension | High | Medium | Low |
|---|---|---|---|
| Confidence in claim | Clear code path and reproducible concern | Plausible issue, missing some context | Ambiguous or contradicted by nearby code/contracts |
| False-positive likelihood | Strong evidence issue is real | Could be real but uncertain | Likely misread by bot or intentionally designed behavior |

### Strong false-positive signals

- Comment ignores guard/validation that exists earlier in the call path
- Comment misses framework/runtime guarantees (schema validation, generated types)
- Suggestion conflicts with intentional behavior documented in code comments/tests
- Comment is purely stylistic while current code follows project conventions

---

## 4. Recommendation Mapping

Map each comment to one action:

- `do now`: High impact or high risk if ignored, with acceptable effort
- `do later`: Valid issue, but urgency is lower or effort is comparatively high
- `skip`: Likely false positive, preference-only suggestion, or poor ROI

Always include one sentence explaining the tradeoff behind the recommendation.

---

## 5. Triage Examples

> **Comment 1** - `auth/session.ts:42`
> "This function returns `null` when the session is expired, but callers on lines 88 and 103 dereference the result without a null check."

- **Category/Priority:** `bug` / P1
- **Confidence:** high
- **False-positive likelihood:** low
- **Recommendation:** `do now`
- **Why:** high probability runtime error on an expected path.

---

> **Comment 2** - `api/users.ts:17`
> "User-supplied `id` is interpolated directly into the SQL string. Use a parameterized query."

- **Category/Priority:** `security` / P1
- **Confidence:** high
- **False-positive likelihood:** low
- **Recommendation:** `do now`
- **Why:** potential injection vector with high impact.

---

> **Comment 3** - `components/Table.tsx:22`
> "Why is `pageSize` set to 50 here? Is this intentional?"

- **Category/Priority:** question / n/a
- **Confidence:** low
- **False-positive likelihood:** high
- **Recommendation:** `skip` (or convert to team discussion)
- **Why:** no concrete defect described.

---

> **Comment 4** - `lib/db.ts:10`
> "This variable is typed as `any`."

- **Category/Priority:** `type-safety` / P2
- **Confidence:** medium
- **False-positive likelihood:** medium
- **Recommendation:** `do later`
- **Why:** valid maintainability issue, but lower immediate risk than correctness/security defects.
