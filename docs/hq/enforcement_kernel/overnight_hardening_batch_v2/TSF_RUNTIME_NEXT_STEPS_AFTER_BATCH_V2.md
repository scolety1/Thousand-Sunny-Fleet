# TSF Runtime Next Steps After Batch V2

## Ready For Commit

- Foreground lifecycle runner.
- Exact fixture mission and approval ledger example.
- Failure-mode regression fixtures and V2 tests.
- HQ escalation packet schema, no API.

## Ready For Local Manual Use

- Author mission packets with `tools/New-TsfMissionPacket.ps1`.
- Run dry-run lifecycle without worker execution.
- Use preflight, verifier, and preservation packet commands on TSF-local fixtures.

## Needs Tim Approval

- Any retry of Codex CLI worker execution with config override, config edit, or `--ignore-user-config`.
- Any product repo mission.
- Any canonical NWR or normal NWR packet mission.
- Any push, merge, deploy, install, migration, secrets, PrivateLens, all-fleet, or background runner action.

## Should Wait Until Operator Console

- Mission queue browsing and lifecycle buttons.
- Approval ledger UI.
- Multi-mission state dashboard.

## Should Wait Until API/HQ Choke-Point Integration

- Sending HQ escalation packets to API.
- Source-truth promotion review.
- Model/ranking/formula decisions.

## Should Not Build Yet

- Persistent runner.
- App-server bridge.
- Product-repo autopilot.
- All-fleet lifecycle runner.
