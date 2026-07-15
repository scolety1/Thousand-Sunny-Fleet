# Deterministic Proof Matrix

| Proof | Assertions | Canonical outcome |
|---|---:|---|
| Exact approval | Included in 152 canonical assertions | One exact ledger record; revision 2; new queue/run; matcher pass; usage exhausted; original result immutable |
| Broader approval rejection | Included in 152 | Closed-input rejection plus direct canonical writer/matcher mutation probes for extra path, operation, reuse, repository/worktree, and cross-mission binding |
| Denial | Included in 152 | Immutable `TIM_REQUIRED_DENIED`; no approval/revision/queue/worker |
| Clarification | Included in 152 | Bounded response; revision 2; rerouting; new run; original immutable |
| Authority-changing clarification | Included in 152 | Fresh approval request; no worker before approval |
| HTTP/session/request binding/UI | 89 | Token, Host/Origin, JSON/size/shape, exact bindings, compatibility, double-click, and view controls pass |
| M2A exact adapter/request relay | 136 | Milestone 2A preview, exact response, session, and request-to-result behavior preserved |
| Optional lifecycle | 23 | Missing approval can reach canonical TIM only in the fixed executor path; direct callers still fail closed |
| Exact result evidence | 12 | Run/result/response hashes remain exact |
| Minimum kernel | 36 | Approval schema/matcher/kernel regressions pass |
| Mission queue | 8 | Canonical queue state machine regressions pass |
| Project Main Bot | 391 | Route, policy, mission, and stop-condition regressions pass |
| Recovery | 17 | Same-revision idempotency and no duplicate execution pass |
| Final authority | 34 | Verifier/admission/preservation authority remains canonical |
| Static integrity | Recorded in `VALIDATION.json` | Node/PowerShell syntax, JSON/CSV, protected paths, path budget, plugins, network posture, and `git diff --check` pass |

All PASS states are emitted only after assertions. Fixture artifacts stay below `.codex-local` and do not enter the candidate tree.
