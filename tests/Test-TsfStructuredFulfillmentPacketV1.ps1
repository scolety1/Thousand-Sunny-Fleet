[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$packet=Join-Path $repo 'docs\hq\tsf_v1_structured_fulfillment_policy_hotfix_v1_20260724'
function Get-CanonicalLfSha256([string]$Path){
    $text=[IO.File]::ReadAllText($Path).Replace("`r`n","`n").Replace("`r","`n")
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}
    finally{$sha.Dispose()}
}
$required=@(
    'READ_THIS_FIRST.md','ARCHITECTURAL_DECISION_RECORD.md','GENERIC_TEXT_NON_ADMISSION_POLICY.md',
    'STRUCTURED_GENERAL_RESULT_CONTRACT.md','RECOVERY_FIXTURE_CONTRACTS.md','RESULT_CONTRACT_SELECTION.md','VERIFIER_AND_ADMISSION_RULES.md',
    'UI_OPERATOR_TRUTH.md','LEGACY_COMPATIBILITY_AND_HISTORY.md','REAL_PROOFS.md',
    'TARGETED_SOAK_V4_RESULTS.md','TARGETED_SOAK_V5_RESULTS.md','SECURITY_AND_AUTHORITY_REVIEW.md','EXECUTED_TEST_COVERAGE.csv',
    'VALIDATION.json','SHA256SUMS.txt'
)
foreach($name in $required){if(!(Test-Path -LiteralPath (Join-Path $packet $name) -PathType Leaf)){throw "PACKET_REQUIRED_FILE_MISSING:$name"}}
$manifestLines=@(Get-Content -LiteralPath (Join-Path $packet 'SHA256SUMS.txt')|Where-Object{$_})
if($manifestLines.Count-ne($required.Count-1)){throw "PACKET_MANIFEST_ENTRY_COUNT_INVALID:$($manifestLines.Count)"}
$observed=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($line in $manifestLines){
    if($line-cnotmatch '^(?<hash>[a-f0-9]{64})  (?<name>[^\\/:]+)$'){throw "PACKET_MANIFEST_LINE_INVALID:$line"}
    $name=[string]$Matches.name;$hash=[string]$Matches.hash
    if(!$observed.Add($name)){throw "PACKET_MANIFEST_DUPLICATE:$name"}
    if($name-eq'SHA256SUMS.txt'){throw 'PACKET_MANIFEST_SELF_REFERENCE_REJECTED'}
    $path=Join-Path $packet $name
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw "PACKET_MANIFEST_TARGET_MISSING:$name"}
    if((Get-CanonicalLfSha256 $path)-cne$hash){throw "PACKET_HASH_MISMATCH:$name"}
}
$expected=@($required|Where-Object{$_-ne'SHA256SUMS.txt'}|Sort-Object)
if((@($observed|Sort-Object)-join"`n")-cne($expected-join"`n")){throw 'PACKET_MANIFEST_COVERAGE_INVALID'}
$validation=Get-Content -Raw -LiteralPath (Join-Path $packet 'VALIDATION.json')|ConvertFrom-Json
if([string]$validation.schema_version-ne'tsf_v1_structured_fulfillment_policy_hotfix_validation_v1'){throw 'PACKET_VALIDATION_SCHEMA_INVALID'}
$rows=@(Import-Csv -LiteralPath (Join-Path $packet 'EXECUTED_TEST_COVERAGE.csv'))
if($rows.Count-lt15-or@($rows|Where-Object{[string]::IsNullOrWhiteSpace($_.check)-or[string]::IsNullOrWhiteSpace($_.status)}).Count){throw 'PACKET_COVERAGE_CSV_INVALID'}
"TSF_STRUCTURED_FULFILLMENT_PACKET_SELF_CHECK_PASS files=$($required.Count) manifest_entries=$($manifestLines.Count) coverage_rows=$($rows.Count)"
