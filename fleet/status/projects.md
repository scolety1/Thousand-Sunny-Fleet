# Fleet Project Status Snapshot

Phone HQ is request/status only. It does not execute Codex, approve work, merge, push, or deploy.

This is a generated public-safe snapshot. It intentionally omits local filesystem paths, secrets, credentials, tokens, private device identifiers, and product/customer data.

Status can be stale until `tools/fleet-project-status.ps1` is regenerated and the snapshot is separately reviewed/published.

| Project | Status | Branch | Clean | Checkpoint | Build | Pending | Next action |
| --- | --- | --- | --- | --- | --- | ---: | --- |
| PrivateLens | GREEN | codex/experiment-PrivateLens-20260611-010133 | clean | GREEN | Passed | 0 | Human review next; queue one bounded task when ready. |
| Bottlelight | YELLOW | master | clean | YELLOW | Quarantined | 2 | Request one-project proof run for the next queued task. |
| CursorPets | YELLOW | codex/cursor-pets-CursorPets-20260425-034126 | clean | YELLOW | Passed | 0 | Review evidence before requesting more work. |
| EasyLife | YELLOW | codex/product-EasyLife-20260504-231503 | clean | UNKNOWN | Not run; docs-only final handoff with no app code changes. | 6 | Request one-project proof run for the next queued task. |
| EventBook | YELLOW | master | clean | YELLOW | Passed | 4 | Request one-project proof run for the next queued task. |
| FinanceDecisionLab | YELLOW | master | clean | YELLOW | Quarantined | 0 | Review evidence before requesting more work. |
| ForecastLab | YELLOW | master | clean | YELLOW | Quarantined | 0 | Review evidence before requesting more work. |
| LifeCapacity | YELLOW | master | clean | YELLOW | Quarantined | 0 | Review evidence before requesting more work. |
| LineupLab | YELLOW | master | clean | YELLOW | Quarantined | 5 | Request one-project proof run for the next queued task. |
| NinersWarRoom | RED | nwr-outcome-build-sprint-1-scoring-labels | dirty | RED | Quarantined | 0 | Review local changes before requesting work. |
| OrderPilot | RED | master | dirty | RED | Blocked | 1 | Review local changes before requesting work. |
| RestaurantDemo | RED | main | clean | RED | Quarantined | 10 | Request one-project proof run for the next queued task. |
| RestaurantProfitLab | YELLOW | master | clean | YELLOW | Quarantined | 0 | Review evidence before requesting more work. |
| ShiftLedger | YELLOW | master | clean | YELLOW | Quarantined | 2 | Request one-project proof run for the next queued task. |
| ShiftPlate | RED | codex/special-sauce-SpecialSauce-20260425-034127 | clean | RED | Passed | 0 | Review evidence before requesting more work. |
| Tree | YELLOW | codex/tree-Tree-20260425-235451 | clean | YELLOW | Passed | 0 | Review evidence before requesting more work. |
| UrbanKitchenSite | GREEN | master | clean | GREEN | Passed | 0 | Human review next; queue one bounded task when ready. |

Controls are request-only links: quick mission request, cooperative stop request, and status/log navigation. They are not command execution or approval.
