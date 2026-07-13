[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:AssertionCount = 0

function Assert-Static {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:AssertionCount++
    if (-not $Condition) {
        throw "FAIL [$Id] $Message"
    }
    Write-Output "PASS [$Id] $Message"
}

function Test-Null {
    param([AllowNull()]$Value)
    return $null -eq $Value
}

$root = Split-Path -Parent $PSScriptRoot
$safeRoot = $root.Replace('\', '/')
$referenceRoot = Join-Path $root 'fleet\reference\plugin-catalog-risk-v1'
$docsRoot = Join-Path $root 'docs\hq\tsf_plugin_catalog_risk_v1_20260713'
$schemaPath = Join-Path $referenceRoot 'plugin-catalog.schema.v1.json'
$catalogPath = Join-Path $referenceRoot 'plugin-catalog.v1.json'
$riskPath = Join-Path $referenceRoot 'plugin-risk-policy.v1.json'
$packsPath = Join-Path $referenceRoot 'plugin-packs-reference.v1.json'
$priorityPath = Join-Path $referenceRoot 'plugin-review-priority.v1.json'

$jsonPaths = @(
    $schemaPath,
    $catalogPath,
    $riskPath,
    $packsPath,
    $priorityPath,
    (Join-Path $docsRoot 'VALIDATION.json')
)

$parsed = @{}
foreach ($path in $jsonPaths) {
    Assert-Static -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Id 'JSON-001' -Message "Required JSON exists: $([IO.Path]::GetFileName($path))"
    $parsed[$path] = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    Assert-Static -Condition ($null -ne $parsed[$path]) -Id 'JSON-002' -Message "JSON parses: $([IO.Path]::GetFileName($path))"
}

$schema = $parsed[$schemaPath]
$catalog = $parsed[$catalogPath]
$risk = $parsed[$riskPath]
$packs = $parsed[$packsPath]
$priority = $parsed[$priorityPath]

Assert-Static -Condition ($schema.'$schema' -eq 'https://json-schema.org/draft/2020-12/schema') -Id 'SCHEMA-001' -Message 'Catalog schema declares JSON Schema draft 2020-12.'
Assert-Static -Condition ($schema.type -eq 'object' -and $schema.additionalProperties -eq $false) -Id 'SCHEMA-002' -Message 'Catalog schema is a closed object.'
Assert-Static -Condition ($schema.properties.plugins.minItems -eq 36 -and $schema.properties.plugins.maxItems -eq 36) -Id 'SCHEMA-003' -Message 'Catalog schema fixes the seed count at 36.'

Assert-Static -Condition ($catalog.catalog_version -eq 'tsf_plugin_catalog_risk_v1') -Id 'CAT-001' -Message 'Catalog version is exact.'
Assert-Static -Condition ($catalog.baseline_state -eq 'REVIEW_ONLY_REFERENCE_NOT_RUNTIME_ENFORCED') -Id 'CAT-002' -Message 'Catalog baseline is review-only.'
Assert-Static -Condition ($catalog.authority_boundary -eq 'STATIC_NON_OPERATIONAL_NON_AUTHORITATIVE_HUMAN_DECISION_SUPPORT_ONLY') -Id 'CAT-003' -Message 'Catalog authority boundary is static and non-authoritative.'
Assert-Static -Condition ($catalog.runtime_observation_count -eq 0) -Id 'CAT-004' -Message 'Catalog top-level runtime observation count is zero.'
Assert-Static -Condition (@($catalog.plugins).Count -eq 36) -Id 'CAT-005' -Message 'Catalog has exactly 36 records.'

$requiredRecordProperties = @($schema.'$defs'.plugin.required)
$allowedRecordProperties = @($schema.'$defs'.plugin.properties.PSObject.Properties.Name)
$classificationEnum = @($schema.'$defs'.classification.enum)
$idPattern = [regex]'^[A-Za-z0-9._:-]+$'

foreach ($plugin in @($catalog.plugins)) {
    $propertyNames = @($plugin.PSObject.Properties.Name)
    $missing = @($requiredRecordProperties | Where-Object { $propertyNames -notcontains $_ })
    $extra = @($propertyNames | Where-Object { $allowedRecordProperties -notcontains $_ })
    Assert-Static -Condition ($missing.Count -eq 0) -Id 'SCHEMA-REC-001' -Message "$($plugin.plugin_id) has every required schema field."
    Assert-Static -Condition ($extra.Count -eq 0) -Id 'SCHEMA-REC-002' -Message "$($plugin.plugin_id) has no undeclared schema field."
    Assert-Static -Condition ($plugin.catalog_version -eq 'tsf_plugin_catalog_risk_v1') -Id 'SCHEMA-REC-003' -Message "$($plugin.plugin_id) carries the catalog version."
    Assert-Static -Condition ($idPattern.IsMatch([string]$plugin.plugin_id)) -Id 'SCHEMA-REC-004' -Message "$($plugin.plugin_id) has a valid static ID."
    Assert-Static -Condition ($classificationEnum -contains [string]$plugin.classification) -Id 'SCHEMA-REC-005' -Message "$($plugin.plugin_id) uses a declared classification."
    Assert-Static -Condition ($plugin.risk_tier -eq 'UNKNOWN') -Id 'SCHEMA-REC-006' -Message "$($plugin.plugin_id) keeps risk unknown."
    Assert-Static -Condition ($plugin.source_quality -eq 'USER_SUPPLIED_UNVERIFIED' -and $plugin.source_confidence -eq 'USER_SUPPLIED_UNVERIFIED') -Id 'SCHEMA-REC-007' -Message "$($plugin.plugin_id) is user-supplied and unverified."
    Assert-Static -Condition ($plugin.operational_verification_state -eq 'UNVERIFIED_NO_RUNTIME_OBSERVATION') -Id 'SCHEMA-REC-008' -Message "$($plugin.plugin_id) claims no operational verification."
    Assert-Static -Condition ($plugin.authority_granted -eq $false) -Id 'SCHEMA-REC-009' -Message "$($plugin.plugin_id) grants no authority."
    Assert-Static -Condition (@($plugin.runtime_observations).Count -eq 0) -Id 'SCHEMA-REC-010' -Message "$($plugin.plugin_id) contains zero runtime observations."
    Assert-Static -Condition ((Test-Null $plugin.publisher) -and (Test-Null $plugin.version) -and (Test-Null $plugin.manifest_sha256)) -Id 'SCHEMA-REC-011' -Message "$($plugin.plugin_id) keeps publisher/version/manifest unknown."
    Assert-Static -Condition ((Test-Null $plugin.permission_scopes) -and (Test-Null $plugin.authentication_requirements) -and (Test-Null $plugin.network_requirements)) -Id 'SCHEMA-REC-012' -Message "$($plugin.plugin_id) keeps permission/auth/network facts unknown."
    Assert-Static -Condition ((Test-Null $plugin.likely_surfaces) -and $plugin.connection_state -eq 'UNKNOWN' -and $plugin.host_availability -eq 'UNKNOWN') -Id 'SCHEMA-REC-013' -Message "$($plugin.plugin_id) keeps surface/connection/host facts unknown."
    Assert-Static -Condition ($plugin.current_enablement -eq 'UNKNOWN' -and $plugin.capability_probe_status -eq 'UNKNOWN') -Id 'SCHEMA-REC-014' -Message "$($plugin.plugin_id) keeps enablement/probe facts unknown."
    Assert-Static -Condition ($plugin.last_reviewed_at -eq '2026-07-13') -Id 'SCHEMA-REC-015' -Message "$($plugin.plugin_id) has the fixed V1 review date."
}

$ids = @($catalog.plugins | ForEach-Object { [string]$_.plugin_id })
Assert-Static -Condition (@($ids | Group-Object | Where-Object Count -gt 1).Count -eq 0) -Id 'CAT-006' -Message 'Plugin IDs are unique.'
Assert-Static -Condition (@($catalog.plugins | Where-Object { $_.reported_discovery_state -eq 'AVAILABLE' -and $_.reported_installation_state -eq 'NOT_INSTALLED' }).Count -eq 8) -Id 'CAT-007' -Message 'Exactly eight records are reported AVAILABLE / NOT_INSTALLED.'
Assert-Static -Condition (@($catalog.plugins | Where-Object { $_.reported_discovery_state -eq 'DISCOVERED' -and $_.reported_installation_state -eq 'UNKNOWN' }).Count -eq 28) -Id 'CAT-008' -Message 'Exactly 28 records are reported DISCOVERED / UNKNOWN.'
Assert-Static -Condition (@($catalog.plugins | Where-Object { $_.source_quality -ne 'USER_SUPPLIED_UNVERIFIED' -or $_.source_confidence -ne 'USER_SUPPLIED_UNVERIFIED' }).Count -eq 0) -Id 'CAT-009' -Message 'All source-quality values are USER_SUPPLIED_UNVERIFIED.'
Assert-Static -Condition ((@($catalog.plugins | ForEach-Object { @($_.runtime_observations).Count } | Measure-Object -Sum).Sum) -eq 0) -Id 'CAT-010' -Message 'Aggregate runtime observation count is zero.'
Assert-Static -Condition (@($catalog.plugins | Where-Object { $_.authority_granted -ne $false }).Count -eq 0) -Id 'CAT-011' -Message 'No catalog record grants authority.'
Assert-Static -Condition (@($catalog.plugins | Where-Object { $_.operational_verification_state -ne 'UNVERIFIED_NO_RUNTIME_OBSERVATION' }).Count -eq 0) -Id 'CAT-012' -Message 'No catalog record claims operational verification.'

$quarantineIds = @(
    'alpaca',
    'app-68d579f7b0948191a7da3124a3b560f',
    'app-68de829bf7648191acd70a907364c67c',
    'app-69949aa62bf48191be5e57a01202beca',
    'app-69a8f78087e081919e52cacacf00ff36',
    'app-69d319ffb64c8191a1c1abcd30fae202'
)
$actualQuarantine = @($catalog.plugins | Where-Object { $_.quarantine_state -eq 'QUARANTINED_PENDING_IDENTITY' } | ForEach-Object { [string]$_.plugin_id } | Sort-Object)
Assert-Static -Condition ($actualQuarantine.Count -eq 6) -Id 'QUAR-001' -Message 'Exactly six records are quarantined.'
Assert-Static -Condition ((Compare-Object ($quarantineIds | Sort-Object) $actualQuarantine).Count -eq 0) -Id 'QUAR-002' -Message 'Alpaca and the five required opaque IDs are quarantined.'
Assert-Static -Condition (@($catalog.plugins | Where-Object { $_.quarantine_state -eq 'QUARANTINED_PENDING_IDENTITY' -and ([string]::IsNullOrWhiteSpace([string]$_.quarantine_reason)) }).Count -eq 0) -Id 'QUAR-003' -Message 'Every quarantine has a reason.'

$requiredClassifications = @(
    'TSF_CORE_REQUIRED_CANDIDATE', 'TSF_CORE_OPTIONAL_CANDIDATE', 'PROJECT_SPECIFIC_CANDIDATE',
    'RESEARCH_ONLY', 'REVIEW_ONLY', 'ARTIFACT_CAPABILITY', 'SENSITIVE_CONNECTOR_MISSION_ONLY',
    'HIGH_RISK_LAST_RESORT', 'EXPERIMENTAL', 'REDUNDANT_OR_OVERLAPPING', 'OPAQUE_QUARANTINED',
    'UNSAFE_OR_REJECTED'
)
$riskClassifications = @($risk.classifications | ForEach-Object { [string]$_.id })
Assert-Static -Condition ((Compare-Object ($requiredClassifications | Sort-Object) ($classificationEnum | Sort-Object)).Count -eq 0) -Id 'CLASS-001' -Message 'Schema represents all required static classifications.'
Assert-Static -Condition ((Compare-Object ($requiredClassifications | Sort-Object) ($riskClassifications | Sort-Object)).Count -eq 0) -Id 'CLASS-002' -Message 'Risk policy defines all required static classifications.'
Assert-Static -Condition ($risk.fail_closed_rule -eq 'UNKNOWN_RISK_OR_PERMISSION_REQUIRES_REVIEW') -Id 'RISK-001' -Message 'Risk policy has the exact fail-closed rule.'
Assert-Static -Condition (@($risk.risk_considerations).Count -eq 10) -Id 'RISK-002' -Message 'Risk policy covers all ten required consideration areas.'
Assert-Static -Condition ($risk.runtime_enforced -eq $false -and $risk.approval_granted -eq $false) -Id 'RISK-003' -Message 'Risk policy is neither runtime-enforced nor approving.'

$expectedPackIds = @('TSF_DEV_CORE', 'TSF_RESEARCH_ARTIFACT', 'TSF_PRODUCT_DESIGN', 'TSF_GAME_STUDIO', 'TSF_SENSITIVE_CONNECTORS')
$actualPackIds = @($packs.packs | ForEach-Object { [string]$_.pack_id })
Assert-Static -Condition ((Compare-Object ($expectedPackIds | Sort-Object) ($actualPackIds | Sort-Object)).Count -eq 0) -Id 'PACK-001' -Message 'Exactly the five required pack labels exist.'
foreach ($pack in @($packs.packs)) {
    $allFalse = $pack.auto_select -eq $false -and $pack.auto_install -eq $false -and $pack.auto_enable -eq $false -and $pack.auto_load -eq $false -and $pack.runtime_enforced -eq $false -and $pack.approval_granted -eq $false
    Assert-Static -Condition $allFalse -Id 'PACK-002' -Message "$($pack.pack_id) has no auto-select/install/enable/load, runtime enforcement, or approval behavior."
    Assert-Static -Condition ($pack.requires_every_member -eq $false -and $pack.overrides_quarantine -eq $false -and $pack.proves_availability -eq $false -and $pack.expands_mission_permission -eq $false) -Id 'PACK-003' -Message "$($pack.pack_id) is a non-authorizing review aid."
}
$sensitivePack = @($packs.packs | Where-Object pack_id -eq 'TSF_SENSITIVE_CONNECTORS')
Assert-Static -Condition ($sensitivePack.Count -eq 1 -and $sensitivePack[0].classification_pool_only -eq $true) -Id 'PACK-004' -Message 'Sensitive pack is classification-only.'
Assert-Static -Condition ([string]$sensitivePack[0].description -match 'not a bundle to load') -Id 'PACK-005' -Message 'Sensitive pack explicitly denies bundle loading.'
Assert-Static -Condition ($packs.runtime_resolver_input -eq $false) -Id 'PACK-006' -Message 'Pack reference is not runtime resolver input.'

$manualDispositions = @(
    'PRIORITY_FOR_METADATA_REVIEW', 'PROJECT_SPECIFIC_REVIEW', 'SENSITIVE_REQUIRES_EXACT_MISSION',
    'QUARANTINED_PENDING_IDENTITY', 'REDUNDANT_REVIEW_REQUIRED', 'NOT_NEEDED_FOR_CURRENT_V1', 'TIM_REQUIRED'
)
Assert-Static -Condition ($priority.prioritization_is_authorization -eq $false) -Id 'REVIEW-001' -Message 'Prioritization is explicitly not authorization.'
Assert-Static -Condition ((Compare-Object ($manualDispositions | Sort-Object) (@($priority.allowed_manual_dispositions) | Sort-Object)).Count -eq 0) -Id 'REVIEW-002' -Message 'Review matrix allows every required manual disposition.'
Assert-Static -Condition (@($priority.plugins).Count -eq 36) -Id 'REVIEW-003' -Message 'Review matrix contains every plugin.'
Assert-Static -Condition ((Compare-Object ($ids | Sort-Object) (@($priority.plugins.plugin_id) | Sort-Object)).Count -eq 0) -Id 'REVIEW-004' -Message 'Review matrix IDs exactly match catalog IDs.'
$priorityOrder = @($priority.plugins | Where-Object { $null -ne $_.investigation_priority } | Sort-Object investigation_priority | ForEach-Object display_name)
$actualPriorityIds = @($priority.plugins | Where-Object { $null -ne $_.investigation_priority } | Sort-Object investigation_priority | ForEach-Object plugin_id)
$expectedPriorityIds = @('codex-security', 'github', 'openai-developers', 'browser', 'template-creator', 'documents', 'pdf', 'spreadsheets', 'presentations', 'visualize')
Assert-Static -Condition ((Compare-Object $expectedPriorityIds $actualPriorityIds -SyncWindow 0).Count -eq 0) -Id 'REVIEW-005' -Message 'Initial metadata-review order is exact.'

$allReferenceText = (Get-ChildItem -LiteralPath $referenceRoot, $docsRoot -File -Recurse | Get-Content -Raw) -join "`n"
$forbiddenCanonicalClaims = @('parked branch is canonical', 'parked branch as canonical authority', 'canonical_branch.*work/plugin-discovery-capability-selection')
foreach ($pattern in $forbiddenCanonicalClaims) {
    Assert-Static -Condition ($allReferenceText -notmatch $pattern) -Id 'TRACE-001' -Message "No positive canonical claim matches: $pattern"
}
Assert-Static -Condition ($allReferenceText -match 'PARKED_EXPERIMENTAL_DO_NOT_PUBLISH') -Id 'TRACE-002' -Message 'Parked advanced research has the required disposition.'
Assert-Static -Condition ($allReferenceText -match 'must not be treated as canonical') -Id 'TRACE-003' -Message 'Documentation tells future workers not to treat parked research as canonical.'

$changed = @(
    git -c "safe.directory=$safeRoot" -C $root diff --name-only origin/main --
    git -c "safe.directory=$safeRoot" -C $root ls-files --others --exclude-standard
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique

$allowedFile = [regex]'^(fleet/reference/plugin-catalog-risk-v1/|docs/hq/tsf_plugin_catalog_risk_v1_20260713/|tests/run-tsf-plugin-catalog-risk-v1-static-validation\.ps1$)'
$outsideScope = @($changed | Where-Object { -not $allowedFile.IsMatch($_.Replace('\', '/')) })
Assert-Static -Condition ($outsideScope.Count -eq 0) -Id 'SCOPE-001' -Message 'Only isolated catalog/risk artifacts and the static validator changed.'
Assert-Static -Condition ($changed.Count -eq 17) -Id 'SCOPE-002' -Message 'Exactly 17 intended files are present.'

$forbiddenPathPattern = [regex]'(?i)(mission-envelope|result-envelope|admission|producer-evidence-registry|native-capability-evidence|plugin-capability-observation|resolve-tsfmissionplugins|invoke-tsfprojectmainbot|tsfdurablecontract|codex-fleet-enforcement-kernel|approval-ledger|queue|lifecycle)'
$forbiddenChanged = @($changed | Where-Object { $forbiddenPathPattern.IsMatch($_) })
Assert-Static -Condition ($forbiddenChanged.Count -eq 0) -Id 'SCOPE-003' -Message 'No runtime resolver, evidence, admission, Main Bot, approval, queue, or lifecycle file changed.'

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$tokens, [ref]$parseErrors)
Assert-Static -Condition (@($parseErrors).Count -eq 0) -Id 'EXEC-001' -Message 'Static validation script parses without PowerShell errors.'
$commandNames = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
$operationalCommands = @('Invoke-WebRequest', 'Invoke-RestMethod', 'Start-Process', 'New-PSSession', 'Invoke-Command', 'Install-Module', 'Install-Package', 'Start-Job')
Assert-Static -Condition (@($commandNames | Where-Object { $operationalCommands -contains $_ }).Count -eq 0) -Id 'EXEC-002' -Message 'No network, package, background, remote, or plugin operation command was added.'
Assert-Static -Condition (@($changed | Where-Object { $_ -match '\.(psm1|exe|dll|cmd|bat|js|mjs|py)$' }).Count -eq 0) -Id 'EXEC-003' -Message 'No runtime implementation executable was added.'

$diffCheckOutput = @(git -c "safe.directory=$safeRoot" -C $root diff --check origin/main -- 2>&1)
$diffCheckExit = $LASTEXITCODE
Assert-Static -Condition ($diffCheckExit -eq 0) -Id 'GIT-001' -Message 'git diff --check passes against origin/main.'

Write-Output "STATIC_VALIDATION_PASS assertions=$script:AssertionCount catalog=36 available_not_installed=8 discovered_unknown=28 quarantined=6 runtime_observations=0 changed_files=$($changed.Count)"
