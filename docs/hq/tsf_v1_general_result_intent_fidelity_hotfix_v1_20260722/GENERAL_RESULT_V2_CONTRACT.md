# GENERAL_RESULT_V2

Schemas: `fleet/control/task-completion-contract.schema.v1.json` and `fleet/control/general-result-v2.schema.v1.json`.

Mission preparation binds the exact authorized task, required/optional deliverables, output format, evidence rules, partial policy, success criteria, fail-closed conditions, and original-intent/scope identities. The worker receives a closed JSON outcome-claim format. Its claim is evidence only; it cannot set verifier, admission, approval, or mission identity.

Canonical dispositions are `FULFILLED`, `FULFILLED_WITH_CAVEATS`, `PARTIAL`, `UNABLE_TO_PERFORM`, `REFUSED`, `BLOCKED_BY_POLICY`, `NEEDS_CLARIFICATION`, `REQUIRED_DELIVERABLE_MISSING`, `WRONG_TASK_PERFORMED`, `FAILED`, and `UNCLASSIFIED_RESULT`.

The adapter reports transport independently and never calls a general result semantic success. Lifecycle parses the closed claim, validates mission/revision/run plus task/intent/scope hashes, rejects unclosed fields, detects inability/refusal/policy/clarification/unsupported text, checks required deliverables and a substantive answer, and emits semantic success only for an accepted disposition. The mapper/verifier reproduce that evidence, while admission separately checks the closed claim against the projected canonical fields and task contract. Exact-literal handling remains `EXACT_LITERAL_V1` and byte-sensitive.
