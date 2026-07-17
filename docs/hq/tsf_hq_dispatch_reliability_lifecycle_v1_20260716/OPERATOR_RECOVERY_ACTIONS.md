# Operator Recovery Actions

The Recovery Center lists only canonical recoverable items. Every mutation requires the current item ID and evidence hash plus an exact confirmation equal to the selected action. The server reloads canonical records before acting; changed evidence returns conflict.

| Action | Effect | Immutable evidence |
|---|---|---|
| `ACKNOWLEDGE_COMPLETED` | Append idempotent non-authoritative acknowledgment | Completed mission/result/admission |
| `VIEW_CANONICAL_RECEIPT` | Read-only receipt projection | Everything |
| `RESPOND_TO_TIM_REQUIRED` | Rehydrate request into the fresh session and delegate to M2B response control | Original terminal run/thread/turn |
| `CREATE_NEW_REVISION` | Use canonical revision path when required | Prior revision and response |
| `RETRY_AS_NEW_RUN` | Revalidate/route and create new mission, queue, run, thread, turn, verifier, preservation, and admission identities | Interrupted/rejected source run |
| `MARK_PROCESS_INTERRUPTED` | Append stop record and exact queue snapshot after observed owned-child loss | Queue source and incomplete lifecycle truth |
| `RECONCILE_QUEUE_FROM_CANONICAL_RECEIPT` | Validate receipt/transaction/queue identities and delegate to canonical mover | Result, preservation, admission, source receipt |
| `DECLINE_RECOVERY` | Append idempotent decline receipt | Everything |
| `TIM_REQUIRED` | No mutation; request the missing authority | Everything |

Recovery receipts are append-only audit evidence, not approval or replay authority. Repeating the same evidence/action is idempotent; changed confirmation/content fails closed. There is no Reset, Force complete, Delete mission, Clear queue, Resume old thread, Retry same result, or arbitrary Kill process control.
