[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$OutRoot = ".\out\stage45-evidence",
    [string]$AuditId = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

if ([string]::IsNullOrWhiteSpace($AuditId)) {
    $AuditId = "stage45-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

function Resolve-LocalPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

$outFullRoot = Resolve-LocalPath $OutRoot
$evidenceRoot = Join-Path $outFullRoot $AuditId
if (Test-Path -LiteralPath $evidenceRoot) { throw "Evidence folder already exists: $evidenceRoot" }
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null

$fixtureRoot = Join-Path $evidenceRoot "fixture"
$repo = Join-Path $fixtureRoot "Ship"
New-Item -ItemType Directory -Force -Path (Join-Path $repo "docs\codex") | Out-Null
Push-Location $repo
try {
    git init | Out-Null
    git config user.email "codex@example.local"
    git config user.name "Codex Fleet Evidence"
    Set-Content -Path "README.md" -Value "stage 4.5 evidence fixture" -Encoding UTF8
    Set-Content -Path "docs/codex/TASK_QUEUE.md" -Value "# Task Queue" -Encoding UTF8
    git add README.md docs/codex/TASK_QUEUE.md
    git commit -m "init" | Out-Null
} finally {
    Pop-Location
}

$configPath = Join-Path $evidenceRoot "projects.fixture.json"
@([pscustomobject]@{ name = "Stage45Fixture"; repo = $repo }) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8
$head = [string](git -C $repo rev-parse --short HEAD)

$packetDir = Join-Path $evidenceRoot "packets"
$resultDir = Join-Path $evidenceRoot "validation-results"
New-Item -ItemType Directory -Force -Path $packetDir, $resultDir | Out-Null

$validTask = "- [ ] User pain: reviewer needs proof that safe packet ingestion works. Skill: fleet-evidence. Target: docs/codex/RUN_SUMMARY.md. Change: add one concise validation proof note. Guardrails: docs/codex only and no sensitive systems. Acceptance: packet ingestion report accepts this task. Proof: ingest JSON marks applied true. Stop if: repo state is missing or packet is stale. Check: powershell -NoProfile -ExecutionPolicy Bypass -File .\write-run-evidence.ps1 -Repo . [class:proof risk:low mode:single scope:docs/codex/]"
$forbiddenTask = "- [ ] User pain: unsafe packet tries to alter dependencies. Skill: fleet-evidence. Target: package.json. Change: add dependency without review. Guardrails: none. Acceptance: package changes. Proof: package file changes. Stop if: never. Check: npm install [class:proof risk:high mode:single scope:package.json]"

$packets = @(
    [pscustomobject]@{
        name = "accepted-valid"
        file = "accepted-valid.json"
        expectExit = 0
        body = [pscustomobject]@{
            packetId = "stage45-valid-" + [guid]::NewGuid().ToString("N")
            generatedAt = (Get-Date).ToUniversalTime().ToString("o")
            project = "Stage45Fixture"
            baseCommit = $head
            tasks = @([pscustomobject]@{ id = "valid-1"; title = "Accepted safe proof task"; checklistLine = $validTask })
        }
    },
    [pscustomobject]@{
        name = "rejected-stale"
        file = "rejected-stale.json"
        expectExit = 1
        body = [pscustomobject]@{
            packetId = "stage45-stale-" + [guid]::NewGuid().ToString("N")
            generatedAt = (Get-Date).ToUniversalTime().ToString("o")
            project = "Stage45Fixture"
            baseCommit = "stale"
            tasks = @([pscustomobject]@{ id = "stale-1"; title = "Stale packet"; checklistLine = $validTask })
        }
    },
    [pscustomobject]@{
        name = "rejected-malformed"
        file = "rejected-malformed.json"
        expectExit = 1
        body = [pscustomobject]@{
            packetId = "stage45-malformed-" + [guid]::NewGuid().ToString("N")
            generatedAt = (Get-Date).ToUniversalTime().ToString("o")
            project = "Stage45Fixture"
            baseCommit = $head
            tasks = @([pscustomobject]@{ id = "malformed-1"; title = "Malformed"; checklistLine = "- [ ] vague task" })
        }
    },
    [pscustomobject]@{
        name = "rejected-forbidden-scope"
        file = "rejected-forbidden-scope.json"
        expectExit = 1
        body = [pscustomobject]@{
            packetId = "stage45-forbidden-" + [guid]::NewGuid().ToString("N")
            generatedAt = (Get-Date).ToUniversalTime().ToString("o")
            project = "Stage45Fixture"
            baseCommit = $head
            tasks = @([pscustomobject]@{ id = "forbidden-1"; title = "Forbidden package edit"; checklistLine = $forbiddenTask })
        }
    }
)

$checks = [System.Collections.Generic.List[object]]::new()
foreach ($packetCase in $packets) {
    $packetPath = Join-Path $packetDir $packetCase.file
    $packetCase.body | ConvertTo-Json -Depth 10 | Set-Content -Path $packetPath -Encoding UTF8
    $resultPath = Join-Path $resultDir "$($packetCase.name).txt"
    $started = Get-Date
    $command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\ingest-task-packet.ps1 -PacketPath `"$packetPath`" -ConfigPath `"$configPath`" -Apply"
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "ingest-task-packet.ps1") -PacketPath $packetPath -ConfigPath $configPath -Apply *>&1
    $exit = $LASTEXITCODE
    $ended = Get-Date
    @(
        "Command: $command",
        "Expected exit: $($packetCase.expectExit)",
        "Actual exit: $exit",
        "",
        "Output:",
        ($output -join "`n")
    ) | Set-Content -Path $resultPath -Encoding UTF8
    $status = if ($exit -eq [int]$packetCase.expectExit) { "passed" } else { "failed" }
    $checks.Add([pscustomobject]@{
        name = $packetCase.name
        status = $status
        command = $command
        exitCode = $exit
        startedAt = $started.ToUniversalTime().ToString("o")
        endedAt = $ended.ToUniversalTime().ToString("o")
        durationSeconds = [Math]::Round(($ended - $started).TotalSeconds, 3)
        evidence = @(
            ("out/stage45-evidence/$AuditId/packets/" + $packetCase.file),
            ("out/stage45-evidence/$AuditId/validation-results/$($packetCase.name).txt")
        )
    }) | Out-Null
}

$duplicatePacket = Join-Path $packetDir "accepted-valid.json"
$duplicateResultPath = Join-Path $resultDir "rejected-duplicate.txt"
$startedDuplicate = Get-Date
$duplicateCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\ingest-task-packet.ps1 -PacketPath `"$duplicatePacket`" -ConfigPath `"$configPath`" -Apply"
$duplicateOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "ingest-task-packet.ps1") -PacketPath $duplicatePacket -ConfigPath $configPath -Apply *>&1
$duplicateExit = $LASTEXITCODE
$endedDuplicate = Get-Date
@(
    "Command: $duplicateCommand",
    "Expected exit: 1",
    "Actual exit: $duplicateExit",
    "",
    "Output:",
    ($duplicateOutput -join "`n")
) | Set-Content -Path $duplicateResultPath -Encoding UTF8
$checks.Add([pscustomobject]@{
    name = "rejected-duplicate"
    status = if ($duplicateExit -eq 1) { "passed" } else { "failed" }
    command = $duplicateCommand
    exitCode = $duplicateExit
    startedAt = $startedDuplicate.ToUniversalTime().ToString("o")
    endedAt = $endedDuplicate.ToUniversalTime().ToString("o")
    durationSeconds = [Math]::Round(($endedDuplicate - $startedDuplicate).TotalSeconds, 3)
    evidence = @(
        "out/stage45-evidence/$AuditId/packets/accepted-valid.json",
        "out/stage45-evidence/$AuditId/validation-results/rejected-duplicate.txt"
    )
}) | Out-Null

$checksPath = Join-Path $evidenceRoot "checks.json"
$checks | ConvertTo-Json -Depth 10 | Set-Content -Path $checksPath -Encoding UTF8

$summaryPath = Join-Path $evidenceRoot "STAGE45_EVIDENCE_SUMMARY.md"
@(
    "# Stage 4.5 Evidence Summary",
    "",
    "- Audit evidence ID: $AuditId",
    "- Fixture repo: $repo",
    "- Checks: $($checks.Count)",
    "- Passed checks: $(@($checks | Where-Object { $_.status -eq 'passed' }).Count)",
    "",
    "## Packet Cases",
    "",
    "- accepted-valid",
    "- rejected-stale",
    "- rejected-malformed",
    "- rejected-forbidden-scope",
    "- rejected-duplicate"
) | Set-Content -Path $summaryPath -Encoding UTF8

Write-Host "STAGE45_EVIDENCE: $evidenceRoot"
Write-Host "STAGE45_CHECKS: $checksPath"
