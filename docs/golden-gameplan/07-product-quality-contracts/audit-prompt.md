# Golden Gameplan Stage 7 Audit Prompt

Use this prompt after Stage 7 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 7: Product Quality Contracts.

Goal of Stage 7:
The fleet should have explicit contracts for product usefulness, first-screen clarity, information hierarchy, simplicity, done criteria, and taste gates.

Please review the provided audit package, docs, templates, examples, tests, and sample product-quality verdicts.

Important distinction:

- "Missing from package" means the file or proof was not included in the zip.
- "Missing from repo/implementation" means the package includes enough evidence to show the file or proof does not exist in the repo.
- "Missing evidence" means the file may exist, but the package does not prove the claim with tests, run evidence, or a clear report.

Do not treat a package omission as a repo implementation failure unless the package also includes repo evidence proving the file is absent.

Audit questions:

1. Do the contracts directly address the user's problem that fleet websites were pretty but overwhelming?
2. Is the first-screen contract clear enough to guide future implementation tasks?
3. Does the information hierarchy contract distinguish primary, secondary, tertiary, and hidden/admin content?
4. Does the simplicity gate avoid both extremes: clutter and lifeless minimalism?
5. Are customer-facing hospitality demos clearly different from manager-facing operations demos?
6. Are analytical tools treated differently from marketing websites?
7. Are done contracts and taste gates meaningfully different?
8. Can Stage 6 decisions use the product-quality evidence later?
9. Are examples concrete enough for another Codex agent to follow?
10. Is anything too vague, too broad, or likely to cause filler tasks?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Package completeness findings.
- Repo implementation completeness findings.
- Evidence completeness findings.
- Any missing contract fields.
- Any lane profile that needs tightening.
- Any examples that are too vague.
- Recommended fixes before implementing Stage 8.

Do not recommend redesigning real products yet. This audit is about the quality system, not the current apps.
```
