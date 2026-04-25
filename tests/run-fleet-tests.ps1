[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$KeepFixtures
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$fixtureRoot = Join-Path $fleetRoot ".codex-local\fixtures"
$fixtureConfig = Join-Path $fixtureRoot "projects.fixture.json"
$runtimePath = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"

. $runtimePath

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $script:Failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        Write-Host "PASS: $Message" -ForegroundColor Green
    } else {
        Add-Failure $Message
    }
}

function Assert-False {
    param(
        [bool]$Condition,
        [string]$Message
    )

    Assert-True -Condition (!$Condition) -Message $Message
}

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ([string]$Actual -eq [string]$Expected) {
        Write-Host "PASS: $Message" -ForegroundColor Green
    } else {
        Add-Failure "$Message (expected '$Expected', got '$Actual')"
    }
}

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory = $fleetRoot,
        [int]$TimeoutSeconds = 60
    )

    return Invoke-FleetProcess -FilePath $FilePath -Arguments $Arguments -WorkingDirectory $WorkingDirectory -TimeoutSeconds $TimeoutSeconds
}

function Get-Project {
    param([string]$Name)

    $parsedProjects = Get-Content $fixtureConfig -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    return @($projects | Where-Object { [string]$_.name -eq $Name })[0]
}

function Test-PowerShellParsing {
    $files = @()
    $files += @(Get-ChildItem $fleetRoot -Filter "*.ps1" -File)
    $files += @(Get-ChildItem (Join-Path $fleetRoot "tools") -Filter "*.ps1" -File)
    $files += @(Get-ChildItem (Join-Path $fleetRoot "tests") -Filter "*.ps1" -File)

    foreach ($file in $files) {
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        Assert-Equal -Actual $parseErrors.Count -Expected 0 -Message "PowerShell parses $($file.Name)"
    }
}

function Test-TaskParsing {
    $lines = @(
        "- [ ] Top task",
        "  - [ ] Indented task",
        "`t- [ ] Tabbed task",
        "- [x] Completed task",
        "   text - [ ] not a task"
    )
    $unchecked = @($lines | Where-Object { $_ -match "^\s*-\s+\[ \]\s+(.+)$" })
    Assert-Equal -Actual $unchecked.Count -Expected 3 -Message "Unchecked markdown task regex allows zero or more leading whitespace"

    $updated = $false
    $completed = foreach ($line in $lines) {
        if (-not $updated -and $line -match "^(\s*-\s+)\[ \](\s+.+)$") {
            $updated = $true
            "$($Matches[1])[x]$($Matches[2])"
        } else {
            $line
        }
    }
    Assert-Equal -Actual $completed[0] -Expected "- [x] Top task" -Message "Task completion regex marks the first unchecked task only"
    Assert-Equal -Actual $completed[1] -Expected "  - [ ] Indented task" -Message "Task completion regex leaves later unchecked tasks alone"

    $quarantined = $false
    $quarantinedLines = foreach ($line in $lines) {
        if (-not $quarantined -and $line -match "^(\s*-\s+)\[ \](\s+.+)$") {
            $quarantined = $true
            "$($Matches[1])[!]$($Matches[2])"
        } else {
            $line
        }
    }
    Assert-Equal -Actual $quarantinedLines[0] -Expected "- [!] Top task" -Message "Task quarantine syntax removes failed task from unchecked queue"
    $remainingUnchecked = @($quarantinedLines | Where-Object { $_ -match "^\s*-\s+\[ \]\s+(.+)$" })
    Assert-Equal -Actual $remainingUnchecked.Count -Expected 2 -Message "Quarantined tasks are skipped by unchecked-task regex"
}

function Test-RuntimeHelpers {
    Assert-True -Condition (Test-FleetRateLimitOutput -Output @("usage limit reached, try again in 12 minutes")) -Message "Rate-limit detector catches usage limit text"
    Assert-False -Condition (Test-FleetRateLimitOutput -Output @("regular build failed")) -Message "Rate-limit detector ignores normal failures"
    Assert-Equal -Actual (Get-FleetRateLimitDelaySeconds -Output @("try again in 12 minutes") -DefaultSeconds 3600) -Expected 780 -Message "Rate-limit delay parser adds a small buffer"

    Assert-True -Condition (Test-FleetBlockingReviewOutput -Text "REVIEW_FINDING: P1: bad thing") -Message "Review parser blocks P1 findings"
    Assert-True -Condition (Test-FleetBlockingReviewOutput -Text "::code-comment{priority=2 file='x'}") -Message "Review parser blocks priority 2 inline comments"
    Assert-False -Condition (Test-FleetBlockingReviewOutput -Text "REVIEW_STATUS: PASS") -Message "Review parser allows clean pass"

    $splitModels = @(ConvertTo-FleetStringArray -Value "gpt-5.5,gpt-5.4")
    Assert-Equal -Actual $splitModels.Count -Expected 2 -Message "Runtime splits delimited model chains"
    Assert-Equal -Actual $splitModels[1] -Expected "gpt-5.4" -Message "Runtime preserves model chain order"

    $splitArrayModels = @(ConvertTo-FleetStringArray -Value @("gpt-5.5,gpt-5.4"))
    Assert-Equal -Actual $splitArrayModels.Count -Expected 2 -Message "Runtime recursively splits delimited array items"

    $modelArgs = @(Add-FleetArrayArgument -Arguments @("-File", "planner.ps1") -Name "-Models" -Values @("gpt-5.5", "gpt-5.4"))
    Assert-Equal -Actual ($modelArgs -join "|") -Expected "-File|planner.ps1|-Models|gpt-5.5,gpt-5.4" -Message "Runtime passes array arguments as one CLI value"

    $pathArgs = @(Add-FleetArrayArgument -Arguments @("-File", "visual-inspect.ps1") -Name "-Paths" -Values @("/", "/wine.html"))
    Assert-Equal -Actual ($pathArgs -join "|") -Expected "-File|visual-inspect.ps1|-Paths|/,/wine.html" -Message "Runtime packs slash-prefixed visual paths into one CLI value"

    $normalizedVisualPaths = @(@("/,/wine.html") | ForEach-Object { ([string]$_) -split "," } | ForEach-Object { $_.Trim() } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    Assert-Equal -Actual ($normalizedVisualPaths -join "|") -Expected "/|/wine.html" -Message "Visual path normalization restores packed slash-prefixed routes"

    $singleChangedFile = @(@("src/app.txt") | Sort-Object -Unique)
    $combinedStageList = @($singleChangedFile + @("docs/codex/TASK_QUEUE.md", "docs/codex/NIGHTLY_REPORT.md"))
    Assert-Equal -Actual $combinedStageList.Count -Expected 3 -Message "Single-file change lists stay arrays before staging"

    $shimRoot = Join-Path $env:TEMP ("fleet shim test " + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $shimRoot | Out-Null
    $ps1Shim = Join-Path $shimRoot "sample-tool.ps1"
    $cmdShim = Join-Path $shimRoot "sample-tool.cmd"
    Set-Content -Path $ps1Shim -Value "Write-Output 'ps1-shim'"
    Set-Content -Path $cmdShim -Value @("@echo off", "echo cmd-shim %1")
    try {
        $resolvedShim = Resolve-FleetProcessFilePath -FilePath $ps1Shim
        Assert-Equal -Actual $resolvedShim -Expected $cmdShim -Message "Runtime prefers adjacent cmd shim for ps1 tools"

        $shimResult = Invoke-FleetProcess -FilePath $ps1Shim -Arguments @("ok") -TimeoutSeconds 10
        Assert-Equal -Actual $shimResult.exitCode -Expected 0 -Message "Invoke-FleetProcess executes cmd shims"
        Assert-True -Condition (($shimResult.output -join "`n") -match "cmd-shim ok") -Message "Invoke-FleetProcess passes arguments to cmd shims"

        $nodeCommand = Get-Command "node" -ErrorAction SilentlyContinue
        if ($nodeCommand) {
            $nodeScript = Join-Path $shimRoot "read-utf8.js"
            Set-Content -Path $nodeScript -Encoding UTF8 -Value "const chunks=[];process.stdin.on('data', b=>chunks.push(b));process.stdin.on('end',()=>{const b=Buffer.concat(chunks);if(!b.includes(Buffer.from([0xc3,0xa9]))){process.exit(2);}console.log(b.toString('utf8'));});"
            $accentedText = "caf" + [char]0x00E9
            $utf8Result = Invoke-FleetProcess -FilePath "node" -Arguments @($nodeScript) -InputText $accentedText -TimeoutSeconds 10
            Assert-Equal -Actual $utf8Result.exitCode -Expected 0 -Message "Invoke-FleetProcess writes stdin as UTF-8"
            Assert-True -Condition (($utf8Result.output -join "`n") -match $accentedText) -Message "Invoke-FleetProcess preserves UTF-8 stdin text"
        }
    } finally {
        Remove-Item -LiteralPath $shimRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $codexCommand = Get-Command "codex.cmd" -ErrorAction SilentlyContinue
    if ($codexCommand) {
        $resolvedCodex = Resolve-FleetProcessFilePath -FilePath "codex"
        Assert-True -Condition ($resolvedCodex -like "*.cmd") -Message "Runtime resolves codex to executable cmd shim on Windows"
    }

    $normal = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-Command", "Write-Output fixture-ok") -TimeoutSeconds 10
    Assert-Equal -Actual $normal.exitCode -Expected 0 -Message "Invoke-FleetProcess captures successful exit code"
    Assert-True -Condition (($normal.output -join "`n") -match "fixture-ok") -Message "Invoke-FleetProcess captures output"

    $timeout = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-Command", "Start-Sleep -Seconds 5") -TimeoutSeconds 1
    Assert-Equal -Actual $timeout.exitCode -Expected 124 -Message "Invoke-FleetProcess returns 124 on timeout"
    Assert-True -Condition $timeout.timedOut -Message "Invoke-FleetProcess marks timed-out process"
}

function Test-FixtureGeneration {
    $generator = Join-Path $fleetRoot "tests\new-fixture-ships.ps1"
    $result = Invoke-Checked -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $generator, "-Force")
    Assert-Equal -Actual $result.exitCode -Expected 0 -Message "Fixture ship generator exits successfully"
    Assert-True -Condition (Test-Path $fixtureConfig) -Message "Fixture project config exists"

    $parsedProjects = Get-Content $fixtureConfig -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    Assert-Equal -Actual $projects.Count -Expected 3 -Message "Fixture config contains three ships"
}

function Test-PhaseZeroIntakeSupport {
    $allowedProjectTypes = @("marketing-site", "full-stack-web", "desktop-app", "cli-tool", "library", "data-pipeline", "ai-workflow", "mobile-app", "game", "documentation", "sandbox-prototype")
    $allowedRiskTiers = @("sandbox", "local-only", "staging", "production-adjacent", "production")
    $capabilityNames = @("canEditPackageFiles", "canAddDependencies", "canEditBackendCode", "canEditMigrations", "canEditAuthPolicy", "canEditDeploymentConfig", "canUseNetworkApis", "canOpenPullRequests", "canDeploy")

    foreach ($profilePath in @(Get-ChildItem (Join-Path $fleetRoot "profiles") -Filter "*.json")) {
        $profile = Get-Content $profilePath.FullName -Raw | ConvertFrom-Json
        Assert-True -Condition ($allowedProjectTypes -contains [string]$profile.projectType) -Message "$($profile.name) profile has a valid projectType"
        Assert-True -Condition ($allowedRiskTiers -contains [string]$profile.riskTier) -Message "$($profile.name) profile has a valid riskTier"
        foreach ($capabilityName in $capabilityNames) {
            Assert-True -Condition ($null -ne $profile.capabilities.PSObject.Properties[$capabilityName]) -Message "$($profile.name) profile declares $capabilityName"
        }
    }

    $addProjectText = Get-Content (Join-Path $fleetRoot "add-project.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition ($addProjectText -match '\[string\]\$ProjectType') -Message "add-project accepts project type intake metadata"
    Assert-True -Condition ($addProjectText -match '\[string\]\$RiskTier') -Message "add-project accepts risk tier intake metadata"
    Assert-True -Condition ($addProjectText -match '\[string\[\]\]\$Capability') -Message "add-project accepts capability intake metadata"
    Assert-True -Condition ($doctorText -match 'Resolve-IntakeMetadata') -Message "Fleet doctor resolves Phase 0 intake metadata"
    Assert-True -Condition ($doctorText -match 'Unknown projectType') -Message "Fleet doctor blocks unknown project types"
    Assert-True -Condition ($doctorText -match 'Unknown riskTier') -Message "Fleet doctor blocks unknown risk tiers"
    Assert-True -Condition ($readmeText -match 'Phase 0 intake metadata') -Message "README documents Phase 0 intake metadata"
}

function Test-PhaseOneArchitectureSupport {
    $planText = Get-Content (Join-Path $fleetRoot "fleet-plan.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "fleet-plan.ps1")) -Message "Fleet exposes Phase 1 architecture planning script"
    Assert-True -Condition ($planText -match '\[switch\]\$Template') -Message "fleet-plan can write architecture templates"
    Assert-True -Condition ($planText -match '\[switch\]\$ValidateOnly') -Message "fleet-plan can validate architecture approval"
    Assert-True -Condition ($planText -match 'ARCHITECTURE\.md') -Message "fleet-plan manages ARCHITECTURE.md"
    Assert-True -Condition ($planText -match 'ENGINEERING_PLAN\.md') -Message "fleet-plan manages ENGINEERING_PLAN.md"
    Assert-True -Condition ($planText -match 'RISK_REGISTER\.md') -Message "fleet-plan manages RISK_REGISTER.md"
    Assert-True -Condition ($planText -match 'ARCHITECTURE_APPROVAL\.md') -Message "fleet-plan manages ARCHITECTURE_APPROVAL.md"
    Assert-True -Condition ($planText -match 'Status:\s*APPROVED') -Message "fleet-plan validates human approval status"
    Assert-True -Condition ($doctorText -match 'Get-ArchitecturePlanStatus') -Message "Fleet doctor reports architecture planning status"
    Assert-True -Condition ($doctorText -match 'Phase 1 architecture planning pack') -Message "Fleet doctor warns when serious ships lack architecture planning"
    Assert-True -Condition ($readmeText -match 'Phase 1 Architect gate') -Message "README documents the Phase 1 Architect gate"
}

function Test-PhaseTwoScaffoldSupport {
    $scaffoldText = Get-Content (Join-Path $fleetRoot "scaffold-project.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "scaffold-project.ps1")) -Message "Fleet exposes Phase 2 scaffold script"
    foreach ($scaffoldType in @("vite-react", "next-js", "express-api", "electron-desktop", "python-cli", "library-js", "test-harness")) {
        Assert-True -Condition ($scaffoldText -match [regex]::Escape($scaffoldType)) -Message "scaffold-project supports $scaffoldType"
    }
    Assert-True -Condition ($scaffoldText -match 'Test-ArchitectureApproved') -Message "scaffold-project gates scaffolding on architecture approval"
    Assert-True -Condition ($scaffoldText -match 'DEPENDENCY_PROPOSAL\.md') -Message "scaffold-project writes dependency proposals"
    Assert-True -Condition ($scaffoldText -match 'DEPENDENCY_APPROVAL\.md') -Message "scaffold-project writes dependency approvals"
    Assert-True -Condition ($scaffoldText -match 'Status:\s*DRAFT') -Message "dependency approval starts as draft"
    Assert-True -Condition ($doctorText -match 'Get-DependencyApprovalStatus') -Message "Fleet doctor reports dependency approval status"
    Assert-True -Condition ($doctorText -match 'Phase 2 dependency proposal') -Message "Fleet doctor warns for missing or draft dependency gates"
    Assert-True -Condition ($readmeText -match 'Phase 2 scaffold and dependency gate') -Message "README documents the Phase 2 scaffold gate"
}

function Test-PhaseThreeTaskContractSupport {
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $plannerText = Get-Content (Join-Path $fleetRoot "generate-next-five.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition ($loopText -match 'Resolve-TaskContract') -Message "Checkpoint loop parses Phase 3 task contracts"
    Assert-True -Condition ($loopText -match 'class:') -Message "Task contract parser recognizes class metadata"
    Assert-True -Condition ($loopText -match 'risk:') -Message "Task contract parser recognizes risk metadata"
    Assert-True -Condition ($loopText -match 'scope:') -Message "Task contract parser recognizes scope metadata"
    Assert-True -Condition ($loopText -match 'accept:\(\.\+\?') -Message "Task contract parser recognizes acceptance commands"
    Assert-True -Condition ($loopText -match 'Test-TaskScope') -Message "Checkpoint loop enforces declared task scopes"
    Assert-True -Condition ($loopText -match 'Invoke-TaskAcceptanceChecks') -Message "Checkpoint loop runs task-specific acceptance checks"
    Assert-True -Condition ($loopText -match 'High/gated task requires approved architecture plan') -Message "Checkpoint loop blocks high/gated tasks without architecture approval"
    Assert-True -Condition ($loopText -match 'Task class:') -Message "Nightly report includes task class metadata"
    Assert-True -Condition ($plannerText -match 'Supported classes') -Message "Nami planner is taught task classes"
    Assert-True -Condition ($plannerText -match 'Supported risks') -Message "Nami planner is taught task risks"
    Assert-True -Condition ($readmeText -match 'Phase 3 task contracts') -Message "README documents Phase 3 task contracts"
}

function Test-PhaseFourMigrationSupport {
    $migrationText = Get-Content (Join-Path $fleetRoot "migration-review.ps1") -Raw
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "migration-review.ps1")) -Message "Fleet exposes Phase 4 migration review script"
    Assert-True -Condition ($migrationText -match 'MIGRATION_PROPOSAL\.md') -Message "Migration review requires migration proposal"
    Assert-True -Condition ($migrationText -match 'MIGRATION_APPROVAL\.md') -Message "Migration review requires migration approval"
    foreach ($heading in @("Reversibility", "Data Impact", "Affected Tables Or Collections", "Local Run Evidence", "Rollback Plan")) {
        Assert-True -Condition ($migrationText -match [regex]::Escape($heading)) -Message "Migration review checks $heading"
    }
    Assert-True -Condition ($loopText -match 'Invoke-MigrationReviewGate') -Message "Checkpoint loop runs migration review gate"
    Assert-True -Condition ($loopText -match 'class -in @\("backend", "migration"\)') -Message "Checkpoint loop gates backend and migration classes on architecture approval"
    Assert-True -Condition ($loopText -match 'Get-MigrationApprovalStatusForLoop') -Message "Checkpoint loop checks migration approval status"
    Assert-True -Condition ($doctorText -match 'Get-MigrationApprovalStatus') -Message "Fleet doctor reports migration approval status"
    Assert-True -Condition ($doctorText -match 'Phase 4 migration proposal') -Message "Fleet doctor warns for missing or draft migration gates"
    Assert-True -Condition ($readmeText -match 'Phase 4 migration safety gate') -Message "README documents Phase 4 migration safety"
}

function Test-PhaseFiveSensitiveSystemsSupport {
    $sensitiveText = Get-Content (Join-Path $fleetRoot "sensitive-systems-review.ps1") -Raw
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "sensitive-systems-review.ps1")) -Message "Fleet exposes Phase 5 sensitive systems review script"
    Assert-True -Condition ($sensitiveText -match 'EXTERNAL_SERVICES\.md') -Message "Sensitive systems review validates external service registry"
    Assert-True -Condition ($sensitiveText -match 'AUTH_POLICY\.md') -Message "Sensitive systems review recognizes auth policy"
    Assert-True -Condition ($sensitiveText -match 'PAYMENT_RISK\.md') -Message "Sensitive systems review recognizes payment risk"
    Assert-True -Condition ($sensitiveText -match 'sk-\[A-Za-z0-9_-\]') -Message "Sensitive systems review scans staged diffs for secret-like tokens"
    Assert-True -Condition ($loopText -match 'Invoke-SensitiveSystemsReviewGate') -Message "Checkpoint loop runs sensitive systems review gate"
    Assert-True -Condition ($loopText -match 'Invoke-FleetCommit') -Message "Checkpoint loop centralizes commits behind sensitive systems gate"
    Assert-True -Condition ($loopText -match 'Test-SensitiveTaskApproval') -Message "Checkpoint loop checks auth/payment/integration task approvals"
    Assert-True -Condition ($doctorText -match 'Get-SensitiveSystemsStatus') -Message "Fleet doctor reports sensitive systems status"
    Assert-True -Condition ($doctorText -match 'Phase 5 sensitive systems') -Message "Fleet doctor warns for missing or draft sensitive systems gates"
    Assert-True -Condition ($readmeText -match 'Phase 5 auth, payment, secrets') -Message "README documents Phase 5 sensitive systems safety"
}

function Test-PhaseSixRuntimeVerificationSupport {
    $runtimeText = Get-Content (Join-Path $fleetRoot "runtime-verify.ps1") -Raw
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "runtime-verify.ps1")) -Message "Fleet exposes Phase 6 runtime verification script"
    Assert-True -Condition ($runtimeText -match 'RUNTIME_CHECKS\.md') -Message "Runtime verifier reads runtime checks"
    Assert-True -Condition ($runtimeText -match 'RUNTIME_VERIFICATION\.md') -Message "Runtime verifier writes runtime report"
    Assert-True -Condition ($runtimeText -match 'command\|url\|text') -Message "Runtime verifier supports command, url, and text checks"
    Assert-True -Condition ($loopText -match 'Invoke-RuntimeVerificationGate') -Message "Checkpoint loop runs runtime verification gate"
    Assert-True -Condition ($loopText -match 'integration", "performance"') -Message "Runtime gate is triggered for integration and performance tasks"
    Assert-True -Condition ($doctorText -match 'Get-RuntimeVerificationStatus') -Message "Fleet doctor reports runtime verification status"
    Assert-True -Condition ($doctorText -match 'Phase 6 runtime verification') -Message "Fleet doctor warns on failed runtime verification"
    Assert-True -Condition ($readmeText -match 'Phase 6 runtime verification gate') -Message "README documents Phase 6 runtime verification"
}

function Test-PhaseSevenReleaseSupport {
    $releaseText = Get-Content (Join-Path $fleetRoot "release-readiness.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "release-readiness.ps1")) -Message "Fleet exposes Phase 7 release readiness script"
    Assert-True -Condition ($releaseText -match 'DEPLOYMENT_PLAN\.md') -Message "Release readiness checks deployment plan"
    Assert-True -Condition ($releaseText -match 'POST_DEPLOY_SMOKE\.md') -Message "Release readiness checks post-deploy smoke plan"
    Assert-True -Condition ($releaseText -match 'ROLLBACK_PLAN\.md') -Message "Release readiness checks rollback plan"
    Assert-True -Condition ($releaseText -match 'RELEASE_APPROVAL\.md') -Message "Release readiness checks human release approval"
    Assert-True -Condition ($releaseText -match 'RUNTIME_VERIFICATION\.md') -Message "Release readiness includes runtime evidence"
    Assert-True -Condition ($releaseText -match 'MIGRATION_REVIEW\.md') -Message "Release readiness includes migration evidence"
    Assert-True -Condition ($releaseText -match 'SENSITIVE_SYSTEMS_REVIEW\.md') -Message "Release readiness includes sensitive systems evidence"
    Assert-True -Condition ($releaseText -match 'This report never deploys') -Message "Release readiness explicitly does not deploy"
    Assert-True -Condition ($readmeText -match 'Phase 7 release and operations gate') -Message "README documents Phase 7 release readiness"
}

function Test-PhaseEightMaintenanceSupport {
    $maintenanceText = Get-Content (Join-Path $fleetRoot "fleet-maintenance.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw
    $roadmapText = Get-Content (Join-Path $fleetRoot "docs\AUTONOMOUS_SOFTWARE_ROADMAP.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "fleet-maintenance.ps1")) -Message "Fleet exposes Phase 8 maintenance script"
    Assert-True -Condition ($maintenanceText -match 'MAINTENANCE_QUEUE\.md') -Message "Maintenance lane manages a maintenance queue"
    Assert-True -Condition ($maintenanceText -match 'MAINTENANCE_WINDOWS\.md') -Message "Maintenance lane manages maintenance windows"
    Assert-True -Condition ($maintenanceText -match 'TECH_DEBT\.md') -Message "Maintenance lane tracks technical debt"
    Assert-True -Condition ($maintenanceText -match '\[switch\]\$IncludeDirty') -Message "Maintenance lane requires an explicit opt-in to scan dirty ships"
    Assert-True -Condition ($maintenanceText -match 'SKIPPED DIRTY') -Message "Maintenance lane skips dirty ships by default"
    foreach ($signal in @("dependency-review", "performance-regression", "flaky", "bug-triage", "issue-intake")) {
        Assert-True -Condition ($maintenanceText -match [regex]::Escape($signal)) -Message "Maintenance lane handles $signal signals"
    }
    Assert-True -Condition ($maintenanceText -match 'This report does not edit ships') -Message "Maintenance report is read-only by default"
    Assert-True -Condition ($doctorText -match 'Get-MaintenanceStatus') -Message "Fleet doctor reports maintenance status"
    Assert-True -Condition ($doctorText -match 'Phase 8 maintenance') -Message "Fleet doctor warns for missing maintenance lane"
    Assert-True -Condition ($readmeText -match 'Phase 8 autonomous maintenance intake lane') -Message "README documents Phase 8 maintenance"
    Assert-True -Condition ($roadmapText -match 'Status: started') -Message "Roadmap marks Phase 8 as started"
}

function Test-PhaseNineAutopilotSupport {
    $autopilotText = Get-Content (Join-Path $fleetRoot "fleet-autopilot-policy.ps1") -Raw
    $doctorText = Get-Content (Join-Path $fleetRoot "fleet-doctor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw
    $roadmapText = Get-Content (Join-Path $fleetRoot "docs\AUTONOMOUS_SOFTWARE_ROADMAP.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "fleet-autopilot-policy.ps1")) -Message "Fleet exposes Phase 9 autopilot policy script"
    Assert-True -Condition ($autopilotText -match 'AUTOPILOT_POLICY\.md') -Message "Autopilot gate validates policy artifact"
    Assert-True -Condition ($autopilotText -match 'AUTOPILOT_APPROVAL\.md') -Message "Autopilot gate validates approval artifact"
    Assert-True -Condition ($autopilotText -match 'Spending Limit') -Message "Autopilot gate requires spending limits"
    Assert-True -Condition ($autopilotText -match 'Customer Data') -Message "Autopilot gate requires customer-data rules"
    Assert-True -Condition ($autopilotText -match 'Escalation') -Message "Autopilot gate requires escalation rules"
    foreach ($blocked in @("pricing", "production deploy", "payment", "auth", "mass email", "data deletion", "legal")) {
        Assert-True -Condition ($autopilotText -match [regex]::Escape($blocked)) -Message "Autopilot gate checks human approval for $blocked"
    }
    Assert-True -Condition ($autopilotText -match '\.codex-local\\audit') -Message "Autopilot gate writes an audit log"
    Assert-True -Condition ($autopilotText -match 'does not spend money, deploy, email customers') -Message "Autopilot report states sensitive actions are not performed"
    Assert-True -Condition ($doctorText -match 'Get-AutopilotStatus') -Message "Fleet doctor reports autopilot status"
    Assert-True -Condition ($doctorText -match 'Phase 9 limited autopilot') -Message "Fleet doctor warns for missing autopilot policy"
    Assert-True -Condition ($readmeText -match 'Phase 9 limited business autopilot gate') -Message "README documents Phase 9 autopilot gate"
    Assert-True -Condition ($roadmapText -match 'fleet-autopilot-policy\.ps1') -Message "Roadmap marks Phase 9 as started"
}

function Test-ConfigResolution {
    foreach ($name in @("FixtureStaticDemo", "FixtureDocsOnly", "FixtureRealProduct")) {
        $result = Invoke-Checked -FilePath "powershell" -Arguments @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "run-checkpoint-loop.ps1"),
            "-ConfigPath", $fixtureConfig,
            "-Project", $name,
            "-ValidateOnly"
        )
        $output = $result.output -join "`n"
        Assert-Equal -Actual $result.exitCode -Expected 0 -Message "Checkpoint loop validates $name"
        Assert-True -Condition ($output -match "Implement models: gpt-fixture-primary, gpt-fixture-fallback") -Message "Model chain resolves for $name"
        Assert-True -Condition ($output -match "Rate-limit cooldown: 60s, max cooldowns 1") -Message "Rate-limit config resolves for $name"
        Assert-True -Condition ($output -match "Visual paths:") -Message "Visual path config is reported for $name"
    }
}

function Test-DoctorAndReadiness {
    $doctor = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"),
        "-ConfigPath", $fixtureConfig,
        "-Quiet"
    )
    Assert-Equal -Actual $doctor.exitCode -Expected 0 -Message "Fleet doctor passes fixture ships"

    $readiness = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "merge-readiness.ps1"),
        "-ConfigPath", $fixtureConfig,
        "-SkipBuild"
    )
    Assert-Equal -Actual $readiness.exitCode -Expected 0 -Message "Merge readiness passes fixture ships in skip-build mode"
    Assert-True -Condition (($readiness.output -join "`n") -match "SAFE TO MERGE AFTER HUMAN REVIEW") -Message "Merge readiness can produce a green overall result"
}

function Test-MaintenanceDirtySkip {
    $project = Get-Project -Name "FixtureStaticDemo"
    $outFile = Join-Path $fixtureRoot "maintenance-dirty-skip.md"

    Push-Location $project.repo
    try {
        Set-Content -Path "dirty-maintenance-fixture.txt" -Value "active work"
    } finally {
        Pop-Location
    }

    try {
        $maintenance = Invoke-Checked -FilePath "powershell" -Arguments @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "fleet-maintenance.ps1"),
            "-ConfigPath", $fixtureConfig,
            "-Project", "FixtureStaticDemo",
            "-OutFile", $outFile
        )
        Assert-Equal -Actual $maintenance.exitCode -Expected 0 -Message "Maintenance report succeeds when fixture ship is dirty"
        $report = Get-Content $outFile -Raw
        Assert-True -Condition ($report -match "SKIPPED DIRTY") -Message "Maintenance report skips dirty ships by default"
        Assert-True -Condition ($report -match "Use -IncludeDirty") -Message "Maintenance report explains dirty-scan opt-in"
    } finally {
        Remove-Item -LiteralPath (Join-Path $project.repo "dirty-maintenance-fixture.txt") -Force -ErrorAction SilentlyContinue
    }
}

function Test-DebugCheckpoint {
    $project = Get-Project -Name "FixtureStaticDemo"
    $debug = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "debug-checkpoint.ps1"),
        "-Repo", $project.repo,
        "-BaseBranch", "main",
        "-Json"
    )
    Assert-Equal -Actual $debug.exitCode -Expected 0 -Message "Checkpoint debugger passes clean fixture branch"
    Assert-True -Condition (($debug.output -join "`n") -match '"result"\s*:\s*"PASS"') -Message "Checkpoint debugger JSON reports PASS"

    Push-Location $project.repo
    try {
        foreach ($index in 1..5) {
            Set-Content -Path "preexisting-$index.txt" -Value "older branch work $index"
        }
        & git add -- preexisting-*.txt
        & git commit -m "fixture accumulated branch work" | Out-Null
        Assert-Equal -Actual $LASTEXITCODE -Expected 0 -Message "Fixture commits accumulated branch work"

        $batchBase = (git rev-parse HEAD).Trim()
        Set-Content -Path "current-batch.txt" -Value "current batch"
        & git add -- current-batch.txt
        & git commit -m "fixture current batch work" | Out-Null
        Assert-Equal -Actual $LASTEXITCODE -Expected 0 -Message "Fixture commits current batch work"
    } finally {
        Pop-Location
    }

    $batchDebug = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "debug-checkpoint.ps1"),
        "-Repo", $project.repo,
        "-BaseBranch", "main",
        "-BatchBase", $batchBase,
        "-MaxChangedFiles", "2",
        "-MaxBatchChangedFiles", "2",
        "-Json"
    )
    $batchOutput = $batchDebug.output -join "`n"
    Assert-Equal -Actual $batchDebug.exitCode -Expected 0 -Message "Checkpoint debugger allows small current batch on accumulated branch"
    Assert-True -Condition ($batchOutput -match '"result"\s*:\s*"WARN"') -Message "Checkpoint debugger warns for oversized whole branch"
    Assert-True -Condition ($batchOutput -match '"batchChangedFileCount"\s*:\s*1') -Message "Checkpoint debugger reports current batch file count"
}

function Test-SafeStaging {
    $project = Get-Project -Name "FixtureStaticDemo"
    Push-Location $project.repo
    try {
        Set-Content -Path "file with spaces.txt" -Value "stage me"
        Set-Content -Path "do-not-stage.txt" -Value "leave me"
        $paths = @("file with spaces.txt")
        & git add -- @paths
        $staged = @(git diff --cached --name-only)
        $unstaged = @(git ls-files --others --exclude-standard)
        Assert-True -Condition ($staged -contains "file with spaces.txt") -Message "Safe staging handles paths with spaces"
        Assert-True -Condition ($unstaged -contains "do-not-stage.txt") -Message "Safe staging leaves unrelated untracked files unstaged"
        & git reset -- "file with spaces.txt" | Out-Null
        Remove-Item -LiteralPath "file with spaces.txt", "do-not-stage.txt" -Force
    } finally {
        Pop-Location
    }
}

function Test-ReadOnlyDirtyGuard {
    $project = Get-Project -Name "FixtureStaticDemo"
    Push-Location $project.repo
    try {
        Set-Content -Path "dirty-before-planner.txt" -Value "dirty"
        $planner = Invoke-Checked -FilePath "powershell" -Arguments @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "generate-next-five.ps1"),
            "-Repo", $project.repo,
            "-BaseBranch", "main",
            "-Count", "1",
            "-TimeoutSeconds", "5"
        )
        Assert-True -Condition ($planner.exitCode -ne 0) -Message "Nami planner refuses dirty working tree before Codex"
        Assert-True -Condition (($planner.output -join "`n") -match "requires a clean working tree") -Message "Nami planner reports dirty tree reason"
        Remove-Item -LiteralPath "dirty-before-planner.txt" -Force
    } finally {
        Pop-Location
    }
}

function Test-CheckpointGateOrder {
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $visualIndex = $loopText.IndexOf('if ($VisualInspectEvery -gt 0')
    $simonIndex = $loopText.IndexOf('if ($SimonEvery -gt 0')
    $robinIndex = $loopText.IndexOf('if ($RobinEvery -gt 0')
    $joeyIndex = $loopText.IndexOf('if ($JoeyEvery -gt 0')
    $checkpointIndex = $loopText.IndexOf('$checkpointText = Invoke-CheckpointReviewGate -Batch $batch')
    $debugIndex = $loopText.IndexOf('if (!$SkipDebug)')

    Assert-True -Condition ($visualIndex -ge 0) -Message "Checkpoint loop contains visual inspect gate"
    Assert-True -Condition ($simonIndex -gt $visualIndex) -Message "Simon runs after visual inspect"
    Assert-True -Condition ($robinIndex -gt $simonIndex) -Message "Robin runs after Simon"
    Assert-True -Condition ($joeyIndex -gt $robinIndex) -Message "Joey runs after Robin"
    Assert-True -Condition ($checkpointIndex -gt $joeyIndex) -Message "Final checkpoint runs after visual, Simon, Robin, and Joey"
    Assert-True -Condition ($debugIndex -gt $checkpointIndex) -Message "Debugger runs after final checkpoint"
}

function Test-TaskQuarantineSupport {
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    Assert-True -Condition ($loopText -match '\[switch\]\$QuarantineFailedTasks') -Message "Checkpoint loop exposes task quarantine switch"
    Assert-True -Condition ($loopText -match '\[int\]\$MaxTaskQuarantines') -Message "Checkpoint loop exposes task quarantine limit"
    Assert-True -Condition ($loopText -match 'docs/codex/QUARANTINED_TASKS.md') -Message "Checkpoint loop writes a quarantine report"
    Assert-True -Condition ($loopText -match 'Restore-TaskChanges') -Message "Checkpoint loop restores failed task changes before continuing"
    Assert-True -Condition ($loopText -match 'git restore --staged') -Message "Checkpoint loop unstages files before quarantine cleanup"
    Assert-True -Condition ($loopText -match 'git restore --worktree') -Message "Checkpoint loop restores tracked worktree edits during quarantine cleanup"
    Assert-True -Condition ($loopText -match 'Codex changed HEAD during implementation') -Message "Checkpoint loop stops if Codex commits during implementation"
    Assert-True -Condition ($loopText -match 'Codex quarantine failed task batch') -Message "Checkpoint loop commits quarantine notes separately"

    $schoolText = Get-Content (Join-Path $fleetRoot "launch-school-run.ps1") -Raw
    Assert-True -Condition ($schoolText -match '-QuarantineFailedTasks') -Message "School launcher can pass quarantine mode to ships"
    Assert-True -Condition ($schoolText -match '-MaxTaskQuarantines') -Message "School launcher can pass quarantine limit to ships"

    $proofText = Get-Content (Join-Path $fleetRoot "launch-proof-run.ps1") -Raw
    Assert-True -Condition ($proofText -match '-QuarantineFailedTasks') -Message "Proof launcher can pass quarantine mode to ships"
    Assert-True -Condition ($proofText -match '-MaxTaskQuarantines') -Message "Proof launcher can pass quarantine limit to ships"

    $overnightText = Get-Content (Join-Path $fleetRoot "launch-overnight-run.ps1") -Raw
    Assert-True -Condition ($overnightText -match '-QuarantineFailedTasks') -Message "Overnight launcher can pass quarantine mode to ships"
    Assert-True -Condition ($overnightText -match '-MaxTaskQuarantines') -Message "Overnight launcher can pass quarantine limit to ships"

    $plannerText = Get-Content (Join-Path $fleetRoot "generate-next-five.ps1") -Raw
    Assert-True -Condition ($plannerText -match 'QUARANTINED_TASKS.md') -Message "Nami planner reads quarantined task report"
    Assert-True -Condition ($plannerText -match 'Do not repeat quarantined tasks') -Message "Nami planner is told not to repeat quarantined tasks"
    Assert-True -Condition ($plannerText -match 'ROBIN_COPY_REVIEW.md') -Message "Nami planner reads Robin copy review"
    Assert-True -Condition ($plannerText -match 'Priority Rewrite') -Message "Nami planner is told to prioritize Robin rewrite orders"
}

function Test-DuplicateRunGuard {
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    Assert-True -Condition ($loopText -match '\[switch\]\$AllowDuplicateRun') -Message "Checkpoint loop exposes explicit duplicate-run override"
    Assert-True -Condition ($loopText -match 'Assert-NoDuplicateFleetRun') -Message "Checkpoint loop checks for active duplicate processes"
    Assert-True -Condition ($loopText -match 'Acquire-FleetRunLock') -Message "Checkpoint loop acquires a per-ship run lock"
    Assert-True -Condition ($loopText -match '\.codex-local\\locks') -Message "Checkpoint loop stores locks under .codex-local locks"
    Assert-True -Condition ($loopText -match 'Get-CimInstance Win32_Process') -Message "Checkpoint loop scans existing PowerShell command lines for older runs"
    Assert-True -Condition ($loopText -match 'CreateNew') -Message "Checkpoint loop creates locks atomically"
    Assert-True -Condition ($loopText -match 'Duplicate fleet run refused') -Message "Checkpoint loop reports duplicate run refusal clearly"
}

function Test-SafeStopSupport {
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $stopText = Get-Content (Join-Path $fleetRoot "request-safe-stop.ps1") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "request-safe-stop.ps1")) -Message "Fleet exposes a safe stop request script"
    Assert-True -Condition ($loopText -match 'Invoke-FleetSafeStopCheck') -Message "Checkpoint loop checks safe stop requests"
    Assert-True -Condition ($loopText -match '\.codex-local\\stop-requests') -Message "Safe stop requests live under local runtime state"
    Assert-True -Condition ($loopText -match 'before task \$i in batch \$batch') -Message "Checkpoint loop checks safe stop before starting each task"
    Assert-True -Condition ($loopText -match 'before Nami task planning') -Message "Checkpoint loop checks safe stop before planning new tasks"
    Assert-True -Condition ($stopText -match '\[switch\]\$All') -Message "Safe stop script can target all ships"
    Assert-True -Condition ($stopText -match '\[switch\]\$Clear') -Message "Safe stop script can clear requests"
    Assert-True -Condition ($stopText -match '\[switch\]\$List') -Message "Safe stop script can list active requests"
}

function Test-LaunchControlSupport {
    $launcherText = Get-Content (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1") -Raw
    Assert-True -Condition ($launcherText -match 'Assert-NoFleetSafeStopRequests') -Message "Shared launcher helper blocks stale safe stop requests"
    Assert-True -Condition ($launcherText -match 'New-FleetLaunchManifest') -Message "Shared launcher helper creates launch manifests"
    Assert-True -Condition ($launcherText -match 'NewGuid') -Message "Launch manifest IDs include a uniqueness suffix for parallel launches"
    Assert-True -Condition ($launcherText -match 'out\\latest-launch\.md') -Message "Launch manifests update the latest-launch report"
    Assert-True -Condition ($launcherText -match '\.codex-local\\launches') -Message "Launch manifests write raw local launch records"

    foreach ($launcherName in @("launch-proof-run.ps1", "launch-school-run.ps1", "launch-overnight-run.ps1", "run-fleet.ps1")) {
        $launcher = Get-Content (Join-Path $fleetRoot $launcherName) -Raw
        Assert-True -Condition ($launcher -match 'codex-fleet-launcher\.ps1') -Message "$launcherName uses shared launcher helpers"
        Assert-True -Condition ($launcher -match 'AllowSafeStopRequests') -Message "$launcherName exposes a safe-stop override"
        Assert-True -Condition ($launcher -match 'Assert-NoFleetSafeStopRequests') -Message "$launcherName refuses accidental safe-stop launches"
        Assert-True -Condition ($launcher -match 'Write-FleetLaunchManifest') -Message "$launcherName writes a launch manifest"
        Assert-True -Condition ($launcher -match '-PassThru') -Message "$launcherName records launched PowerShell PIDs"
    }

    foreach ($launcherName in @("launch-school-run.ps1", "launch-overnight-run.ps1")) {
        $launcher = Get-Content (Join-Path $fleetRoot $launcherName) -Raw
        Assert-True -Condition ($launcher -match 'ExcludeProject') -Message "$launcherName can exclude docked ships"
    }

    $statusText = Get-Content (Join-Path $fleetRoot "fleet-status.ps1") -Raw
    Assert-True -Condition ($statusText -match 'Safe stop requests') -Message "Fleet status reports active safe stop requests"
    Assert-True -Condition ($statusText -match 'Run lock:') -Message "Fleet status reports run locks"

    $visualRunner = Get-Content (Join-Path $fleetRoot "tools\visual-inspect-runner.mjs") -Raw
    Assert-True -Condition ($visualRunner -match 'routeUrl\.search') -Message "Visual inspect route URLs preserve query strings"
}

function Test-JoeyStorageRules {
    $joeyText = Get-Content (Join-Path $fleetRoot "joey-security-review.ps1") -Raw
    Assert-True -Condition ($joeyText -match 'Test-SensitiveAddedLine') -Message "Joey centralizes sensitive added-line detection"
    Assert-True -Condition ($joeyText -match 'storageSensitivePattern') -Message "Joey treats local storage as sensitive only for risky data names"
    Assert-False -Condition ($joeyText -match 'process\\.env\|import\\.meta\\.env\|localStorage\\.setItem') -Message "Joey does not blanket-block harmless localStorage writes"
}

function Test-DebuggerReportFileAllowance {
    $debugText = Get-Content (Join-Path $fleetRoot "debug-checkpoint.ps1") -Raw
    Assert-True -Condition ($debugText -match 'expectedReportFilePattern') -Message "Debugger identifies expected Codex report files"
    Assert-True -Condition ($debugText -match 'batchChangedForLimit') -Message "Debugger uses a non-report file count for hard batch limits"
    Assert-True -Condition ($debugText -match 'Too many non-report files changed') -Message "Debugger batch limit message distinguishes report-file overhead"
}

function Test-ShipPreviewRefreshSupport {
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition ($loopText -match '\[switch\]\$SkipShipPreviewRefresh') -Message "Checkpoint loop exposes ship preview refresh override"
    Assert-True -Condition ($loopText -match 'Update-ShipPreviewDashboard') -Message "Checkpoint loop refreshes ship preview dashboard on completion"
    Assert-True -Condition ($loopText -match 'open-ship-previews\.ps1') -Message "Checkpoint loop uses the ship preview script for refreshes"
    Assert-True -Condition ($loopText -match '-NoOpen') -Message "Checkpoint loop refreshes previews without opening browser windows"
    Assert-True -Condition ($readmeText -match 'SkipShipPreviewRefresh') -Message "README documents the ship preview refresh behavior"
}

Set-Location $fleetRoot
Write-Host "Running Codex Fleet tests..." -ForegroundColor Cyan

Test-PowerShellParsing
Test-TaskParsing
Test-RuntimeHelpers
Test-FixtureGeneration
Test-PhaseZeroIntakeSupport
Test-PhaseOneArchitectureSupport
Test-PhaseTwoScaffoldSupport
Test-PhaseThreeTaskContractSupport
Test-PhaseFourMigrationSupport
Test-PhaseFiveSensitiveSystemsSupport
Test-PhaseSixRuntimeVerificationSupport
Test-PhaseSevenReleaseSupport
Test-PhaseEightMaintenanceSupport
Test-PhaseNineAutopilotSupport
Test-ConfigResolution
Test-DoctorAndReadiness
Test-MaintenanceDirtySkip
Test-DebugCheckpoint
Test-SafeStaging
Test-ReadOnlyDirtyGuard
Test-CheckpointGateOrder
Test-TaskQuarantineSupport
Test-DuplicateRunGuard
Test-SafeStopSupport
Test-LaunchControlSupport
Test-JoeyStorageRules
Test-DebuggerReportFileAllowance
Test-ShipPreviewRefreshSupport

if (!$KeepFixtures -and (Test-Path $fixtureRoot)) {
    $fixtureFullPath = [System.IO.Path]::GetFullPath($fixtureRoot)
    $allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $fleetRoot ".codex-local\fixtures"))
    if ($fixtureFullPath.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $fixtureFullPath -Recurse -Force
    }
}

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Codex Fleet tests failed: $($script:Failures.Count)" -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "Codex Fleet tests passed." -ForegroundColor Green
exit 0
