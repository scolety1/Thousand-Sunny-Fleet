# Worker Instruction Packet Sample

Mission ID: tsf-kernel-fixture-valid-0001

Adapter status: STUB_READY_CODEX_CLI_BLOCKED

## Command Preview

```text
NOT RUN IN V1: codex exec --cd "C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet\.codex-local\fixtures\overnight-hardening-dogfood\repo" < worker_instruction_packet.md
```

## Allowed Scope

Allowed reads: docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1; tools/codex-fleet-enforcement-kernel.ps1

Allowed writes: expected/fixture-artifact.txt

## Forbidden Actions

push; merge; deploy; install_packages; migration; secrets; privatelens; proof_run; all_fleet; background_runner; persistent_runner; canonical_nwr_inspection; canonical_nwr_mutation; normal_nwr_packet_read; product_repo_inspection; product_repo_mutation; api_bridge; open_network_port; credential_change; app_wiring; ranking_formula_source_truth_promotion; hidden_sort; recommendation_behavior

## Expected Artifact Contract

expected/fixture-artifact.txt

## Worker Instruction

Use only the mission packet scope. Do not run background, all-fleet, product repo mutation, push, merge, deploy, install, migration, secrets, PrivateLens, canonical NWR, or normal NWR packet work.

## Post-Run Verifier Instruction

```powershell
After foreground worker output exists, run: powershell -NoProfile -ExecutionPolicy Bypass -File .\tsf-kernel-postrun-verify.ps1 -MissionPath <mission.json> -WorkerResultPath <worker-result.json> -OutFile <verifier-result.json>
```

## Restricted-Action Confirmation

- Codex CLI exec invoked: false
- Background runner started: false
- All-fleet command started: false
- Product repo mutated: false
