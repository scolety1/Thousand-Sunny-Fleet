# TSF Repo Onboarding Workflow V1

Evidence only; not executable authority or product-repo mutation approval.

## Purpose

TSF Repo Onboarding Workflow V1 is the canonical route for adding a repo to the
fleet without losing the source-trace discipline:

1. Register the repo using the existing TSF project framework.
2. Run a read-only inventory before product changes.
3. Search for existing features, tools, workflows, docs, tests, and protocols.
4. Produce improvement opportunities without implementing them.
5. Create continuation/handoff context for future Codex runs.
6. Produce a review packet.
7. Stop before product repo mutation unless Tim approves exact scope.

Research first. Source trace first. Code second.

## Existing TSF Assets Reused

- `add-project.ps1` remains the registration path.
- `projects.json` remains the project metadata registry.
- `docs/HOW_TO_ADD_PROJECT.md` remains the operator entrypoint.
- `tools/fleet-proof-run-preflight.ps1` remains proof-run preflight logic.
- Coder Upgrade outputs remain supporting context and recovery evidence.
- Blocker-recovery protocols remain the stop/recovery path when onboarding hits
  a true blocker.

This workflow extends the current TSF framework. It does not replace
`add-project.ps1`, duplicate `projects.json`, or create a parallel registry.

## Canonical Route

### 1. Register Repo

Use the existing project intake:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\add-project.ps1 -Name YourProject -Repo C:\Dev\your-project -Profile real-product
```

Expected TSF-side result:

- project is present in `projects.json`
- repo metadata is recorded using the existing schema
- harness files are installed only when that action is in scope

If registration would require forbidden action, stop and repacketize.

### 2. Run Read-Only Repo Inventory

Generate a TSF-side onboarding packet with the read-only adapter:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-repo-onboarding-packet.ps1 `
  -Repo C:\Dev\your-project `
  -ProjectName YourProject `
  -RequestedCapability "feature or workflow to trace" `
  -OutDirectory .\fleet\status\repo-onboarding\your-project
```

The adapter scans:

- top-level structure
- important docs
- scripts/tools
- tests
- configs
- package/build files
- CI/workflow files
- data folders
- generated/artifact folders
- project-specific protocols
- likely app entrypoints
- likely test entrypoints
- current git status summary
- obvious risk areas

The adapter writes only the configured output directory and rejects an output
directory inside the scanned target repo.

### 3. Run Existing-Feature / Source-Trace Scan

Use `-RequestedCapability` to search for whether the requested feature, tool, or
workflow already exists.

Classifications:

- `already_exists_operational`
- `exists_partial`
- `exists_docs_only`
- `exists_test_only`
- `exists_wrong_scope`
- `exists_stale`
- `exists_conflicting`
- `exists_duplicate`
- `not_found`

Reuse decisions:

- `REUSE`
- `EXTEND_EXISTING`
- `DOCUMENT_EXISTING`
- `VALIDATE_EXISTING`
- `ADAPTER_NEEDED`
- `NEW_BUILD_MAY_BE_NEEDED_LATER`
- `STOP`

Default action: reuse or extend existing assets when source trace supports it.
Do not rebuild under a new name until the detector and packet have been
reviewed.

### 4. Generate Improvement Opportunity Register

The packet includes `improvement_opportunities.csv`.

Each row is review-only and includes:

- opportunity id
- area
- evidence
- existing assets involved
- risk
- suggested next step
- whether coding is allowed now
- why or why not

Default coding state is `false`; onboarding evidence can support a later
bounded lane, but it does not approve implementation.

### 5. Create Continuation / Handoff Context

The packet includes `onboarding_handoff.md` so future TSF/Codex runs know:

- what repo was onboarded
- what was scanned
- what already exists
- what should not be rebuilt
- what gaps remain
- what future lanes are safe
- what requires Tim approval
- what product repo boundaries apply

Use this handoff before asking a new Codex run to touch the repo.

### 6. Produce Review Packet

Required packet files from `tools/write-repo-onboarding-packet.ps1`:

- `repo_inventory.csv`
- `existing_feature_scan.csv`
- `improvement_opportunities.csv`
- `onboarding_handoff.md`
- `repo_onboarding_review.md`
- `repo_onboarding_validation.json`

These files are evidence and handoff context. They are not implementation
approval.

### 7. Stop Before Product Mutation

Stop after the review packet unless Tim approves exact next scope.

Product repo mutation, installs, migrations, secrets, push, merge, deploy,
proof runs, all-fleet commands, background runners, risk-area edits, and
restricted product operations remain Tim-gated.

## Boundaries

- Preserve repo boundaries.
- Do not write onboarding output inside the scanned target repo.
- Do not use product repo paths in TSF metadata as approval to inspect or
  mutate those repos.
- Do not treat generated packets as authority.
- Do not replace existing TSF registration, registry, proof-preflight, Coder
  Upgrade, or blocker-recovery assets.

## Validation

Focused validation lives in `tests/run-fleet-tests.ps1` under
`Test-HqTsfRepoOnboardingFrameworkV1`.

Safe direct smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-repo-onboarding-packet.ps1 `
  -Repo .\tests\fixtures\fleet\repo-onboarding\sample-app `
  -ProjectName FixtureOnboarding `
  -RequestedCapability "report export" `
  -OutDirectory .\.codex-local\fixtures\repo-onboarding-smoke
```

Expected result: the fixture repo remains unchanged and the output directory
contains the inventory, feature scan, improvement register, handoff, review,
and validation files.
