# Existing Component Reuse Note

The bounded self-continuation lane adapts existing TSF components instead of creating a second orchestration system.

## Reused Directly

- `tools/New-TsfProjectMainBotMissionDraft.ps1` for Tim-style request normalization and mission draft creation.
- `tools/Invoke-TsfProjectMainBotDryRun.ps1` for Project Main Bot route decision and dry-run lifecycle handoff.
- `tools/Invoke-TsfMissionLifecycle.ps1` for mission schema validation, kernel preflight, role-aware preflight, worker instruction packet generation, and preservation patterns.
- `tools/Test-TsfWorkerRolePermission.ps1` for fail-closed role permission checks.
- `tools/Update-TsfProjectContextCapsule.ps1` for local context capsule update writing.
- `tools/Test-TsfMainBotLoopPrevention.ps1` for bounded loop prevention classification.
- `tools/codex-fleet-enforcement-kernel.ps1` post-run verifier and preservation writer.
- `tools/codex-fleet-runtime.ps1` foreground process wrapper.

## Adapted

- `tools/Invoke-TsfProjectMainBotSelfContinuation.ps1` now supports an opt-in approved fixture worker mode while keeping dry-run-only behavior as the default.
- The worker execution step uses the previously proven `service_tier=fast` and `workspace-write` command shape.

## Not Built

- No background runner.
- No Operator Console.
- No API/HQ transport.
- No true parallel worker launcher.
- No product repo or canonical NWR adapter.

## Duplicate-System Risk

Low. The lane routes through existing mission intake, role preflight, approval ledger semantics, verifier, preservation, context, and loop-prevention pieces. New logic is limited to bounded foreground self-continuation coordination.
