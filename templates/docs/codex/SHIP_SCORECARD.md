# Ship Scorecard

Use this before giving a ship meaningful autonomous runtime. The goal is to prove the ship has a narrow useful job, a clear user, and a local way to evaluate progress.

## Summary

Ship name:

Primary user or buyer:

Weekly job this replaces:

First useful version:

Local evaluator:

Current recommendation: TODO: ADMIT / REVISE / PARK

## Admission Score

Score each row from 0 to the listed weight. Do not award points for vague intent; award points only when the answer is concrete enough to guide tasks.

| Criterion | Weight | Score | Evidence |
| --- | ---: | ---: | --- |
| Recurring pain | 20 | TODO | The user feels this at least weekly, preferably daily. |
| Clear buyer or user | 15 | TODO | The person who pays, approves, or uses it is named. |
| Local evaluability | 20 | TODO | Tests, fixtures, screenshot diffs, spreadsheet parity, deterministic outputs, or clear manual checks exist. |
| Thin first release | 10 | TODO | V1 is useful without auth, billing, complex integrations, or production data. |
| Bounded scope | 10 | TODO | One to three workflows, not a broad platform. |
| Revenue or demo speed | 10 | TODO | A useful demo or sellable v1 can exist within weeks. |
| Demo clarity | 5 | TODO | A stranger can understand the value in under one minute. |
| Fleet leverage | 5 | TODO | Design, copy, tests, visual review, repair, or formulas can be split into independent passes. |
| Data and compliance safety | 5 | TODO | Low-regret data and no regulated-data burden in v1. |
| Total | 100 | TODO | 70+ admit, 55-69 revise, below 55 park. |

## Red Flags

Mark any red flag that applies. A red flag blocks admission until the ship is redesigned or explicitly approved.

- [ ] Needs payments to be useful.
- [ ] Needs custom auth or account roles to be useful.
- [ ] Stores regulated, sensitive, payment, medical, payroll, tax, or private production data.
- [ ] Depends on many third-party integrations before v1 has value.
- [ ] Has no credible local evaluator.
- [ ] Has no named user workflow.
- [ ] Is broad, platform-shaped, or generic AI-wrapper-shaped.
- [ ] Requires live external APIs at decision time.

## Decision

Choose one:

- ADMIT: Score is 70+ and no red flags apply.
- REVISE: Score is 55-69 or the job/user/evaluator needs sharpening.
- PARK: Score is below 55, red flags apply, or the ship cannot prove local usefulness.

Decision:

Reason:

Next action:

