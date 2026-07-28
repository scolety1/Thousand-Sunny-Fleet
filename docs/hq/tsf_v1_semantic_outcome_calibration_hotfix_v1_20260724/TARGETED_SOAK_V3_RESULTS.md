# Targeted operator soak V3

Runner:

`tests/run-tsf-semantic-outcome-targeted-soak-v3.ps1`

The first harness attempt preserved its command outputs at:

`C:\TSF_HOTFIX4\.codex-local\evidence\semantic-outcome-soak-v3\20260724T030148925Z`

All cases ran; result serialization then stopped on a PowerShell boolean-literal typo. The unchanged cases were rerun after the localized harness correction.

Working-tree GREEN result:

`C:\TSF_HOTFIX4\.codex-local\evidence\semantic-outcome-soak-v3\20260724T030534560Z\TARGETED_SOAK_V3_RESULT.json`

Result SHA-256:

`2bfe370b2c3853b7d6bf47aae92c62ad1e2eaa8e2fda2d363b944f79211ff111`

The 12 commands cover historical/normative success, contractions/passives/indirect inability, missing deliverable, wrong task, policy block, exact success/mismatch, detached intent denial, duplicate/changed replay, one-active-mission protection, interruption/recovery, responsive populated state, runtime cleanliness, and Start/Stop/Doctor. Every command exited 0.

Exact candidate `db2aff814dde0c03d2ab4393aa76dfb3f99f369a` rerun:

`C:\TSF_SEMANTIC_PROOF2\.codex-local\evidence\semantic-outcome-soak-v3\20260724T034853969Z\TARGETED_SOAK_V3_RESULT.json`

Exact result SHA-256:

`3818748cd9c36b32df535af6406b92047591e87f18aaf42b48ad09e2ac55d14a`

All 12 cases passed on the exact candidate. The final post-documentation commit is bound separately by the ignored final proof packet.
