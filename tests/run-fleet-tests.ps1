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
    Assert-True -Condition ($doctorText -match '-split ","') -Message "Fleet doctor accepts comma-packed project exclusions"
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
    Assert-True -Condition ($loopText -match 'impact:') -Message "Task contract parser recognizes impact metadata"
    Assert-True -Condition ($loopText -match 'scope:') -Message "Task contract parser recognizes scope metadata"
    Assert-True -Condition ($loopText -match 'accept:\(\.\+\?') -Message "Task contract parser recognizes acceptance commands"
    Assert-True -Condition ($loopText -match 'Test-TaskScope') -Message "Checkpoint loop enforces declared task scopes"
    Assert-True -Condition ($loopText -match 'RUNTIME_VERIFICATION\.md') -Message "Task scope allows Fleet-generated runtime reports"
    Assert-True -Condition ($loopText -match 'SENSITIVE_SYSTEMS_REVIEW\.md') -Message "Task scope allows Fleet-generated sensitive systems reports"
    Assert-True -Condition ($loopText -match 'Invoke-TaskAcceptanceChecks') -Message "Checkpoint loop runs task-specific acceptance checks"
    Assert-True -Condition ($loopText -match 'High/gated task requires approved architecture plan') -Message "Checkpoint loop blocks high/gated tasks without architecture approval"
    Assert-True -Condition ($loopText -match 'Task class:') -Message "Nightly report includes task class metadata"
    Assert-True -Condition ($plannerText -match 'Supported classes') -Message "Nami planner is taught task classes"
    Assert-True -Condition ($plannerText -match 'Supported risks') -Message "Nami planner is taught task risks"
    Assert-True -Condition ($plannerText -match 'Supported impacts') -Message "Nami planner is taught task impacts"
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
    Assert-True -Condition ($sensitiveText -match 'Test-GeneratedSensitiveReportPath') -Message "Sensitive systems review ignores generated report prose for registry detection"
    Assert-True -Condition ($sensitiveText -match '\[-\*\+\]') -Message "Sensitive systems review strips markdown-bullet negative sensitive clauses"
    Assert-True -Condition ($loopText -match 'Invoke-SensitiveSystemsReviewGate') -Message "Checkpoint loop runs sensitive systems review gate"
    Assert-True -Condition ($loopText -match 'Invoke-FleetCommit') -Message "Checkpoint loop centralizes commits behind sensitive systems gate"
    Assert-True -Condition ($loopText -match 'Test-SensitiveTaskApproval') -Message "Checkpoint loop checks auth/payment/integration task approvals"
    Assert-True -Condition ($loopText -match 'Get-SensitiveIntentText') -Message "Checkpoint loop strips forbidden-scope text before sensitive task detection"
    Assert-True -Condition ($loopText -match 'forbidden\\s\+scope') -Message "Sensitive task detection ignores forbidden scope guardrail text"
    Assert-True -Condition ($loopText -match 'forbid\|forbids\|forbidden') -Message "Sensitive task detection ignores forbid/forbidden guardrail language"
    Assert-True -Condition ($loopText -match 'preserv\(\?:e\|ing\)') -Message "Sensitive task detection ignores preserve-boundary guardrail language"
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
    Assert-True -Condition ($maintenanceText -match 'Get-MaintenanceSignalPriority') -Message "Maintenance lane centralizes signal priority"
    Assert-True -Condition ($maintenanceText -match '\\bRED\\b') -Message "Maintenance lane avoids substring matches for RED"
    Assert-True -Condition ($maintenanceText -match 'Test-InformationalMaintenanceLine') -Message "Maintenance lane skips informational review boilerplate"
    Assert-True -Condition ($maintenanceText -match 'Task\\s\+attempted') -Message "Maintenance lane skips task-attempted prose"
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

    $fixtureProjects = @(Get-Content $fixtureConfig -Raw | ConvertFrom-Json | ForEach-Object { $_ })
    foreach ($fixtureProject in $fixtureProjects) {
        Push-Location $fixtureProject.repo
        try {
            New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
            Set-Content -Path "docs/codex/MAGIC_SCORECARD.md" -Value @"
# Magic Scorecard

## Batch 1 QA - 2026-01-01 00:00:00

- Active work pack: Fixture Pack
- Batch impact mode: standard
- Fresh QA evidence:
- Fixture visual evidence.
- Checkpoint verdict: GREEN
- Simon verdict: GREEN
- Robin verdict: GREEN
- Joey verdict: GREEN
- Simon improvement score: SCORE: 4; DIRECTION: improved; ACTIVE_PACK: Fixture Pack; REASON: fixture.
- Debug checkpoint result: PASS (passed)
"@
            & git add -- docs/codex/MAGIC_SCORECARD.md
            & git commit -m "fixture batch QA memory" | Out-Null
        } finally {
            Pop-Location
        }
    }

    $readiness = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "merge-readiness.ps1"),
        "-ConfigPath", $fixtureConfig,
        "-SkipBuild"
    )
    Assert-Equal -Actual $readiness.exitCode -Expected 0 -Message "Merge readiness passes fixture ships in skip-build mode"
    Assert-True -Condition (($readiness.output -join "`n") -match "SAFE TO MERGE AFTER HUMAN REVIEW") -Message "Merge readiness can produce a green overall result"
    $mergeText = Get-Content (Join-Path $fleetRoot "merge-readiness.ps1") -Raw
    Assert-True -Condition ($mergeText -match 'Get-LatestBatchQaSummary') -Message "Merge readiness reads latest batch QA scorecard"
    Assert-True -Condition ($mergeText -match 'Batch QA') -Message "Merge readiness reports batch QA status"
    Assert-True -Condition ($mergeText -match 'No fresh batch QA scorecard entry found') -Message "Merge readiness warns when batch QA memory is missing"
    Assert-True -Condition ($mergeText -match 'Batch QA scorecard is stale') -Message "Merge readiness warns when commits land after batch QA"

    $staleProject = Get-Project -Name "FixtureStaticDemo"
    Push-Location $staleProject.repo
    try {
        Set-Content -Path "post-qa-change.txt" -Value "change after QA"
        & git add -- post-qa-change.txt
        & git commit -m "fixture post QA change" | Out-Null
    } finally {
        Pop-Location
    }

    $staleReadiness = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "merge-readiness.ps1"),
        "-ConfigPath", $fixtureConfig,
        "-Project", "FixtureStaticDemo",
        "-SkipBuild"
    )
    $staleOutput = $staleReadiness.output -join "`n"
    Assert-Equal -Actual $staleReadiness.exitCode -Expected 0 -Message "Merge readiness allows stale QA as inspect-only"
    Assert-True -Condition ($staleOutput -match "SAFE TO INSPECT") -Message "Stale batch QA downgrades merge readiness to inspect-only"
    Assert-True -Condition ($staleOutput -match "batch QA present/PASS") -Message "Stale batch QA still reports the latest QA result"
    $staleReport = Get-Content (Join-Path $fleetRoot "out\merge-readiness.md") -Raw
    Assert-True -Condition ($staleReport -match "Batch QA scorecard is stale: 1 commit") -Message "Stale batch QA reports commits after latest scorecard"
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

function Test-RecoveryIncludesStagedFiles {
    $recoveryText = Get-Content (Join-Path $fleetRoot "recover-interrupted-task.ps1") -Raw
    Assert-True -Condition ($recoveryText -match 'git diff --cached --name-only') -Message "Interrupted-task recovery includes staged files"
    Assert-True -Condition ($recoveryText -match 'foreach \(\$path in \$cleanPaths\)') -Message "Interrupted-task recovery stages paths one at a time"
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
    Assert-True -Condition ($overnightText -match '\[int\]\$SimonEvery') -Message "Overnight launcher can override Simon cadence"
    Assert-True -Condition ($overnightText -match '\[int\]\$VisualInspectEvery') -Message "Overnight launcher can override visual inspection cadence"

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
    Assert-True -Condition ($loopText -match 'Ignoring stale run-checkpoint-loop shells') -Message "Checkpoint loop ignores stale launch shells without active locks"
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
    Assert-True -Condition ($launcherText -match 'ExcludeProject') -Message "Shared launcher helper ignores safe stops for excluded ships"
    Assert-True -Condition ($launcherText -match 'New-FleetLaunchManifest') -Message "Shared launcher helper creates launch manifests"
    Assert-True -Condition ($launcherText -match 'NewGuid') -Message "Launch manifest IDs include a uniqueness suffix for parallel launches"
    Assert-True -Condition ($launcherText -match 'LatestFileName = "latest-launch\.md"' -and $launcherText -match 'markdownPath') -Message "Launch manifests update the latest-launch report"
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
        Assert-True -Condition ($launcher -match 'Assert-NoFleetSafeStopRequests[^\r\n]+-ExcludeProject') -Message "$launcherName ignores safe stops for excluded ships"
        Assert-True -Condition ($launcher -match 'doctorExclusions') -Message "$launcherName forwards multiple doctor exclusions together"
        Assert-True -Condition ($launcher -match '-join ","') -Message "$launcherName comma-packs doctor exclusions for child PowerShell"
    }

    $proofLauncher = Get-Content (Join-Path $fleetRoot "launch-proof-run.ps1") -Raw
    Assert-True -Condition ($proofLauncher -match 'Assert-NoFleetSafeStopRequests[^\r\n]+-ExcludeProject') -Message "launch-proof-run.ps1 ignores safe stops for excluded ships"
    Assert-True -Condition ($proofLauncher -match '\[int\]\$RobinEvery = 1') -Message "launch-proof-run.ps1 runs Robin by default"
    Assert-True -Condition ($proofLauncher -match '-RobinEvery \$RobinEvery') -Message "launch-proof-run.ps1 forwards Robin cadence into checkpoint loop"
    Assert-True -Condition ($proofLauncher -match '-RobinEvery must be 0 or greater') -Message "launch-proof-run.ps1 validates Robin cadence"

    $statusText = Get-Content (Join-Path $fleetRoot "fleet-status.ps1") -Raw
    Assert-True -Condition ($statusText -match 'Safe stop requests') -Message "Fleet status reports active safe stop requests"
    Assert-True -Condition ($statusText -match 'Run lock:') -Message "Fleet status reports run locks"
    Assert-True -Condition ($statusText -match 'Get-FleetStatusChildSummary') -Message "Fleet status reports active child work for run locks"
    Assert-True -Condition ($statusText -match 'codex') -Message "Fleet status labels Codex child work clearly"
    Assert-True -Condition ($statusText -match 'git status --short 2>\$null') -Message "Fleet status suppresses noisy inaccessible temp-directory warnings"

    $visualRunner = Get-Content (Join-Path $fleetRoot "tools\visual-inspect-runner.mjs") -Raw
    Assert-True -Condition ($visualRunner -match 'routeUrl\.search') -Message "Visual inspect route URLs preserve query strings"
}

function Test-FleetVisualQaLaneSupport {
    $visualInspectText = Get-Content (Join-Path $fleetRoot "visual-inspect.ps1") -Raw
    $visualRunnerText = Get-Content (Join-Path $fleetRoot "tools\visual-inspect-runner.mjs") -Raw
    $fleetVisualText = Get-Content (Join-Path $fleetRoot "fleet-visual-check.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "fleet-visual-check.ps1")) -Message "Fleet exposes a direct visual QA lane"
    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "templates\visual-routes.json")) -Message "Fleet includes a starter visual route map"
    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "templates\docs\codex\SITE_MAP.md")) -Message "Fleet includes a starter site map"
    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "set-ship-pages.ps1")) -Message "Fleet exposes reusable ship page configuration"
    Assert-True -Condition ($visualInspectText -match '\$RouteConfig') -Message "Visual inspect accepts an explicit route config"
    Assert-True -Condition ($visualInspectText -match 'docs\\codex\\visual-routes\.json') -Message "Visual inspect auto-discovers ship route maps"
    Assert-True -Condition ($visualRunnerText -match 'requiredText') -Message "Visual runner supports route-specific required text"
    Assert-True -Condition ($visualRunnerText -match 'configuredViewports') -Message "Visual runner supports configured viewports"
    Assert-True -Condition ($fleetVisualText -match 'out\\fleet-visual-check\.md') -Message "Fleet visual check writes a fleet summary"
    Assert-True -Condition ($fleetVisualText -match 'visual-inspect\.ps1') -Message "Fleet visual check delegates to visual inspect"
    Assert-True -Condition ($fleetVisualText -match 'visualServeDirectory') -Message "Fleet visual check supports visual-only serve directories"
    Assert-True -Condition ($fleetVisualText -match 'INFRA_FAIL') -Message "Fleet visual check distinguishes harness failures from visual findings"
    Assert-True -Condition ($fleetVisualText -match 'NoFailOnFindings' -and $fleetVisualText -match 'did not produce a fresh summary') -Message "NoFailOnFindings does not hide missing visual summaries"
    Assert-True -Condition ($fleetVisualText -match 'No projects selected') -Message "Fleet visual check rejects empty project selections"
    Assert-True -Condition ($fleetVisualText -match 'WriteShipReports' -and $visualInspectText -match 'SkipShipReport') -Message "Direct visual checks can avoid dirtying ship report files"
    Assert-True -Condition ($fleetVisualText -match 'VerboseRunner' -and $visualInspectText -match '\$Quiet') -Message "Direct visual checks quiet noisy runner output by default"
    Assert-True -Condition ($fleetVisualText -match 'WARN' -and $fleetVisualText -match 'topFindings') -Message "Fleet visual check reports non-blocking warning summaries"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "tools\visual-smoke-runner.mjs") -Raw) -match 'filteredConsoleIssues') -Message "Visual smoke filters ignored console noise from recorded results"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw) -match 'visualServeDirectory') -Message "Checkpoint visual gates support visual-only serve directories"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "visual-smoke.ps1") -Raw) -match 'static-preview-server\.ps1') -Message "Visual smoke supports static preview ships"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "visual-smoke.ps1") -Raw) -match '\[string\]\$Path') -Message "Visual smoke supports non-root smoke paths"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw) -match 'visualSmokePath') -Message "Checkpoint visual smoke uses configured visual paths"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw) -match 'SITE_MAP\.md' -and (Get-Content (Join-Path $fleetRoot "generate-next-five.ps1") -Raw) -match 'visual-routes\.json') -Message "Planner and implementation prompts include route/page context"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "install-harness.ps1") -Raw) -match 'SITE_MAP\.md' -and (Get-Content (Join-Path $fleetRoot "install-harness.ps1") -Raw) -match 'visual-routes\.json') -Message "Harness install provides route planning docs"
    Assert-True -Condition ($readmeText -match 'fleet-visual-check\.ps1') -Message "README documents the direct visual QA lane"
    Assert-True -Condition ($readmeText -match 'set-ship-pages\.ps1') -Message "README documents reusable ship page configuration"
}

function Test-JoeyStorageRules {
    $joeyText = Get-Content (Join-Path $fleetRoot "joey-security-review.ps1") -Raw
    Assert-True -Condition ($joeyText -match 'Test-SensitiveAddedLine') -Message "Joey centralizes sensitive added-line detection"
    Assert-True -Condition ($joeyText -match 'storageSensitivePattern') -Message "Joey treats local storage as sensitive only for risky data names"
    Assert-False -Condition ($joeyText -match 'process\\.env\|import\\.meta\\.env\|localStorage\\.setItem') -Message "Joey does not blanket-block harmless localStorage writes"
}

function Test-RobinCopySmokeSupport {
    $robinText = Get-Content (Join-Path $fleetRoot "robin-copy-review.ps1") -Raw
    Assert-True -Condition ($robinText -match 'copySmokeTerms') -Message "Robin wrapper defines deterministic copy-smoke terms"
    Assert-True -Condition ($robinText -match 'Static public-copy smoke hits') -Message "Robin prompt includes copy-smoke evidence"
    Assert-True -Condition ($robinText -match 'Ignore harmless component names') -Message "Robin copy smoke distinguishes visible copy from internal identifiers"
    Assert-True -Condition ($robinText -match 'service notes') -Message "Robin copy smoke catches vague restaurant-service wording"
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

function Test-MagicRunSupport {
    $preflightPath = Join-Path $fleetRoot "prepare-magic-run.ps1"
    $plannerText = Get-Content (Join-Path $fleetRoot "generate-next-five.ps1") -Raw
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $overnightText = Get-Content (Join-Path $fleetRoot "launch-overnight-run.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw

    Assert-True -Condition (Test-Path $preflightPath) -Message "Fleet exposes magic-run preflight"
    Assert-True -Condition ($plannerText -match 'MAGIC_MISSION\.md') -Message "Nami planner reads magic mission"
    Assert-True -Condition ($plannerText -match 'WORK_PACKS\.md') -Message "Nami planner reads work packs"
    Assert-True -Condition ($plannerText -match 'WORK_PACK_STATUS\.md') -Message "Nami planner reads work pack status"
    Assert-True -Condition ($plannerText -match 'MAGIC_SCORECARD\.md') -Message "Nami planner reads magic scorecard"
    Assert-True -Condition ($plannerText -match 'QUALITY_QUARANTINE\.md') -Message "Nami planner reads quality quarantine"
    Assert-True -Condition ($plannerText -match 'coherent work-pack progress') -Message "Nami planner prioritizes coherent work-pack progress"
    Assert-True -Condition ($plannerText -match 'do not mention the active work pack') -Message "Nami rejects tasks that ignore active work pack"
    Assert-True -Condition ($loopText -match 'Append-MagicScorecard') -Message "Checkpoint loop appends magic scorecard entries"
    Assert-True -Condition ($loopText -match 'Append-BatchQualityScorecard') -Message "Checkpoint loop appends fresh batch QA scorecard entries"
    Assert-True -Condition ($loopText -match 'Save-BatchQualityScorecardForLoop') -Message "Checkpoint loop centralizes batch QA scorecard commits"
    Assert-True -Condition ($loopText -match 'Active work pack') -Message "Checkpoint loop records active work pack in scorecard"
    Assert-True -Condition ($loopText -match 'Before visual evidence') -Message "Checkpoint loop records before visual evidence"
    Assert-True -Condition ($loopText -match 'After visual evidence') -Message "Checkpoint loop records after visual evidence"
    Assert-True -Condition ($loopText -match 'QUALITY_QUARANTINE\.md') -Message "Checkpoint loop writes quality quarantine"
    Assert-True -Condition ($loopText -match 'Magic Improvement Score') -Message "Checkpoint loop reads Simon magic improvement score"
    Assert-True -Condition ($loopText -match 'Get-TaskMaterialityFailureForLoop') -Message "Checkpoint loop blocks visible-impact tasks that lack material product changes"
    Assert-True -Condition ($loopText -match 'VISIBLE_IMPACT') -Message "Implementation prompt asks Codex to state visible user impact"
    Assert-True -Condition ($loopText -match 'Materiality signal') -Message "Magic scorecard records visible-impact materiality"
    Assert-True -Condition ($loopText -match 'Fresh QA evidence') -Message "Batch scorecard records fresh post-gate visual evidence"
    Assert-True -Condition ($loopText -match 'Debug checkpoint result') -Message "Batch scorecard records checkpoint debugger result"
    Assert-True -Condition ($loopText -match 'Codex batch QA scorecard') -Message "Checkpoint loop commits batch QA scorecard updates"
    Assert-True -Condition ($loopText -match 'human stop' -and $loopText -match 'DebugExit -1') -Message "Checkpoint loop records batch QA when human-stop gates fire before debug"
    Assert-True -Condition ($loopText -match 'debug stop') -Message "Checkpoint loop records batch QA when debug gate fails"
    Assert-True -Condition ($loopText -match 'Release-FleetRunLock\s*\r?\n\s*exit 1') -Message "Checkpoint loop releases run lock before debug failure exit"
    Assert-True -Condition ($loopText -match 'Task impact:') -Message "Nightly report records task impact metadata"
    Assert-True -Condition ($loopText -match 'Append-MagicScorecard.+-TaskBase') -Message "Magic scorecard receives task base for materiality line counts"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "debug-checkpoint.ps1") -Raw) -match 'ImpactMode') -Message "Checkpoint debugger can enforce visible-impact batches"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "debug-checkpoint.ps1") -Raw) -match '\(GREEN\|YELLOW\|RED\)\\b\[\\s\\\.') -Message "Checkpoint debugger accepts verdict punctuation"
    Assert-True -Condition ($plannerText -match 'impact:showpiece') -Message "Nami planner can mark high-expectation creative tasks as showpiece impact"
    Assert-True -Condition ((Get-Content (Join-Path $fleetRoot "simon-design-review.ps1") -Raw) -match 'Magic Improvement Score') -Message "Simon is asked for magic improvement score"
    Assert-True -Condition ($loopText -match 'docs/codex/MAGIC_SCORECARD\.md') -Message "Checkpoint loop stages magic scorecard"
    Assert-True -Condition ($readmeText -match 'WORK_PACK_STATUS\.md') -Message "README documents active work-pack status"
    Assert-True -Condition ($overnightText -match '\[switch\]\$RequireMagicPreflight') -Message "Overnight launcher exposes magic preflight gate"
    Assert-True -Condition ($overnightText -match 'prepare-magic-run\.ps1') -Message "Overnight launcher can run magic preflight"
    Assert-True -Condition ($overnightText -match '-Strict') -Message "Overnight magic preflight treats warnings as blockers"
    Assert-True -Condition ($readmeText -match 'prepare-magic-run\.ps1') -Message "README documents magic-run preflight"
    Assert-True -Condition ($readmeText -match 'visible-impact guard') -Message "README documents the visible-impact guard"
}

function Test-PhaseLoopSupport {
    $phasePath = Join-Path $fleetRoot "fleet-phase.ps1"
    $phaseAuditPath = Join-Path $fleetRoot "fleet-phase-audit.ps1"
    $phaseText = Get-Content $phasePath -Raw
    $phaseAuditText = Get-Content $phaseAuditPath -Raw
    $plannerText = Get-Content (Join-Path $fleetRoot "generate-next-five.ps1") -Raw
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $schoolText = Get-Content (Join-Path $fleetRoot "launch-school-run.ps1") -Raw
    $overnightText = Get-Content (Join-Path $fleetRoot "launch-overnight-run.ps1") -Raw
    $cellarText = Get-Content (Join-Path $fleetRoot "launch-cellar-fleet.ps1") -Raw
    $docsText = Get-Content (Join-Path $fleetRoot "docs\CODEX_FLEET_CONTROL_ROOM.md") -Raw

    Assert-True -Condition (Test-Path $phasePath) -Message "Fleet exposes phase state manager"
    Assert-True -Condition (Test-Path $phaseAuditPath) -Message "Fleet exposes phase readiness audit"
    Assert-True -Condition ($phaseText -match 'Audience') -Message "Phase state stores audience"
    Assert-True -Condition ($phaseText -match 'Primary Action') -Message "Phase state stores primary action"
    Assert-True -Condition ($phaseText -match 'Showable Moment') -Message "Phase state stores showable moment"
    Assert-True -Condition ($phaseText -match 'No More Features Lock') -Message "Phase state stores feature lock"
    Assert-True -Condition ($phaseText -match 'Complexity Budget') -Message "Phase state stores complexity budget"
    Assert-True -Condition ($phaseText -match 'Before/After Judgment') -Message "Phase state stores before-after judgment"
    Assert-True -Condition ($phaseText -match 'Parking State') -Message "Phase state stores parking state"
    Assert-True -Condition ($phaseText -match '\$ParkingState') -Message "Phase state accepts parking state updates"
    Assert-True -Condition ($phaseText -match 'Phase Model Policy') -Message "Phase state stores phase model policy"
    Assert-True -Condition ($phaseText -match 'Evidence Required') -Message "Phase state stores required evidence"
    Assert-True -Condition ($phaseText -match 'Done Signal') -Message "Phase state stores done signal"
    Assert-True -Condition ($phaseText -match 'Next Phase Criteria') -Message "Phase state stores next phase criteria"
    Assert-True -Condition ($phaseText -match 'repair') -Message "Phase state supports repair as an interrupt lane"
    Assert-True -Condition ($phaseText -match 'problem-brief' -and $phaseText -match 'analysis-proof') -Message "Phase state supports analytical software phases"
    Assert-True -Condition ($phaseText -match 'Repair Trigger') -Message "Phase state stores repair trigger"
    Assert-True -Condition ($phaseText -match 'Repair Return Phase') -Message "Phase state stores repair return phase"
    Assert-True -Condition ($phaseText -match '\$Validate') -Message "Phase state can be validated"
    Assert-True -Condition ($phaseAuditText -match 'PHASE_STATE\.md') -Message "Phase audit checks phase files"
    Assert-True -Condition ($phaseAuditText -match 'validPhases') -Message "Phase audit rejects unknown phases"
    Assert-True -Condition ($phaseAuditText -match 'Done Signal') -Message "Phase audit checks done signal"
    Assert-True -Condition ($phaseAuditText -match 'Repair Trigger') -Message "Phase audit checks repair trigger"
    Assert-True -Condition ($phaseAuditText -match 'Repair Return Phase') -Message "Phase audit checks repair return phase"
    Assert-True -Condition ($phaseAuditText -match '\$Strict') -Message "Phase audit can fail strict runs"
    Assert-True -Condition ($plannerText -match 'PHASE_STATE\.md') -Message "Planner reads phase state"
    Assert-True -Condition ($plannerText -match 'Current loop phase') -Message "Planner receives current loop phase"
    Assert-True -Condition ($plannerText -match 'Audience') -Message "Planner treats audience as first-class"
    Assert-True -Condition ($plannerText -match 'No More Features Lock') -Message "Planner treats feature lock as first-class"
    Assert-True -Condition ($plannerText -match 'Product Promise') -Message "Planner treats product promise as first-class"
    Assert-True -Condition ($plannerText -match 'Complexity Budget') -Message "Planner treats complexity budget as first-class"
    Assert-True -Condition ($plannerText -match 'Done Signal') -Message "Planner treats done signal as first-class"
    Assert-True -Condition ($plannerText -match 'Repair Trigger') -Message "Planner treats repair trigger as first-class"
    Assert-True -Condition ($plannerText -match 'interrupt lane') -Message "Planner understands repair as an interrupt lane"
    Assert-True -Condition ($plannerText -match 'Analytical software doctrine') -Message "Planner understands analytical software doctrine"
    Assert-True -Condition ($plannerText -match 'fixture-tests' -and $plannerText -match 'engine-build') -Message "Planner exposes analytical engine phases"
    Assert-True -Condition ($loopText -match 'judgment-heavy' -or $loopText -match 'shape.*simplicity.*polish') -Message "Loop has phase-aware model policy"
    Assert-True -Condition ($loopText -match 'Phase Model Policy') -Message "Loop reads phase model policy"
    Assert-True -Condition ($plannerText -match 'foundation.*shape.*simplicity.*polish.*proof') -Message "Planner prompt includes phase doctrine"
    Assert-True -Condition ($loopText -match 'repair') -Message "Checkpoint loop accepts repair loop phase"
    Assert-True -Condition ($loopText -match 'problem-brief' -and $loopText -match 'analysis-proof') -Message "Checkpoint loop accepts analytical phases"
    Assert-True -Condition ($loopText -match '\$LoopPhase') -Message "Checkpoint loop exposes LoopPhase"
    Assert-True -Condition ($loopText -match '-LoopPhase') -Message "Checkpoint loop passes LoopPhase to planner"
    Assert-True -Condition ($schoolText -match '\$LoopPhase') -Message "School launcher exposes LoopPhase"
    Assert-True -Condition ($overnightText -match '\$LoopPhase') -Message "Overnight launcher exposes LoopPhase"
    Assert-True -Condition ($cellarText -match '\$LoopPhase') -Message "Cellar launcher exposes LoopPhase"
    Assert-True -Condition ($schoolText -match 'repair' -and $overnightText -match 'repair' -and $cellarText -match 'repair') -Message "Launchers expose repair loop phase"
    Assert-True -Condition ($schoolText -match 'problem-brief' -and $overnightText -match 'formula-spec' -and $cellarText -match 'analysis-proof') -Message "Launchers expose analytical loop phases"
    Assert-True -Condition ($schoolText -match 'RequirePhaseValidation') -Message "School launcher can require phase validation"
    Assert-True -Condition ($overnightText -match 'RequirePhaseValidation') -Message "Overnight launcher can require phase validation"
    Assert-True -Condition ($cellarText -match 'RequirePhaseValidation') -Message "Cellar launcher can require phase validation"
    Assert-True -Condition ($cellarText -match '\$FleetGroup') -Message "Cellar launcher can target a named fleet group"
    Assert-True -Condition ($cellarText -match 'SkipDoctor') -Message "Cellar launcher forwards SkipDoctor"
    Assert-True -Condition ($docsText -match 'Phase loops') -Message "Control room docs explain phase loops"
    Assert-True -Condition ($docsText -match 'Repair Trigger') -Message "Control room docs explain repair lane fields"
    Assert-True -Condition ($docsText -match 'Analytical software phase order') -Message "Control room docs explain analytical loop"
}

function Test-LongRunSupervisorSupport {
    $supervisorText = Get-Content (Join-Path $fleetRoot "fleet-supervisor.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw
    $roadmapText = Get-Content (Join-Path $fleetRoot "docs\TWELVE_HOUR_MAGIC_ROADMAP.md") -Raw

    Assert-True -Condition ($supervisorText -match 'Resolve-SupervisorState') -Message "Supervisor classifies ship state"
    Assert-True -Condition ($supervisorText -match 'ExcludeProject') -Message "Supervisor can exclude docked ships"
    Assert-True -Condition ($supervisorText -match 'PROGRESSING') -Message "Supervisor reports progressing ships"
    Assert-True -Condition ($supervisorText -match 'IDLE_RUNNING') -Message "Supervisor reports idle running ships"
    Assert-True -Condition ($supervisorText -match 'BLOCKED_REVIEW') -Message "Supervisor reports blocked ships"
    Assert-True -Condition ($supervisorText -match 'LOOPING_QUALITY') -Message "Supervisor reports looping quality ships"
    Assert-True -Condition ($supervisorText -match 'MaxTaskCommits') -Message "Supervisor has task progress budgets"
    Assert-True -Condition ($supervisorText -match 'MaxQuarantines') -Message "Supervisor has quarantine budgets"
    Assert-True -Condition ($supervisorText -match 'MaxQualityStops') -Message "Supervisor has quality-stop budgets"
    Assert-True -Condition ($supervisorText -match 'Write-OvernightDigest') -Message "Supervisor writes overnight digest"
    Assert-True -Condition ($supervisorText -match 'request-safe-stop\.ps1') -Message "Supervisor recommends safe stop path"
    Assert-True -Condition ($supervisorText -match 'AutoSafeStop') -Message "Supervisor can auto-request safe stops"
    Assert-True -Condition ($supervisorText -match 'Request-FleetSafeStop') -Message "Supervisor writes safe-stop requests"
    Assert-True -Condition ($supervisorText -match 'Safe Stops Requested') -Message "Supervisor reports auto safe-stop actions"
    Assert-True -Condition ($supervisorText -match '\$Row\.budget -match "\^OVER"') -Message "Supervisor prioritizes budget stops even while active work is dirty"
    Assert-True -Condition ($supervisorText -match 'AutoRepair') -Message "Supervisor exposes auto-repair mode"
    Assert-True -Condition ($supervisorText -match 'AutoRepairStates = @\("BUDGET_STOP", "LOOPING_QUALITY", "BLOCKED_REVIEW"\)') -Message "Supervisor auto-repair defaults to blocker states"
    Assert-True -Condition ($supervisorText -match 'Add-SupervisorAutoRepairTask') -Message "Supervisor can queue repair tasks"
    Assert-True -Condition ($supervisorText -match 'Set-SupervisorRepairPhase') -Message "Supervisor enters repair phase before repair tasks"
    Assert-True -Condition ($supervisorText -match 'Complete-SupervisorRepairPhaseIfClear') -Message "Supervisor exits repair phase after blockers clear"
    Assert-True -Condition ($supervisorText -match 'MaxRepairAttempts') -Message "Supervisor caps repair attempts"
    Assert-True -Condition ($supervisorText -match 'repairAttempts') -Message "Supervisor reports repair attempt counts"
    Assert-True -Condition ($supervisorText -match 'Repair Skipped') -Message "Supervisor reports skipped repair attempts"
    Assert-True -Condition ($supervisorText -match 'Repair Return Phase') -Message "Supervisor records repair return phase"
    Assert-True -Condition ($supervisorText -match 'Supervisor Auto Repair') -Message "Supervisor creates high-priority repair queue sections"
    Assert-True -Condition ($supervisorText -match 'AUTO_REPAIR\.md') -Message "Supervisor records auto-repair actions"
    Assert-True -Condition ($supervisorText -match 'ClearSafeStopAfterRepair') -Message "Supervisor can clear a ship safe-stop after repair task creation"
    Assert-True -Condition ($supervisorText -match 'AutoRelaunchRepair') -Message "Supervisor exposes auto-relaunch repair mode"
    Assert-True -Condition ($supervisorText -match 'Start-SupervisorRepairRun') -Message "Supervisor can relaunch one repair batch"
    Assert-True -Condition ($supervisorText -match '-LoopPhase", "repair"') -Message "Supervisor relaunches repair batches in repair phase"
    Assert-True -Condition ($supervisorText -match 'Repair lane') -Message "Supervisor queues explicit repair-lane tasks"
    Assert-True -Condition ($supervisorText -match 'Repair Runs Launched') -Message "Supervisor reports repair relaunches"
    Assert-True -Condition ($supervisorText -match 'Child Work') -Message "Supervisor report separates active child work from idle shells"
    Assert-True -Condition ($supervisorText -match 'childSummary') -Message "Supervisor tracks active child process names"
    Assert-True -Condition ($supervisorText -match 'codex') -Message "Supervisor labels Codex child work clearly"
    Assert-True -Condition ($supervisorText -match 'no child work') -Message "Supervisor digest explains missing active child work"
    Assert-True -Condition ($supervisorText -match 'RepairBatchSize') -Message "Supervisor keeps repair relaunch batches small"
    Assert-True -Condition ($supervisorText -match 'IsOutputRedirected') -Message "Supervisor skips console clear under redirected autopilot logs"
    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "start-overnight-autopilot.ps1")) -Message "Fleet exposes overnight autopilot wrapper"
    $autopilotText = Get-Content (Join-Path $fleetRoot "start-overnight-autopilot.ps1") -Raw
    Assert-True -Condition ($autopilotText -match 'AutoSafeStop') -Message "Overnight autopilot enables auto safe-stop"
    Assert-True -Condition ($autopilotText -match 'AutoRepair') -Message "Overnight autopilot enables auto repair queueing"
    Assert-True -Condition ($autopilotText -match 'AutoRelaunchRepair') -Message "Overnight autopilot enables repair relaunches"
    Assert-True -Condition ($autopilotText -match 'MaxRepairAttempts') -Message "Overnight autopilot forwards repair attempt cap"
    Assert-True -Condition ($autopilotText -match 'NinersDynastyWarRoom') -Message "Overnight autopilot excludes docked Niners by default"
    Assert-True -Condition ($autopilotText -match 'overnight-autopilot\.md') -Message "Overnight autopilot writes a report"
    Assert-True -Condition ($autopilotText -match 'StepTimeoutSeconds') -Message "Overnight autopilot bounds supervisor step hangs"
    Assert-True -Condition ($autopilotText -match 'autopilot-runs') -Message "Overnight autopilot writes step logs"
    Assert-True -Condition ($autopilotText -match '\$null -eq \$process\.ExitCode') -Message "Overnight autopilot handles blank completed process exit codes"
    Assert-True -Condition ($supervisorText -match 'planner will need to generate tasks') -Message "Supervisor distinguishes idle ready ships"
    Assert-True -Condition ($readmeText -match 'all-day watchdog') -Message "README documents supervisor watchdog"
    Assert-True -Condition ($readmeText -match 'start-overnight-autopilot\.ps1') -Message "README documents overnight autopilot wrapper"
    Assert-True -Condition ($roadmapText -match '\[x\] Upgrade `fleet-supervisor\.ps1`') -Message "Roadmap marks supervisor phase complete"

    $harborText = Get-Content (Join-Path $fleetRoot "harbor-master.ps1") -Raw
    Assert-True -Condition ($harborText -match 'childSummary') -Message "Harbor Master tracks active child process names"
    Assert-True -Condition ($harborText -match 'codex') -Message "Harbor Master labels Codex child work clearly"
}

function Test-SophisticatedSoftwareModeSupport {
    $loopText = Get-Content (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Raw
    $plannerText = Get-Content (Join-Path $fleetRoot "generate-next-five.ps1") -Raw
    $featureText = Get-Content (Join-Path $fleetRoot "software-feature-mode.ps1") -Raw
    $readmeText = Get-Content (Join-Path $fleetRoot "README.md") -Raw
    $roadmapText = Get-Content (Join-Path $fleetRoot "docs\TWELVE_HOUR_MAGIC_ROADMAP.md") -Raw

    Assert-True -Condition (Test-Path (Join-Path $fleetRoot "software-feature-mode.ps1")) -Message "Fleet exposes software feature mode gate"
    Assert-True -Condition ($loopText -match 'mode:') -Message "Task contract parser recognizes mode metadata"
    Assert-True -Condition ($loopText -match 'feature-pack') -Message "Checkpoint loop supports feature-pack mode"
    Assert-True -Condition ($loopText -match 'Test-SoftwareFeatureModeApproval') -Message "Feature-pack mode has approval gate"
    Assert-True -Condition ($loopText -match 'SOFTWARE_FEATURE_PLAN\.md') -Message "Feature-pack mode requires feature plan"
    Assert-True -Condition ($loopText -match 'SOFTWARE_FEATURE_APPROVAL\.md') -Message "Feature-pack mode requires feature approval"
    Assert-True -Condition ($loopText -match 'RUNTIME_CHECKS\.md') -Message "Feature-pack mode requires runtime checks"
    Assert-True -Condition ($loopText -match 'Test-PackageAndDependencyChanges') -Message "Checkpoint loop gates package/dependency changes"
    Assert-True -Condition ($loopText -match 'canEditPackageFiles') -Message "Package edits require ship capability"
    Assert-True -Condition ($loopText -match 'canAddDependencies') -Message "Dependency edits require ship capability"
    Assert-True -Condition ($plannerText -match 'mode:feature-pack') -Message "Planner is taught feature-pack metadata"
    Assert-True -Condition ($featureText -match 'IncludeDependencyChange') -Message "Software feature mode supports dependency lane"
    Assert-True -Condition ($featureText -match 'DEPENDENCY_APPROVAL\.md') -Message "Software feature mode validates dependency approval"
    Assert-True -Condition ($readmeText -match 'Devil Fruit Phase 5') -Message "README documents sophisticated software mode"
    Assert-True -Condition ($roadmapText -match '\[x\] Add approved "bigger-change mode"') -Message "Roadmap marks sophisticated software mode complete"
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
Test-RecoveryIncludesStagedFiles
Test-CheckpointGateOrder
Test-TaskQuarantineSupport
Test-DuplicateRunGuard
Test-SafeStopSupport
Test-LaunchControlSupport
Test-FleetVisualQaLaneSupport
Test-JoeyStorageRules
Test-RobinCopySmokeSupport
Test-DebuggerReportFileAllowance
Test-ShipPreviewRefreshSupport
Test-MagicRunSupport
Test-PhaseLoopSupport
Test-LongRunSupervisorSupport
Test-SophisticatedSoftwareModeSupport

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
