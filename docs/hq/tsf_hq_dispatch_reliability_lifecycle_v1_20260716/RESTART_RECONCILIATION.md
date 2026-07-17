# Restart Reconciliation

Doctor and startup read canonical evidence before making any lifecycle projection. Required classifications are:

- `COMPLETED_ADMITTED`
- `COMPLETED_ADMITTED_WITH_CAVEATS`
- `COMPLETED_REJECTED`
- `TIM_REQUIRED_PENDING_RESPONSE`
- `TIM_REQUIRED_RESPONDED_REVISION_EXISTS`
- `RUNNING_PROCESS_CONFIRMED`
- `INTERRUPTED_PROCESS_GONE`
- `QUEUED_NOT_STARTED`
- `DISPATCHING_WITHOUT_OWNER`
- `RESULT_WITHOUT_ADMISSION`
- `ADMISSION_WITH_QUEUE_MISMATCH`
- `DUPLICATE_EXACT_REPLAY`
- `CONFLICTING_REPLAY`
- `STALE_OR_UNKNOWN`

Each item supplies mission/revision/run/result, canonical paths and hashes, last queue state, live process evidence, verifier/admission state, duplicate/replay evidence, safe options, recommended action, authority required, and immutable-history warning.

Reconciliation never reruns a completed admitted mission, converts interruption into completion, assumes a missing process means failure before reading canonical records, resumes an old Codex thread/turn, answers TIM_REQUIRED, overwrites conflicting evidence, or moves a queue document for UI consistency. The controlled real proof restarted Doctor after Stop and classified the original run `INTERRUPTED_PROCESS_GONE`; it performed no automatic rerun.
