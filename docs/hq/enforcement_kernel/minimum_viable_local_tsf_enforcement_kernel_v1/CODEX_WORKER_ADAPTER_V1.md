# Codex Worker Adapter V1

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tsf-kernel-worker-adapter.ps1 -MissionPath <mission.json> -PreflightResultPath <preflight-result.json> -OutFile <worker-instruction.json>
```

V1 is a foreground-only adapter stub.

It:

- accepts only a preflight-approved mission
- refuses failed preflight results
- writes a worker handoff packet with allowed reads, writes, forbidden paths, forbidden actions, expected artifacts, and stop conditions
- records that direct Codex CLI invocation is blocked in V1
- records that no background runner, all-fleet command, or product repo mutation was started

Adapter status for V1 approved missions is:

`STUB_READY_CODEX_CLI_BLOCKED`

This is intentional. Direct Codex CLI execution should be a later exact approval gate.
