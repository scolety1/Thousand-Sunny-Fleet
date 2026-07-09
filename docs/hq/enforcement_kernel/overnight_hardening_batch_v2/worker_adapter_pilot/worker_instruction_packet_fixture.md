# Worker Instruction Packet Fixture

Mission ID: tsf-kernel-v2-codex-fixture-worker-pilot
Adapter status before CLI: STUB_READY_CODEX_CLI_BLOCKED

## Command Preview

```text
NOT RUN IN V1: codex exec --cd "C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet" < worker_instruction_packet.md
```

## Allowed Scope

Allowed reads: docs/hq/enforcement_kernel/overnight_hardening_batch_v2/fixture_pilot; tests/fixtures/fleet/enforcement-kernel

Allowed writes: tests/fixtures/fleet/enforcement-kernel/worker-output/fixture_worker_result.txt

## Forbidden Actions

push; merge; deploy; install_packages; migration; secrets; privatelens; proof_run; all_fleet; background_runner; persistent_runner; canonical_nwr_inspection; canonical_nwr_mutation; normal_nwr_packet_read; product_repo_inspection; product_repo_mutation; api_bridge; open_network_port; credential_change; app_wiring; ranking_formula_source_truth_promotion; hidden_sort; recommendation_behavior

## Expected Artifact Contract

tests/fixtures/fleet/enforcement-kernel/worker-output/fixture_worker_result.txt

## Post-Run Verifier Instruction

```powershell
After foreground worker output exists, run: powershell -NoProfile -ExecutionPolicy Bypass -File .\tsf-kernel-postrun-verify.ps1 -MissionPath <mission.json> -WorkerResultPath <worker-result.json> -OutFile <verifier-result.json>
```

## Actual Pilot Status

Codex CLI invoked: True
Codex exit code: 1
Worker status: CODEX_CLI_NONZERO
Final decision: RED
Blocked reasons: Codex CLI fixture pilot exited nonzero: 1
