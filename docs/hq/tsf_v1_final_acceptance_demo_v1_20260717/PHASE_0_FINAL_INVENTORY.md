# Phase 0 Final Inventory

The exact external readiness packet at `C:\TSF_REVIEW\tsf_v1_m4_readiness_prep_20260716` was read without inspecting its parent or siblings. Its seven declared content hashes were independently recomputed and matched. Canonical `origin/main` was fetched read-only and verified exactly at `952f30e137214735fe2513a7b068d9680ca882c7`; the accepted M1, M2A, M2B, and M3 branches are clean ancestors.

| Capability | Classification entering M4 | Canonical source and M4 disposition |
|---|---|---|
| Doctor JSON | ACCEPTED_CANONICAL | `reliability.mjs` / `reliability-cli.mjs`; unchanged authority |
| Doctor human output | LOCALIZED_CORRECTION_REQUIRED | Wrapper incorrectly read absent `name`; use stable `id` and fail on missing label |
| Foreground Start | ACCEPTED_CANONICAL | Public Start plus repeated Doctor gate, fixed `127.0.0.1:4317`, single owner |
| Cooperative Stop | ACCEPTED_CANONICAL | Exact PID/start/executable/worktree/instance/listener authentication and bounded tree cleanup |
| Deterministic Demo | ACCEPTED_WITH_CAVEAT | M1/M2A/M2B fixture-only; must never be presented as a real worker |
| Route preview | ACCEPTED_CANONICAL | M1 closed preview contract; no execution or authority |
| Governed mission submission | ACCEPTED_CANONICAL | M2A closed session/submission and canonical mission preparation |
| Canonical queue | ACCEPTED_CANONICAL | Existing canonical queue writer and foreground executor |
| Status and result UI | ACCEPTED_CANONICAL | Canonical projection with exact run/result/thread/turn/hash identities |
| Real Codex app-server execution | IMPLEMENTED_NEEDS_FINAL_PROOF | Accepted M2A/M2B/M3 bounded real proofs; rerun once in M4 |
| Verifier, preservation, admission | ACCEPTED_CANONICAL | Existing kernel owners; M4 only indexes receipts and hashes |
| Exact approval | ACCEPTED_CANONICAL | Existing approval-ledger writer and matcher; use/expiry/scope bound |
| Denial | ACCEPTED_CANONICAL | Immutable terminal response; no execution or revision |
| Clarification and revision | ACCEPTED_CANONICAL | Linked canonical response; distinct revision/run; no old-thread resume |
| Duplicate submission/response | ACCEPTED_CANONICAL | Exact replay is idempotent; changed content fails closed |
| Controlled interruption | IMPLEMENTED_NEEDS_FINAL_PROOF | Private in-memory M3 fixture seam after observed real child ownership |
| Restart reconciliation | IMPLEMENTED_NEEDS_FINAL_PROOF | Read-only classification; no automatic rerun, answer, or completion |
| Explicit new-run recovery | IMPLEMENTED_NEEDS_FINAL_PROOF | Distinct mission/run/thread/turn/verifier/admission with immutable source |
| Final receipts | IMPLEMENTED_NEEDS_FINAL_PROOF | Canonical receipt identities and SHA-256 values must be indexed |
| Parser evidence | LOCALIZED_CORRECTION_REQUIRED | Generic row helper hardcoded exit zero; replace with honest parser identity |
| M3 historical validation hash | ACCEPTED_WITH_CAVEAT | Additive erratum; never rewrite accepted M3 packet |
| Existing tests/evidence | ACCEPTED_WITH_CAVEAT | Broad GREEN coverage; final runner and truthful row schema required |
| Unified operator documentation | DOCUMENTATION_REQUIRED | One V1 runbook, demo script, limitations, and evidence map |
| Workspace-write proof | NOT_REQUIRED | Excluded by default; no separate approval was supplied |
| Background watcher/daemon/service | DEFERRED_POST_V1 | Explicitly prohibited for V1 |
| Multiple governed workers | DEFERRED_POST_V1 | V1 is one foreground owner/active mission |
| Product-repository execution | NOT_REQUIRED | Outside V1 authority and prohibited |
| Plugins/credential discovery/deployment | NOT_REQUIRED | Outside V1 authority and prohibited |

No accepted subsystem is rebuilt by M4.
