# Preflight Validator V1

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tsf-kernel-preflight.ps1 -MissionPath <mission.json> -OutFile <preflight-result.json>
```

The validator checks one mission packet and fails closed.

Required checks:

- JSON parses and required mission fields exist.
- Array fields are actual JSON arrays.
- `repo_path` exists.
- allowed path scope stays inside the mission repo.
- forbidden path scope is explicit and machine-checkable.
- all baseline restricted actions are either explicitly forbidden or approval-gated.
- stop conditions have supported check types.
- git branch, HEAD, and `git status --short` can be captured.
- project is registered if `projects.json` exists, with a narrow TSF control-plane internal exception.
- approval requirements match an active local ledger entry or return `TIM_REQUIRED`.

V1 does not start a worker, runner, server, proof run, or all-fleet command.
