[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CandidatePath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$module = Import-Module (Join-Path $root 'tools\TsfDurableContract.psm1') -Force -PassThru
try {
    $candidateFull = [IO.Path]::GetFullPath($CandidatePath)
    if (!(Test-Path -LiteralPath $candidateFull -PathType Leaf)) {
        throw 'SYNTHETIC_ADMISSION_CANDIDATE_ABSENT'
    }
    $candidate = Get-Content -LiteralPath $candidateFull -Raw -Encoding UTF8 | ConvertFrom-Json
    $decision = Get-TsfSyntheticIterationAdmissionDecisionV2 -Candidate $candidate -CandidatePath $candidateFull
    ConvertTo-Json -InputObject $decision -Depth 20 -Compress
}
finally {
    Remove-Module -ModuleInfo $module -Force -ErrorAction SilentlyContinue
}
