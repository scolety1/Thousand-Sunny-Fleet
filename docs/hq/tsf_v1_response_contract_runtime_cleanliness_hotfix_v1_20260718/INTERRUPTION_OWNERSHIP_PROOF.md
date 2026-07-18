# Exact interruption ownership proof

The authoritative adapter spawn point records the child PID, child start time, executable, parent PID/start time, server instance, mission/run identity, exact in-memory test capability, candidate worktree/commit/tree, creation timestamp, a credential-free launch-identity hash, and an ownership-evidence hash.

Barrier readiness requires the exact real app-server child to have been spawned and registered as proof-owned, to remain alive, to have no terminal result, and to match fixture/capability/run/candidate identities. Readiness is not derived from timing increases or process-name scanning. Process-name enumeration is safety inventory only; unattributed Codex app-server processes are ignored and left untouched.

Failure diagnostics always name the last stage, fixture, expected and observed roots, candidate, server instance, executor/app-server identities when known, timeout/abort state, and a closed failure classification. Successful Stop is also recorded as `READY_CLEANED` with `EXACT_OWNED_PROCESS_CLEANUP_CONFIRMED`.

Working-tree proof 1 bound authoritative spawn `19c8f16a77b03285ed46782c92a8f8c2c0848484ef326860254fc39296ecf965`, ownership evidence `d5671075f90e7a96faeefa02278cd0ea9b6fc2c70d251557e983216d351d6503`, and capability `e8f3c8af3a26c01b1f75cc350b9faff120ad01d23d6440cb862eda4db68e0526`. Proof 2 bound spawn `1af46e26df5dc635f296b0a1d8d93f2cbec0a33d07b81dc69f87c4b203af88ee`, ownership `880e4d2825b793f652afc90c867089e15aa28527b7d9b25c796838a9aa46c7d5`, and capability `bba7fa699f64883b92b8451934fff68b43a7b7318457854e19564dd7fe060d69`.

The two final-candidate interruption proofs must be the first two attempts from `C:\TSF_HOTFIX2_PROOF_FINAL`, must have distinct fixture/run identities, and must independently reproduce exact-child Stop, truthful interruption, restart reconciliation, a new recovery run, verifier, preservation, admission, receipt, and final cleanup.
