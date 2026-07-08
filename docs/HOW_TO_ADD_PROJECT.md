# How To Add A Project

## 1. Add the project to the fleet

Prefer `add-project.ps1` for new projects. It installs the repo harness files, registers build settings, excludes raw logs locally, and validates the fleet config.

```powershell
cd C:\Dev\codex-fleet
.\add-project.ps1 -Name YourProject -Repo C:\Dev\your-project -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
```

Profiles:

- `real-product`
- `frontend-static-demo`
- `docs-only`
- `experimental-prototype`

Phase 0 intake fields are recorded in `projects.json` when a ship joins the fleet. Profiles provide conservative defaults, and you can override them during intake:

```powershell
.\add-project.ps1 -Name YourApi -Repo C:\Dev\your-api -Profile real-product -ProjectType full-stack-web -RiskTier staging -Capability edit-backend-code
```

Supported project types: `marketing-site`, `full-stack-web`, `desktop-app`, `cli-tool`, `library`, `data-pipeline`, `ai-workflow`, `mobile-app`, `game`, `documentation`, `sandbox-prototype`.

Supported risk tiers: `sandbox`, `local-only`, `staging`, `production-adjacent`, `production`.

Supported capabilities: `edit-package-files`, `add-dependencies`, `edit-backend-code`, `edit-migrations`, `edit-auth-policy`, `edit-deployment-config`, `use-network-apis`, `open-pull-requests`, `deploy`.

For EasyLife-style repos where the app lives in a subfolder:

```powershell
.\add-project.ps1 -Name YourProduct -Repo C:\Dev\your-product -Profile real-product -BuildDirectory app-vNext -BuildCommand "npm.cmd run build"
```

If the repo already has uncommitted changes, commit them first. Use `-Force` only when you intentionally want to install/register despite a dirty tree.

## 2. Run the repo onboarding packet

Before product-repo changes, run the canonical repo onboarding route in
`docs/fleet/TSF_REPO_ONBOARDING_WORKFLOW_V1.md`.

The route is:

1. register repo with `add-project.ps1`
2. run read-only repo inventory
3. run existing-feature/source-trace scan
4. generate improvement opportunity register
5. create continuation/handoff context
6. produce review packet
7. stop before product repo mutation unless Tim approves exact scope

Use the TSF-local packet generator:

```powershell
cd C:\Dev\codex-fleet
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-repo-onboarding-packet.ps1 `
  -Repo C:\Dev\your-project `
  -ProjectName YourProject `
  -RequestedCapability "feature or workflow to trace" `
  -OutDirectory .\fleet\status\repo-onboarding\your-project
```

The packet generator writes only the configured output directory and rejects an
output directory inside the scanned target repo. Review
`existing_feature_scan.csv`, `improvement_opportunities.csv`, and
`onboarding_handoff.md` before any coding lane.

## 3. Edit the task queue

For serious software ships, create the Phase 1 architecture pack before broad implementation:

```powershell
cd C:\Dev\codex-fleet
.\fleet-plan.ps1 -Project YourProject -Template
```

Review the generated files in `docs/codex/`, then change `docs/codex/ARCHITECTURE_APPROVAL.md` to `Status: APPROVED` only after human review. Check the gate with:

```powershell
.\fleet-plan.ps1 -Project YourProject -ValidateOnly
```

After architecture approval, use the Phase 2 scaffold gate for new codebases:

```powershell
.\scaffold-project.ps1 -Repo C:\Dev\your-project -ScaffoldType vite-react -Register
```

Allowed scaffold types: `vite-react`, `next-js`, `express-api`, `electron-desktop`, `python-cli`, `library-js`, `test-harness`.

Scaffolds that add package dependencies also create `docs/codex/DEPENDENCY_PROPOSAL.md` and `docs/codex/DEPENDENCY_APPROVAL.md` with `Status: DRAFT`. Keep dependency work gated until human review changes the approval file to `Status: APPROVED`.

When the ship is mature enough for recurring maintenance, install the Phase 8 maintenance templates:

```powershell
.\fleet-maintenance.ps1 -Project YourProject -Template
```

The regular maintenance report is read-only:

```powershell
.\fleet-maintenance.ps1 -Project YourProject
```

Before any limited business autopilot lane is allowed, create and review the Phase 9 policy templates:

```powershell
.\fleet-autopilot-policy.ps1 -Project YourProject -Template
```

Keep `AUTOPILOT_APPROVAL.md` in `Status: DRAFT` until the safe lanes, spending limit, customer-data rules, and escalation rules have human approval.

Open:

```text
C:\Dev\your-project\docs\codex\TASK_QUEUE.md
```

Add small unchecked tasks using:

```md
- [ ] Narrow task: describe exactly one safe change. Do not add backend, auth, payment, secrets, deployment, dependencies, or broad rewrites.
```

## 4. Prove the project with one task first

```powershell
cd C:\Dev\codex-fleet
.\run-checkpoint-loop.ps1 -Project YourProject -BatchSize 1 -MaxBatches 1
```

If that passes, scale slowly:

```powershell
.\run-checkpoint-loop.ps1 -Project YourProject -BatchSize 2 -MaxBatches 1
```

Then choose longer settings based on risk:

```powershell
.\run-checkpoint-loop.ps1 -Project YourProject -BatchSize 3 -MaxBatches 4
```

## 5. Validate or review anytime

```powershell
.\run-checkpoint-loop.ps1 -Project YourProject -ValidateOnly
.\debug-checkpoint.ps1 -Repo C:\Dev\your-project
.\fleet-status.ps1
```

## 6. Generate next-task request

```powershell
cd C:\Dev\codex-fleet
.\planner\prepare-next-task-request.ps1 -Repo C:\Dev\your-project
```

Paste `docs/codex/NEXT_TASK_REQUEST.md` into ChatGPT Pro, or run the Codex CLI planner:

```powershell
.\planner\run-planner.ps1 -Repo C:\Dev\your-project
```

## 7. Import proposed tasks

Review:

```text
C:\Dev\your-project\docs\codex\NEXT_TASKS_PROPOSED.md
```

Then import:

```powershell
.\planner\import-next-tasks.ps1 -Repo C:\Dev\your-project -Mode append
```

## Morning merge check

Before merging an unattended branch, run:

```powershell
cd C:\Dev\codex-fleet
.\fleet-morning-review.ps1
```

Only merge after the branch is clean, the build passes, and the report/diff look safe.

## Mission checkpoint loop

For longer autonomous work, create or edit:

```text
C:\Dev\your-project\docs\codex\MISSION.md
```

Then run:

```powershell
cd C:\Dev\codex-fleet
.\run-checkpoint-loop.ps1 -Project YourProjectName -BatchSize 5 -MaxBatches 2 -PushCheckpoint
```

The loop may push the Codex branch if `-PushCheckpoint` is used, but it never merges to `main`.

## What a project needs

Minimum files inside the target repo:

```text
docs/codex/MISSION.md
docs/codex/TASK_QUEUE.md
docs/codex/RUN_POLICY.md
docs/codex/NIGHTLY_REPORT.md
scripts/codex-brief.ps1
scripts/codex-guardrails.ps1
scripts/codex-night-loop.ps1
```

`add-project.ps1` creates these from templates when they are missing.
