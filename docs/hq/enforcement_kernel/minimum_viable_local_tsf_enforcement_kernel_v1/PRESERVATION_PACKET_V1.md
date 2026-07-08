# Preservation Packet V1

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tsf-kernel-preserve.ps1 -MissionPath <mission.json> -PreflightResultPath <preflight-result.json> -WorkerResultPath <worker-result.json> -VerifierResultPath <verifier-result.json> -OutputDirectory <packet-dir>
```

The preservation writer creates a local packet folder containing:

- mission packet
- preflight result
- worker instruction or worker result
- verifier result when present
- preservation summary JSON
- CSV manifest
- next-action note

It never starts a runner or approves future work. It only preserves evidence and a bounded next instruction.
