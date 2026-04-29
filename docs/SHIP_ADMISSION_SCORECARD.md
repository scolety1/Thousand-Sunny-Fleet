# Ship Admission Scorecard

Codex Fleet should spend runtime on ships that solve a narrow, recurring job and can be evaluated locally. This scorecard is the shared rule for deciding whether a ship should run, be sharpened, or be parked.

## Scoring

| Criterion | Weight | Good answer |
| --- | ---: | --- |
| Recurring pain | 20 | A user feels this problem at least weekly, preferably daily. |
| Clear buyer or user | 15 | The payer, approver, or daily user is obvious. |
| Local evaluability | 20 | Tests, fixtures, screenshots, spreadsheet parity, deterministic outputs, or manual checks can prove progress. |
| Thin first release | 10 | V1 works without accounts, billing, production backends, or heavy integrations. |
| Bounded scope | 10 | One to three workflows, not a platform. |
| Revenue or demo speed | 10 | A demo or sellable v1 can exist within weeks. |
| Demo clarity | 5 | A stranger understands the value in under one minute. |
| Fleet leverage | 5 | Multiple fleet passes can help without stepping on each other. |
| Data and compliance safety | 5 | Low-regret data and low compliance risk. |

## Decision Bands

- `70+`: admit the ship.
- `55-69`: revise the concept or task plan before running.
- `<55`: park the ship.
- Any red flag: block admission until redesigned or explicitly approved.

## Red Flags

- Needs payments to be useful.
- Needs custom auth or account roles to be useful.
- Stores regulated, sensitive, payment, medical, payroll, tax, or private production data.
- Depends on many third-party integrations before v1 has value.
- Has no credible local evaluator.
- Has no named user workflow.
- Is broad, platform-shaped, or generic AI-wrapper-shaped.
- Requires live external APIs at decision time.

## Required Output

Every admitted ship should eventually have a filled copy of `docs/codex/SHIP_SCORECARD.md` with:

- ship name
- primary user or buyer
- weekly job replaced
- first useful version
- local evaluator
- weighted score
- red flag check
- `ADMIT`, `REVISE`, or `PARK`

