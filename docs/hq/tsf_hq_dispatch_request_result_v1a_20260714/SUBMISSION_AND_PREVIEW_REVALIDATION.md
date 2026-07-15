# Submission and Preview Revalidation

`POST /api/v1/missions` accepts only natural request, preview ID, preview SHA-256, request hash, server-generated submission ID, and intent `CREATE_GOVERNED_MISSION`.

Before mission creation the relay:

1. binds the preview to the issuing operator session;
2. requires its path beneath `.codex-local/hq-dispatch/preview`;
3. re-reads and hashes the artifact;
4. requires the V1 schema, `PREVIEW_ONLY_NOT_AUTHORITY`, preview record kind, non-mission/non-queue classification, and all authority flags false;
5. recomputes the unchanged canonical route preview;
6. compares request hash, project/lane, classification, role, model/effort, access, reads/writes, forbidden actions, approvals, clarifications, stops, explanations, and canonical source bindings.

Missing, stale, altered, promoted, mismatched, or cross-session previews fail closed. Tests reject caller executable/script/arguments/environment, queue/output/repository paths, mission envelopes, verifier/admission/approval state, and thread identity.
