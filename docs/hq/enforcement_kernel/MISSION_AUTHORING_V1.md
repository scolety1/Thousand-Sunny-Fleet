# Mission Authoring V1

`tools/New-TsfMissionPacket.ps1` creates a local TSF mission packet without executing it.

Example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\New-TsfMissionPacket.ps1 `
  -ProjectId TSF_CONTROL_PLANE `
  -RepoPath C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet `
  -Lane MASTER_TSF_CONTROL_PLANE `
  -MissionType tsf_infrastructure `
  -AllowedReads docs/hq/enforcement_kernel `
  -AllowedWrites docs/hq/enforcement_kernel/example-output.md `
  -ExpectedArtifacts docs/hq/enforcement_kernel/example-output.md `
  -StopCondition "expected-artifact|artifact_exists|Expected artifact must exist after worker run." `
  -OutFile fleet/missions/drafted/example-mission.json `
  -ValidateShape
```

The helper supports:

- `project_id`
- `repo_path`
- `lane`
- `mission_type`
- `allowed_reads`
- `allowed_writes`
- `forbidden_actions`
- `expected_artifacts`
- `stop_conditions`
- `approval_requirements`

If `-ForbiddenActions` is omitted, the helper defaults to forbidding the V1 restricted-action list. If an action is supplied as a required approval requirement, the helper removes that exact action from the default forbidden list so the preflight can classify it as approval-gated instead of silently blocked by prose.

The helper can run local packet shape checks with `-ValidateShape`. It does not run preflight, start a worker, invoke Codex CLI, start background work, mutate product repos, push, merge, deploy, install packages, run migrations, access secrets, use PrivateLens, or approve any action.
