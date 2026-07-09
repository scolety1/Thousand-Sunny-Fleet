# Codex CLI Fast Workspace-Write Fixture Retry V1

## Verdict

`GREEN_TSF_CODEX_CLI_FAST_WORKSPACE_WRITE_FIXTURE_PASSED`

## Summary

This gate ran exactly one approved foreground Codex worker attempt using normal user config with only the service-tier override:

`codex exec -c service_tier=fast --sandbox workspace-write --ephemeral --cd <TSF repo> --output-last-message <scratch> --json -`

The worker prompt was passed through stdin. The worker created exactly the approved fixture artifact, touched no other repo paths, and the TSF post-run verifier returned `GREEN`.

## Fixture Contract

- Expected artifact: `tests/fixtures/fleet/enforcement-kernel/worker-output/fast_workspace_write_fixture_worker_result.txt`
- Expected content: `TSF fast workspace-write foreground worker pilot complete.`
- Artifact created: yes
- Artifact content matched: yes
- Forbidden paths touched: no
- Product repos mutated: no
- Canonical NWR mutated: no
- API called: no
- Background runner started: no
- `service_tier=fast` used: yes
- `--sandbox workspace-write` used: yes
- `--ignore-user-config` used: no
- `danger-full-access` used: no

## TSF Gate Results

- Kernel preflight: `GREEN`
- Approval ledger: `MATCHED_ACTIVE_APPROVAL`
- Role-aware preflight: `GREEN`
- Codex worker execution: invoked exactly once
- Codex exit code: `0`
- Worker status: `CODEX_CLI_FIXTURE_WORKER_GREEN`
- Post-run verifier: `GREEN`
- Preservation packet: written under the scratch evidence directory

## Worker Last Message

The worker reported that it wrote the requested fixture file and touched no other files.

## Conclusion

The `service_tier=fast` strategy successfully allowed one TSF-governed foreground Codex worker to execute under `workspace-write` and satisfy the exact fixture contract. This does not approve broader worker execution, product repo work, background automation, push, merge, deploy, API transport, or Operator Console work.
