# TSF V1 semantic outcome calibration

This packet documents the localized post-PR21 correction for GENERAL_RESULT_V2. The correction removes arbitrary answer prose from worker-outcome classification, adds a closed V2 worker claim, verifies deliverables from content, keeps the worker claim non-authoritative, fails legacy output closed, and projects transport, claim, verifier, and admission separately.

Publication is permitted only when the exact candidate has one commit over `ed149f0ec42439f9faa2b65d9187bf2995d96180`, all exact-candidate gates pass, fresh Tester and Auditor verdicts are GREEN, and one ready PR can be opened without merge.

Read in this order:

1. `ROOT_CAUSE_FALSE_SUCCESS.md`
2. `ROOT_CAUSE_FALSE_REJECTION.md`
3. `STRUCTURED_WORKER_OUTCOME_CONTRACT.md`
4. `LEGACY_COMPATIBILITY_POLICY.md`
5. `DELIVERABLE_FIRST_VERIFIER.md`
6. `OUTCOME_TEST_CORPUS.md`
7. `UI_SEMANTIC_PROJECTION.md`
8. `HISTORICAL_SOAK_PRESERVATION.md`
9. `REAL_PROOFS.md`
10. `TARGETED_SOAK_V3_RESULTS.md`
11. `SECURITY_AND_AUTHORITY_REVIEW.md`
12. `EXECUTED_TEST_COVERAGE.csv`
13. `VALIDATION.json`
14. `SHA256SUMS.txt`

No document in this packet grants approval, merge, deployment, production, plugin, credential, product-repository, installation, or expanded network authority.

`SHA256SUMS.txt` hashes each named file in the canonical Git-blob byte domain after repository text normalization, not a platform-specific checkout materialization.
