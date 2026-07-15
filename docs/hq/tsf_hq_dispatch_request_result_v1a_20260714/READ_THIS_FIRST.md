# TSF HQ Dispatch Request-to-Result V1A — Exact Result Evidence Correction

Verdict: `GREEN_TSF_HQ_DISPATCH_EXACT_RESULT_EVIDENCE_READY_FOR_INDEPENDENT_AUDIT`.

This bounded Milestone 2A correction binds the required terminal response to the fixed SHA-256 `106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba`, preserves the raw final response, separates app-server transport success from semantic success, makes the existing verifier independently recompute the raw UTF-8 hash, and prevents admission unless the required test evidence is bound to that same hash.

All six audit findings were `CONFIRMED` and corrected:

1. the adapter accepted any nonempty final response;
2. lifecycle worker success followed transport success;
3. verifier/admission trusted producer verdicts without exact mission-bound recomputation;
4. the real proof runner hardcoded unobserved non-use booleans;
5. status events omitted `result_id` and replay/cross-run projection binding was incomplete;
6. browser copy still described the surface as future/disabled instead of the bounded current Milestone 2A behavior.

The correction reuses the existing queue, foreground executor, lifecycle, adapter, verifier, preservation, admission, relay, and UI. It adds no queue, executor, lifecycle, verifier, admission path, watcher, daemon, plugin, credential, deployment, push, merge, product-repository access, or Milestone 2B response-writing behavior.

The clean-fingerprint canonical proofs ran in a temporary local mirror because the governing policy correctly rejects a dirty tree. The mirror contained the exact candidate implementation in a disposable local commit; it used no remote. The target branch remains the publication authority and receives exactly one follow-up commit after all gates pass.

Proof outcome: adapter matrix `43/43`, exact verifier/admission matrix `12/12`, HTTP/replay/UI suite `93/93`, deterministic accepted canonical slice `59/59` with `ADMITTED_WITH_CAVEATS`, deterministic wrong-response canonical slice `21/21` with `REJECTED`, real read-only app-server slice with HTTP `200` and `ADMITTED_WITH_CAVEATS`, and canonical runtime compatibility `149/149`. Expected and observed response hashes matched in both accepted vertical slices, the verifier independently recomputed them, and result identity survived admission, terminal events, and replay. The wrong-response slice proves that transport success cannot become semantic success, verification, admission, or an invented top-level or nested result identity.

The admission caveat is deliberate evidence truth: policy/configuration can prove a prohibition or disabled setting, but product-repository, plugin, credential, and external-network runtime non-use remain `NOT_OBSERVED` where the protocol exposes no authoritative audit. Such facts are no longer invented as `false`.

Milestone 2B remains deferred. TIM request display/preservation does not answer, approve, deny, or clarify a request.

Exact next action: one independent read-only audit of the follow-up correction commit.
