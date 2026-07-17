# Interrupted Mission Recovery

## Test-only deterministic seam

`createM3RealInterruptionBarrier` is a module-private-branded dependency accepted only when `HqMissionRelay` is directly constructed by the committed harness. The exact fixture must be `TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1`, use a root beneath `C:\TSF_M3\.codex-local\fixtures\hq-dispatch-m3-real-interruption-v1`, be READ_ONLY, set worker-tool network `DISABLED`, control plane `CODEX_SERVICE_ONLY`, permit no writes, target no product repository, provide an exact test-run identity, and possess the in-memory capability object.

The hook fires after the canonical foreground executor is spawned and recorded as an exact owned child. The fixture monitor observes its real `codex.exe` app-server descendant, binds PID/start/executable, suspends that descendant before a terminal worker result can be accepted, verifies that terminal/lifecycle/adapter/verifier artifacts are absent, writes hashed `BARRIER_READY.json`, and awaits existing Stop behavior. Timeout or identity mismatch fails closed. Production startup supplies no hook.

Static and behavioral tests prove natural language, mission context, HTTP body/header/query, environment, queue document, response, Start/Doctor/Stop/Demo arguments, and browser UI cannot activate or expose the hook. The suite passed 25 assertions.

## Real interrupted run

- Fixture run: `run-mrpd6q1v-29584`
- Server instance: `hq-instance-d5f96e23-492a-4f44-883b-1c57af361d5b` (PID 36284)
- Mission: `hq2-mrpd6ya4-c4c88a`, revision 1
- Run/result allocation: `canonical-result-hq2-mrpd6ya4-c4c88a-1`
- Owned executor: PID 22352, start `2026-07-17T20:02:30.5479175Z`
- Real app-server child: PID 27756, start `2026-07-17T20:02:36.4891010Z`
- Hook: `REAL_APP_SERVER_PROCESS_SUSPENDED_BEFORE_TERMINAL_RESULT`
- Barrier SHA-256: `ab323b8c6b69c87ac222c83d335f4b693f01bde1987a4fd7742aca77e0152ffc`
- Stop requested: `2026-07-17T20:02:38.687Z`
- Stop-record SHA-256: `bc7845797c5a15acd799f057b161ffc094ab3c33c3a3e202a150ae08951ebb52`
- Preserved queue observation: `worker_running`
- Admission receipt: absent; verifier success: absent

Stop removed the exact owned tree, invalidated the session, closed port 4317, removed ownership evidence, and left the unrelated harness alive. Fresh Doctor classified the source `INTERRUPTED_PROCESS_GONE`; no automatic rerun or old thread/turn resumption occurred.

## New-run recovery

The explicit `RETRY_AS_NEW_RUN` action created mission `hq2-mrpd6ya4-c4c88a-retry-6a9d2b7dff838556` and run/result `canonical-result-hq2-mrpd6ya4-c4c88a-retry-6a9d2b7dff838556-1`. Its real app-server child was PID 34232; thread `019f71ad-062f-7ca0-81a5-90f52b9b919a`; turn `019f71ad-1bab-70b1-9742-c3120cde6c67`; verifier `canonical-kernel-postrun`; admission `admission-n6pg773tngptf57xw3ea4iak`, SHA-256 `8505acebe5d504d87ce277c6bfcffd83ab246554e02254ad98a805c167759b1b`; final state `ADMITTED_WITH_CAVEATS`.

Recovery receipt `hq-recovery-receipt-a952c465a0173fb49a8e671d1d55dce4` has SHA-256 `c9dbeec9c9851a6d2245be9fc3e0f8413c5ad6ff72fcc0e4ad4de6ea09a1e823`. Source mission/run hashes were unchanged.

## Preserved completed-race run

The earlier attempt that completed before Stop remains untouched: lifecycle `COMPLETED_GREEN`, worker `CODEX_APP_SERVER_WORKER_GREEN`, verifier GREEN, queue `postrun_pending`, admission absent, reconciliation `RESULT_WITHOUT_ADMISSION`. It is evidence of the race and was never relabeled interrupted.
