# TSF HQ Dispatch Reliability and Operator Lifecycle V1

Milestone 3 makes HQ Dispatch safely operable as one bounded local foreground process. The supported lifecycle is Doctor -> Start -> governed operation -> Stop. After interruption it is Doctor -> inspect canonical evidence -> make an explicit recovery decision -> use an existing canonical path. Nothing automatically submits, resumes, approves, completes, or reruns a mission.

The implementation reuses the mission envelope, canonical queue, foreground executor, real Codex app-server adapter, lifecycle terminal result, verifier, preservation packet, admission receipt, TIM_REQUIRED response writer, and canonical duplicate/replay identities. New local state is limited to ignored process-ownership evidence and append-only interruption/recovery audit receipts. None is a second approval, queue, result, admission, or replay authority.

The fixed production listener is `127.0.0.1:4317`. Start runs Doctor and the server repeats the gate before claiming an atomic ownership record. Stop authenticates the exact owner and locally held stop capability, stops submissions, invalidates the in-memory session, drains or terminates only the exact owned tree, closes the listener, and preserves canonical evidence.

The committed deterministic interruption seam is test-only. It can be constructed only by direct in-memory injection for fixture type `TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1` beneath `.codex-local/fixtures/hq-dispatch-m3-real-interruption-v1`. It is absent from HTTP, browser UI, mission and queue schemas, headers, query parameters, environment variables, and all production Start/Doctor/Stop/Demo arguments.

Validation status: implementation, deterministic matrix, M1/M2A/M2B regressions, canonical app-server matrix, real Start/Doctor/Stop behavior, real controlled interruption, restart reconciliation, and distinct new-run recovery are GREEN. Publication remains gated on a fresh independent Tester and mandatory GPT-5.6 Sol Auditor. Milestone 4 acceptance and source work have not begun.

## Operator commands

```powershell
.\tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1
.\tools\hq-dispatch\v1\Start-TsfHqDispatchV1.ps1
.\tools\hq-dispatch\v1\Stop-TsfHqDispatchV1.ps1
.\tools\hq-dispatch\v1\Start-TsfHqDispatchDemoV1.ps1
```

Begin with `OPERATOR_RUNBOOK.md`. The older `RUNBOOK.md`, `PHASE_0_RELIABILITY_INVENTORY.md`, and related documents remain supplementary implementation history.
