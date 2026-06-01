# Stage 14 Phase 4 Prompt: Failure Injection

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 14 Phase 4 only: Failure Injection.

Goal:
Define controlled failure injections that prove the fleet fails safely.

Failure cases:
- build failure
- test failure
- runtime failure
- invalid RUN_RESULT
- missing evidence
- stale lock
- dirty repo without active owner
- invalid task packet
- stale task packet
- broad unsafe task
- backend-sensitive scope violation
- formula fixture mismatch
- low budget during active run
- report write failure
- audit package too large

For each failure define:
- setup
- expected state
- expected decision
- expected report
- whether repair is allowed
- what must not happen

Guardrails:
- Use fixtures/disposable ships.
- Do not inject failures into real product repos.
- Do not delete locks manually in real projects.
- Do not hide failures behind PARK.

Acceptance:
- Failure injection plan exists.
- Every critical failure has expected safe behavior.
- Repair/block/taste/wait outcomes are distinct.

Proof:
Show failure injection matrix.
```

## Notes

This is where we prove the fleet does not panic-code through danger.

## Implemented Failure Injection Matrix

| Failure | Expected State | Expected Decision | Repair Allowed | Must Not Happen |
| --- | --- | --- | --- | --- |
| build failure | REPAIRING | REPAIR | yes, bounded | mark complete |
| test failure | REPAIRING | REPAIR | yes, bounded | skip tests |
| runtime failure | REPAIRING/BLOCKED | REPAIR/BLOCK | maybe | continue feature work |
| invalid `RUN_RESULT` | BLOCKED | BLOCK | no | claim audit-ready |
| missing evidence | BLOCKED | BLOCK | no | hollow success |
| stale lock | BLOCKED | BLOCK | no manual delete | delete lock |
| dirty unowned repo | BLOCKED | BLOCK | no | edit user work |
| invalid task packet | BLOCKED | BLOCK | no | queue mutation |
| stale task packet | BLOCKED | BLOCK | no | import packet |
| broad unsafe task | BLOCKED | BLOCK | no | broad edit |
| backend-sensitive scope | BLOCKED | BLOCK | only after approval | casual mobile approval |
| formula mismatch | BLOCKED | BLOCK | yes after fixture update | fake confidence |
| low budget | RATE_LIMIT_PAUSED | WAIT_FOR_RATE_RESET | no model-heavy work | launch new work |
| report write failure | BLOCKED | BLOCK | no | continue without report |
| audit package too large | BLOCKED | PACKAGE_AUDIT/BLOCK | yes, reduce package | omit required evidence silently |
