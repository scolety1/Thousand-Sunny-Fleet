function Get-FleetLaneProfiles {
    $profiles = @(
        [pscustomobject]@{
            id = "hospitality_website"
            displayName = "Hospitality Website"
            purpose = "Guest-facing restaurant, beverage, event, catering, and local hospitality websites."
            allowedTaskClasses = @("visible-product", "copy", "design", "accessibility", "performance")
            forbiddenTaskClasses = @("auth", "payments", "deployment", "migration", "package-change", "secret")
            requiredGates = @("first-screen-contract", "information-hierarchy", "mobile-contract", "copy-review", "accessibility-basic", "taste-gate")
            evidenceRequirements = @("desktop-screenshot", "mobile-screenshot", "navigation-proof", "first-screen-proof", "copy-review")
            defaultBudgetMode = "balanced"
            overnightEligibility = "allowed-with-visual-evidence"
            approvalTriggers = @("subjective-brand-direction", "reference-site-copying-risk", "backend-sensitive-touch")
        }
        [pscustomobject]@{
            id = "manager_internal_tool"
            displayName = "Manager / Internal Tool"
            purpose = "Operational surfaces for managers, service teams, kitchens, events, and staff."
            allowedTaskClasses = @("visible-product", "workflow", "fixture-data", "state-interaction", "accessibility")
            forbiddenTaskClasses = @("customer-marketing-hero", "auth", "payments", "deployment", "package-change")
            requiredGates = @("daily-workflow-proof", "primary-action-proof", "mobile-contract", "information-hierarchy", "no-overload-gate")
            evidenceRequirements = @("workflow-screenshot", "sample-operating-data", "primary-action-proof", "mobile-screenshot")
            defaultBudgetMode = "balanced"
            overnightEligibility = "allowed-with-workflow-proof"
            approvalTriggers = @("live-integration-claim", "backend-sensitive-touch", "unclear-operational-owner")
        }
        [pscustomobject]@{
            id = "analytical_software"
            displayName = "Analytical Software"
            purpose = "Formula-first, data-driven, simulation, forecasting, pricing, and decision tools."
            allowedTaskClasses = @("formula", "fixture", "test", "data-validation", "explainability", "ui-for-analysis")
            forbiddenTaskClasses = @("untested-formula", "fake-confidence", "visual-polish-before-correctness", "live-data-without-approval")
            requiredGates = @("formula-review", "fixture-expectations", "unit-tests", "data-contract", "confidence-rules")
            evidenceRequirements = @("test-output", "fixture-table", "formula-docs", "audit-receipt", "before-after-output")
            defaultBudgetMode = "premium-for-correctness"
            overnightEligibility = "allowed-only-with-deterministic-tests"
            approvalTriggers = @("formula-weight-change", "live-data-source", "missing-fixture-expectations")
        }
        [pscustomobject]@{
            id = "backend_sensitive"
            displayName = "Backend-Sensitive Work"
            purpose = "Auth, payments, deployment, migrations, dependencies, secrets, production data, and external APIs."
            allowedTaskClasses = @("approval-plan", "risk-review", "rollback-plan", "contract-test", "security-scope-audit")
            forbiddenTaskClasses = @("autonomous-execution-without-approval", "broad-refactor", "secret-storage", "silent-deploy")
            requiredGates = @("captain-approval", "sensitive-systems-review", "migration-review-if-needed", "api-contract-review-if-needed", "rollback-plan")
            evidenceRequirements = @("approval-note", "changed-files-list", "risk-assessment", "tests", "rollback-instructions", "secret-scan")
            defaultBudgetMode = "approval-required"
            overnightEligibility = "status-only-unless-explicitly-approved"
            approvalTriggers = @("always")
        }
        [pscustomobject]@{
            id = "maintenance"
            displayName = "Maintenance"
            purpose = "Small bug fixes, docs cleanup, fixture repair, status work, and narrow harness upkeep."
            allowedTaskClasses = @("bugfix", "docs", "fixture-repair", "status-report", "small-test", "low-token")
            forbiddenTaskClasses = @("broad-redesign", "new-feature", "dependency-update-without-approval", "vague-polish")
            requiredGates = @("small-diff-proof", "focused-test", "before-after-note", "scope-check")
            evidenceRequirements = @("files-changed", "test-command", "before-after-note", "small-scope-reason")
            defaultBudgetMode = "cheap"
            overnightEligibility = "status-or-small-repair"
            approvalTriggers = @("scope-growth", "product-redesign", "dependency-change")
        }
    )

    return $profiles
}

function Get-FleetLaneProfile {
    param([Parameter(Mandatory = $true)][string]$LaneId)

    return @(Get-FleetLaneProfiles | Where-Object { $_.id -eq $LaneId } | Select-Object -First 1)[0]
}

function Test-FleetBackendSensitiveText {
    param([string]$Text)

    return ($Text -match "(?i)\b(auth|oauth|login|password|payment|stripe|billing|deploy|deployment|production|migration|database schema|secret|token|credential|api contract|external api|package\.json|package-lock|pnpm-lock|yarn\.lock|dependency|dependencies|env file|\.env)\b")
}

function Resolve-FleetSpecializedLane {
    param(
        [string]$Text = "",
        [string[]]$TouchedPaths = @(),
        [string]$ShipName = "",
        [string]$RiskTier = "",
        [string]$RequestedLane = ""
    )

    $combined = @($Text, $ShipName, ($TouchedPaths -join " ")) -join " "
    $reasons = @()
    $captainApprovalNeeded = $false
    $escalated = $false
    $laneId = ""

    if (![string]::IsNullOrWhiteSpace($RequestedLane)) {
        $known = @(Get-FleetLaneProfiles | Where-Object { $_.id -eq $RequestedLane })
        if ($known.Count -eq 0) {
            $laneId = "backend_sensitive"
            $reasons += "Unknown requested lane chooses the safer backend-sensitive lane."
            $captainApprovalNeeded = $true
            $escalated = $true
        } else {
            $laneId = $RequestedLane
            $reasons += "Requested lane was recognized."
        }
    }

    if (Test-FleetBackendSensitiveText -Text $combined) {
        if ($laneId -ne "backend_sensitive") {
            $reasons += "Backend-sensitive keyword/path overrides normal lane routing."
            $escalated = (![string]::IsNullOrWhiteSpace($laneId))
        }
        $laneId = "backend_sensitive"
        $captainApprovalNeeded = $true
    }

    if ([string]::IsNullOrWhiteSpace($laneId)) {
        if ($combined -match "(?i)\b(niners|formula|keeper|drop|model|scoring|margin|pricing|forecast|simulation|fixture expectation|golden value|confidence|data validation|weights?)\b") {
            $laneId = "analytical_software"
            $reasons += "Formula/data language maps to analytical software."
        } elseif ($combined -match "(?i)\b(restaurant|wine list|menu|beverage|bar|catering|private event|reservation|guest|hospitality|landing page|brand page|customer-facing|customer facing)\b") {
            $laneId = "hospitality_website"
            $reasons += "Guest-facing hospitality language maps to hospitality website."
        } elseif ($combined -match "(?i)\b(manager|shift|handoff|brief|order sheet|prep|checklist|training hub|staff|kitchen|service|event board|operations?)\b") {
            $laneId = "manager_internal_tool"
            $reasons += "Operational workflow language maps to manager/internal tool."
        } elseif ($combined -match "(?i)\b(bug|fix|docs?|cleanup|stale|fixture repair|status report|small patch|test harness|maintenance)\b") {
            $laneId = "maintenance"
            $reasons += "Small repair/docs language maps to maintenance."
        } else {
            $laneId = "maintenance"
            $reasons += "Unclear low-risk work defaults to maintenance/status until better scoped."
        }
    }

    if ($laneId -eq "maintenance" -and $combined -match "(?i)\b(redesign|new feature|full website|hero|brand direction|large visual|workflow overhaul)\b") {
        $laneId = "hospitality_website"
        $reasons += "Maintenance request grew into visible product/design work, so it escalates out of maintenance."
        $escalated = $true
    }

    if ($laneId -eq "analytical_software" -and $combined -match "(?i)\b(weight|formula|score|calculation)\b") {
        $reasons += "Analytical formula work requires formula review and deterministic fixtures."
    }

    $profile = Get-FleetLaneProfile -LaneId $laneId
    $blocked = ($laneId -eq "backend_sensitive" -and !$captainApprovalNeeded)
    $status = if ($laneId -eq "backend_sensitive") { "APPROVAL_REQUIRED" } elseif ($escalated) { "ESCALATED" } else { "SELECTED" }

    return [pscustomobject]@{
        lane = $laneId
        displayName = $profile.displayName
        status = $status
        reasons = $reasons
        requiredGates = @($profile.requiredGates)
        evidenceRequirements = @($profile.evidenceRequirements)
        defaultBudgetMode = $profile.defaultBudgetMode
        overnightEligibility = $profile.overnightEligibility
        captainApprovalNeeded = [bool]($captainApprovalNeeded -or $profile.approvalTriggers -contains "always")
        escalated = [bool]$escalated
        blocked = [bool]$blocked
    }
}

function New-FleetLaneMarkdownReport {
    param(
        [Parameter(Mandatory = $true)][object[]]$Results
    )

    $lines = @(
        "# Stage 11 Specialized Lane Report",
        "",
        "| Ship / Task | Lane | Status | Approval | Reason |",
        "| --- | --- | --- | --- | --- |"
    )

    foreach ($result in @($Results)) {
        $name = if ($result.name) { [string]$result.name } else { "Task" }
        $reason = (($result.resolution.reasons | Select-Object -First 2) -join "; ").Replace("|", "/")
        $lines += "| $name | $($result.resolution.lane) | $($result.resolution.status) | $($result.resolution.captainApprovalNeeded) | $reason |"
    }

    return ($lines -join "`n")
}
