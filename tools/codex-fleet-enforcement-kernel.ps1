$script:TsfKernelRestrictedActions = @(
    "push",
    "merge",
    "deploy",
    "install_packages",
    "migration",
    "secrets",
    "privatelens",
    "proof_run",
    "all_fleet",
    "background_runner",
    "persistent_runner",
    "canonical_nwr_inspection",
    "canonical_nwr_mutation",
    "normal_nwr_packet_read",
    "product_repo_inspection",
    "product_repo_mutation",
    "api_bridge",
    "open_network_port",
    "credential_change",
    "app_wiring",
    "ranking_formula_source_truth_promotion",
    "hidden_sort",
    "recommendation_behavior"
)

$script:TsfKernelMissionStates = @(
    "drafted",
    "preflight-pending",
    "approved-for-worker",
    "running",
    "postrun-pending",
    "completed",
    "blocked-tim-required",
    "archived"
)

function Get-TsfKernelRoot {
    return (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
}

function ConvertTo-TsfKernelArray {
    param([object]$Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @($Value)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @()
        foreach ($item in $Value) {
            $items += $item
        }
        return $items
    }

    return @($Value)
}

function Test-TsfKernelJsonArray {
    param([object]$Value)

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [string]) {
        return $false
    }

    return ($Value -is [System.Array])
}

function Read-TsfKernelJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
}

function Write-TsfKernelJson {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $json = $Value | ConvertTo-Json -Depth 30
    Set-Content -LiteralPath $Path -Encoding UTF8 -Value $json
}

function New-TsfKernelCheck {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message,
        [string]$Evidence = ""
    )

    return [pscustomobject]@{
        name = $Name
        status = $Status
        passed = ($Status -eq "PASS" -or $Status -eq "WARN")
        message = $Message
        evidence = $Evidence
    }
}

function Get-TsfKernelFullPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$BasePath = ""
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        $BasePath = (Get-Location).Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Test-TsfKernelPathInside {
    param(
        [Parameter(Mandatory = $true)][string]$ChildPath,
        [Parameter(Mandatory = $true)][string]$ParentPath
    )

    $child = [System.IO.Path]::GetFullPath($ChildPath)
    $parent = [System.IO.Path]::GetFullPath($ParentPath)
    $trimChars = [char[]]@('\', '/')
    $childTrimmed = $child.TrimEnd($trimChars)
    $parentTrimmed = $parent.TrimEnd($trimChars)

    if ([string]::Equals($childTrimmed, $parentTrimmed, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $parentWithSlash = $parentTrimmed + [System.IO.Path]::DirectorySeparatorChar
    return $child.StartsWith($parentWithSlash, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-TsfKernelPathTokenSafe {
    param([string]$Path)

    $value = ([string]$Path).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }

    if ($value -in @("*", ".", "\", "/", "all", "ALL")) {
        return $false
    }

    if ($value -match "(^|[\\/])\.\.([\\/]|$)") {
        return $false
    }

    if ($value -match "[\x00-\x1F\x7F]") {
        return $false
    }

    return $true
}

function Get-TsfKernelGitState {
    param([Parameter(Mandatory = $true)][string]$RepoPath)

    $state = [ordered]@{
        can_capture = $false
        git_available = $false
        branch = ""
        head = ""
        status_short = @()
        dirty = $false
        error = ""
    }

    try {
        $rootOutput = @(& git -C $RepoPath rev-parse --show-toplevel 2>&1)
        $rootExit = $LASTEXITCODE
        if ($rootExit -ne 0) {
            $state.error = ($rootOutput -join "`n")
            return [pscustomobject]$state
        }

        $state.git_available = $true
        $branchOutput = @(& git -C $RepoPath branch --show-current 2>&1)
        $branchExit = $LASTEXITCODE
        if ($branchExit -eq 0) {
            $state.branch = ($branchOutput -join "`n").Trim()
        }

        $statusOutput = @(& git -C $RepoPath status --short 2>&1)
        $statusSucceeded = $?
        if ($statusSucceeded) {
            $state.status_short = @($statusOutput | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
            $state.dirty = ($state.status_short.Count -gt 0)
            $state.can_capture = $true
        } else {
            $state.error = ($statusOutput -join "`n")
        }

        $headOutput = @(& git -C $RepoPath rev-parse HEAD 2>&1)
        $headExit = $LASTEXITCODE
        if ($headExit -eq 0) {
            $state.head = ($headOutput -join "`n").Trim()
        } elseif ($state.can_capture) {
            $state.error = "HEAD unavailable; status was captured for an unborn or empty git repository."
        }
    } catch {
        $state.error = $_.Exception.Message
    }

    return [pscustomobject]$state
}

function Get-TsfKernelProjectRegistration {
    param(
        [Parameter(Mandatory = $true)][object]$Mission,
        [Parameter(Mandatory = $true)][string]$FleetRoot
    )

    $repoFull = Get-TsfKernelFullPath -Path ([string]$Mission.repo_path)
    $fleetFull = Get-TsfKernelFullPath -Path $FleetRoot
    if ([string]$Mission.lane -eq "MASTER_TSF_CONTROL_PLANE" -and [string]$Mission.mission_type -eq "tsf_infrastructure" -and (Test-TsfKernelPathInside -ChildPath $repoFull -ParentPath $fleetFull)) {
        return [pscustomobject]@{
            registered = $true
            status = "TSF_CONTROL_PLANE_INTERNAL"
            evidence = "Mission is a TSF-local infrastructure mission inside the TSF repo."
        }
    }

    $registryPath = Join-Path $FleetRoot "projects.json"
    if (!(Test-Path -LiteralPath $registryPath)) {
        return [pscustomobject]@{
            registered = $true
            status = "NO_REGISTRY"
            evidence = "No projects.json registry found."
        }
    }

    $projects = @(Read-TsfKernelJson -Path $registryPath | ForEach-Object { $_ })
    foreach ($project in $projects) {
        $names = @()
        foreach ($prop in @("name", "id", "projectId")) {
            if ($project.PSObject.Properties.Name -contains $prop) {
                $names += [string]$project.$prop
            }
        }

        $repo = ""
        if ($project.PSObject.Properties.Name -contains "repo") {
            $repo = [string]$project.repo
        } elseif ($project.PSObject.Properties.Name -contains "repoPath") {
            $repo = [string]$project.repoPath
        } elseif ($project.PSObject.Properties.Name -contains "path") {
            $repo = [string]$project.path
        }

        $nameMatch = @($names | Where-Object { ![string]::IsNullOrWhiteSpace($_) -and [string]::Equals($_, [string]$Mission.project_id, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        $repoMatch = $false
        if (![string]::IsNullOrWhiteSpace($repo)) {
            $repoFullFromRegistry = Get-TsfKernelFullPath -Path $repo
            $repoMatch = [string]::Equals($repoFullFromRegistry.TrimEnd('\', '/'), $repoFull.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)
        }

        if ($nameMatch -or $repoMatch) {
            return [pscustomobject]@{
                registered = $true
                status = "REGISTERED"
                evidence = "Matched project registry entry."
            }
        }
    }

    return [pscustomobject]@{
        registered = $false
        status = "NOT_REGISTERED"
        evidence = "projects.json exists but no matching project_id or repo_path entry was found."
    }
}

function Get-TsfKernelApprovalRequirements {
    param([Parameter(Mandatory = $true)][object]$Mission)

    $requirements = @()
    foreach ($requirement in (ConvertTo-TsfKernelArray -Value $Mission.approval_requirements)) {
        $isRequired = $false
        if ($requirement.PSObject.Properties.Name -contains "required") {
            $isRequired = [bool]$requirement.required
        }

        if ($isRequired) {
            $requirements += $requirement
        }
    }

    return $requirements
}

function Get-TsfKernelApprovalLedger {
    param([string]$ApprovalLedgerPath)

    if ([string]::IsNullOrWhiteSpace($ApprovalLedgerPath) -or !(Test-Path -LiteralPath $ApprovalLedgerPath)) {
        return [pscustomobject]@{
            schema_version = 1
            ledger_id = "empty-local-ledger"
            approvals = @()
        }
    }

    return Read-TsfKernelJson -Path $ApprovalLedgerPath
}

function Test-TsfKernelApprovalPathScope {
    param(
        [Parameter(Mandatory = $true)][object]$Mission,
        [Parameter(Mandatory = $true)][object]$Approval
    )

    $allowedApprovalPaths = @(ConvertTo-TsfKernelArray -Value $Approval.allowed_files_or_paths)
    if ($allowedApprovalPaths.Count -eq 0) {
        return $false
    }

    $missionWritePaths = @(ConvertTo-TsfKernelArray -Value $Mission.allowed_writes)
    if ($missionWritePaths.Count -eq 0) {
        return $true
    }

    $repoPath = Get-TsfKernelFullPath -Path ([string]$Mission.repo_path)
    foreach ($writePath in $missionWritePaths) {
        $resolvedWritePath = Get-TsfKernelFullPath -Path ([string]$writePath) -BasePath $repoPath
        $covered = $false
        foreach ($approvalPath in $allowedApprovalPaths) {
            if (!(Test-TsfKernelPathTokenSafe -Path ([string]$approvalPath))) {
                continue
            }

            $resolvedApprovalPath = Get-TsfKernelFullPath -Path ([string]$approvalPath) -BasePath $repoPath
            if (Test-TsfKernelPathInside -ChildPath $resolvedWritePath -ParentPath $resolvedApprovalPath) {
                $covered = $true
                break
            }
        }

        if (-not $covered) {
            return $false
        }
    }

    return $true
}

function Find-TsfKernelApprovalMatches {
    param(
        [Parameter(Mandatory = $true)][object]$Mission,
        [Parameter(Mandatory = $true)][object]$Ledger,
        [string]$LedgerPath = "",
        [switch]$AllowFixtureApprovalsForTests
    )

    $now = Get-Date
    $matches = @()
    $requirements = @(Get-TsfKernelApprovalRequirements -Mission $Mission)
    $approvals = @(ConvertTo-TsfKernelArray -Value $Ledger.approvals)
    $repoFull = Get-TsfKernelFullPath -Path ([string]$Mission.repo_path)
    $fixtureLedgerAllowed = $false
    if ($AllowFixtureApprovalsForTests -and ![string]::IsNullOrWhiteSpace($LedgerPath)) {
        $fixtureRoot = Get-TsfKernelFullPath -Path (Join-Path (Get-TsfKernelRoot) "tests\fixtures")
        $localFixtureRoot = Get-TsfKernelFullPath -Path (Join-Path (Get-TsfKernelRoot) ".codex-local\fixtures")
        $ledgerFull = Get-TsfKernelFullPath -Path $LedgerPath
        $fixtureLedgerAllowed = (Test-TsfKernelPathInside -ChildPath $ledgerFull -ParentPath $fixtureRoot) -or (Test-TsfKernelPathInside -ChildPath $ledgerFull -ParentPath $localFixtureRoot)
    }

    foreach ($requirement in $requirements) {
        $exactAction = [string]$requirement.exact_action
        $requirementResult = [ordered]@{
            exact_action = $exactAction
            satisfied = $false
            match_status = "NO_MATCH"
            approval_id = ""
            sample_fixture_only = $false
            reason = ""
        }

        foreach ($approval in $approvals) {
            if ([string]$approval.exact_action -ne $exactAction) {
                continue
            }

            if (![string]::Equals([string]$approval.lane, [string]$Mission.lane, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            if (![string]::Equals((Get-TsfKernelFullPath -Path ([string]$approval.repo_path)).TrimEnd('\', '/'), $repoFull.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $active = $true
            $expiryText = ""
            if ($approval.PSObject.Properties.Name -contains "expires_at") {
                $expiryText = [string]$approval.expires_at
            }

            if (![string]::IsNullOrWhiteSpace($expiryText)) {
                $expiry = [datetime]::MinValue
                if ([datetime]::TryParse($expiryText, [ref]$expiry)) {
                    if ($expiry -lt $now) {
                        $active = $false
                    }
                } else {
                    $active = $false
                }
            } elseif (!($approval.PSObject.Properties.Name -contains "scope_limit") -or [string]::IsNullOrWhiteSpace([string]$approval.scope_limit)) {
                $active = $false
            }

            if (-not $active) {
                $requirementResult.match_status = "MATCH_EXPIRED_OR_INACTIVE"
                $requirementResult.approval_id = [string]$approval.approval_id
                continue
            }

            if (-not (Test-TsfKernelApprovalPathScope -Mission $Mission -Approval $approval)) {
                $requirementResult.match_status = "MATCH_SCOPE_MISMATCH"
                $requirementResult.approval_id = [string]$approval.approval_id
                continue
            }

            $fixtureOnly = $false
            if ($approval.PSObject.Properties.Name -contains "sample_fixture_only") {
                $fixtureOnly = [bool]$approval.sample_fixture_only
            }

            $requirementResult.approval_id = [string]$approval.approval_id
            $requirementResult.sample_fixture_only = $fixtureOnly
            if ($fixtureOnly -and -not $fixtureLedgerAllowed) {
                $requirementResult.match_status = "FIXTURE_MATCH_NOT_AUTHORITY"
                $requirementResult.reason = "Sample fixture approval was recognized but cannot satisfy real authority."
                continue
            }

            $requirementResult.satisfied = $true
            $requirementResult.match_status = if ($fixtureOnly) { "MATCHED_FIXTURE_FOR_TEST" } else { "MATCHED_ACTIVE_APPROVAL" }
            $requirementResult.reason = "Active approval matched exact action, repo, lane, and allowed path scope."
            break
        }

        $matches += [pscustomobject]$requirementResult
    }

    return $matches
}

function Test-TsfKernelMissionShape {
    param([Parameter(Mandatory = $true)][object]$Mission)

    $checks = [System.Collections.Generic.List[object]]::new()
    $requiredFields = @(
        "mission_id",
        "project_id",
        "repo_path",
        "lane",
        "mission_type",
        "allowed_reads",
        "allowed_writes",
        "forbidden_reads",
        "forbidden_writes",
        "forbidden_actions",
        "expected_artifacts",
        "required_preflight_checks",
        "required_postrun_checks",
        "stop_conditions",
        "approval_requirements",
        "hq_escalation_policy",
        "created_by",
        "created_at"
    )

    $propertyNames = @($Mission.PSObject.Properties.Name)
    foreach ($field in $requiredFields) {
        if ($propertyNames -contains $field) {
            $checks.Add((New-TsfKernelCheck -Name "schema.$field" -Status "PASS" -Message "Required field exists.")) | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "schema.$field" -Status "FAIL" -Message "Required field is missing.")) | Out-Null
        }
    }

    foreach ($field in @("allowed_reads", "allowed_writes", "forbidden_reads", "forbidden_writes", "forbidden_actions", "expected_artifacts", "required_preflight_checks", "required_postrun_checks", "stop_conditions", "approval_requirements")) {
        if ($propertyNames -contains $field) {
            if (Test-TsfKernelJsonArray -Value $Mission.$field) {
                $checks.Add((New-TsfKernelCheck -Name "schema.$field.array" -Status "PASS" -Message "Field is a JSON array.")) | Out-Null
            } else {
                $checks.Add((New-TsfKernelCheck -Name "schema.$field.array" -Status "FAIL" -Message "Field must be a JSON array.")) | Out-Null
            }
        }
    }

    foreach ($field in @("mission_id", "project_id", "repo_path", "lane", "mission_type", "created_by", "created_at")) {
        if ($propertyNames -contains $field -and [string]::IsNullOrWhiteSpace([string]$Mission.$field)) {
            $checks.Add((New-TsfKernelCheck -Name "schema.$field.nonempty" -Status "FAIL" -Message "Field must be non-empty.")) | Out-Null
        }
    }

    if ($propertyNames -contains "mission_id" -and [string]$Mission.mission_id -notmatch "^[A-Za-z0-9._:-]{8,120}$") {
        $checks.Add((New-TsfKernelCheck -Name "schema.mission_id.pattern" -Status "FAIL" -Message "mission_id must be stable and bounded.")) | Out-Null
    }

    if ($propertyNames -contains "created_at") {
        $createdAt = [datetime]::MinValue
        if ([datetime]::TryParse([string]$Mission.created_at, [ref]$createdAt)) {
            $checks.Add((New-TsfKernelCheck -Name "schema.created_at.parse" -Status "PASS" -Message "created_at parses as a timestamp.")) | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "schema.created_at.parse" -Status "FAIL" -Message "created_at must parse as a timestamp.")) | Out-Null
        }
    }

    if ($propertyNames -contains "expected_artifacts" -and @(ConvertTo-TsfKernelArray -Value $Mission.expected_artifacts).Count -eq 0) {
        $checks.Add((New-TsfKernelCheck -Name "schema.expected_artifacts.nonempty" -Status "FAIL" -Message "expected_artifacts must declare at least one artifact.")) | Out-Null
    }

    if ($propertyNames -contains "required_preflight_checks" -and @(ConvertTo-TsfKernelArray -Value $Mission.required_preflight_checks).Count -eq 0) {
        $checks.Add((New-TsfKernelCheck -Name "schema.required_preflight_checks.nonempty" -Status "FAIL" -Message "required_preflight_checks must declare at least one check.")) | Out-Null
    }

    if ($propertyNames -contains "required_postrun_checks" -and @(ConvertTo-TsfKernelArray -Value $Mission.required_postrun_checks).Count -eq 0) {
        $checks.Add((New-TsfKernelCheck -Name "schema.required_postrun_checks.nonempty" -Status "FAIL" -Message "required_postrun_checks must declare at least one check.")) | Out-Null
    }

    if ($propertyNames -contains "stop_conditions" -and @(ConvertTo-TsfKernelArray -Value $Mission.stop_conditions).Count -eq 0) {
        $checks.Add((New-TsfKernelCheck -Name "schema.stop_conditions.nonempty" -Status "FAIL" -Message "stop_conditions must declare at least one condition.")) | Out-Null
    }

    return @($checks)
}

function Test-TsfKernelPathScope {
    param([Parameter(Mandatory = $true)][object]$Mission)

    $checks = [System.Collections.Generic.List[object]]::new()
    $repoPath = Get-TsfKernelFullPath -Path ([string]$Mission.repo_path)

    foreach ($field in @("allowed_reads", "allowed_writes", "forbidden_reads", "forbidden_writes", "expected_artifacts")) {
        $values = @(ConvertTo-TsfKernelArray -Value $Mission.$field)
        if ($field -eq "allowed_reads" -and $values.Count -eq 0) {
            $checks.Add((New-TsfKernelCheck -Name "scope.$field.nonempty" -Status "FAIL" -Message "$field must not be empty.")) | Out-Null
            continue
        }

        foreach ($value in $values) {
            if (!(Test-TsfKernelPathTokenSafe -Path ([string]$value))) {
                $checks.Add((New-TsfKernelCheck -Name "scope.$field.safe_token" -Status "FAIL" -Message "Unsafe or broad path token found." -Evidence ([string]$value))) | Out-Null
                continue
            }

            $resolved = Get-TsfKernelFullPath -Path ([string]$value) -BasePath $repoPath
            $mustStayInsideRepo = ($field -in @("allowed_reads", "allowed_writes", "expected_artifacts"))
            if ($mustStayInsideRepo -and !(Test-TsfKernelPathInside -ChildPath $resolved -ParentPath $repoPath)) {
                $checks.Add((New-TsfKernelCheck -Name "scope.$field.inside_repo" -Status "FAIL" -Message "Path must stay inside mission repo_path for V1." -Evidence $resolved)) | Out-Null
            } else {
                $message = if ($mustStayInsideRepo) { "Path stays inside mission repo_path." } else { "Forbidden path token is explicit and machine-checkable." }
                $checks.Add((New-TsfKernelCheck -Name "scope.$field.safe_scope" -Status "PASS" -Message $message -Evidence $resolved)) | Out-Null
            }
        }
    }

    return @($checks)
}

function Test-TsfKernelActionCoverage {
    param([Parameter(Mandatory = $true)][object]$Mission)

    $checks = [System.Collections.Generic.List[object]]::new()
    $forbidden = @(ConvertTo-TsfKernelArray -Value $Mission.forbidden_actions | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
    $requirements = @(Get-TsfKernelApprovalRequirements -Mission $Mission | ForEach-Object { ([string]$_.exact_action).Trim().ToLowerInvariant() })

    if ($forbidden.Count -eq 0) {
        $checks.Add((New-TsfKernelCheck -Name "actions.forbidden_actions.nonempty" -Status "FAIL" -Message "forbidden_actions must explicitly list blocked actions.")) | Out-Null
    }

    foreach ($action in $script:TsfKernelRestrictedActions) {
        if (($forbidden -contains $action) -or ($requirements -contains $action)) {
            $checks.Add((New-TsfKernelCheck -Name "actions.$action.covered" -Status "PASS" -Message "Restricted action is explicitly forbidden or approval-gated.")) | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "actions.$action.covered" -Status "FAIL" -Message "Restricted action must be explicitly forbidden or approval-gated.")) | Out-Null
        }
    }

    return @($checks)
}

function Test-TsfKernelStopConditions {
    param([Parameter(Mandatory = $true)][object]$Mission)

    $checks = [System.Collections.Generic.List[object]]::new()
    $conditions = @(ConvertTo-TsfKernelArray -Value $Mission.stop_conditions)
    $allowedCheckTypes = @("manual", "path_absent", "approval_required", "forbidden_action_absent", "artifact_exists", "git_status_captured")

    foreach ($condition in $conditions) {
        $properties = @($condition.PSObject.Properties.Name)
        if (($properties -contains "id") -and ($properties -contains "check_type") -and ($allowedCheckTypes -contains [string]$condition.check_type)) {
            $checks.Add((New-TsfKernelCheck -Name "stop_conditions.machine_checkable" -Status "PASS" -Message "Stop condition has an allowed check_type." -Evidence ([string]$condition.id))) | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "stop_conditions.machine_checkable" -Status "FAIL" -Message "Stop condition must include id and an allowed check_type.")) | Out-Null
        }
    }

    return @($checks)
}

function Initialize-TsfKernelMissionFolders {
    param([string]$StateRoot = "")

    if ([string]::IsNullOrWhiteSpace($StateRoot)) {
        $StateRoot = Join-Path (Get-TsfKernelRoot) "fleet\missions"
    }

    foreach ($state in $script:TsfKernelMissionStates) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StateRoot $state) | Out-Null
    }

    return $StateRoot
}

function Copy-TsfKernelMissionToState {
    param(
        [Parameter(Mandatory = $true)][string]$MissionPath,
        [Parameter(Mandatory = $true)][string]$MissionId,
        [string]$StateRoot = "",
        [Parameter(Mandatory = $true)][string]$State
    )

    if ([string]::IsNullOrWhiteSpace($StateRoot)) {
        $StateRoot = Join-Path (Get-TsfKernelRoot) "fleet\missions"
    }

    if ($script:TsfKernelMissionStates -notcontains $State) {
        throw "Unknown TSF mission state: $State"
    }

    Initialize-TsfKernelMissionFolders -StateRoot $StateRoot | Out-Null
    $safeMissionId = ([string]$MissionId) -replace "[^A-Za-z0-9._:-]", "_"
    $destination = Join-Path (Join-Path $StateRoot $State) "$safeMissionId.json"
    Copy-Item -LiteralPath $MissionPath -Destination $destination -Force
    return $destination
}

function Invoke-TsfKernelPreflight {
    param(
        [Parameter(Mandatory = $true)][string]$MissionPath,
        [string]$ApprovalLedgerPath = "",
        [string]$OutFile = "",
        [string]$StateRoot = "",
        [switch]$AllowFixtureApprovalsForTests
    )

    $fleetRoot = Get-TsfKernelRoot
    $checks = [System.Collections.Generic.List[object]]::new()
    $blockedReasons = [System.Collections.Generic.List[string]]::new()
    $timRequiredReasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $mission = $null

    try {
        $mission = Read-TsfKernelJson -Path $MissionPath
        foreach ($check in (Test-TsfKernelMissionShape -Mission $mission)) {
            $checks.Add($check) | Out-Null
            if ($check.status -eq "FAIL") { $blockedReasons.Add($check.message) | Out-Null }
        }
    } catch {
        $checks.Add((New-TsfKernelCheck -Name "schema.json_parse" -Status "FAIL" -Message $_.Exception.Message)) | Out-Null
        $blockedReasons.Add("Mission packet could not be parsed.") | Out-Null
    }

    if ($null -ne $mission -and ![string]::IsNullOrWhiteSpace([string]$mission.mission_id)) {
        Copy-TsfKernelMissionToState -MissionPath $MissionPath -MissionId ([string]$mission.mission_id) -StateRoot $StateRoot -State "preflight-pending" | Out-Null
    }

    $gitState = $null
    $projectRegistration = $null
    $approvalMatches = @()

    if ($null -ne $mission -and $blockedReasons.Count -eq 0) {
        $repoPath = Get-TsfKernelFullPath -Path ([string]$mission.repo_path)
        if (Test-Path -LiteralPath $repoPath -PathType Container) {
            $checks.Add((New-TsfKernelCheck -Name "repo.exists" -Status "PASS" -Message "Mission repo_path exists." -Evidence $repoPath)) | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "repo.exists" -Status "FAIL" -Message "Mission repo_path does not exist." -Evidence $repoPath)) | Out-Null
            $blockedReasons.Add("Mission repo_path does not exist.") | Out-Null
        }

        foreach ($check in (Test-TsfKernelPathScope -Mission $mission)) {
            $checks.Add($check) | Out-Null
            if ($check.status -eq "FAIL") { $blockedReasons.Add($check.message) | Out-Null }
        }

        foreach ($check in (Test-TsfKernelActionCoverage -Mission $mission)) {
            $checks.Add($check) | Out-Null
            if ($check.status -eq "FAIL") { $blockedReasons.Add($check.message) | Out-Null }
        }

        foreach ($check in (Test-TsfKernelStopConditions -Mission $mission)) {
            $checks.Add($check) | Out-Null
            if ($check.status -eq "FAIL") { $blockedReasons.Add($check.message) | Out-Null }
        }

        if (Test-Path -LiteralPath $repoPath -PathType Container) {
            $gitState = Get-TsfKernelGitState -RepoPath $repoPath
            if ($gitState.can_capture) {
                $status = if ($gitState.dirty) { "WARN" } else { "PASS" }
                $message = if ($gitState.dirty) { "Git status captured; worktree is dirty and must be considered by worker." } else { "Git branch, HEAD, and status captured." }
                if ($gitState.dirty) { $warnings.Add("Mission repo worktree is dirty.") | Out-Null }
                $checks.Add((New-TsfKernelCheck -Name "git.status.capture" -Status $status -Message $message -Evidence ([string]$gitState.branch))) | Out-Null
            } else {
                $checks.Add((New-TsfKernelCheck -Name "git.status.capture" -Status "FAIL" -Message "Git status could not be captured safely." -Evidence ([string]$gitState.error))) | Out-Null
                $blockedReasons.Add("Git status could not be captured safely.") | Out-Null
            }
        }

        $projectRegistration = Get-TsfKernelProjectRegistration -Mission $mission -FleetRoot $fleetRoot
        if ($projectRegistration.registered) {
            $checks.Add((New-TsfKernelCheck -Name "project.registration" -Status "PASS" -Message ([string]$projectRegistration.status) -Evidence ([string]$projectRegistration.evidence))) | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "project.registration" -Status "FAIL" -Message ([string]$projectRegistration.status) -Evidence ([string]$projectRegistration.evidence))) | Out-Null
            $blockedReasons.Add("Project is not registered and is not TSF control-plane internal.") | Out-Null
        }

        $ledger = Get-TsfKernelApprovalLedger -ApprovalLedgerPath $ApprovalLedgerPath
        $approvalMatches = @(Find-TsfKernelApprovalMatches -Mission $mission -Ledger $ledger -LedgerPath $ApprovalLedgerPath -AllowFixtureApprovalsForTests:$AllowFixtureApprovalsForTests)
        foreach ($match in $approvalMatches) {
            if ($match.satisfied) {
                $checks.Add((New-TsfKernelCheck -Name "approval.$($match.exact_action)" -Status "PASS" -Message ([string]$match.match_status) -Evidence ([string]$match.approval_id))) | Out-Null
            } else {
                $checks.Add((New-TsfKernelCheck -Name "approval.$($match.exact_action)" -Status "TIM_REQUIRED" -Message ([string]$match.match_status) -Evidence ([string]$match.approval_id))) | Out-Null
                $timRequiredReasons.Add("Missing active approval for exact action: $($match.exact_action)") | Out-Null
            }
        }
    }

    $verdict = "GREEN"
    $preflightApproved = $true
    if ($blockedReasons.Count -gt 0) {
        $verdict = "RED"
        $preflightApproved = $false
    } elseif ($timRequiredReasons.Count -gt 0) {
        $verdict = "TIM_REQUIRED"
        $preflightApproved = $false
    } elseif ($warnings.Count -gt 0) {
        $verdict = "YELLOW"
    }

    if ($null -ne $mission -and ![string]::IsNullOrWhiteSpace([string]$mission.mission_id)) {
        $nextState = if ($preflightApproved) { "approved-for-worker" } else { "blocked-tim-required" }
        Copy-TsfKernelMissionToState -MissionPath $MissionPath -MissionId ([string]$mission.mission_id) -StateRoot $StateRoot -State $nextState | Out-Null
    }

    $result = [pscustomobject]@{
        schema_version = 1
        generated_at = (Get-Date).ToString("o")
        mission_path = (Get-TsfKernelFullPath -Path $MissionPath)
        mission_id = if ($null -ne $mission) { [string]$mission.mission_id } else { "" }
        verdict = $verdict
        preflight_approved = $preflightApproved
        checks = @($checks)
        blocked_reasons = @($blockedReasons)
        tim_required_reasons = @($timRequiredReasons)
        warnings = @($warnings)
        approval_matches = @($approvalMatches)
        git_state = $gitState
        project_registration = $projectRegistration
        background_runner_started = $false
        all_fleet_started = $false
        product_repos_mutated = $false
        canonical_nwr_mutated = $false
        push_merge_deploy_attempted = $false
    }

    if (![string]::IsNullOrWhiteSpace($OutFile)) {
        Write-TsfKernelJson -Value $result -Path $OutFile
    }

    return $result
}

function New-TsfKernelWorkerInstruction {
    param(
        [Parameter(Mandatory = $true)][string]$MissionPath,
        [Parameter(Mandatory = $true)][string]$PreflightResultPath,
        [string]$OutFile = "",
        [string]$StateRoot = ""
    )

    $mission = Read-TsfKernelJson -Path $MissionPath
    $preflight = Read-TsfKernelJson -Path $PreflightResultPath
    $approved = [bool]$preflight.preflight_approved

    if (!$approved) {
        $result = [pscustomobject]@{
            schema_version = 1
            generated_at = (Get-Date).ToString("o")
            mission_id = [string]$mission.mission_id
            adapter_status = "REFUSED_PREFLIGHT_FAILED"
            codex_cli_invocation_started = $false
            background_runner_started = $false
            all_fleet_started = $false
            product_repos_mutated = $false
            intended_command = ""
            worker_instruction = "Preflight did not approve this mission. Do not invoke a worker."
            handoff_packet = $null
        }
        if (![string]::IsNullOrWhiteSpace($OutFile)) { Write-TsfKernelJson -Value $result -Path $OutFile }
        return $result
    }

    Copy-TsfKernelMissionToState -MissionPath $MissionPath -MissionId ([string]$mission.mission_id) -StateRoot $StateRoot -State "running" | Out-Null

    $handoff = [pscustomobject]@{
        mission_id = [string]$mission.mission_id
        project_id = [string]$mission.project_id
        repo_path = [string]$mission.repo_path
        lane = [string]$mission.lane
        mission_type = [string]$mission.mission_type
        allowed_reads = @(ConvertTo-TsfKernelArray -Value $mission.allowed_reads)
        allowed_writes = @(ConvertTo-TsfKernelArray -Value $mission.allowed_writes)
        forbidden_reads = @(ConvertTo-TsfKernelArray -Value $mission.forbidden_reads)
        forbidden_writes = @(ConvertTo-TsfKernelArray -Value $mission.forbidden_writes)
        forbidden_actions = @(ConvertTo-TsfKernelArray -Value $mission.forbidden_actions)
        expected_artifacts = @(ConvertTo-TsfKernelArray -Value $mission.expected_artifacts)
        stop_conditions = @(ConvertTo-TsfKernelArray -Value $mission.stop_conditions)
        required_postrun_checks = @(ConvertTo-TsfKernelArray -Value $mission.required_postrun_checks)
    }

    $allowedReadSummary = (@(ConvertTo-TsfKernelArray -Value $mission.allowed_reads) -join "; ")
    $allowedWriteSummary = (@(ConvertTo-TsfKernelArray -Value $mission.allowed_writes) -join "; ")
    $forbiddenActionSummary = (@(ConvertTo-TsfKernelArray -Value $mission.forbidden_actions) -join "; ")
    $expectedArtifactSummary = (@(ConvertTo-TsfKernelArray -Value $mission.expected_artifacts) -join "; ")
    $postrunVerifierInstruction = "After foreground worker output exists, run: powershell -NoProfile -ExecutionPolicy Bypass -File .\tsf-kernel-postrun-verify.ps1 -MissionPath <mission.json> -WorkerResultPath <worker-result.json> -OutFile <verifier-result.json>"
    $commandPreview = "NOT RUN IN V1: codex exec --cd `"$([string]$mission.repo_path)`" < worker_instruction_packet.md"

    $result = [pscustomobject]@{
        schema_version = 1
        generated_at = (Get-Date).ToString("o")
        mission_id = [string]$mission.mission_id
        adapter_status = "STUB_READY_CODEX_CLI_BLOCKED"
        codex_cli_invocation_started = $false
        background_runner_started = $false
        all_fleet_started = $false
        product_repos_mutated = $false
        intended_command = "Manual foreground Codex worker handoff only. Direct Codex CLI invocation is intentionally blocked in V1."
        command_preview = $commandPreview
        allowed_scope_summary = [pscustomobject]@{
            allowed_reads = $allowedReadSummary
            allowed_writes = $allowedWriteSummary
        }
        forbidden_action_summary = $forbiddenActionSummary
        expected_artifact_contract = $expectedArtifactSummary
        postrun_verifier_instruction = $postrunVerifierInstruction
        worker_instruction = "Use only the mission packet scope. Do not run background, all-fleet, product repo mutation, push, merge, deploy, install, migration, secrets, PrivateLens, canonical NWR, or normal NWR packet work."
        handoff_packet = $handoff
    }

    if (![string]::IsNullOrWhiteSpace($OutFile)) {
        Write-TsfKernelJson -Value $result -Path $OutFile
    }

    return $result
}

function Invoke-TsfKernelPostRunVerify {
    param(
        [Parameter(Mandatory = $true)][string]$MissionPath,
        [Parameter(Mandatory = $true)][string]$WorkerResultPath,
        [string]$OutFile = "",
        [string]$StateRoot = ""
    )

    $mission = Read-TsfKernelJson -Path $MissionPath
    $worker = Read-TsfKernelJson -Path $WorkerResultPath
    $repoPath = Get-TsfKernelFullPath -Path ([string]$mission.repo_path)
    $checks = [System.Collections.Generic.List[object]]::new()
    $blockedReasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $expectedArtifacts = @(ConvertTo-TsfKernelArray -Value $mission.expected_artifacts)

    if ([string]$worker.mission_id -eq [string]$mission.mission_id) {
        $checks.Add((New-TsfKernelCheck -Name "postrun.mission_id" -Status "PASS" -Message "Worker result mission_id matches mission packet.")) | Out-Null
    } else {
        $checks.Add((New-TsfKernelCheck -Name "postrun.mission_id" -Status "FAIL" -Message "Worker result mission_id does not match mission packet.")) | Out-Null
        $blockedReasons.Add("Worker result mission_id mismatch.") | Out-Null
    }

    foreach ($artifact in $expectedArtifacts) {
        $artifactPath = Get-TsfKernelFullPath -Path ([string]$artifact) -BasePath $repoPath
        if (Test-Path -LiteralPath $artifactPath) {
            $checks.Add((New-TsfKernelCheck -Name "postrun.artifact.exists" -Status "PASS" -Message "Expected artifact exists." -Evidence $artifactPath)) | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "postrun.artifact.exists" -Status "FAIL" -Message "Expected artifact is missing." -Evidence $artifactPath)) | Out-Null
            $blockedReasons.Add("Expected artifact missing: $artifact") | Out-Null
        }
    }

    if ($worker.PSObject.Properties.Name -contains "files_created") {
        $createdArtifacts = @(ConvertTo-TsfKernelArray -Value $worker.files_created | ForEach-Object { ([string]$_).Replace("\", "/").Trim() })
        foreach ($artifact in $expectedArtifacts) {
            $normalizedArtifact = ([string]$artifact).Replace("\", "/").Trim()
            if ($createdArtifacts -contains $normalizedArtifact) {
                $checks.Add((New-TsfKernelCheck -Name "postrun.expected_artifact_claimed" -Status "PASS" -Message "Worker result claims expected artifact." -Evidence $normalizedArtifact)) | Out-Null
            } else {
                $checks.Add((New-TsfKernelCheck -Name "postrun.expected_artifact_claimed" -Status "FAIL" -Message "Worker result does not claim expected artifact in files_created." -Evidence $normalizedArtifact)) | Out-Null
                $blockedReasons.Add("Worker result did not claim expected artifact: $artifact") | Out-Null
            }
        }
    } else {
        $checks.Add((New-TsfKernelCheck -Name "postrun.files_created" -Status "FAIL" -Message "Worker result must include files_created evidence.")) | Out-Null
        $blockedReasons.Add("Worker result missing files_created evidence.") | Out-Null
    }

    $attemptedRestrictedActions = @()
    if ($worker.PSObject.Properties.Name -contains "restricted_actions_attempted") {
        $attemptedRestrictedActions = @(ConvertTo-TsfKernelArray -Value $worker.restricted_actions_attempted)
    } else {
        $checks.Add((New-TsfKernelCheck -Name "postrun.restricted_actions_evidence" -Status "FAIL" -Message "Worker result must include restricted_actions_attempted evidence.")) | Out-Null
        $blockedReasons.Add("Worker result missing restricted_actions_attempted evidence.") | Out-Null
    }

    if ($attemptedRestrictedActions.Count -eq 0) {
        $checks.Add((New-TsfKernelCheck -Name "postrun.restricted_actions" -Status "PASS" -Message "No restricted actions attempted in worker result evidence.")) | Out-Null
    } else {
        $checks.Add((New-TsfKernelCheck -Name "postrun.restricted_actions" -Status "FAIL" -Message "Restricted actions were attempted." -Evidence ($attemptedRestrictedActions -join ","))) | Out-Null
        $blockedReasons.Add("Restricted actions attempted: $($attemptedRestrictedActions -join ', ')") | Out-Null
    }

    if ($worker.PSObject.Properties.Name -contains "files_touched") {
        $filesTouched = @(ConvertTo-TsfKernelArray -Value $worker.files_touched)
        foreach ($file in $filesTouched) {
            $filePath = Get-TsfKernelFullPath -Path ([string]$file) -BasePath $repoPath
            foreach ($forbidden in @(ConvertTo-TsfKernelArray -Value $mission.forbidden_writes)) {
                $forbiddenPath = Get-TsfKernelFullPath -Path ([string]$forbidden) -BasePath $repoPath
                if (Test-TsfKernelPathInside -ChildPath $filePath -ParentPath $forbiddenPath) {
                    $checks.Add((New-TsfKernelCheck -Name "postrun.forbidden_write" -Status "FAIL" -Message "Worker touched a forbidden output path." -Evidence $filePath)) | Out-Null
                    $blockedReasons.Add("Forbidden output path touched: $file") | Out-Null
                }
            }
        }

        if ($filesTouched.Count -eq 0) {
            $checks.Add((New-TsfKernelCheck -Name "postrun.files_touched" -Status "WARN" -Message "Worker reported no touched files.")) | Out-Null
            $warnings.Add("Worker reported no touched files.") | Out-Null
        } else {
            $checks.Add((New-TsfKernelCheck -Name "postrun.files_touched" -Status "PASS" -Message "Worker provided touched-file evidence.")) | Out-Null
        }
    } else {
        $checks.Add((New-TsfKernelCheck -Name "postrun.files_touched" -Status "WARN" -Message "Worker result did not include touched-file evidence.")) | Out-Null
        $warnings.Add("Worker result did not include touched-file evidence.") | Out-Null
    }

    $verdict = "GREEN"
    $verified = $true
    if ($blockedReasons.Count -gt 0) {
        $verdict = "RED"
        $verified = $false
    } elseif ($warnings.Count -gt 0) {
        $verdict = "YELLOW"
    }

    $finalState = if ($verdict -eq "GREEN") {
        "complete_green"
    } elseif ($verdict -eq "YELLOW") {
        "complete_yellow"
    } elseif ($verdict -eq "TIM_REQUIRED") {
        "blocked_tim_required"
    } else {
        "blocked_red"
    }

    Copy-TsfKernelMissionToState -MissionPath $MissionPath -MissionId ([string]$mission.mission_id) -StateRoot $StateRoot -State "postrun-pending" | Out-Null
    if ($verified) {
        Copy-TsfKernelMissionToState -MissionPath $MissionPath -MissionId ([string]$mission.mission_id) -StateRoot $StateRoot -State "completed" | Out-Null
    } else {
        Copy-TsfKernelMissionToState -MissionPath $MissionPath -MissionId ([string]$mission.mission_id) -StateRoot $StateRoot -State "blocked-tim-required" | Out-Null
    }

    $result = [pscustomobject]@{
        schema_version = 1
        generated_at = (Get-Date).ToString("o")
        mission_id = [string]$mission.mission_id
        verdict = $verdict
        final_state = $finalState
        verified = $verified
        checks = @($checks)
        blocked_reasons = @($blockedReasons)
        warnings = @($warnings)
        background_runner_started = $false
        all_fleet_started = $false
        product_repos_mutated = $false
        canonical_nwr_mutated = $false
        push_merge_deploy_attempted = $false
    }

    if (![string]::IsNullOrWhiteSpace($OutFile)) {
        Write-TsfKernelJson -Value $result -Path $OutFile
    }

    return $result
}

function Write-TsfKernelPreservationPacket {
    param(
        [Parameter(Mandatory = $true)][string]$MissionPath,
        [Parameter(Mandatory = $true)][string]$PreflightResultPath,
        [string]$WorkerResultPath = "",
        [string]$VerifierResultPath = "",
        [string]$OutputDirectory = "",
        [string]$ExactNextAction = "Review preservation packet and continue only through a new TSF mission packet."
    )

    $mission = Read-TsfKernelJson -Path $MissionPath
    $preflight = Read-TsfKernelJson -Path $PreflightResultPath
    $verifier = $null
    if (![string]::IsNullOrWhiteSpace($VerifierResultPath) -and (Test-Path -LiteralPath $VerifierResultPath)) {
        $verifier = Read-TsfKernelJson -Path $VerifierResultPath
    }

    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path (Get-TsfKernelRoot) "fleet\missions\completed"
    }

    $safeMissionId = ([string]$mission.mission_id) -replace "[^A-Za-z0-9._:-]", "_"
    $packetDirectory = Join-Path $OutputDirectory ("$safeMissionId-preservation")
    New-Item -ItemType Directory -Force -Path $packetDirectory | Out-Null

    $manifest = [System.Collections.Generic.List[object]]::new()
    $sources = [ordered]@{
        "mission_packet.json" = $MissionPath
        "preflight_result.json" = $PreflightResultPath
    }
    if (![string]::IsNullOrWhiteSpace($WorkerResultPath) -and (Test-Path -LiteralPath $WorkerResultPath)) {
        $sources["worker_result_or_instruction.json"] = $WorkerResultPath
    }
    if (![string]::IsNullOrWhiteSpace($VerifierResultPath) -and (Test-Path -LiteralPath $VerifierResultPath)) {
        $sources["verifier_result.json"] = $VerifierResultPath
    }

    foreach ($name in $sources.Keys) {
        $destination = Join-Path $packetDirectory $name
        Copy-Item -LiteralPath $sources[$name] -Destination $destination -Force
        $manifest.Add([pscustomobject]@{
            artifact = $name
            source = Get-TsfKernelFullPath -Path $sources[$name]
            preserved_path = $destination
        }) | Out-Null
    }

    $finalDecision = if ($null -ne $verifier) { [string]$verifier.verdict } else { [string]$preflight.verdict }
    $packet = [pscustomobject]@{
        schema_version = 1
        generated_at = (Get-Date).ToString("o")
        mission_id = [string]$mission.mission_id
        final_decision = $finalDecision
        mission_packet = "mission_packet.json"
        preflight_result = "preflight_result.json"
        worker_result_or_instruction = if ($sources.Contains("worker_result_or_instruction.json")) { "worker_result_or_instruction.json" } else { "" }
        verifier_result = if ($sources.Contains("verifier_result.json")) { "verifier_result.json" } else { "" }
        expected_artifacts = @(ConvertTo-TsfKernelArray -Value $mission.expected_artifacts)
        stop_conditions = @(ConvertTo-TsfKernelArray -Value $mission.stop_conditions)
        exact_next_action = $ExactNextAction
        restricted_action_confirmation = [pscustomobject]@{
            background_runner_started = $false
            all_fleet_started = $false
            product_repos_mutated = $false
            canonical_nwr_mutated = $false
            push_merge_deploy_attempted = $false
        }
    }

    Write-TsfKernelJson -Value $packet -Path (Join-Path $packetDirectory "preservation_packet.json")
    $manifest | Export-Csv -LiteralPath (Join-Path $packetDirectory "manifest.csv") -NoTypeInformation
    Set-Content -LiteralPath (Join-Path $packetDirectory "NEXT_ACTION.md") -Encoding UTF8 -Value @(
        "# Next Action",
        "",
        $ExactNextAction
    )

    return [pscustomobject]@{
        schema_version = 1
        generated_at = (Get-Date).ToString("o")
        mission_id = [string]$mission.mission_id
        packet_directory = $packetDirectory
        final_decision = $finalDecision
        artifacts_preserved = @($manifest)
    }
}
