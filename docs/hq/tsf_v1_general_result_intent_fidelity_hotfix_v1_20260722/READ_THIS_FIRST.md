# TSF V1 general-result and intent-fidelity hotfix

This packet describes the correction that separates app-server transport from task fulfillment and prevents a read-only substitute from silently replacing authority-bearing operator intent.

Canonical base: `5cc3ca21eaf97d7fff9051ae566c44e7e914e2d4` (`744412e1340e978df847d2a1ae8fc758060e6ce0`). Branch: `hotfix/tsf-general-result-intent-fidelity-v1-20260722`. Worktree: `C:\TSF_HOTFIX3`.

The implementation strengthens the existing Project Main Bot, HQ Dispatch preview/submission, canonical mission translator, lifecycle, kernel verifier, durable result mapper, preservation, and admission path. It creates no second router, queue, verifier, admission authority, or approval ledger.

Read the two root-cause reports first, then the three contracts and verifier/admission rules. Exact-candidate `VALIDATION.json`, executed-test coverage, screenshots, command output, and SHA-256 indexes are generated only after the single commit and are kept under the ignored `.codex-local/evidence` tree. This avoids changing the audited tree with self-referential evidence after its identity is fixed.

Historical soak missions and receipts are evidence, not fixtures to rewrite. No product repository, plugin, credential, installation, deployment, merge, or auto-merge is authorized.
