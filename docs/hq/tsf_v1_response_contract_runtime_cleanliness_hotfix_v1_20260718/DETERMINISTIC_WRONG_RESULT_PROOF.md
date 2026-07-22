# Deterministic wrong-result canonical lifecycle proof

This is deterministic fake app-server execution through the production app-server adapter, canonical queue, enforcement-kernel verifier, preservation writer, producer registry, lifecycle terminal result, and Doctor authority. It is not labeled real Codex app-server execution.

Corrected pre-amend command:

`powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run-tsf-hq-dispatch-wrong-result-lifecycle-proof-v1.ps1 -TestOnlyIsolatedQueue`

- UTC: `2026-07-18T05:57:12.2611852Z` through `2026-07-18T05:57:40.5411560Z`
- exit: `0`
- assertions: `46`
- stdout SHA-256: `6b5072a5e1a5e81e837eb91a1d7511a41a5624749c5cb9211f94a5cc87d68042`
- stderr SHA-256: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- mission: `synthetic-hq2-wrong-result-20260718055712549-94c23483`, revision `1`
- run/result: `canonical-result-synthetic-hq2-wrong-result-20260718055712549-94c23483-1`
- reviewed expected SHA-256: `192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627`
- observed obsolete SHA-256: `106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba`
- transport: success; semantic response: failure; exact match: false
- verifier: `RED`, independently recomputed
- lifecycle: `BLOCKED_VERIFIER`, final decision `RED`
- preservation packet SHA-256: `01f934db89892fb7ff6caa258479b7ed67b6a40eff7772d6773e5ef2fee44bad`
- preservation manifest SHA-256: `cac53f147f68c594262e9b0d9d8f325dd774da0ed6bdd7b1f034a0c09af546fb`
- queue document SHA-256: `6fc7a6497200a93678f6db08824761c1fa20ab2fcb65309297ac489efdd3723f`
- exact replay: idempotent; changed durable-policy replay: failed closed with original packet, manifest, and registry unchanged
- admission invoked: false; admission/transaction receipts: zero; admitted success presented: false
- caller-supplied verifier/admission input: rejected by the closed submission contract

The post-amend PROOF_FINAL command omits `-TestOnlyIsolatedQueue`, leaving the complete canonical negative record in `fleet/missions/complete_review_only`. That run must prove the Doctor file authority validates it, source Git status stays clean, the UI authority has no successful receipt to present, and any final Doctor action item is truthfully attributed to the preserved negative record.
