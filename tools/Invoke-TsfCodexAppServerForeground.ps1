[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)][string]$MissionId,
    [Parameter(Mandatory = $true)][int]$MissionRevision,
    [Parameter(Mandatory = $true)][string]$PolicyFingerprint,
    [Parameter(Mandatory = $true)][string]$QueueDocumentSha256,
    [Parameter(Mandatory = $true)][string]$Cwd,
    [Parameter(Mandatory = $true)][string]$Model,
    [Parameter(Mandatory = $true)][string]$ReasoningEffort,
    [Parameter(Mandatory = $true)][ValidateSet('RECOMMENDED_ONLY','USER_CONFIRMED','ADAPTER_VERIFIED','TECHNICALLY_ENFORCED')][string]$EffortAssurance,
    [Parameter(Mandatory = $true)][ValidateSet('read-only','workspace-write')][string]$Sandbox,
    [Parameter(Mandatory = $true)][string]$PromptFile,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$ResultPath = '',
    [string]$EventJournalPath = '',
    [string]$StderrPath = '',
    [Parameter(Mandatory = $true)][datetimeoffset]$ExpiresAt,
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot 'tools\codex-fleet-enforcement-kernel.ps1')
$node = (Get-Command node -ErrorAction Stop).Source
$codexCmd = (Get-Command codex.cmd -ErrorAction Stop).Source
$npmRoot = Split-Path -Parent $codexCmd
$codexExe = Join-Path $npmRoot 'node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\bin\codex.exe'
if (!(Test-Path -LiteralPath $codexExe -PathType Leaf)) { throw "Codex app-server executable not found: $codexExe" }
$effortMap = @{ LIGHT='low'; MEDIUM='medium'; HIGH='high'; EXTRA_HIGH='xhigh'; MAX='max'; ULTRA='ultra' }
if (!$effortMap.ContainsKey($ReasoningEffort)) { throw "Unsupported app-server effort: $ReasoningEffort" }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$artifactCatalog=Get-TsfRuntimeArtifactCatalog
if ([string]::IsNullOrWhiteSpace($ResultPath)) { $ResultPath = Join-Path $OutputDirectory $artifactCatalog.adapter_result }
if ([string]::IsNullOrWhiteSpace($EventJournalPath)) { $EventJournalPath = Join-Path $OutputDirectory $artifactCatalog.event_journal }
if ([string]::IsNullOrWhiteSpace($StderrPath)) { $StderrPath = Join-Path $OutputDirectory $artifactCatalog.stderr }
$pathPlan = Test-TsfRuntimePathPlan -RuntimeRoot $OutputDirectory -Paths @($ResultPath,$EventJournalPath,$StderrPath)
if (!$pathPlan.valid) { throw "App-server runtime artifact path preflight failed: $($pathPlan.errors -join '; ')" }
$arguments = @(
    (Join-Path $fleetRoot 'tools\tsf-codex-app-server-adapter.mjs'),
    '--codex-executable', $codexExe,
    '--mission-id', $MissionId,
    '--mission-revision', [string]$MissionRevision,
    '--policy-fingerprint', $PolicyFingerprint,
    '--queue-document-sha256', $QueueDocumentSha256,
    '--cwd', $Cwd,
    '--model', $Model,
    '--mission-requested-effort', $ReasoningEffort,
    '--canonical-resolved-effort', $ReasoningEffort,
    '--required-effort-assurance', $EffortAssurance,
    '--effort', $effortMap[$ReasoningEffort],
    '--sandbox', $Sandbox,
    '--prompt-file', $PromptFile,
    '--output-dir', $OutputDirectory,
    '--result-file', $ResultPath,
    '--event-file', $EventJournalPath,
    '--stderr-file', $StderrPath,
    '--timeout-seconds', [string]$TimeoutSeconds,
    '--expires-at', $ExpiresAt.ToUniversalTime().ToString('o')
)
& $node @arguments
$exitCode = $LASTEXITCODE
if (!(Test-Path -LiteralPath $ResultPath -PathType Leaf)) { throw 'App-server adapter did not write its result.' }
$result = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json
if ($exitCode -ne 0 -or ![bool]$result.success) { throw "App-server adapter failed: $($result.failure)" }
$result
