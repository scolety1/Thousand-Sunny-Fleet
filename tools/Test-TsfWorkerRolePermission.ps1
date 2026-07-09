param(
    [Parameter(Mandatory = $true)]
    [string]$MissionDraftPath,

    [string]$RegistryPath = "fleet/control/worker-role-registry.v1.json",
    [string]$PermissionProfilesPath = "fleet/control/worker-permission-profiles.v1.json",
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

function Read-TsfRoleJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing JSON file: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Add-TsfRoleCheck {
    param(
        [System.Collections.ArrayList]$Checks,
        [string]$Name,
        [string]$Status,
        [string]$Message,
        [string]$Evidence = ""
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        status = $Status
        message = $Message
        evidence = $Evidence
    }) | Out-Null
}

function Get-TsfRoleArray {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value | ForEach-Object { [string]$_ } | Where-Object { $_ }) }
    return @([string]$Value)
}

function Get-TsfRoleFullPath {
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

function Test-TsfRolePathInside {
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
    return $child.StartsWith(($parentTrimmed + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-TsfRolePathTokenSafe {
    param([string]$Path)
    $value = ([string]$Path).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    if ($value -in @("*", ".", "\", "/", "all", "ALL")) { return $false }
    if ($value -match "(^|[\\/])\.\.([\\/]|$)") { return $false }
    if ($value -match "[\x00-\x1F\x7F]") { return $false }
    return $true
}

$draft = Read-TsfRoleJson -Path $MissionDraftPath
$registry = Read-TsfRoleJson -Path $RegistryPath
$profiles = Read-TsfRoleJson -Path $PermissionProfilesPath
$checks = New-Object System.Collections.ArrayList
$blockedReasons = New-Object System.Collections.ArrayList
$timRequiredReasons = New-Object System.Collections.ArrayList

$mission = if ($null -ne $draft.mission_packet) { $draft.mission_packet } else { $draft }
$extension = $draft.role_extension
$roleId = ""
if ($null -ne $extension -and ![string]::IsNullOrWhiteSpace([string]$extension.worker_role)) {
    $roleId = [string]$extension.worker_role
} elseif ($null -ne $draft.worker_role) {
    $roleId = [string]$draft.worker_role
}

if ([string]::IsNullOrWhiteSpace($roleId)) {
    Add-TsfRoleCheck -Checks $checks -Name "role.exists" -Status "FAIL" -Message "Mission draft does not name a worker role."
    $blockedReasons.Add("Missing worker role.") | Out-Null
} else {
    $role = @($registry.roles | Where-Object { [string]$_.role_id -eq $roleId }) | Select-Object -First 1
    if ($null -eq $role) {
        Add-TsfRoleCheck -Checks $checks -Name "role.exists" -Status "FAIL" -Message "Worker role is not registered." -Evidence $roleId
        $blockedReasons.Add("Unregistered worker role: $roleId") | Out-Null
    } else {
        Add-TsfRoleCheck -Checks $checks -Name "role.exists" -Status "PASS" -Message "Worker role is registered." -Evidence $roleId
    }
}

$profile = $null
if (![string]::IsNullOrWhiteSpace($roleId) -and $null -ne $profiles.profiles.PSObject.Properties[$roleId]) {
    $profile = $profiles.profiles.PSObject.Properties[$roleId].Value
    Add-TsfRoleCheck -Checks $checks -Name "profile.exists" -Status "PASS" -Message "Role permission profile exists." -Evidence $roleId
} else {
    Add-TsfRoleCheck -Checks $checks -Name "profile.exists" -Status "FAIL" -Message "Role permission profile is missing." -Evidence $roleId
    $blockedReasons.Add("Missing role permission profile: $roleId") | Out-Null
}

if ($null -ne $extension -and ![string]::IsNullOrWhiteSpace([string]$extension.role_permission_profile_id)) {
    if ([string]$extension.role_permission_profile_id -eq $roleId) {
        Add-TsfRoleCheck -Checks $checks -Name "profile.id_matches_role" -Status "PASS" -Message "Role permission profile id matches worker role." -Evidence $roleId
    } else {
        Add-TsfRoleCheck -Checks $checks -Name "profile.id_matches_role" -Status "FAIL" -Message "Role permission profile id does not match worker role." -Evidence "role=$roleId; profile=$($extension.role_permission_profile_id)"
        $blockedReasons.Add("Role permission profile id mismatch.") | Out-Null
    }
}

$missionForbidden = @(Get-TsfRoleArray $mission.forbidden_actions | ForEach-Object { $_.ToLowerInvariant() })
$restricted = @(Get-TsfRoleArray $profiles.restricted_actions | ForEach-Object { $_.ToLowerInvariant() })
$missingForbidden = @($restricted | Where-Object { $missionForbidden -notcontains $_ })
if ($missingForbidden.Count -eq 0) {
    Add-TsfRoleCheck -Checks $checks -Name "forbidden_actions.present" -Status "PASS" -Message "Mission carries the default restricted-action fence."
} else {
    Add-TsfRoleCheck -Checks $checks -Name "forbidden_actions.present" -Status "FAIL" -Message "Mission is missing restricted-action forbidden entries." -Evidence ($missingForbidden -join ";")
    $blockedReasons.Add("Missing forbidden action fence entries: $($missingForbidden -join ', ')") | Out-Null
}

$protectedNeedles = @("C:\NWR\Niners-War-Room", "normal NWR", "PrivateLens", "product repo")
$requestedPaths = @((Get-TsfRoleArray $mission.allowed_reads) + (Get-TsfRoleArray $mission.allowed_writes))
foreach ($path in $requestedPaths) {
    foreach ($needle in $protectedNeedles) {
        if ($path -match [regex]::Escape($needle)) {
            Add-TsfRoleCheck -Checks $checks -Name "protected_path.blocked" -Status "FAIL" -Message "Mission requests protected path or lane." -Evidence $path
            $timRequiredReasons.Add("Protected path or lane requested: $path") | Out-Null
        }
    }
}
if (($checks | Where-Object { $_.name -eq "protected_path.blocked" -and $_.status -eq "FAIL" }).Count -eq 0) {
    Add-TsfRoleCheck -Checks $checks -Name "protected_path.blocked" -Status "PASS" -Message "No protected path or lane requested."
}

$repoPath = ""
if ($mission.PSObject.Properties.Name -contains "repo_path" -and ![string]::IsNullOrWhiteSpace([string]$mission.repo_path)) {
    $repoPath = Get-TsfRoleFullPath -Path ([string]$mission.repo_path)
} else {
    $repoPath = Get-TsfRoleFullPath -Path (Join-Path $PSScriptRoot "..")
}

foreach ($path in $requestedPaths) {
    if (!(Test-TsfRolePathTokenSafe -Path $path)) {
        Add-TsfRoleCheck -Checks $checks -Name "path.token_safe" -Status "FAIL" -Message "Requested path is unsafe or too broad." -Evidence $path
        $blockedReasons.Add("Unsafe or broad requested path: $path") | Out-Null
        continue
    }

    if ([System.IO.Path]::IsPathRooted([string]$path)) {
        $resolved = Get-TsfRoleFullPath -Path ([string]$path)
        if (!(Test-TsfRolePathInside -ChildPath $resolved -ParentPath $repoPath)) {
            Add-TsfRoleCheck -Checks $checks -Name "path.inside_repo" -Status "FAIL" -Message "Absolute requested path is outside mission repo." -Evidence $resolved
            $timRequiredReasons.Add("Requested path outside mission repo: $resolved") | Out-Null
        }
    }
}
if (($checks | Where-Object { $_.name -eq "path.token_safe" -and $_.status -eq "FAIL" }).Count -eq 0) {
    Add-TsfRoleCheck -Checks $checks -Name "path.token_safe" -Status "PASS" -Message "Requested read/write path tokens are bounded."
}
if (($checks | Where-Object { $_.name -eq "path.inside_repo" -and $_.status -eq "FAIL" }).Count -eq 0) {
    Add-TsfRoleCheck -Checks $checks -Name "path.inside_repo" -Status "PASS" -Message "No absolute requested path escapes the mission repo."
}

if ($null -ne $profile) {
    if ([bool]$profile.may_invoke_codex_cli) {
        Add-TsfRoleCheck -Checks $checks -Name "codex_cli.blocked_by_default" -Status "WARN" -Message "Role profile allows Codex CLI; separate approval is still required."
    } else {
        Add-TsfRoleCheck -Checks $checks -Name "codex_cli.blocked_by_default" -Status "PASS" -Message "Role profile blocks Codex CLI invocation."
    }
    if ([bool]$profile.may_use_api) {
        Add-TsfRoleCheck -Checks $checks -Name "api.blocked_by_default" -Status "WARN" -Message "Role profile allows API; separate approval is still required."
    } else {
        Add-TsfRoleCheck -Checks $checks -Name "api.blocked_by_default" -Status "PASS" -Message "Role profile blocks API usage."
    }
    if ([bool]$profile.may_touch_product_repo) {
        Add-TsfRoleCheck -Checks $checks -Name "product_repo.blocked_by_default" -Status "WARN" -Message "Role profile allows product repo access; exact approval is still required."
    } else {
        Add-TsfRoleCheck -Checks $checks -Name "product_repo.blocked_by_default" -Status "PASS" -Message "Role profile blocks product repo access."
    }
    if ($null -ne $extension -and @($extension.sibling_lane_ids).Count -gt 0 -and -not [bool]$profile.may_spawn_workers) {
        Add-TsfRoleCheck -Checks $checks -Name "spawn_workers.allowed" -Status "FAIL" -Message "Role cannot spawn or coordinate sibling workers." -Evidence $roleId
        $blockedReasons.Add("Role cannot spawn or coordinate sibling workers: $roleId") | Out-Null
    } else {
        Add-TsfRoleCheck -Checks $checks -Name "spawn_workers.allowed" -Status "PASS" -Message "Sibling lane/spawn request does not exceed role profile."
    }

    $requestedForbidden = @($missionForbidden | ForEach-Object { $_.Trim().ToLowerInvariant() })
    $profileMandatory = @(Get-TsfRoleArray $profile.mandatory_forbidden_actions | ForEach-Object { $_.Trim().ToLowerInvariant() })
    $missingProfileFence = @()
    foreach ($action in $profileMandatory) {
        if ($action -match "^[a-z0-9_]+$" -and $restricted -contains $action -and $requestedForbidden -notcontains $action) {
            $missingProfileFence += $action
        }
    }
    if ($missingProfileFence.Count -gt 0) {
        Add-TsfRoleCheck -Checks $checks -Name "profile.forbidden_fence" -Status "FAIL" -Message "Mission does not carry all machine-readable forbidden actions required by the role profile." -Evidence ($missingProfileFence -join ";")
        $blockedReasons.Add("Missing role-profile forbidden action fence entries: $($missingProfileFence -join ', ')") | Out-Null
    } else {
        Add-TsfRoleCheck -Checks $checks -Name "profile.forbidden_fence" -Status "PASS" -Message "Mission carries the role profile forbidden-action fence."
    }
}

$approvalRequirements = @(Get-TsfRoleArray $mission.approval_requirements)
foreach ($approval in @($mission.approval_requirements)) {
    $action = [string]$approval.exact_action
    $required = $false
    if ($null -ne $approval.required) { $required = [bool]$approval.required }
    $approvalId = [string]$approval.approval_id
    if ($required -and [string]::IsNullOrWhiteSpace($approvalId)) {
        Add-TsfRoleCheck -Checks $checks -Name "approval.present" -Status "FAIL" -Message "Required approval is missing active approval id." -Evidence $action
        $timRequiredReasons.Add("Required approval missing for: $action") | Out-Null
    }
}
if (($checks | Where-Object { $_.name -eq "approval.present" }).Count -eq 0) {
    Add-TsfRoleCheck -Checks $checks -Name "approval.present" -Status "PASS" -Message "No missing role approval requirements detected."
}

$verdict = "GREEN"
if ($timRequiredReasons.Count -gt 0) {
    $verdict = "TIM_REQUIRED"
} elseif ($blockedReasons.Count -gt 0) {
    $verdict = "RED"
}

$result = [pscustomobject]@{
    schema_version = "worker_role_permission_preflight_v1"
    mission_draft_path = $MissionDraftPath
    role_id = $roleId
    verdict = $verdict
    role_preflight_approved = ($verdict -eq "GREEN")
    checks = @($checks)
    blocked_reasons = @($blockedReasons)
    tim_required_reasons = @($timRequiredReasons)
    codex_cli_invoked = $false
    api_called = $false
    product_repo_touched = $false
    canonical_nwr_mutated = $false
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$result
