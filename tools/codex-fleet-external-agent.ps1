function Get-FleetExternalAgentRoles {
    return @(
        "Issue Auditor",
        "Improvement Auditor",
        "Product Taste Auditor",
        "Formula Auditor",
        "Security Scope Auditor",
        "Tie-Breaker Auditor"
    )
}

function Test-FleetExternalAgentRole {
    param([Parameter(Mandatory = $true)][string]$Role)
    $normalized = $Role.Trim()
    return ((Get-FleetExternalAgentRoles) -contains $normalized)
}

function Get-FleetExternalRolePrompt {
    param([Parameter(Mandatory = $true)][string]$Role)

    switch ($Role) {
        "Issue Auditor" {
            return "Find concrete bugs, failed gates, missing evidence, stalls, unsafe states, and model-budget waste. Do not suggest taste-only work unless it blocks usefulness."
        }
        "Improvement Auditor" {
            return "Suggest the smallest useful next upgrades that improve autonomy, reliability, or product quality. Prefer bounded task packets over broad roadmaps."
        }
        "Product Taste Auditor" {
            return "Review first-screen clarity, information hierarchy, progressive disclosure, copy, mobile fit, and demo usefulness. Treat remaining subjective direction as captain taste questions."
        }
        "Formula Auditor" {
            return "Review analytical/model correctness, formulas, fixtures, deterministic tests, assumptions, and fake-confidence risks. Prefer testable formula tasks."
        }
        "Security Scope Auditor" {
            return "Review forbidden paths, secrets, auth, payments, deployment, migrations, package/dependency changes, external APIs, and unsafe scope expansion."
        }
        "Tie-Breaker Auditor" {
            return "Compare conflicting reports, group consensus, reject risky advice, and recommend the safest validated next packet or captain question."
        }
        default {
            throw "Unknown external agent role: $Role"
        }
    }
}

function New-FleetExternalAgentPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$Ship,
        [Parameter(Mandatory = $true)][string]$AuditPackagePath,
        [string]$Mission = "Audit the selected ship and recommend safe next work.",
        [string]$KnownConstraints = "Do not edit repos, bypass validation, touch secrets/auth/payments/deploy config, or ask for broad rewrites.",
        [ValidateSet("findings-only", "task-packet", "comparison")]
        [string]$DesiredOutputType = "task-packet",
        [ValidateSet("low", "normal", "urgent")]
        [string]$Urgency = "normal"
    )

    if (!(Test-FleetExternalAgentRole -Role $Role)) { throw "Unknown external agent role: $Role" }
    $rolePrompt = Get-FleetExternalRolePrompt -Role $Role

    return @(
        "You are the $Role for Codex Fleet.",
        "",
        "Ship: $Ship",
        "Audit package: $AuditPackagePath",
        "Mission: $Mission",
        "Urgency/budget mode: $Urgency",
        "",
        "Role focus:",
        $rolePrompt,
        "",
        "Known constraints:",
        $KnownConstraints,
        "",
        "Rules:",
        "- You are a reviewer, not an executor.",
        "- Do not edit files, run commands, merge, push, deploy, delete locks, or touch product repos.",
        "- Do not recommend bypassing Stage 4 task-packet validation.",
        "- Do not ask the captain to review broken builds, missing evidence, or stalled loops as normal operation.",
        "- Human/captain review is the final taste or approval gate after deterministic checks pass.",
        "",
        "Return format:",
        "- verdict: PASS, PASS_WITH_FIXES, or FAIL",
        "- topIssues: ordered by severity with evidence references",
        "- rejectedIdeas: unsafe, stale, vague, or too broad recommendations",
        "- captainQuestions: only taste/business/high-risk approval questions",
        "- taskPacket: include only if useful and safe; it is a suggestion until the fleet validates it",
        "",
        "Desired output type: $DesiredOutputType"
    ) -join "`r`n"
}

function Test-FleetExternalAgentResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [string]$ExpectedAuditId = "",
        [string]$ExpectedShip = "",
        [string]$ExpectedBaseCommit = ""
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($field in @("auditId", "agentRole", "ship", "baseCommit", "verdict")) {
        if ([string]::IsNullOrWhiteSpace([string]$Response.$field)) { $errors.Add("Missing $field.") | Out-Null }
    }
    if (![string]::IsNullOrWhiteSpace([string]$Response.agentRole) -and !(Test-FleetExternalAgentRole -Role ([string]$Response.agentRole))) {
        $errors.Add("Unknown agentRole: $($Response.agentRole)") | Out-Null
    }
    if ($Response.verdict -and ([string]$Response.verdict) -notin @("PASS", "PASS_WITH_FIXES", "FAIL")) {
        $errors.Add("Invalid verdict: $($Response.verdict)") | Out-Null
    }
    if ($ExpectedAuditId -and [string]$Response.auditId -ne $ExpectedAuditId) { $errors.Add("Audit ID mismatch.") | Out-Null }
    if ($ExpectedShip -and [string]$Response.ship -ne $ExpectedShip) { $errors.Add("Ship mismatch.") | Out-Null }
    if ($ExpectedBaseCommit -and [string]$Response.baseCommit -ne $ExpectedBaseCommit) { $errors.Add("Base commit mismatch.") | Out-Null }

    $forbiddenPattern = "(?i)(\.env|secret|token|credential|private[-_]?key|\.git|node_modules|dist|build|auth|payment|deploy|migration|package\.json|package-lock\.json|pnpm-lock|yarn\.lock|merge|push|deploy|delete\s+lock)"
    $tasks = @()
    if ($null -ne $Response.taskPacket -and $null -ne $Response.taskPacket.tasks) { $tasks = @($Response.taskPacket.tasks) }
    foreach ($task in $tasks) {
        foreach ($field in @("id", "title", "priority", "risk", "lane", "userPain", "target", "change", "guardrails", "acceptance", "proof", "stopIf", "checkCommand")) {
            if ([string]::IsNullOrWhiteSpace([string]$task.$field)) { $errors.Add("Task $($task.id) missing $field.") | Out-Null }
        }
        $unsafeActionText = @(
            [string]$task.title,
            [string]$task.target,
            [string]$task.change,
            [string]$task.acceptance,
            [string]$task.proof,
            [string]$task.stopIf,
            [string]$task.checkCommand
        ) -join " "
        if ($unsafeActionText -match $forbiddenPattern) {
            $errors.Add("Task $($task.id) touches forbidden scope or unsafe command language.") | Out-Null
        }
        if ([string]$task.risk -match "(?i)high|sensitive") {
            $warnings.Add("Task $($task.id) is high risk and needs captain approval even if structurally valid.") | Out-Null
        }
    }

    return [pscustomobject]@{
        valid = ($errors.Count -eq 0)
        errors = @($errors)
        warnings = @($warnings)
        taskCount = @($tasks).Count
    }
}

function Compare-FleetExternalAgentResponses {
    param([Parameter(Mandatory = $true)][object[]]$Responses)

    $accepted = [System.Collections.Generic.List[object]]::new()
    $deferred = [System.Collections.Generic.List[object]]::new()
    $rejected = [System.Collections.Generic.List[object]]::new()
    $needsCaptain = [System.Collections.Generic.List[object]]::new()
    $seen = @{}

    foreach ($response in @($Responses)) {
        $validation = Test-FleetExternalAgentResponse -Response $response
        if (!$validation.valid) {
            $rejected.Add([pscustomobject]@{ source = [string]$response.agentRole; reason = ($validation.errors -join "; "); response = $response }) | Out-Null
            continue
        }
        foreach ($task in @($response.taskPacket.tasks)) {
            $key = (([string]$task.title + "|" + [string]$task.target + "|" + [string]$task.change).ToLowerInvariant())
            $tasteText = @(
                [string]$task.lane,
                [string]$task.title,
                [string]$task.userPain,
                [string]$task.target,
                [string]$task.change
            ) -join " "
            if ($seen.ContainsKey($key)) {
                $accepted.Add([pscustomobject]@{ bucket = "ACCEPT"; reason = "Consensus or duplicate recommendation."; task = $task }) | Out-Null
            } else {
                $seen[$key] = $true
                if ([string]$task.risk -match "(?i)high|sensitive") {
                    $needsCaptain.Add([pscustomobject]@{ bucket = "NEEDS_CAPTAIN"; reason = "High-risk or sensitive task."; task = $task }) | Out-Null
                } elseif ([string]$response.agentRole -eq "Product Taste Auditor" -or $tasteText -match "(?i)taste|visual direction|brand direction|subjective|preference") {
                    $needsCaptain.Add([pscustomobject]@{ bucket = "NEEDS_CAPTAIN"; reason = "Taste or visual-direction recommendation requires captain approval."; task = $task }) | Out-Null
                } elseif ([string]$task.priority -match "(?i)low") {
                    $deferred.Add([pscustomobject]@{ bucket = "DEFER"; reason = "Low priority single-agent suggestion."; task = $task }) | Out-Null
                } else {
                    $accepted.Add([pscustomobject]@{ bucket = "ACCEPT_WITH_EDITS"; reason = "Structurally valid single-agent suggestion; normalize through Stage 4 before import."; task = $task }) | Out-Null
                }
            }
        }
    }

    return [pscustomobject]@{
        accepted = @($accepted)
        deferred = @($deferred)
        rejected = @($rejected)
        needsCaptain = @($needsCaptain)
    }
}

function New-FleetExternalCaptainSummary {
    param(
        [Parameter(Mandatory = $true)][object]$Comparison,
        [string]$Ship = "",
        [string]$AuditPackage = "",
        [string[]]$RolesUsed = @()
    )

    $accepted = @($Comparison.accepted)
    $deferred = @($Comparison.deferred)
    $rejected = @($Comparison.rejected)
    $needsCaptain = @($Comparison.needsCaptain)
    $recommendation = if ($rejected.Count -gt 0) {
        "Inspect rejected unsafe/stale suggestions before importing anything."
    } elseif ($needsCaptain.Count -gt 0) {
        "Answer captain questions before importing taste/high-risk work."
    } elseif ($accepted.Count -gt 0) {
        "Normalize accepted candidates through Stage 4 validation."
    } else {
        "No safe task candidates; keep ship parked or request another audit."
    }

    $lines = @(
        "# External Audit Captain Summary",
        "",
        "- Ship: $Ship",
        "- Audit package: $AuditPackage",
        "- Roles used: $(@($RolesUsed) -join ', ')",
        "- Accepted candidates: $($accepted.Count)",
        "- Deferred ideas: $($deferred.Count)",
        "- Rejected candidates: $($rejected.Count)",
        "- Needs captain: $($needsCaptain.Count)",
        "- Recommended next command: $recommendation",
        "",
        "## Urgent Blockers",
        ""
    )
    if ($rejected.Count -eq 0) { $lines += "- None" } else {
        foreach ($item in $rejected | Select-Object -First 5) {
            $lines += "- $($item.source): $($item.reason)"
        }
    }

    $lines += @("", "## Accepted Task Candidates", "")
    if ($accepted.Count -eq 0) { $lines += "- None" } else {
        foreach ($item in $accepted | Select-Object -First 5) {
            $lines += "- $($item.task.id): $($item.task.title) ($($item.bucket))"
        }
    }

    $lines += @("", "## Deferred Ideas", "")
    if ($deferred.Count -eq 0) { $lines += "- None" } else {
        foreach ($item in $deferred | Select-Object -First 5) {
            $lines += "- $($item.task.id): $($item.task.title)"
        }
    }

    $lines += @("", "## Taste Or High-Risk Questions", "")
    if ($needsCaptain.Count -eq 0) { $lines += "- None" } else {
        foreach ($item in $needsCaptain | Select-Object -First 5) {
            $lines += "- $($item.task.id): $($item.reason) $($item.task.title)"
        }
    }

    $lines += @(
        "",
        "## Safety Note",
        "",
        "External agent output is advice. Accepted candidates still require Stage 4 validation before ingestion. Human review is the final taste/high-risk approval gate, not the repair path for broken builds or missing evidence."
    )

    return ($lines -join "`r`n")
}
