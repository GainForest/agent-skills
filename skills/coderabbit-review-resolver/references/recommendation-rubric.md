# Recommendation Rubric

Use this rubric to decide whether each CodeRabbit comment should be `do now`, `do later`, or `skip`.

---

## 1. Score the Comment

Assign four dimensions:

| Dimension | Values | Guidance |
|---|---|---|
| Effort | `S`, `M`, `L`, `XL` | Time + complexity + test blast radius |
| Impact | `high`, `medium`, `low` | Expected user/system benefit if fixed |
| Risk if ignored | `high`, `medium`, `low` | Likelihood/severity of negative outcome |
| Confidence | `high`, `medium`, `low` | How certain you are the issue is real |

Effort bands:
- `S`: small, localized change, minimal verification
- `M`: moderate change across one module, some testing needed
- `L`: cross-module updates or behavior-sensitive refactor
- `XL`: architecture-level or broad refactor with high verification cost

---

## 2. Decision Rules

Apply in order:

1. If confidence is low and false-positive likelihood is high -> `skip`
2. If risk if ignored is high and confidence is medium/high -> `do now`
3. If impact is high and effort is `S`/`M` -> `do now`
4. If issue is valid but effort is `L`/`XL` and risk if ignored is low/medium -> `do later`
5. If issue is mostly preference/style and project conventions are already met -> `skip`

---

## 3. Severity Overrides

Use these overrides when applicable:

- Security concerns with plausible exploit path: bias to `do now`
- Runtime crash/data corruption path: bias to `do now`
- Pure naming/formatting suggestion without defect: bias to `skip`
- Broad refactor requested by comment with limited immediate benefit: bias to `do later`

---

## 4. Output Template

Use this shape for consistent reporting:

```text
Comment <N> - <path>:<line>
- Effort: <S|M|L|XL>
- Impact: <high|medium|low>
- Risk if ignored: <high|medium|low>
- Confidence: <high|medium|low>
- False-positive likelihood: <low|medium|high>
- Recommendation: <do now|do later|skip>
- Why: <single sentence describing tradeoff>
```

---

## 5. Portfolio-Level Prioritization

After per-comment decisions, prioritize implementation in this order:

1. `do now` items with high risk if ignored
2. `do now` items with high impact and low effort
3. `do later` items with medium/high impact
4. `skip` items (document rationale only)

Provide an estimated total effort for the `do now` group.
