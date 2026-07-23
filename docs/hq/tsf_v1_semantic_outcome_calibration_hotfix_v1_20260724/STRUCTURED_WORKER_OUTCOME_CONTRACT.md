# Structured worker outcome contract

New GENERAL_RESULT_V2 missions use:

- `tsf_task_completion_contract_v2`
- `tsf_worker_outcome_claim_v2`

The worker claim is closed to:

- mission, revision, run, intent, scope, task-contract, and attempted-task identities;
- `task_attempted`;
- `task_completed`;
- `outcome_disposition`;
- `completed_deliverables`;
- `missing_deliverables`;
- `blocked_reason`;
- `substantive_answer`;
- `evidence`;
- `caveats`.

Affirmative dispositions require `task_attempted=true`, `task_completed=true`, `blocked_reason=NONE`, a complete deliverable partition, valid content, and all required deliverables independently observed. Non-success dispositions require `task_completed=false` and a bounded non-`NONE` reason consistent with the disposition.

The worker cannot set canonical semantic success, verifier GREEN, admission, approval, merge, deployment, or production state. Additional fields are rejected.

V1 claim parsing is retained only to identify legacy structure. It cannot satisfy new admission.
