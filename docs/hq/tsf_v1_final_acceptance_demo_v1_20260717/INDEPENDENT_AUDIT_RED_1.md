# Independent Audit 1 — RED

The first independent Tester and Auditor both rejected candidate `c18ea760f09c91a1f13adda3e51c6a58e68f011f` for publication. This disposition is retained even though the findings were later corrected.

The Tester’s deterministic rerun passed 20 of 20 gates, but inspection of the sealed real artifact found that its verifier recorded top-level revision `0` while every durable identity and its own nested exact-response evidence recorded revision `1`. The Auditor independently confirmed that defect and found two evidence-harness gaps: committed-diff whitespace was not checked, and the versioned real-proof output omitted verifier and preservation hashes.

Publication stayed blocked. No push or PR was attempted.

Correction commit `f8d5d845e1e3e32061b914a5a500b2080b686604`:

- derives verifier top-level identity from the authoritative durable response contract;
- requires durable-result mapping to reject an unbound verifier mission/revision/run/result identity;
- adds a revision-zero negative case and full real-proof identity assertions;
- checks `refs/remotes/origin/main...HEAD` in both committed-diff gates;
- includes verifier, preservation packet, preservation manifest, admission, and recovery receipt hashes in the real proof.

The M3 additive hash erratum was independently classified GREEN/nonblocking during this RED audit. A fresh independent Tester and Auditor must still approve the corrected candidate before publication.
