# New Ship Intake

Use this when adding a new project to Codex Fleet.

## Intake Form

```md
# New Ship Intake

Ship name:

Repo path or GitHub URL:

What it is:

Tech stack:

Build command:

Build directory:

Risk level:

Things Codex must not touch:

Goal for first autonomous run:

Deadline or event this supports:

Anything that must look especially good:

Anything that must stay boring and safe:

Ship admission score:

Admission decision: ADMIT / REVISE / PARK

Primary user:

Weekly job replaced:

First useful outcome:

Local evaluator:
```

## Profile Guide

Use `real-product` for:
- real users
- auth
- production data
- Firebase or backend risk
- payment, deployment, or business-critical behavior

Use `frontend-static-demo` for:
- Vite/React demo sites
- landing pages
- static sales pages
- fake sample data
- no backend

Use `docs-only` for:
- documentation repos
- planning docs
- policy or process cleanup

Use `experimental-prototype` for:
- sandbox-only prototypes
- fake data
- mock services
- no production writes

## Add Project Commands

Before adding a project, fill the admission docs or use the control-room rubric in `docs/SHIP_ADMISSION_SCORECARD.md`. New ships should score `70+` with no red flags before getting meaningful autonomous runtime.

Required ship docs:
- `docs/codex/USER_JOB.md`
- `docs/codex/EVALUATORS.md`
- `docs/codex/SHIP_ADMISSION.md`
- `docs/codex/SHIP_SCORECARD.md`
- `docs/codex/PRODUCT_USEFULNESS.md`

Static frontend demo:

```powershell
cd C:\Dev\codex-fleet
.\add-project.ps1 -Name ShipName -Repo C:\Dev\ship-repo -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
```

Real product with app subfolder:

```powershell
cd C:\Dev\codex-fleet
.\add-project.ps1 -Name ShipName -Repo C:\Dev\ship-repo -Profile real-product -BuildDirectory app-vNext -BuildCommand "npm.cmd run build"
```

Static/non-Node check:

```powershell
cd C:\Dev\codex-fleet
.\add-project.ps1 -Name ShipName -Repo C:\Dev\ship-repo -Profile frontend-static-demo -BuildDirectory . -BuildCommand "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1"
```

## First Proof Run

```powershell
cd C:\Dev\codex-fleet
.\run-checkpoint-loop.ps1 -Project ShipName -BatchSize 1 -MaxBatches 1 -VisualInspectEvery 1 -SimonEvery 1 -JoeyEvery 1 -ContinueOnYellowCheckpoint -QuarantineFailedTasks -MaxTaskQuarantines 1
```

## Safe Scale-Up

```powershell
cd C:\Dev\codex-fleet
.\run-checkpoint-loop.ps1 -Project ShipName -BatchSize 2 -MaxBatches 3 -VisualInspectEvery 1 -SimonEvery 1 -JoeyEvery 2 -ContinueOnYellowCheckpoint -QuarantineFailedTasks -MaxTaskQuarantines 3
```

## Morning Inspection

```powershell
cd C:\Dev\codex-fleet
.\fleet-status.ps1
.\fleet-morning-review.ps1
```

Review before merge:
- branch name
- build result
- changed files
- `docs/codex/NIGHTLY_REPORT.md`
- `docs/codex/CHECKPOINT_REVIEW.md`
- `docs/codex/SIMON_DESIGN_REVIEW.md`
- `docs/codex/JOEY_SECURITY_REVIEW.md`
- `docs/codex/VISUAL_BUGS.md`
- `docs/codex/QUARANTINED_TASKS.md` if present
- screenshots or local visual review for frontend ships

Never merge automatically.
