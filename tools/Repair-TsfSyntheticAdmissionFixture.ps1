[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FixtureRoot,
    [Parameter(Mandatory)][string]$MissionId,
    [Parameter(Mandatory)][string]$PreservedArchivePath,
    [Parameter(Mandatory)][string]$OutFile
)

$ErrorActionPreference='Stop'
$fleetRoot=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot 'tools\codex-fleet-enforcement-kernel.ps1')

$fixture=Get-TsfKernelFullPath $FixtureRoot
$allowedRoot=Get-TsfKernelFullPath (Join-Path $fleetRoot '.codex-local\fixtures\tsf-app-v1')
$archive=Get-TsfKernelFullPath $PreservedArchivePath
$preservationRoot=Get-TsfKernelFullPath (Join-Path $fleetRoot '.codex-local\preservation')
if(!(Test-TsfKernelPathInside $fixture $allowedRoot)-or[string]::Equals($fixture,$allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Synthetic recovery target is outside the bounded TSF fixture root.'}
if(!$MissionId.StartsWith('synthetic-')){throw 'Synthetic recovery requires a synthetic mission ID.'}
if(!(Test-TsfKernelPathInside $archive $preservationRoot)-or!(Test-Path -LiteralPath $archive -PathType Leaf)){throw 'Preserved failed-run archive is missing or outside scratch preservation.'}

$complete=Join-Path $fixture "queue\complete_ready_for_gate\$MissionId.json"
$postrun=Join-Path $fixture "queue\postrun_pending\$MissionId.json"
$executor=Join-Path $fixture 'evidence\queue_executor_result.json'
if(!(Test-Path -LiteralPath $complete -PathType Leaf)-or(Test-Path -LiteralPath $postrun)-or!(Test-Path -LiteralPath $executor -PathType Leaf)){throw 'Synthetic fixture does not match the observed inconsistent queue shape.'}
$executorResult=Get-Content -LiteralPath $executor -Raw|ConvertFrom-Json
if([string]$executorResult.final_decision-ne'RED_QUEUE_EXECUTOR_BLOCKED'){throw 'Synthetic recovery refuses a fixture without the recorded RED executor result.'}
$receipts=@(Get-ChildItem -LiteralPath $fixture -Recurse -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(admission|queue-transition)\.json$'})
if($receipts.Count){throw 'Synthetic recovery refuses a fixture that already has an admission or transition receipt.'}

$record=[pscustomobject][ordered]@{schema_version='tsf_synthetic_admission_recovery_v1';mission_id=$MissionId;fixture_root=$fixture;observed_queue_state='complete_ready_for_gate';admission_receipt_present=$false;transition_receipt_present=$false;executor_result_sha256=(Get-FileHash -LiteralPath $executor -Algorithm SHA256).Hash.ToLowerInvariant();preserved_archive_path=$archive;preserved_archive_sha256=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant();recovery_action='RECREATE_EXACT_SYNTHETIC_FIXTURE_ROOT';recovered_at=[datetimeoffset]::UtcNow.ToString('o')}
$outParent=Split-Path -Parent (Get-TsfKernelFullPath $OutFile)
New-Item -ItemType Directory -Force -Path $outParent|Out-Null
$record|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $OutFile -Encoding UTF8
$verified=(Resolve-Path -LiteralPath $fixture).Path
if(!(Test-TsfKernelPathInside $verified $allowedRoot)-or[string]::Equals($verified,$allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Resolved synthetic recovery target failed the final containment check.'}
Remove-Item -LiteralPath $verified -Recurse -Force
New-Item -ItemType Directory -Force -Path $fixture|Out-Null
$record
