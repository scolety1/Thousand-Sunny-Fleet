# Stage 8.5 Through Stage 11 Test Summary

Status: GREEN

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

Latest verified result: exit code `0`.

## Key Test Groups

| Area | Result | What The Tests Prove |
| --- | --- | --- |
| Stage 8.5 autonomy hardening | GREEN | Missing scope fails contained, corrupt state writes a report, packet import requires real validation evidence, default `MaxShips` blocks accidental multi-ship runs, and manual `LowTokenMode` blocks implementation actions. |
| Stage 9 external agent workflow | GREEN | External-agent prompts are generated locally, agents are reviewers only, structured responses validate, stale/unsafe packets are rejected, and multi-agent comparison separates accepted/rejected work. |
| Stage 9.5 review reliability | GREEN | Missing fields, unknown roles, invalid verdicts, malformed JSON, forbidden patterns, and taste disagreements are handled safely; taste disagreement routes to `NEEDS_CAPTAIN`. |
| Stage 10 overnight mode | GREEN | Healthy budget allows bounded planning, low/critical budget blocks or safe-lands, exhausted budget waits for reset, recovered budget can resume eligible fixtures, taste-gated ships do not resume, and retry caps stop loops. |
| Stage 11 specialized lanes | GREEN | Five lane IDs exist, each has gates/evidence, hospitality/manager/analytical/backend/maintenance examples route correctly, backend-sensitive scope overrides normal lanes, and maintenance cannot become broad redesign silently. |

## Audit Use

The full transcript is intentionally preserved in audit packages for exact
evidence. This summary is the phone-readable and reviewer-readable index so an
auditor can quickly confirm which critical behaviors were covered.

