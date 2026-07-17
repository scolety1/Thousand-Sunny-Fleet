# Failure Injection Matrix

`tests/test-tsf-hq-dispatch-reliability-v1.mjs` passed 60 assertions across all 21 required scenarios. Every scenario asserts immutable history, no completed rerun, no inferred approval, exact operator action, and cleanup/receipt behavior where applicable.

| # | Scenario | Result |
|---:|---|---|
| 1 | Clean startup | Safe empty reconciliation |
| 2 | Second instance | Valid owner rejected |
| 3 | Occupied port | Unsafe; unrelated listener preserved |
| 4 | Stale owner/no process | Explicit stale disposition |
| 5 | Owner points to unrelated process | Identity mismatch; process preserved |
| 6 | Active mission/owned child | `RUNNING_PROCESS_CONFIRMED` |
| 7 | Child exits before terminal | `INTERRUPTED_PROCESS_GONE` |
| 8 | Interrupted canonical mission | Incomplete preserved; no rerun |
| 9 | Completed admitted after restart | Existing completion acknowledged only |
| 10 | TIM_REQUIRED pending | Canonical response action only |
| 11 | TIM_REQUIRED answered | Existing response/new revision linked |
| 12 | Stale queue/valid receipt | Receipt-bound review only |
| 13 | Result without admission | No acceptance inferred |
| 14 | Verifier rejection | Rejected remains rejected |
| 15 | Exact duplicate submission | Idempotent existing mission |
| 16 | Changed-content replay | Conflict fails closed |
| 17 | Duplicate response | Idempotent existing response |
| 18 | Shutdown during execution | Interrupted incomplete state |
| 19 | Orphan listener | Unsafe; no arbitrary kill |
| 20 | Recovery retry | Distinct run and parent receipt |
| 21 | Demo reset | Only exact demo root affected |

Additional behavioral suites: Start/Doctor/Stop 24 assertions, Demo 20, interruption-seam safety 25, and real interruption/recovery 83.
