# TSF V1 Operator Runbook

Run every command from `C:\TSF_V1`. Keep Start or Demo in its foreground terminal. Use a second terminal only for the cooperative Stop command.

## 1. Doctor

```powershell
.\tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1
.\tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1 -Json
```

The human labels are the same stable check identifiers carried by JSON. Status, severity, and next action must agree. Doctor is read-only. `UNSAFE_TO_START` means stop and preserve evidence. `TIM_REQUIRED` means Start may open the Recovery Center, but only the exact canonical response path may answer it.

## 2. Foreground Start

```powershell
.\tools\hq-dispatch\v1\Start-TsfHqDispatchV1.ps1
```

Expected disclosures include `http://127.0.0.1:4317`, canonical runtime and queue roots, the local lifecycle root, and the server instance. Keep the terminal open. Start does not submit, resume, approve, retry, or answer a mission.

Open `http://127.0.0.1:4317`. The normal browser flow is route preview, governed submission, canonical status/result projection, and—only when requested—an exact TIM_REQUIRED response. The relay moves the worker instruction and exact response through the existing app-server adapter. The operator never copies worker prompts or results between ChatGPT and Codex.

## 3. Recovery

Use the Recovery Center only after reading mission, revision, run, result, evidence hash, classification, immutable-history warning, and recommended action. An interrupted mission is never resumed; explicit recovery creates a distinct new mission/run/thread/turn and independently verifies/admit it. Exact replay returns the existing receipt; changed replay fails closed.

## 4. Cooperative Stop

```powershell
.\tools\hq-dispatch\v1\Stop-TsfHqDispatchV1.ps1
```

Require exact instance targeting, operator-session invalidation, owned-child cleanup, listener removal, owner-record removal, canonical record preservation, and `unrelated_processes_terminated: false`. Never kill a PID manually.

Only when Doctor proves `STALE_PROCESS_GONE` or `PID_REUSED_OR_IDENTITY_MISMATCH`:

```powershell
.\tools\hq-dispatch\v1\Stop-TsfHqDispatchV1.ps1 -RecoverVerifiedStaleOwnership
```

This removes verified stale local evidence and never terminates the observed unrelated process.

## 5. Deterministic Demo

```powershell
.\tools\hq-dispatch\v1\Start-TsfHqDispatchDemoV1.ps1
.\tools\hq-dispatch\v1\Start-TsfHqDispatchDemoV1.ps1 -ResetFixture
```

Demo is fixture behavior, not real app-server behavior. Reset is confined to `.codex-local/fixtures/hq-dispatch-demo-v1`; it never resets canonical records.

## 6. Final acceptance

```powershell
.\tests\run-tsf-v1-final-acceptance-v1.ps1
```

The default run includes the bounded real app-server interruption and recovery proof. `-SkipRealAppServerProof` exists only for a subsequent deterministic re-audit of already-sealed real evidence; it is not sufficient to declare the release candidate accepted by itself.
