[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $repo 'tests\support\TsfPacketEvidencePath.ps1')
$script:assertions = 0

function Assert-Case([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (!$Condition) { throw "PACKET_EVIDENCE_PATH_TEST_FAILED: $Message" }
}

function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    $script:assertions++
    try { & $Action; throw 'EXPECTED_FAILURE_NOT_RAISED' }
    catch {
        if ($_.Exception.Message -eq 'EXPECTED_FAILURE_NOT_RAISED' -or $_.Exception.Message -notmatch $Pattern) {
            throw "PACKET_EVIDENCE_PATH_TEST_FAILED: $Message ($($_.Exception.Message))"
        }
    }
}

$fixtureRoot = Join-Path $repo ('.codex-local\fixtures\packet-evidence-path-' + [guid]::NewGuid().ToString('N'))
$resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
$allowedFixtureRoot = [IO.Path]::GetFullPath((Join-Path $repo '.codex-local\fixtures'))
if (!(Test-TsfPathWithinRoot -Path $resolvedFixture -Root $allowedFixtureRoot)) { throw 'FIXTURE_ROOT_OUTSIDE_ALLOWED_PATH' }
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
try {
    $stderrA = Join-Path $fixtureRoot 'a.stderr.txt'
    $stderrB = Join-Path $fixtureRoot 'b.stderr.txt'
    [IO.File]::WriteAllText($stderrA, '', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrB, 'bounded stderr', [Text.UTF8Encoding]::new($false))
    $relativeA = $stderrA.Substring($repo.Length + 1)
    Assert-Case ((Resolve-TsfPacketEvidencePath -Path $stderrA -RepositoryRoot $repo -ApprovedRoots @($repo)) -eq $stderrA) 'valid Windows absolute path was rejected'
    Assert-Case ((Resolve-TsfPacketEvidencePath -Path $relativeA -RepositoryRoot $repo -ApprovedRoots @($repo)) -eq $stderrA) 'valid repository-relative path was rejected'
    Assert-Case ((Resolve-TsfPacketEvidencePath -Path 'a.stderr.txt' -RepositoryRoot $fixtureRoot -ApprovedRoots @($fixtureRoot)) -eq $stderrA) 'valid evidence-root-relative path was rejected'
    Assert-Case ((Resolve-TsfPacketEvidencePath -Path '' -RepositoryRoot $repo -ApprovedRoots @($repo) -AllowBlank) -eq $null) 'explicitly permitted blank path was rejected'
    Assert-Throws { Resolve-TsfPacketEvidencePath -Path 'PER_COMMAND_STDERR_FILES_UNDER_C:\TSFDA4\evidence' -RepositoryRoot $repo -ApprovedRoots @($repo) } 'PROSE_OR_MALFORMED' 'classification prose was accepted as a path'
    Assert-Throws { Resolve-TsfPacketEvidencePath -Path 'C:malformed\file.txt' -RepositoryRoot $repo -ApprovedRoots @($repo) } 'PROSE_OR_MALFORMED' 'malformed drive path was accepted'
    Assert-Throws { Resolve-TsfPacketEvidencePath -Path "a`nfile.txt" -RepositoryRoot $fixtureRoot -ApprovedRoots @($fixtureRoot) } 'CONTROL_CHARACTER' 'newline-containing path was accepted'
    Assert-Throws { Resolve-TsfPacketEvidencePath -Path '..\outside.txt' -RepositoryRoot $fixtureRoot -ApprovedRoots @($fixtureRoot) } 'OUTSIDE_APPROVED_ROOT' 'path traversal was accepted'
    Assert-Throws { Resolve-TsfPacketEvidencePath -Path 'missing.stderr.txt' -RepositoryRoot $fixtureRoot -ApprovedRoots @($fixtureRoot) } 'FILE_MISSING' 'nonexistent evidence file was accepted'
    Assert-Throws { Resolve-TsfPacketEvidencePath -Path $fixtureRoot -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedType Leaf } 'FILE_MISSING' 'directory was accepted where a file is required'
    Assert-Throws { Resolve-TsfPacketEvidencePath -Path '' -RepositoryRoot $repo -ApprovedRoots @($repo) } 'PATH_EMPTY' 'blank path was accepted without an explicit disposition rule'

    $manifestPath = Join-Path $fixtureRoot 'manifest.json'
    $baseManifest = [ordered]@{
        schema_version = 'tsf_per_command_stderr_manifest_v1'
        suite_id = 'aggregate-suite'
        candidate_head = ('a' * 40)
        candidate_tree = ('b' * 40)
        aggregate_exit = 0
        status = 'PASS'
        evidence_root = $fixtureRoot
        entries = @(
            [ordered]@{ child_id='a'; stderr_path='a.stderr.txt'; stderr_sha256=Get-TsfPacketEvidenceHash $stderrA; exit_code=0; evidence_class='CHILD_PROCESS_STDERR' },
            [ordered]@{ child_id='b'; stderr_path='b.stderr.txt'; stderr_sha256=Get-TsfPacketEvidenceHash $stderrB; exit_code=0; evidence_class='CHILD_PROCESS_STDERR' }
        )
    }
    function Write-Manifest($Value) { [IO.File]::WriteAllText($manifestPath,($Value | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false)) }
    Write-Manifest $baseManifest
    $valid = Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40)
    Assert-Case ($valid.status -eq 'PASS' -and $valid.entry_count -eq 2) 'valid multi-file stderr manifest was rejected'

    $case = $baseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $case.entries[0].stderr_path = 'missing.stderr.txt'; Write-Manifest $case
    Assert-Throws { Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) } 'FILE_MISSING' 'manifest with missing child was accepted'
    $case = $baseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $case.entries[0].stderr_sha256 = ('0' * 64); Write-Manifest $case
    Assert-Throws { Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) } 'HASH_MISMATCH' 'manifest with changed child hash was accepted'
    $case = $baseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $case.entries[1].child_id = 'a'; Write-Manifest $case
    Assert-Throws { Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) } 'DUPLICATE_CHILD_ID' 'manifest with duplicate child id was accepted'
    $case = $baseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $case.entries[1].stderr_path = 'a.stderr.txt'; Write-Manifest $case
    Assert-Throws { Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) } 'DUPLICATE_CHILD_PATH' 'manifest with duplicate child path was accepted'
    $case = $baseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $case.entries[0].stderr_path = '..\escape.stderr.txt'; Write-Manifest $case
    Assert-Throws { Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) } 'OUTSIDE_APPROVED_ROOT' 'manifest child traversal was accepted'
    $case = $baseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $case.candidate_tree = ('c' * 40); Write-Manifest $case
    Assert-Throws { Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) } 'CANDIDATE_MISMATCH' 'stale candidate manifest was accepted'
    $case = $baseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $case.entries[0].exit_code = 'UNKNOWN'; Write-Manifest $case
    Assert-Throws { Test-TsfPerCommandStderrManifest -ManifestPath $manifestPath -RepositoryRoot $repo -ApprovedRoots @($repo) -ExpectedSuiteId 'aggregate-suite' -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) } 'EXIT_INVALID' 'invalid child exit classification was accepted'

    [pscustomobject]@{status='PASS';assertions=$script:assertions;schema_version='tsf_packet_evidence_path_tests_v1'} | ConvertTo-Json -Compress
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
