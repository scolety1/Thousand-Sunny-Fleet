# Real Reliability Proofs

## Start, Doctor, Stop

The committed real proof harness first ran Doctor (`GREEN_WITH_CAVEATS` only for isolated test/worktree caveats), started a foreground server on `127.0.0.1:4317`, rejected a second instance, confirmed Doctor recognized the exact owner, stopped through the public Stop wrapper, invalidated the session, removed the exact owned children and owner record, closed the listener, and preserved canonical/Git state. An unrelated harness process remained alive.

## Deterministic real interruption and recovery

Command: `node.exe .\tests\test-tsf-hq-dispatch-real-reliability-v1.mjs`

- UTC: `2026-07-17T20:02:16.2108209Z` to `2026-07-17T20:03:40.9733028Z`
- Harness PID: 29584
- Exit: 0; assertions: 83
- stdout SHA-256: `c0697cbe41c2e2570fe954d2d9777013ce3ce1a8ed14c87e90bb19f7b643332b`
- stderr SHA-256: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- Raw evidence: `.codex-local/evidence/real-reliability-barrier-20260717T200216205Z`

The barrier record proved the real app-server child was live, inside the exact owned executor tree, and observed before any terminal worker/verifier/admission record. Public Stop rejected submissions, terminated only that exact tree, invalidated the session, closed the listener, and wrote the immutable stop record. Restart Doctor classified the original run interrupted and performed no automatic rerun. Explicit recovery created distinct mission/run/thread/turn identities; a fresh real app-server round trip independently verified and admitted with caveats; the original remained byte-immutable.

Exact identities and hashes are recorded in `INTERRUPTED_MISSION_RECOVERY.md` and `VALIDATION.json`.

## Preserved completed race

An earlier real attempt finished before Stop. Its canonical truth remains `COMPLETED_GREEN` / `CODEX_APP_SERVER_WORKER_GREEN` / verifier GREEN / `postrun_pending` / no admission, reconciled as `RESULT_WITHOUT_ADMISSION`. It was not changed or reused by the deterministic proof.

## Network and authority boundary

Only the Codex control plane was available (`CODEX_SERVICE_ONLY`) for the two real read-only worker turns. Worker-tool network was `DISABLED`. The proof used no product repository, plugin, credential value, deployment, package installation, service, scheduled task, remote listener, background process, detached process, merge, or push.
