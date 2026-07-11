# Root cause

## Proven failure sequence

The preserved queue document moved `inbox -> drafted -> preflight_pending`. The queue executor invoked `Invoke-TsfMissionLifecycle.ps1` synchronously. The lifecycle created its canonical producer registry `pr.json`, proving that mission translation, compact path planning, Git binding, and producer-capability minting completed.

The lifecycle then validated the already-preserved canonical queue evidence. The old implementation compared two different hash domains:

- byte SHA-256 of `qd.json`: `b448d6ace79b44b0b2ac93074b7547c334888617233da690d213600be35c5eb8`;
- canonical JSON identity hash returned by `Test-TsfCanonicalQueueDocument`: `1ca84fc85687b580476288e108aa214007189dab11e7bc2b0fccfef1d3eeb8c4`.

Both hashes were correct for their respective domains, but they are not interchangeable. The comparison deterministically threw `QUEUE_DOCUMENT_EVIDENCE_HASH_MISMATCH` before the old end-of-script result write. The lifecycle process exited nonzero without `lc.json`; the executor then emitted `Canonical lifecycle did not write its result.`

Classification: `LIFECYCLE_EXITED_WITHOUT_TERMINAL_RESULT`, caused by an internal canonical-identity versus serialized-byte hash mismatch. It was not `RESULT_PATH_MISMATCH`: both components derived the same compact `l/<mission-key>/<run-key>/lc.json` path from `New-TsfCompleteRuntimePathPlan`.

No worker or app-server child launched. The producer registry contains no worker artifacts. The preserved executor record reports `worker_invocations_used: 0`, `api_called: false`, and `control_plane_connection_used: false`.

## Mechanical preparation helper failure

The stop record preserves only the fact that the sole earlier recovery corrected a local mission-preparation helper import; it does not preserve the original exception text or helper filename. The repair therefore does not invent a more specific cause. It replaces ad hoc caller-CWD preparation with `tools/New-TsfCanonicalQueueMission.ps1`, whose imports are resolved from `$PSCommandPath`, whose governing helpers are fingerprinted, and whose missing-helper check writes a blocked preparation result before any queue record is created.
