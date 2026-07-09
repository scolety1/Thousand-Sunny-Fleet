# Worker Role Registry V1

This registry preserves the 18 Project Main Bot and worker roles in machine-readable form.

Source: docs/hq/project_main_bot_worker_system_inventory_and_adaptation_v1/worker_role_registry_v1.csv.

Runtime posture: fail closed. Roles do not grant authority. The TSF kernel, approval ledger, verifier, and preservation packet remain the enforcement path.

Created files:

- leet/control/worker-role-registry.v1.json
- leet/control/worker-permission-profiles.v1.json
- docs/hq/project_main_bot_worker_role_foundation_overnight_v1/worker_role_registry_v1.csv

All roles default to:

- no Codex CLI execution
- no API use
- no product repo access
- no canonical NWR mutation or inspection
- no normal NWR packet reads
- no push, merge, deploy, install, migration, secrets, PrivateLens, all-fleet, proof, or background work

Future runtime integration should add role ids to mission drafts and run 	ools/Test-TsfWorkerRolePermission.ps1 before worker handoff.
