# Codex CLI Normal-Config Workspace-Write Fixture Retry V1

## Verdict

`TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL`

## Summary

This gate ran exactly one approved foreground Codex worker attempt using normal user config plus the approved service-tier override:

`codex exec -c service_tier=null --sandbox workspace-write --ephemeral --cd <TSF repo> --output-last-message <scratch> --json -`

The TSF mission packet, approval ledger, role-aware preflight, worker instruction generation, verifier, and preservation path all executed. Kernel preflight was `GREEN`, the approval ledger matched the exact action, and role-aware preflight was `GREEN`.

The worker attempt failed before action. Codex CLI exited `1` with:

`Error loading config.toml: unknown variant null, expected fast or flex in service_tier`

No fixture artifact was created, no forbidden paths were touched, and the verifier returned `RED` because the expected artifact was missing.

## Fixture Contract

- Expected artifact: `tests/fixtures/fleet/enforcement-kernel/worker-output/normal_config_workspace_write_fixture_worker_result.txt`
- Expected content: `TSF normal-config workspace-write foreground worker pilot complete.`
- Artifact created: no
- Artifact content matched: no
- Forbidden paths touched: no
- Product repos mutated: no
- Canonical NWR mutated: no
- API called: no
- Background runner started: no
- `--ignore-user-config` used: no
- `--sandbox workspace-write` used: yes
- `-c service_tier=null` used: yes
- `danger-full-access` used: no

## TSF Gate Results

- Kernel preflight: `GREEN`
- Approval ledger: `MATCHED_ACTIVE_APPROVAL`
- Role-aware preflight: `GREEN`
- Codex worker execution: invoked exactly once
- Codex exit code: `1`
- Worker status: `TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL`
- Post-run verifier: `RED`
- Preservation packet: written under the scratch evidence directory

## Conclusion

The normal-config workspace-write strategy did not reach the effective workspace-write question because `service_tier=null` is rejected by the installed Codex CLI runtime. A future retry needs a new exact Tim-approved strategy that avoids `null`, such as a validated literal supported tier, a config-field removal gate, or another safe config override. Do not run another worker attempt from this packet alone.
