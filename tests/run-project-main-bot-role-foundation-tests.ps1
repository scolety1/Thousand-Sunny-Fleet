$ErrorActionPreference = "Stop"

$repo = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
Set-Location $repo

$failures = New-Object System.Collections.ArrayList

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
        Write-Host "FAIL: $Message" -ForegroundColor Red
    } else {
        Write-Host "PASS: $Message" -ForegroundColor Green
    }
}

function Read-Json {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path) "JSON exists: $Path"
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$registry = Read-Json "fleet/control/worker-role-registry.v1.json"
$profiles = Read-Json "fleet/control/worker-permission-profiles.v1.json"
$context = Read-Json "fleet/control/project-context-capsule.schema.v1.json"
$translator = Read-Json "fleet/control/translator-helper-contract.v1.json"
$extension = Read-Json "fleet/control/role-aware-mission-extension.v1.json"
$decision = Read-Json "fleet/control/main-bot-decision-authority.v1.json"
$parallelPolicy = Read-Json "fleet/control/parallel-lane-coordinator-policy.v1.json"

Assert-True (@($registry.roles).Count -eq 18) "worker role registry preserves all 18 roles"
Assert-True (@($profiles.profiles.PSObject.Properties).Count -eq 18) "permission profiles preserve all 18 roles"

$requiredRoleFields = @(
    "role_id", "role_name", "purpose", "when_to_call", "allowed_reads",
    "allowed_writes", "forbidden_actions", "output_contract",
    "verifier_required", "may_spawn_workers", "may_commit_locally",
    "may_invoke_codex_cli", "may_use_api", "may_touch_product_repo",
    "tim_required_for", "escalation_triggers"
)
foreach ($role in @($registry.roles)) {
    foreach ($field in $requiredRoleFields) {
        Assert-True ($null -ne $role.PSObject.Properties[$field]) "role $($role.role_id) has required field $field"
    }
    $templatePath = "fleet/control/worker-mission-templates/v1/$($role.role_id).mission-template.json"
    Assert-True (Test-Path -LiteralPath $templatePath) "worker template exists for $($role.role_id)"
    Read-Json $templatePath | Out-Null
}

$csvFiles = @(
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/worker_role_registry_v1.csv",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/worker_mission_template_index.csv",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/main_bot_decision_authority_matrix.csv",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/reuse_map/existing_component_reuse_map.csv"
)
foreach ($csv in $csvFiles) {
    Assert-True (Test-Path -LiteralPath $csv) "CSV exists: $csv"
    $rows = Import-Csv -LiteralPath $csv
    Assert-True (($rows | Measure-Object).Count -gt 0) "CSV imports with rows: $csv"
}

$mdFiles = @(
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/WORKER_ROLE_REGISTRY_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/ROLE_AWARE_MISSION_SCHEMA_EXTENSION_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/PROJECT_MAIN_BOT_MISSION_INTAKE_ADAPTER_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/TRANSLATOR_HELPER_CONTRACT_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/CONTEXT_MEMORY_STEWARD_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/MAIN_BOT_DECISION_AUTHORITY_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/PARALLEL_LANE_COORDINATOR_DRY_RUN_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/HQ_ESCALATION_ROLE_AWARE_EXAMPLES_V1.md",
    "docs/hq/project_main_bot_worker_role_foundation_overnight_v1/NEXT_STEPS_AFTER_ROLE_FOUNDATION_V1.md"
)
foreach ($md in $mdFiles) {
    Assert-True (Test-Path -LiteralPath $md) "Markdown artifact exists: $md"
    Assert-True ((Get-Item -LiteralPath $md).Length -gt 0) "Markdown artifact is non-empty: $md"
}

$outRoot = ".codex-local/project-main-bot-role-foundation-tests"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$safeDraftPath = Join-Path $outRoot "mission.safe.json"
& ".\tools\New-TsfProjectMainBotMissionDraft.ps1" `
    -ProjectId "thousand-sunny-fleet" `
    -NaturalRequest "Create TSF-local role registry docs and tests." `
    -RequestedGoal "Create TSF-local role registry docs and tests." `
    -ProposedWorkerRole "documentation_worker" `
    -AllowedReads @("docs/hq", "fleet/control") `
    -AllowedWrites @("docs/hq/project_main_bot_worker_role_foundation_overnight_v1") `
    -ExpectedArtifacts @("docs/hq/project_main_bot_worker_role_foundation_overnight_v1/WORKER_ROLE_REGISTRY_V1.md") `
    -OutFile $safeDraftPath | Out-Null
$safeDraft = Read-Json $safeDraftPath
Assert-True ($safeDraft.classification -eq "SAFE_LOCAL_MISSION") "mission intake creates SAFE_LOCAL_MISSION draft"

$permissionPath = Join-Path $outRoot "permission.safe.json"
& ".\tools\Test-TsfWorkerRolePermission.ps1" `
    -MissionDraftPath $safeDraftPath `
    -OutFile $permissionPath | Out-Null
$permission = Read-Json $permissionPath
Assert-True ($permission.verdict -eq "GREEN") "role-aware preflight approves safe local mission"

$unsafeDraftPath = Join-Path $outRoot "mission.unsafe-push.json"
& ".\tools\New-TsfProjectMainBotMissionDraft.ps1" `
    -ProjectId "thousand-sunny-fleet" `
    -NaturalRequest "Push and merge this branch." `
    -ProposedWorkerRole "release_preservation_worker" `
    -OutFile $unsafeDraftPath | Out-Null
$unsafeDraft = Read-Json $unsafeDraftPath
Assert-True ($unsafeDraft.classification -eq "NEEDS_TIM_APPROVAL") "unsafe push/merge request requires Tim approval"

$codexDraftPath = Join-Path $outRoot "mission.codex-api.json"
& ".\tools\New-TsfProjectMainBotMissionDraft.ps1" `
    -ProjectId "thousand-sunny-fleet" `
    -NaturalRequest "Invoke Codex CLI and call an API for worker routing." `
    -ProposedWorkerRole "ai_builder_worker" `
    -OutFile $codexDraftPath | Out-Null
$codexDraft = Read-Json $codexDraftPath
Assert-True ($codexDraft.classification -eq "NEEDS_TIM_APPROVAL") "Codex CLI/API request requires Tim approval"

$protectedDraftPath = Join-Path $outRoot "mission.protected-path.json"
& ".\tools\New-TsfProjectMainBotMissionDraft.ps1" `
    -ProjectId "thousand-sunny-fleet" `
    -NaturalRequest "Review role permissions." `
    -ProposedWorkerRole "researcher_source_tracer_worker" `
    -AllowedReads @("C:\NWR\Niners-War-Room") `
    -AllowedWrites @("docs/hq/project_main_bot_worker_role_foundation_overnight_v1") `
    -OutFile $protectedDraftPath | Out-Null
$protectedPermissionPath = Join-Path $outRoot "permission.protected-path.json"
& ".\tools\Test-TsfWorkerRolePermission.ps1" `
    -MissionDraftPath $protectedDraftPath `
    -OutFile $protectedPermissionPath | Out-Null
$protectedPermission = Read-Json $protectedPermissionPath
Assert-True ($protectedPermission.verdict -eq "TIM_REQUIRED") "product/canonical protected path is blocked by role-aware preflight"

$unknownDraftPath = Join-Path $outRoot "mission.unknown-role.json"
& ".\tools\New-TsfProjectMainBotMissionDraft.ps1" `
    -ProjectId "thousand-sunny-fleet" `
    -NaturalRequest "Do a local TSF docs task." `
    -ProposedWorkerRole "missing_worker_role" `
    -OutFile $unknownDraftPath | Out-Null
$unknownPermissionPath = Join-Path $outRoot "permission.unknown-role.json"
& ".\tools\Test-TsfWorkerRolePermission.ps1" `
    -MissionDraftPath $unknownDraftPath `
    -OutFile $unknownPermissionPath | Out-Null
$unknownPermission = Read-Json $unknownPermissionPath
Assert-True ($unknownPermission.verdict -eq "RED") "role-aware preflight fails closed on unknown role"

$translatorFixtures = Get-ChildItem -LiteralPath "tests/fixtures/fleet/project-main-bot/translator_examples" -Filter "*.json"
Assert-True ($translatorFixtures.Count -ge 6) "translator examples exist"
foreach ($fixture in $translatorFixtures) { Read-Json $fixture.FullName | Out-Null }

$sampleContext = Read-Json "tests/fixtures/fleet/project-main-bot/sample_project_context_capsule.json"
Assert-True ($sampleContext.project_id -eq "thousand-sunny-fleet") "sample context capsule parses"

$hqFixtures = Get-ChildItem -LiteralPath "tests/fixtures/fleet/project-main-bot/hq_escalation_examples" -Filter "*.json"
Assert-True ($hqFixtures.Count -ge 6) "HQ escalation examples exist"
foreach ($fixture in $hqFixtures) { Read-Json $fixture.FullName | Out-Null }

$parallelValidPath = Join-Path $outRoot "parallel.valid.result.json"
& ".\tools\Test-TsfParallelLanePlan.ps1" `
    -PlanPath "tests/fixtures/fleet/project-main-bot/parallel_lane_plans/parallel-plan.valid.json" `
    -OutFile $parallelValidPath | Out-Null
$parallelValid = Read-Json $parallelValidPath
Assert-True ($parallelValid.verdict -eq "GREEN") "parallel lane dry-run accepts non-overlapping plan"

$parallelCollisionPath = Join-Path $outRoot "parallel.collision.result.json"
& ".\tools\Test-TsfParallelLanePlan.ps1" `
    -PlanPath "tests/fixtures/fleet/project-main-bot/parallel_lane_plans/parallel-plan.collision.json" `
    -OutFile $parallelCollisionPath | Out-Null
$parallelCollision = Read-Json $parallelCollisionPath
Assert-True ($parallelCollision.verdict -eq "RED") "parallel lane dry-run detects file collision"

if ($failures.Count -gt 0) {
    Write-Host "Project Main Bot role foundation tests failed: $($failures.Count)" -ForegroundColor Red
    exit 1
}

Write-Host "Project Main Bot role foundation tests passed." -ForegroundColor Green
exit 0
