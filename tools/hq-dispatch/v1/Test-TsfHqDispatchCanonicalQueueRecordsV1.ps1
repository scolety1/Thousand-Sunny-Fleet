[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$QueueRoot,
    [switch]$TestOnlyAllowAlternateQueueRoot
)

$ErrorActionPreference='Stop'
$scriptRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$expectedRoot=[IO.Path]::GetFullPath($scriptRoot)
$repositoryPath=[IO.Path]::GetFullPath($RepositoryRoot)
if(![string]::Equals($repositoryPath,$expectedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'HQ_QUEUE_VALIDATOR_REPOSITORY_ROOT_MISMATCH'}

Import-Module (Join-Path $repositoryPath 'tools\TsfDurableContract.psm1') -Force
$inputText=[Console]::In.ReadToEnd()
if([string]::IsNullOrWhiteSpace($inputText)){throw 'HQ_QUEUE_VALIDATOR_INPUT_REQUIRED'}
$parsedDescriptors=$inputText|ConvertFrom-Json
$descriptors=@();foreach($item in $parsedDescriptors){$descriptors+=$item}
$results=@($descriptors|ForEach-Object{
    Test-TsfCanonicalQueueRecordFile -QueueRecordPath ([string]$_.path) -QueueRoot $QueueRoot -ExpectedQueueState ([string]$_.state) -ExpectedMissionId ([string]$_.mission_id) -ExpectedMissionRevision ([int]$_.mission_revision) -RepositoryRoot $repositoryPath -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
})
[Console]::Out.Write(($results|ConvertTo-Json -Depth 30 -Compress))
