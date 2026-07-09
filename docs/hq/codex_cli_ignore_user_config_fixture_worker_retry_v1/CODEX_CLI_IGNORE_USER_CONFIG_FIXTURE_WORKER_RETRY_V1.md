# Codex CLI Ignore-User-Config Fixture Worker Retry V1

Verdict: `YELLOW_TSF_CODEX_CLI_IGNORE_USER_CONFIG_WORKER_FAILED_CLOSED`

## Scope

This gate ran exactly one TSF-governed fixture-only foreground Codex worker attempt using:

`codex exec --ignore-user-config`

No retry was run.

## Mission

Create exactly one fixture artifact:

`tests/fixtures/fleet/enforcement-kernel/worker-output/ignore_user_config_fixture_worker_result.txt`

with exactly:

`TSF ignore-user-config foreground worker pilot complete.`

## Result

- Branch containment: passed.
- Starting HEAD: `dd1ee2f1a6fcc96b101dbcdffde61a14cd150fda`.
- Worktree before worker: clean.
- `codex --version`: `codex-cli 0.124.0`.
- `codex exec --ignore-user-config --help`: exited `0`.
- Plugin manifest warning during diagnostics: not observed.
- Kernel preflight: `GREEN`.
- Role-aware preflight: `GREEN`.
- Approval ledger: exact fixture approval matched.
- Codex worker attempts in this gate: `1`.
- `--ignore-user-config` used: yes.
- Worker exit code: `0`.
- Expected artifact created: no.
- Artifact content matched: no.
- Post-run verifier: `RED`.

## Worker Output Summary

The worker returned a concise blocked status:

`Blocked: the workspace is currently in a read-only sandbox, and approval is disabled, so I could not create the requested file. No files were changed.`

This means the prior `service_tier = "flex"` blocker was bypassed, but writable execution was still unavailable under the effective Codex CLI runtime policy.

## Fail-Closed Behavior

The gate failed closed:

- No expected artifact was created.
- No forbidden path was touched.
- No product repo was touched.
- Canonical NWR was not touched.
- No API call was made.
- No background runner was started.
- No push, merge, deploy, install, migration, secrets, PrivateLens, or all-fleet action occurred.

## Evidence Paths

- Work packet: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709`
- Mission packet: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709\ignore_user_config_fixture_mission.json`
- Approval ledger: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709\ignore_user_config_fixture_approval_ledger.json`
- Preflight result: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709\preflight_result.json`
- Role preflight result: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709\role_permission_preflight.json`
- Worker result: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709\worker_result.json`
- Verifier result: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709\verifier_result.json`
- Preservation packet: `C:\NWR_REVIEW\tsf_codex_cli_ignore_user_config_fixture_worker_retry_v1_work_20260709\lifecycle\preservation\tsf-ignore-user-config-fixture-worker-20260709-preservation`

## Recommended Next Step

Run a separate diagnostic gate for Codex CLI writable sandbox execution under `--ignore-user-config`. Do not run another worker retry until Tim approves the exact execution-mode change. The likely question is whether a narrow foreground fixture retry may use a CLI mode such as `--full-auto` or another explicit approval/sandbox setting that preserves TSF scope while allowing the single fixture file write.
