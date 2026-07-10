# Codex CLI Workspace-Write Fixture Worker Retry V1

Verdict: `YELLOW_TSF_CODEX_CLI_WORKSPACE_WRITE_WORKER_FAILED_CLOSED`

## Scope

This gate ran exactly one TSF-governed fixture-only foreground Codex worker attempt using:

`codex exec --ignore-user-config --sandbox workspace-write`

No retry was run. `danger-full-access` was not used.

## Mission

Create exactly one fixture artifact:

`tests/fixtures/fleet/enforcement-kernel/worker-output/workspace_write_fixture_worker_result.txt`

with exactly:

`TSF workspace-write foreground worker pilot complete.`

## Result

- Branch containment: passed.
- Starting HEAD: `a86b2426e3504ef8dd18f512f3516e6336b4c39a`.
- Worktree before worker: clean.
- `codex --version`: `codex-cli 0.124.0`.
- `codex exec --ignore-user-config --sandbox workspace-write --help`: exited `0`.
- Kernel preflight: `GREEN`.
- Role-aware preflight: `GREEN`.
- Approval ledger: exact fixture approval matched.
- Codex worker attempts in this gate: `1`.
- `--ignore-user-config` used: yes.
- `--sandbox workspace-write` used: yes.
- `danger-full-access` used: no.
- Worker exit code: `0`.
- Expected artifact created: no.
- Artifact content matched: no.
- Post-run verifier: `RED`.

## Worker Output Summary

The worker returned a blocked status:

`Blocked: the workspace is currently in a read-only sandbox, and approval requests are disabled, so I could not write the requested file. No files were modified.`

This shows the service-tier blocker remains bypassed, but the effective Codex worker runtime still applies read-only behavior despite the `--sandbox workspace-write` CLI argument.

## Fail-Closed Behavior

The gate failed closed:

- No expected artifact was created.
- No forbidden path was touched.
- No product repo was touched.
- Canonical NWR was not touched.
- No API call was made.
- No background runner was started.
- No push, merge, deploy, install, migration, secrets, PrivateLens, all-fleet, or `danger-full-access` action occurred.

## Evidence Paths

- Work packet: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709`
- Mission packet: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709\workspace_write_fixture_mission.json`
- Approval ledger: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709\workspace_write_fixture_approval_ledger.json`
- Preflight result: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709\preflight_result.json`
- Role preflight result: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709\role_permission_preflight.json`
- Worker result: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709\worker_result.json`
- Verifier result: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709\verifier_result.json`
- Preservation packet: `C:\NWR_REVIEW\tsf_codex_cli_workspace_write_fixture_worker_retry_v1_work_20260709\lifecycle\preservation\tsf-workspace-write-fixture-worker-20260709-preservation`

## Recommended Next Step

Do not run another worker retry until a separate Codex CLI execution-mode diagnostic explains why `--sandbox workspace-write` still resolves to read-only behavior in this environment. Any next retry should require Tim approval and must remain fixture-only.
