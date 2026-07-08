# Post-Run Verifier V1

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tsf-kernel-postrun-verify.ps1 -MissionPath <mission.json> -WorkerResultPath <worker-result.json> -OutFile <verifier-result.json>
```

The verifier checks one worker result against one mission packet.

It verifies:

- worker result `mission_id` matches the mission
- expected artifacts exist
- restricted actions were not attempted
- touched-file evidence, when present, does not include forbidden output paths
- result is classified as `GREEN`, `YELLOW`, or `RED`

Missing required artifacts fail closed as `RED`.
