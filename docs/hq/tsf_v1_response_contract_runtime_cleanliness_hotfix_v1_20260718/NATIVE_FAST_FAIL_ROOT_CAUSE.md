# Native fast-fail root cause and correction

## Classification

The preserved Windows failure is classified as a timing-sensitive Node HTTP client/server shutdown race at the aborted-request to Stop boundary. The observed exit `0xC0000409` identifies a Windows native fast-fail family only; no Windows Error Reporting event or Node diagnostic report established a specific native component or a literal stack-buffer defect.

The failed trace completed `FETCH_TIMEOUT` and entered `EXACT_STOP`, then ended while the Stop fetch was still `STARTED`. Twenty-seven of twenty-eight sibling executions passed, which is consistent with a nondeterministic shutdown race rather than deterministic JavaScript assertion failure.

## Causal correction

The focused test now captures the exact server instance, makes the slow response abort-aware, clears its timer when the response closes, and waits for response settlement. The `/stop` handler only completes its HTTP response. The harness consumes that response, closes the captured exact server instance outside the handler, and awaits the close callback before final serialization. It no longer calls `server.close()` from `setImmediate` through mutable global server state while an aborted response timer is outstanding.

The correction does not add retries, timing increases, broad process matching, persistent workers, or unrelated process termination.

## Evidence

- Architect report: `C:\TSF_HOTFIX2\.codex-local\evidence\overnight-native-fast-fail-recovery\architect-20260721T170053337Z\ARCHITECT_NATIVE_FAST_FAIL_REVIEW.md`, SHA-256 `b4f9880c7213174f9b219ab037b14d4448eee6833a37422b8e5599cd3989cac7`.
- Preserved failed stage trace SHA-256: `fdff33147e2a3c9888170a20266c83c6857d279abe87e95d559ea257f0309c87`.
- Preserved failed fetch trace SHA-256: `9127e480f1526845bb9d5f6134babf24f77a145abec69f479990f133ab5b2d2c`.
- Corrected final-candidate fetch proofs: child PIDs `19100` and `35956`; both exited `0x00000000` at `TEST_ASSERTIONS_COMPLETE` with 93 assertions and empty stderr.
- The workstation reboot interruption exited outside Node with `0xC000026B`; it was preserved separately and was not counted as a native test attempt.
