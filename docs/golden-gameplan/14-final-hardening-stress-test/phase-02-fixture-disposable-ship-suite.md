# Stage 14 Phase 2 Prompt: Fixture And Disposable Ship Suite

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 14 Phase 2 only: Fixture and Disposable Ship Suite.

Goal:
Define the safe test projects used to stress the fleet without risking real user work.

Fixture ships should include:
- clean ready website ship
- dirty unowned ship
- active running ship
- build-failing ship
- test-failing ship
- audit-ready ship
- packet-ready ship
- rate-paused ship
- taste-gated ship
- backend-sensitive blocked ship
- analytical formula-blocked ship

For each fixture define:
- setup
- expected state
- expected decision
- expected report
- cleanup rules
- what must not be touched

Guardrails:
- Fixture setup must not delete user work.
- Fixtures should be disposable.
- Do not repurpose real product repos for destructive tests.
- Do not launch real ships in this docs phase.

Acceptance:
- Fixture suite spec exists.
- Each fixture maps to a known state and decision.
- Cleanup expectations are explicit.

Proof:
Show fixture suite doc and mapping table.
```

## Notes

The fleet needs crash-test dummies, not real products in the blast radius.

## Implemented Fixture Suite

| Fixture | Expected State | Expected Decision | Cleanup | Must Not Touch |
| --- | --- | --- | --- | --- |
| `clean_ready_website` | READY | RUN_AGAIN | remove fixture root only | real repos, locks, secrets |
| `dirty_unowned_ship` | BLOCKED | BLOCK | preserve dirty proof | user work |
| `active_running_ship` | RUNNING | NOOP | leave active PID alone | active process |
| `build_failing_ship` | REPAIRING | REPAIR | fixture repair evidence | product repo |
| `test_failing_ship` | REPAIRING | REPAIR | fixture repair evidence | product repo |
| `audit_ready_ship` | AUDIT_READY | WAIT_FOR_EXTERNAL_AUDIT | keep package evidence | audit source |
| `packet_ready_ship` | PACKET_READY | WAIT_FOR_TASK_PACKET | keep validation evidence | unvalidated packet |
| `rate_paused_ship` | RATE_LIMIT_PAUSED | WAIT_FOR_RATE_RESET | keep resume metadata | budget bypass |
| `taste_gated_ship` | TASTE_GATE | USER_TASTE_GATE | keep screenshots | deterministic gates |
| `backend_sensitive_blocked_ship` | BLOCKED | BLOCK | keep approval note | auth/payment/deploy |
| `analytical_formula_blocked_ship` | BLOCKED | BLOCK | keep fixture mismatch | formula proof |

These fixtures are represented by `New-FleetStage14FixtureSuite`.
