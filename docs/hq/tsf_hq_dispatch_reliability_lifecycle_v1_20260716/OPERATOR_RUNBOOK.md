# Operator Runbook

## Doctor

```powershell
.\tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1
```

Read the overall status, evidence, and exact next action. `UNSAFE_TO_START` means preserve evidence and do not Start. Doctor is read-only; its `-Json` output is the same report used for human output.

## Start

```powershell
.\tools\hq-dispatch\v1\Start-TsfHqDispatchV1.ps1
```

Keep the terminal open. Start prints `http://127.0.0.1:4317`, canonical queue/runtime roots, local lifecycle root, and instance ID. It does not submit or resume work. A second Start is expected to fail closed.

## Recovery

Refresh the Recovery Center, verify mission/revision/run/result plus paths and hashes, read the immutable-history warning, and choose only the listed exact action. A completed admitted mission is acknowledgment/view-only. TIM_REQUIRED is answered through the existing response path. Interrupted retry is a new run and may require fresh approval.

## Stop

From another terminal:

```powershell
.\tools\hq-dispatch\v1\Stop-TsfHqDispatchV1.ps1
```

Confirm the output reports the exact instance, session invalidation, owned-child cleanup, listener removal, owner-record removal, and remaining canonical work. Never target a PID manually.

Only when Doctor explicitly proves a stale/reused owner identity:

```powershell
.\tools\hq-dispatch\v1\Stop-TsfHqDispatchV1.ps1 -RecoverVerifiedStaleOwnership
```

## Demo

```powershell
.\tools\hq-dispatch\v1\Start-TsfHqDispatchDemoV1.ps1
.\tools\hq-dispatch\v1\Start-TsfHqDispatchDemoV1.ps1 -ResetFixture
```

The reset form affects only the isolated demo root.
