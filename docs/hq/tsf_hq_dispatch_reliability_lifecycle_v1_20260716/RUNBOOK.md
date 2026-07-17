# HQ Dispatch V1 Runbook

## 1. Doctor

```powershell
.\tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1
```

- `GREEN`: Start is safe.
- `GREEN_WITH_CAVEATS`: read the caveats and exact next action. An active exact owner is healthy but a second Start is not allowed.
- `ACTION_REQUIRED`: preserved interrupted/stale evidence needs an explicit recovery decision.
- `TIM_REQUIRED`: a canonical human response or broader authority is required. Start may open the Recovery Center when evidence is otherwise safe.
- `UNSAFE_TO_START`: do not start. Preserve evidence and follow the exact check action.

Doctor is read-only. It never creates a directory, resets Git, deletes a record, moves a queue item, resumes a mission, answers a request, or terminates a process.

## 2. Start

```powershell
.\tools\hq-dispatch\v1\Start-TsfHqDispatchV1.ps1
```

Start runs Doctor, then the server repeats the gate immediately before ownership claim. Keep this terminal open. The command prints the fixed local URL, canonical runtime root, canonical queue root, local lifecycle root, and instance ID. It does not submit or resume a mission.

## 3. Recover

Use the browser Recovery Center. Refresh canonical evidence, read the paths/hashes and immutable-history warning, then click only the exact action you intend. A click sends an exact confirmation and the server revalidates the evidence.

Never use a generic reset, force-complete, delete, clear-queue, old-thread resume, same-result retry, or arbitrary kill operation. Those controls do not exist.

For `TIM_REQUIRED`, choose `RESPOND_TO_TIM_REQUIRED`; the original run remains terminal. Approval, denial, or clarification then follows the existing canonical Milestone 2B control. Any continuation is a new revision/run.

For interruption, first preserve/confirm interruption evidence if offered. Retry is always a new run and reruns validation/routing. A completed admitted mission offers acknowledgment/view only and cannot be rerun.

## 4. Stop

From a second terminal:

```powershell
.\tools\hq-dispatch\v1\Stop-TsfHqDispatchV1.ps1
```

Stop targets only the exact owner. It rejects an arbitrary or reused PID. It stops submissions, invalidates sessions, drains or terminates the exact owned child according to the bounded policy, preserves interruption evidence, closes the listener, and prints cleanup proof.

If Doctor explicitly reports `STALE_PROCESS_GONE` or `PID_REUSED_OR_IDENTITY_MISMATCH`, and only then:

```powershell
.\tools\hq-dispatch\v1\Stop-TsfHqDispatchV1.ps1 -RecoverVerifiedStaleOwnership
```

This removes stale evidence files only; it does not terminate the unrelated process.

## Deterministic demo

```powershell
.\tools\hq-dispatch\v1\Start-TsfHqDispatchDemoV1.ps1
```

The demo is foreground-only and visibly labeled fixture behavior. A normal request demonstrates M1 preview and M2A deterministic result/admission projection. A request containing `TIM REQUIRED` demonstrates M2B clarification and a new revision. It uses only `.codex-local\fixtures\hq-dispatch-demo-v1`, no product repository, plugin, credential, external network, or real app-server.

Reset only that root explicitly:

```powershell
.\tools\hq-dispatch\v1\Start-TsfHqDispatchDemoV1.ps1 -ResetFixture
```

The normal Stop command can stop the active demo because it uses the same exact owner protocol and fixed loopback port.
