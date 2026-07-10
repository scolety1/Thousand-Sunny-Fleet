# Codex CLI Priority Config / Fixture Worker Gate V1

## Verdict

YELLOW_TSF_CODEX_CLI_PRIORITY_GATE_CONFIG_EDITED_NO_WORKER

## Summary

The priority gate proved that service_tier = "priority" is invalid for the installed codex-cli 0.124.0 environment. The one foreground codex exec worker attempt failed before worker action with local CLI evidence: unknown variant priority, expected ast or lex.

The config was backed up, then only service_tier was changed from priority to lex. A post-edit codex exec --help parse check succeeded. No second worker invocation was run, so the expected fixture artifact was not created and the TSF verifier failed closed.

## Scope Confirmation

- Repo: $repo
- Branch: work/tsf-pack-and-go-autonomous-deployment-v1-20260709
- Starting HEAD: 90604078d29d156a0ada56a6e23d1aa1f21166c
- Config decision: PRIORITY_INVALID_SAFE_EDIT_TO_FLEX
- Config edited: yes, service_tier only
- Backup path: $backupPath
- Codex worker execution invoked: attempted once, failed before worker action
- Expected artifact created: no
- Verifier result: $(@{schema_version=1; generated_at=2026-07-09T13:09:04.3694450-06:00; mission_id=tsf-priority-gate-fixture-worker-20260709; verdict=RED; final_state=blocked_red; verified=False; checks=System.Object[]; blocked_reasons=System.Object[]; warnings=System.Object[]; background_runner_started=False; all_fleet_started=False; product_repos_mutated=False; canonical_nwr_mutated=False; push_merge_deploy_attempted=False}.verdict)

## Guardrails

No push, merge, deploy, install, migration, secrets, PrivateLens, all-fleet, background runner, product repo mutation, canonical NWR mutation, normal NWR packet read, broad worker swarm, or API call occurred.

## Next Action

Run a separate exact Tim-approved fixture worker execution gate now that local config parses with service_tier = "flex". Do not reuse this lane's consumed worker attempt as approval for another codex exec invocation.
