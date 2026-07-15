# Status Projection

The API can project `PREPARING`, `QUEUED`, `DISPATCHING`, `RUNNING`, `VERIFYING`, `PRESERVING`, `TIM_REQUIRED`, `ADMITTED`, `ADMITTED_WITH_CAVEATS`, `REJECTED`, `FAILED`, and `INTERRUPTED`.

Events retain mission/revision, run identity, timestamp, source record/path, assurance, and explanation. `VERIFYING` and `PRESERVING` are emitted only when their canonical records exist. A missing expected output now points at the last existing canonical queue record instead of an unwritten path.

No percentages, implicit approvals, worker-only success, verification, or admission are invented. Only `ADMITTED` and `ADMITTED_WITH_CAVEATS` from a canonical admission receipt are accepted terminal states.
