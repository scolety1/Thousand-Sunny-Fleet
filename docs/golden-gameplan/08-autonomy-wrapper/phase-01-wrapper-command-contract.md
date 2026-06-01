# Stage 8 Phase 1 Prompt: Wrapper Command Contract

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 1 only: Wrapper Command Contract.

Goal:
Define the command contract for a bounded autonomy wrapper.

The wrapper should eventually perform one controlled cycle:
inspect -> decide -> execute approved bounded action -> report -> stop.

Define command parameters such as:
- selected ships
- dry-run
- max cycles
- max runtime minutes
- budget mode
- allow run batch
- allow audit package
- allow task packet import
- allow repair task creation
- disallow product changes
- report path

Guardrails:
- Do not implement execution yet unless this phase is later explicitly run.
- Do not launch ships.
- Do not modify product repos.
- Do not create an unbounded loop.
- Selected ship scope must be required.

Acceptance:
- Wrapper command contract is documented.
- Required flags and defaults are defined.
- Unsafe defaults are avoided.
- Examples include dry-run, one-ship, and three-ship use cases.

Proof:
Show the command contract doc and sample commands.
```

## Notes

The contract should make it hard to accidentally launch the whole fleet.

## Implementation Status

Status: GREEN

Implemented by `invoke-autonomy-wrapper.ps1`.

Command contract highlights:
- `-Ship` or `-Preset` is required.
- Default mode is dry-run unless `-Execute` is passed.
- `-MaxCycles` defaults to 1 and Stage 8 only accepts one bounded cycle.
- `-AllowRunBatch`, `-AllowAuditPackage`, `-AllowTaskPacketImport`, `-AllowRepairTask`, and `-AllowParkShip` gate higher-impact actions.
- Reports are written to timestamped `out/stage8-autonomy/...` paths by default.
