# Deterministic Recovery Matrix

`tests/test-tsf-hq-dispatch-reliability-v1.mjs` executes all 21 isolated TSF-local scenarios. It passed 60 assertions. Every row asserts immutable canonical history, no completed rerun, no inferred approval, an evidence-bound action, and exact local cleanup/receipt behavior where applicable.

| # | Scenario | Expected disposition |
|---:|---|---|
| 1 | Clean startup | Safe, empty reconciliation |
| 2 | Second-instance rejection | Exclusive owner claim rejected |
| 3 | Occupied port | `UNSAFE_TO_START`; unrelated listener preserved |
| 4 | Stale owner/no process | `ACTION_REQUIRED`; explicit stale recovery only |
| 5 | Owner points to unrelated process | PID/start mismatch; unrelated process preserved |
| 6 | Active mission/confirmed child | `RUNNING_PROCESS_CONFIRMED`; no retry |
| 7 | Child exits/no terminal | `INTERRUPTED_PROCESS_GONE`; new run required |
| 8 | Interrupted canonical mission | Stop record/snapshot; no completion or rerun |
| 9 | Completed admitted after restart | Existing completed mission; acknowledgment only |
| 10 | TIM_REQUIRED pending | Exact canonical response path |
| 11 | TIM_REQUIRED answered/new revision | Existing response/revision; no second answer |
| 12 | Stale queue/valid receipt | Admission mismatch; receipt-bound reconciliation only |
| 13 | Result without admission | No admission inferred; Tim/canonical control required |
| 14 | Verifier rejection | Completed rejected; no automatic retry |
| 15 | Exact duplicate submission | `IDEMPOTENT_REPLAY`; no execution |
| 16 | Changed-content replay | `CONFLICTING_REPLAY`; reconciliation stops |
| 17 | Duplicate response | Same idempotent receipt returned |
| 18 | Shutdown during execution | Interrupted remains incomplete/non-resumable |
| 19 | Orphan listener | Unsafe; no listener owner killed/adopted |
| 20 | Recovery retry | New run identity and parent receipt |
| 21 | Demo reset | Only exact demo root removed; sibling preserved |

Additional proofs:

- `test-tsf-hq-dispatch-start-stop-v1.mjs`: 24 Start/Doctor/Stop fixture-process assertions.
- `test-tsf-hq-dispatch-demo-v1.mjs`: 20 M1/M2A/M2B demo assertions.
- `test-tsf-hq-dispatch-restart-tim-v1.mjs`: terminal request rehydration, no automatic response, new revision/run, old run unchanged.
