[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$PolicyFile = "docs/codex/AUTOPILOT_POLICY.md",

    [string]$OutFile = "out\fleet-autopilot-policy.md",

    [string]$JsonOutFile = "out\fleet-autopilot-policy.json",

    [switch]$Template,

    [switch]$ValidateOnly,

    [switch]$IncludeDirty
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Ensure-OutputParent {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

function Get-ConfigPropertyValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-ProjectList {
    if (!(Test-Path $ConfigPath)) { Stop-WithMessage "Config not found: $ConfigPath" }
    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
        if ($projects.Count -ne 1) { Stop-WithMessage "Project not found: $Project" }
    }
    return $projects
}

function Test-ApprovedStatus {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $false }
    $text = Get-Content $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Get-PolicyValue {
    param([string]$Text, [string]$Name)
    $match = [regex]::Match($Text, "(?im)^\s*$([regex]::Escape($Name))\s*:\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-MarkdownListSection {
    param([string]$Text, [string]$Heading)

    $match = [regex]::Match($Text, "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n(?<body>.*?)(?=^##\s+|\z)")
    if (!$match.Success) { return @() }
    $body = $match.Groups["body"].Value
    return @($body -split "\r?\n" | Where-Object { $_ -match "^\s*-\s+(.+?)\s*$" } | ForEach-Object {
            ([regex]::Match($_, "^\s*-\s+(.+?)\s*$")).Groups[1].Value.Trim().ToLowerInvariant()
        })
}

function Get-InlinePolicyList {
    param([string]$Text, [string]$Name)

    $value = Get-PolicyValue -Text $Text -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }
    return @($value -split "," | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
}

function Test-PolicyTextContainsAny {
    param([string]$Text, [string[]]$Terms)

    foreach ($term in $Terms) {
        if ($Text -match [regex]::Escape($term)) { return $true }
    }
    return $false
}

function Write-AutopilotTemplates {
    foreach ($ship in Get-ProjectList) {
        $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
        $repoPath = Resolve-Path -LiteralPath $repo -ErrorAction SilentlyContinue
        if (!$repoPath) {
            Write-Host "Skipping missing repo: $repo" -ForegroundColor Yellow
            continue
        }
        Push-Location $repoPath.Path
        try {
            New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
            if (!(Test-Path $PolicyFile)) {
                Set-Content -Path $PolicyFile -Value @"
# Autopilot Policy

Status: DRAFT
Spending Limit: 0
Customer Data: no live customer data
Escalation: human review required for reputation, money, user trust, production deploys, auth, payments, secrets, migrations, legal text, mass email, data deletion

## Safe Automatic Lanes

- content typo fixes
- docs updates
- non-sensitive UI polish
- test-backed bug fixes
- staging report generation

## Human Approval Required

- pricing changes
- production deploys
- payment behavior
- auth or permission changes
- mass emails
- deletion of user data
- legal or compliance text
"@
            }
            if (!(Test-Path "docs/codex/AUTOPILOT_APPROVAL.md")) {
                Set-Content -Path "docs/codex/AUTOPILOT_APPROVAL.md" -Value @"
# Autopilot Approval

Status: DRAFT
Approved By:
Approved Lanes:
Notes:
"@
            }
        } finally {
            Pop-Location
        }
        Write-Host "Autopilot policy templates ready: $repo" -ForegroundColor Green
    }
}

function Get-AutopilotStatus {
    param([string]$Repo)

    $requiredSafeLanes = @(
        "content typo fixes",
        "docs updates",
        "non-sensitive ui polish",
        "test-backed bug fixes",
        "staging report generation"
    )
    $humanApprovalTerms = @("pricing", "production deploy", "payment", "auth", "permission", "mass email", "data deletion", "legal", "compliance", "customer data")

    Push-Location $Repo
    try {
        $policyExists = Test-Path $PolicyFile
        $approvalExists = Test-Path "docs/codex/AUTOPILOT_APPROVAL.md"
        if (!$policyExists) {
            return [pscustomobject]@{
                status = "missing"
                spendingLimit = "unknown"
                customerData = "unknown"
                escalation = "unknown"
                safeLanes = @()
                approvedLanes = @()
                reasons = @("Autopilot policy is missing.")
            }
        }

        $policyText = Get-Content $PolicyFile -Raw
        $approvalText = if ($approvalExists) { Get-Content "docs/codex/AUTOPILOT_APPROVAL.md" -Raw } else { "" }
        $spendingLimit = Get-PolicyValue -Text $policyText -Name "Spending Limit"
        $customerData = Get-PolicyValue -Text $policyText -Name "Customer Data"
        $escalation = Get-PolicyValue -Text $policyText -Name "Escalation"
        $safeLanes = @(Get-MarkdownListSection -Text $policyText -Heading "Safe Automatic Lanes")
        $approvedLanes = @(Get-InlinePolicyList -Text $approvalText -Name "Approved Lanes")
        $reasons = [System.Collections.Generic.List[string]]::new()

        if ([string]::IsNullOrWhiteSpace($spendingLimit)) { $reasons.Add("Spending limit is missing.") | Out-Null }
        elseif ($spendingLimit -notmatch "^\s*0\s*$") { $reasons.Add("Spending limit is not zero; human approval required before autopilot.") | Out-Null }

        if ([string]::IsNullOrWhiteSpace($customerData)) { $reasons.Add("Customer-data handling rule is missing.") | Out-Null }
        if ([string]::IsNullOrWhiteSpace($escalation)) { $reasons.Add("Escalation rule is missing.") | Out-Null }

        foreach ($lane in $requiredSafeLanes) {
            if ($safeLanes -notcontains $lane) {
                $reasons.Add("Safe automatic lane missing: $lane.") | Out-Null
            }
        }

        foreach ($lane in $safeLanes) {
            if (Test-PolicyTextContainsAny -Text $lane -Terms $humanApprovalTerms) {
                $reasons.Add("Safe lane mentions human-approval-only action: $lane.") | Out-Null
            }
        }

        foreach ($blockedTerm in @("pricing", "production deploy", "payment", "auth", "mass email", "data deletion", "legal")) {
            if ($policyText -notmatch [regex]::Escape($blockedTerm)) {
                $reasons.Add("Human-approval rule missing for $blockedTerm.") | Out-Null
            }
        }

        $approved = ($approvalExists -and (Test-ApprovedStatus -Path "docs/codex/AUTOPILOT_APPROVAL.md"))
        if ($approved) {
            if ($approvedLanes.Count -eq 0) {
                $reasons.Add("Approved autopilot lanes are missing.") | Out-Null
            }
            foreach ($lane in $approvedLanes) {
                if ($safeLanes -notcontains $lane) {
                    $reasons.Add("Approved lane is not listed as a safe automatic lane: $lane.") | Out-Null
                }
                if (Test-PolicyTextContainsAny -Text $lane -Terms $humanApprovalTerms) {
                    $reasons.Add("Approved lane mentions human-approval-only action: $lane.") | Out-Null
                }
            }
        }
        $status = if ($reasons.Count -gt 0) {
            "blocked"
        } elseif (!$approved) {
            "draft"
        } else {
            "approved-limited"
        }

        return [pscustomobject]@{
            status = $status
            spendingLimit = if ([string]::IsNullOrWhiteSpace($spendingLimit)) { "missing" } else { $spendingLimit }
            customerData = if ([string]::IsNullOrWhiteSpace($customerData)) { "missing" } else { $customerData }
            escalation = if ([string]::IsNullOrWhiteSpace($escalation)) { "missing" } else { $escalation }
            safeLanes = @($safeLanes)
            approvedLanes = @($approvedLanes)
            reasons = @($reasons)
        }
    } finally {
        Pop-Location
    }
}

if ($Template) {
    Write-AutopilotTemplates
    exit 0
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$results = @()
foreach ($ship in Get-ProjectList) {
    $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
    $name = [string](Get-ConfigPropertyValue -Object $ship -Name "name")
    $repoPath = Resolve-Path -LiteralPath $repo -ErrorAction SilentlyContinue
    if (!$repoPath) {
        $results += [pscustomobject]@{ name = $name; repo = $repo; status = "blocked"; spendingLimit = "unknown"; customerData = "unknown"; escalation = "unknown"; dirty = "n/a"; reasons = @("Repo missing.") }
        continue
    }
    Push-Location $repoPath.Path
    try {
        $dirty = @(git status --short 2>$null)
    } finally {
        Pop-Location
    }
    if ($dirty.Count -gt 0 -and !$IncludeDirty) {
        $results += [pscustomobject]@{
            name = $name
            repo = $repoPath.Path
            status = "blocked"
            spendingLimit = "unknown"
            customerData = "unknown"
            escalation = "unknown"
            safeLanes = @()
            approvedLanes = @()
            dirty = "dirty $($dirty.Count)"
            reasons = @("Working tree is dirty; limited autopilot requires a clean ship or explicit -IncludeDirty approval.")
        }
        continue
    }
    $status = Get-AutopilotStatus -Repo $repoPath.Path
    $results += [pscustomobject]@{ name = $name; repo = $repoPath.Path; status = $status.status; spendingLimit = $status.spendingLimit; customerData = $status.customerData; escalation = $status.escalation; safeLanes = @($status.safeLanes); approvedLanes = @($status.approvedLanes); dirty = if ($dirty.Count -eq 0) { "clean" } else { "dirty $($dirty.Count)" }; reasons = @($status.reasons) }
}

if ($ValidateOnly) {
    $blocked = @($results | Where-Object { $_.status -ne "approved-limited" })
    if ($blocked.Count -gt 0) {
        $blocked | ForEach-Object { Write-Host "$($_.name): $($_.status)" -ForegroundColor Red }
        exit 1
    }
    Write-Host "Limited autopilot policy is approved." -ForegroundColor Green
    exit 0
}

$auditRoot = ".codex-local\audit"
New-Item -ItemType Directory -Force -Path $auditRoot | Out-Null
$auditPath = Join-Path $auditRoot ("autopilot-policy-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$audit = [pscustomobject]@{
    generated = $timestamp
    action = "autopilot-policy-review"
    note = "No ship edits, spending, deploys, emails, auth/payment changes, or customer-data actions were performed."
    includeDirty = [bool]$IncludeDirty
    results = $results
}
$audit | ConvertTo-Json -Depth 8 | Set-Content -Path $auditPath

$overall = if (@($results | Where-Object { $_.status -eq "blocked" }).Count -gt 0) {
    "BLOCKED"
} elseif (@($results | Where-Object { $_.status -eq "draft" -or $_.status -eq "missing" }).Count -gt 0) {
    "NEEDS HUMAN APPROVAL"
} else {
    "APPROVED FOR LIMITED AUTOPILOT LANES"
}

$lines = @(
    "# Fleet Autopilot Policy Report",
    "",
    "Generated: $timestamp",
    "Overall: $overall",
    "Audit log: $auditPath",
    "",
    "Phase 9 limited business autopilot policy gate. This report does not spend money, deploy, email customers, change auth or payments, edit legal text, or touch customer data.",
    "",
    "| Ship | Status | Dirty | Spending Limit | Customer Data |",
    "| --- | --- | --- | --- | --- |"
)
foreach ($result in $results) {
    $lines += "| $($result.name) | $($result.status) | $($result.dirty) | $($result.spendingLimit) | $($result.customerData) |"
}

foreach ($result in $results) {
    $lines += ""
    $lines += "## $($result.name)"
    $lines += ""
    $lines += "- Repo: $($result.repo)"
    $lines += "- Status: $($result.status)"
    $lines += "- Dirty: $($result.dirty)"
    $lines += "- Escalation: $($result.escalation)"
    $lines += "- Safe lanes: $(if ($result.safeLanes.Count -gt 0) { $result.safeLanes -join ', ' } else { 'none' })"
    $lines += "- Approved lanes: $(if ($result.approvedLanes.Count -gt 0) { $result.approvedLanes -join ', ' } else { 'none' })"
    $lines += ""
    $lines += "Reasons:"
    if ($result.reasons.Count -eq 0) {
        $lines += "- None"
    } else {
        foreach ($reason in $result.reasons) { $lines += "- $reason" }
    }
}

Ensure-OutputParent -Path $OutFile
Set-Content -Path $OutFile -Value $lines
Ensure-OutputParent -Path $JsonOutFile
[pscustomobject]@{
    generated = $timestamp
    overall = $overall
    auditLog = $auditPath
    includeDirty = [bool]$IncludeDirty
    results = $results
} | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonOutFile
Write-Host "Autopilot policy report: $OutFile" -ForegroundColor Green
Write-Host "Autopilot policy JSON: $JsonOutFile" -ForegroundColor Green
Write-Host "Overall: $overall"

if ($overall -eq "BLOCKED") { exit 1 }
exit 0
