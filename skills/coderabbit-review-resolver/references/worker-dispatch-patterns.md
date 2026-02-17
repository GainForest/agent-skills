# Worker Dispatch Patterns

Reference for creating well-scoped beads task descriptions from CodeRabbit review comments, suitable for dispatch to @worker agents.

---

## 1. Task Description Template

Use this fill-in-the-blank template when creating a beads task from a CodeRabbit comment:

```
## Files
- {file_path} (modify)

## What to do
CodeRabbit flagged: {category} issue at line {line}.

**Original comment:**
> {comment body}

**Suggested fix:**
{extracted suggestion or agent's interpretation}

**Context:**
{any additional context about the surrounding code}

## Don't
- Don't change unrelated code in the same file
- Don't introduce new dependencies unless the comment specifically requires it
```

**Field guide:**

| Field | What to put |
|---|---|
| `{file_path}` | Repo-relative path, e.g. `src/lib/auth.ts` |
| `{category}` | One of: `bug`, `security`, `error-handling`, `type-safety`, `performance`, `style`, `nit` (see [comment-triage-guide.md](comment-triage-guide.md)) |
| `{line}` | Line number from the CodeRabbit comment |
| `{comment body}` | Exact text of the CodeRabbit comment, unedited |
| `{extracted suggestion}` | The concrete change needed; paraphrase if CodeRabbit was vague |
| `{context}` | Function name, surrounding logic, or why the fix matters |

---

## 2. Acceptance Criteria Template

The `--acceptance` flag content must be binary pass/fail — no subjective language.

**Pattern:**
```
{Specific observable outcome}. {Second observable outcome if needed}.
```

**Examples (good):**
- `The function returns early when input is null instead of throwing a TypeError. No existing tests are broken.`
- `The try/catch block in handleSubmit catches the error and logs it with console.error. The error is not re-thrown.`
- `The import of lodash is removed. The equivalent logic uses native Array methods.`

**Anti-patterns (bad):**
- `The code is cleaner.` ← subjective
- `The bug is fixed.` ← not observable
- `Looks good.` ← meaningless

**Rule:** A worker who has never seen the PR must be able to run a check and get a clear yes/no.

---

## 3. Grouping Multiple Comments into One Task

Group comments when they share a theme and affect the same file or tightly coupled files.

**When to group:**
- Same root cause (e.g., missing null checks throughout one module)
- Same file, same function
- Cosmetic fixes (style, naming) across a single file

**When NOT to group:**
- Different files with unrelated logic
- One is a bug fix, another is a refactor — keep separate so workers don't conflict

**Template for grouped tasks:**

```
## Files
- {file_path_1} (modify)
- {file_path_2} (modify)

## What to do
CodeRabbit flagged {N} related issues:

1. [{category}] Line {line}: {comment body 1}
2. [{category}] Line {line}: {comment body 2}
3. [{category}] Line {line}: {comment body 3}

**Suggested fixes:**
1. {fix for comment 1}
2. {fix for comment 2}
3. {fix for comment 3}

## Don't
- Don't change unrelated code in the same files
- Don't introduce new dependencies unless a comment specifically requires it
```

**Acceptance criteria for grouped tasks** must cover every comment:
```
Issue 1: {observable outcome}. Issue 2: {observable outcome}. Issue 3: {observable outcome}.
```

**Priority:** Use the highest priority among the grouped comments.

---

## 4. Time Estimation Heuristics

| Scope | Estimate | `-e` flag |
|---|---|---|
| Single comment, single file, clear fix | 15 min | `-e 15` |
| 2–3 comments, single file | 30 min | `-e 30` |
| 3–5 comments, multiple files, same theme | 45 min | `-e 45` |
| Complex refactor suggested | 60 min | `-e 60` |

When in doubt, round up. Workers should not be time-pressured into cutting corners.

---

## 5. Dispatch Command Pattern

Create each task with the full set of flags:

```bash
hb create "<title>" -t task -p <priority> --parent <epic-id> \
  -d "<description per template above>" \
  --acceptance "<binary pass/fail criteria>" \
  -e <minutes> \
  -l scope:small \
  --json
```

**Priority:** Use the priority already assigned during Phase 2 triage (P1/P2/P3 mapped from category). Do not re-derive priority from CodeRabbit's severity labels.

After creating all tasks, commit the plan:

```bash
hb sync && git add .beads/ && git commit -m "beads: plan CodeRabbit fixes for PR #<N>" && git push
```

Then tell the user which task IDs are ready for dispatch. Tasks with no dependencies can be dispatched in parallel:

```
Ready for dispatch:
- <epic-id>.1: <title> (P1, 15m)
- <epic-id>.2: <title> (P2, 30m)
- <epic-id>.3: <title> (P3, 15m)

Dispatch with: @worker <epic-id>.1
```

---

## 6. Verification After Workers Complete

Once all dispatched workers have closed their tasks:

1. **Review the aggregate diff:**
   ```bash
   git diff <base-branch>...HEAD
   ```

2. **Check for seam issues:**
   - Conflicting imports or duplicate declarations
   - Broken references between files workers touched independently
   - Type errors introduced by partial changes

3. **If seam issues found:** Create follow-up tasks using the same template above.

4. **If clean:** Mark the epic for integration review:
   ```bash
   hb update <epic-id> --add-label needs-integration-review
   hb sync && git add .beads/ && git commit -m "beads: mark <epic-id> for review" && git push
   ```
