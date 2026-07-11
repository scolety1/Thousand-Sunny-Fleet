# TSF Final Publication Evidence V1

This bundle preserves exact bytes from the successful correction runs completed before this static correction. No service-connected task was rerun.

- Read-only mission: `synthetic-tsf-readonly-appserver-correction-0001`
- Workspace-write mission: `synthetic-tsf-workspace-appserver-correction-0001`
- Index: `PUBLICATION_EVIDENCE_INDEX.csv`

Every manifest-selected artifact, the manifest, admission receipt, transaction receipt, and an immutable queue-document snapshot is independently inspectable. The original mutable final queue locations no longer exist; `final_queue_snapshot.json` is an exact second copy of the packet-bound `qd.json`. The corresponding transaction receipt records the committed final state `complete_ready_for_gate`.

These historical runs predate the run-scoped producer registry. No registry was fabricated retrospectively. Their producer provenance remains exactly what their original manifests recorded, and the new registry contract applies prospectively.

The files were limited to synthetic TSF fixtures and scanned for private-key, bearer-token, OpenAI-key, and generic API-key patterns before tracking. No matching secret-like content was found.
