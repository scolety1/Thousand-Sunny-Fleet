[CmdletBinding()]
param(
    [string]$EvidenceRoot = "docs/hq/tsf_canonical_runtime_final_publication_evidence_v1_20260711"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$root = [IO.Path]::GetFullPath((Join-Path $repo $EvidenceRoot))
$indexPath = Join-Path $root "PUBLICATION_EVIDENCE_INDEX.csv"
$script:assertions = 0

function Assert-PublicationEvidence {
    param([bool]$Condition,[string]$Id,[string]$Message)
    if(!$Condition){throw "FAIL $Id :: $Message"}
    $script:assertions++
    "PASS $Id :: $Message"
}

$rows = @(Import-Csv -LiteralPath $indexPath)
Assert-PublicationEvidence ($rows.Count -eq 36) "PE-INDEX-001" "36 indexed exact-byte records"

$expectedRuns = [ordered]@{
    "read-only" = "synthetic-tsf-readonly-appserver-correction-0001"
    "workspace-write" = "synthetic-tsf-workspace-appserver-correction-0001"
}
$requiredTypes = @("manifest","mission","preflight","role_preflight","worker_instruction","worker_result","adapter_result","verifier_result","event_journal","queue_document","prompt","stderr","usage","preservation_packet","durable_result","admission_receipt","transaction_receipt","final_queue_immutable_snapshot")

foreach($entry in $expectedRuns.GetEnumerator()){
    $runRows=@($rows|Where-Object{$_.run-eq$entry.Key})
    Assert-PublicationEvidence ($runRows.Count-eq18) "PE-$($entry.Key)-COUNT" "complete evidence set"
    Assert-PublicationEvidence (@($runRows|Where-Object{$_.mission_id-ne$entry.Value}).Count-eq0) "PE-$($entry.Key)-MISSION" "corrected mission identity only"
    $missingTypes=@($requiredTypes|Where-Object{$candidate=$_;@($runRows|Where-Object{$_.logical_type-eq$candidate}).Count-ne1})
    Assert-PublicationEvidence ($missingTypes.Count-eq0) "PE-$($entry.Key)-TYPES" "all required logical types present exactly once"
    Assert-PublicationEvidence (@($runRows|Where-Object{$_.mission_id-match'baseline|readonly-appserver-0001$|workspace-appserver-0001$'}).Count-eq0) "PE-$($entry.Key)-NO-BASELINE" "baseline runs cannot satisfy corrected lookup"
    foreach($row in $runRows){
        $path=[IO.Path]::GetFullPath((Join-Path $repo ([string]$row.tracked_path)))
        Assert-PublicationEvidence (Test-Path -LiteralPath $path -PathType Leaf) "PE-FILE-$($script:assertions+1)" "indexed file exists"
        $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-PublicationEvidence ($hash-eq[string]$row.expected_sha256-and$hash-eq[string]$row.recomputed_sha256) "PE-HASH-$($script:assertions+1)" "indexed hash matches copied bytes"
        Assert-PublicationEvidence ((Get-Item -LiteralPath $path).Length-eq[long]$row.size) "PE-SIZE-$($script:assertions+1)" "indexed size matches copied bytes"
        $gitRelative=([string]$row.tracked_path).Replace('\','/')
        $rawBlobOid=([string](& git -C $repo hash-object --no-filters -- $gitRelative)).Trim()
        $filteredBlobOid=([string](& git -C $repo hash-object --path=$gitRelative -- $gitRelative)).Trim()
        Assert-PublicationEvidence ($LASTEXITCODE-eq0-and$rawBlobOid-eq$filteredBlobOid) "PE-GIT-BYTES-$($script:assertions+1)" "Git attributes preserve exact evidence bytes"
    }
    $runDir=Join-Path $root $entry.Key
    $manifest=Get-Content -Raw (Join-Path $runDir "manifest.json")|ConvertFrom-Json
    foreach($artifact in @($manifest.artifacts)){
        $bound=@($runRows|Where-Object{$_.logical_type-eq[string]$artifact.logical_type})
        Assert-PublicationEvidence ($bound.Count-eq1-and[string]$bound[0].expected_sha256-eq[string]$artifact.sha256-and[long]$bound[0].size-eq[long]$artifact.size) "PE-MANIFEST-$($script:assertions+1)" "manifest record matches tracked artifact"
    }
    Assert-PublicationEvidence ((Get-FileHash (Join-Path $runDir "qd.json") -Algorithm SHA256).Hash-eq(Get-FileHash (Join-Path $runDir "final_queue_snapshot.json") -Algorithm SHA256).Hash) "PE-$($entry.Key)-QUEUE-SNAPSHOT" "immutable queue snapshot equals packet-bound queue document"
    $transaction=Get-Content -Raw (Get-ChildItem (Join-Path $runDir "r") -Filter "t-*.json"|Select-Object -First 1).FullName|ConvertFrom-Json
    Assert-PublicationEvidence ([string]$transaction.state-eq"COMMITTED"-and[string]$transaction.queue_state_to-eq"complete_ready_for_gate"-and[string]$transaction.mission_id-eq$entry.Value) "PE-$($entry.Key)-TRANSACTION" "transaction commits corrected mission and final queue state"
}

$trackedFiles=@($rows|ForEach-Object{
    $relative=[string]$_.tracked_path
    [IO.Path]::GetFullPath((Join-Path $repo $relative))
})
$badNames=@($trackedFiles|Where-Object{[IO.Path]::GetFileName($_)-match'(?i)(credential|secret|token|auth|config\.toml|\.env)'})
Assert-PublicationEvidence ($badNames.Count-eq0) "PE-SECRET-001" "no prohibited credential/auth filenames"
$secretHits=@(Select-String -LiteralPath $trackedFiles -Pattern 'sk-[A-Za-z0-9_-]{16,}|Bearer\s+[A-Za-z0-9._-]{16,}|api[_-]?key\s*[:=]\s*["'']?[A-Za-z0-9_-]{12,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' -AllMatches)
Assert-PublicationEvidence ($secretHits.Count-eq0) "PE-SECRET-002" "no prohibited secret-like content patterns"

[pscustomobject]@{schema_version="tsf_publication_evidence_test_result_v1";verdict="PASS";assertions=$script:assertions;runs=@($expectedRuns.Keys);indexed_files=$rows.Count;network_used=$false;live_task_run=$false}|ConvertTo-Json -Compress
