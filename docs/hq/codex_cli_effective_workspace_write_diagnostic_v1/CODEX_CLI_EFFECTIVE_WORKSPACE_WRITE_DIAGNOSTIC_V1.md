# Codex CLI Effective Workspace-Write Diagnostic V1

Verdict: `GREEN_WORKSPACE_WRITE_STRATEGY_READY_FOR_FIXTURE_RETRY`

Strategy classification: `GREEN_RETRY_WITHOUT_IGNORE_USER_CONFIG`

## Scope

This was a diagnostic-only gate. No prompt-bearing `codex exec` worker task was run.

## Short Answer

The failed workspace-write retry used correct local CLI syntax and ran from the TSF repo root, but `--ignore-user-config` bypassed the local Codex user config that marks the TSF project trusted and sets Windows sandbox behavior:

- `[projects.'c:\users\codex-agent\documents\vacation\thousand-sunny-fleet'] trust_level = "trusted"`
- `[windows] sandbox = "elevated"`

The TSF mission, approval ledger, role-aware preflight, and normal shell write permissions were all valid. The effective read-only behavior appears to come from the nested Codex runtime running without the local user config that enables trusted/elevated Windows workspace writes.

## Failed Command Inspected

`codex exec --ignore-user-config --sandbox workspace-write --ephemeral --cd C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet --output-last-message <scratch> --json -`

- Run from TSF repo root: yes
- `--cd` repo root supplied: yes
- Sandbox flag syntax matches local help: yes
- `danger-full-access` used: no
- Worker prompt-bearing retry run in this diagnostic gate: no

## Diagnostic Questions

1. Exact command used: recorded above and in `failed_workspace_write_invocation_trace_redacted.json`.
2. Command run from TSF repo root: yes.
3. Correct sandbox flag syntax: yes, local help lists `--sandbox <SANDBOX_MODE>` with `workspace-write`.
4. Relevant flags exposed by local help: `--sandbox`, `--cd`, `--add-dir`, `--profile`, `--config`, `--full-auto`, `--ignore-user-config`; no separate named approval-mode flag was found.
5. Did `--ignore-user-config` remove a necessary setting: likely yes. It bypassed trusted project metadata and `[windows] sandbox = "elevated"`.
6. Did project rules or worker instructions say read-only: no TSF `AGENTS.md`, `.rules`, or exec-policy files were found; worker instructions did not instruct read-only behavior.
7. Did approval ledger allow fixture write path: yes.
8. Did mission packet allow fixture write path: yes.
9. Was fixture output directory present and writable by normal shell: yes; a temp diagnostic file was created and removed successfully.
10. Is `workspace-write` supported in local help: yes, but effective worker runtime still acted read-only when user config was ignored.
11. Is a safe next worker retry possible without `danger-full-access`: yes, with caveat. Use normal user config so trusted/elevated Windows sandbox settings load, but override the invalid service tier at the command line.

## Recommended Next Command Shape

For a separate Tim-approved one-attempt fixture retry:

`codex exec -c service_tier=null --sandbox workspace-write --ephemeral --cd <TSF repo> --output-last-message <scratch> --json -`

Rationale:

- Avoids `--ignore-user-config`, preserving trusted project and Windows sandbox config.
- Overrides the known bad `service_tier = "flex"` without editing config.
- Keeps the documented `workspace-write` sandbox.
- Does not use `danger-full-access`.

## Caveats

- `-c service_tier=null` has been help-tested only; it has not been worker-tested in this gate.
- The temp `ngs-analysis` plugin prompt warning may still appear, but it did not cause the read-only failure.
- A new worker attempt still requires a separate exact Tim approval.

## Stop Result

No worker retry was run in this diagnostic gate. No config was edited. No push, merge, deploy, install, migration, secrets, PrivateLens, all-fleet, API, background runner, product repo mutation, or canonical NWR mutation occurred.
