$ErrorActionPreference = 'Stop'

function Test-TsfPathWithinRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    $fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-TsfPacketEvidencePath {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string[]]$ApprovedRoots,
        [ValidateSet('Leaf', 'Container', 'Any')][string]$ExpectedType = 'Leaf',
        [switch]$AllowBlank
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ($AllowBlank) { return $null }
        throw 'PACKET_EVIDENCE_PATH_EMPTY'
    }
    if ($Path -match "[`r`n`0]") { throw 'PACKET_EVIDENCE_PATH_CONTAINS_CONTROL_CHARACTER' }
    if ($Path.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) { throw 'PACKET_EVIDENCE_PATH_CONTAINS_INVALID_CHARACTER' }

    $driveAbsolute = $Path -match '^[A-Za-z]:[\\/]'
    if ($Path.Contains(':') -and !$driveAbsolute) {
        throw 'PACKET_EVIDENCE_PATH_CONTAINS_PROSE_OR_MALFORMED_DRIVE_PREFIX'
    }

    try {
        $resolved = if ([IO.Path]::IsPathRooted($Path)) {
            [IO.Path]::GetFullPath($Path)
        } else {
            [IO.Path]::GetFullPath((Join-Path $RepositoryRoot ($Path.Replace('/', '\'))))
        }
    } catch {
        throw "PACKET_EVIDENCE_PATH_INVALID: $($_.Exception.Message)"
    }

    $approved = @($ApprovedRoots | Where-Object { Test-TsfPathWithinRoot -Path $resolved -Root $_ })
    if ($approved.Count -eq 0) { throw "PACKET_EVIDENCE_PATH_OUTSIDE_APPROVED_ROOT: $resolved" }

    if ($ExpectedType -eq 'Leaf' -and !(Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "PACKET_EVIDENCE_FILE_MISSING: $resolved"
    }
    if ($ExpectedType -eq 'Container' -and !(Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "PACKET_EVIDENCE_DIRECTORY_MISSING: $resolved"
    }
    if ($ExpectedType -eq 'Any' -and !(Test-Path -LiteralPath $resolved)) {
        throw "PACKET_EVIDENCE_PATH_MISSING: $resolved"
    }
    $resolved
}

function Get-TsfPacketEvidenceHash {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-TsfPerCommandStderrManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string[]]$ApprovedRoots,
        [Parameter(Mandatory)][string]$ExpectedSuiteId,
        [Parameter(Mandatory)][string]$ExpectedHead,
        [Parameter(Mandatory)][string]$ExpectedTree
    )

    $resolvedManifest = Resolve-TsfPacketEvidencePath -Path $ManifestPath -RepositoryRoot $RepositoryRoot -ApprovedRoots $ApprovedRoots -ExpectedType Leaf
    $manifest = Get-Content -LiteralPath $resolvedManifest -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ([string]$manifest.schema_version -ne 'tsf_per_command_stderr_manifest_v1') { throw 'STDERR_MANIFEST_SCHEMA_INVALID' }
    if ([string]$manifest.suite_id -ne $ExpectedSuiteId) { throw 'STDERR_MANIFEST_SUITE_ID_MISMATCH' }
    if ([string]$manifest.candidate_head -ne $ExpectedHead -or [string]$manifest.candidate_tree -ne $ExpectedTree) { throw 'STDERR_MANIFEST_CANDIDATE_MISMATCH' }
    if ([int]$manifest.aggregate_exit -ne 0 -or [string]$manifest.status -ne 'PASS') { throw 'STDERR_MANIFEST_AGGREGATE_NOT_PASS' }

    $evidenceRoot = Resolve-TsfPacketEvidencePath -Path ([string]$manifest.evidence_root) -RepositoryRoot $RepositoryRoot -ApprovedRoots $ApprovedRoots -ExpectedType Container
    $entries = @($manifest.entries)
    if ($entries.Count -eq 0) { throw 'STDERR_MANIFEST_ENTRIES_EMPTY' }
    if (@($entries.child_id | Sort-Object -Unique).Count -ne $entries.Count) { throw 'STDERR_MANIFEST_DUPLICATE_CHILD_ID' }
    $seenPaths = @{}
    foreach ($entry in $entries) {
        $relative = [string]$entry.stderr_path
        if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains(':')) { throw 'STDERR_MANIFEST_CHILD_PATH_NOT_RELATIVE' }
        $candidate = Join-Path $evidenceRoot ($relative.Replace('/', '\'))
        $resolvedChild = Resolve-TsfPacketEvidencePath -Path $candidate -RepositoryRoot $RepositoryRoot -ApprovedRoots @($evidenceRoot) -ExpectedType Leaf
        if ($seenPaths.ContainsKey($resolvedChild)) { throw 'STDERR_MANIFEST_DUPLICATE_CHILD_PATH' }
        $seenPaths[$resolvedChild] = $true
        if ([string]$entry.stderr_sha256 -notmatch '^[a-f0-9]{64}$') { throw 'STDERR_MANIFEST_CHILD_HASH_INVALID' }
        if ((Get-TsfPacketEvidenceHash -Path $resolvedChild) -ne [string]$entry.stderr_sha256) { throw "STDERR_MANIFEST_CHILD_HASH_MISMATCH: $($entry.child_id)" }
        $exitText = [string]$entry.exit_code
        if ($exitText -notmatch '^-?[0-9]+$' -and $exitText -notmatch '^EXIT_[A-Z0-9_]+$') { throw 'STDERR_MANIFEST_CHILD_EXIT_INVALID' }
        if ([string]::IsNullOrWhiteSpace([string]$entry.evidence_class)) { throw 'STDERR_MANIFEST_CHILD_CLASSIFICATION_MISSING' }
    }

    [pscustomobject]@{
        status = 'PASS'
        manifest_path = $resolvedManifest
        manifest_sha256 = Get-TsfPacketEvidenceHash -Path $resolvedManifest
        entry_count = $entries.Count
        evidence_root = $evidenceRoot
    }
}
