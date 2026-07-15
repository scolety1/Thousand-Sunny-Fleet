# Status Projection

The API projects `PREPARING`, `QUEUED`, `DISPATCHING`, `RUNNING`, `VERIFYING`, `PRESERVING`, `TIM_REQUIRED`, `ADMITTED`, `ADMITTED_WITH_CAVEATS`, `REJECTED`, `FAILED`, and `INTERRUPTED` from existing canonical records.

Every event now contains a `result_id` field. Pre-result events set it to `null`; only a terminal result-bearing event projects the canonical result identity. A rejected projection with no durable result or admission receipt leaves both the top-level `result_id` and nested `result.result_id` null instead of deriving either from `run_id`. Mission, revision, run, result, adapter, worker exact evidence, verifier exact evidence, durable result, admission receipt, and structured observation claims are checked as one outcome identity before projection. Any cross-run or cross-result splice fails closed.

Completed identical replay reuses the same canonical terminal mission and preserves the same result ID. It does not execute the mission twice. A worker-green transport result without exact-response evidence or without an admission receipt remains rejected.

No percentages, implicit approvals, producer-only test success, worker-only success, verification, preservation, or admission are invented. Only `ADMITTED` and `ADMITTED_WITH_CAVEATS` from a canonical admission receipt are accepted terminal states.
