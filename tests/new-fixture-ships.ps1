[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$OutputRoot = ".codex-local\fixtures",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$rootFullPath = [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $OutputRoot))
$allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $fleetRoot ".codex-local\fixtures"))

if (!$rootFullPath.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create fixtures outside ${allowedRoot}: $rootFullPath"
}

if ((Test-Path $rootFullPath) -and $Force) {
    Remove-Item -LiteralPath $rootFullPath -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $rootFullPath | Out-Null

function Invoke-Git {
    param(
        [string]$Repo,
        [string[]]$Arguments
    )

    & git -C $Repo @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $Repo"
    }
}

function Write-TextFile {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    Set-Content -Path $Path -Value $Lines
}

function New-FixtureRepo {
    param(
        [string]$Name,
        [string]$Profile,
        [string]$BuildDirectory,
        [string]$BuildCommand,
        [string[]]$VisualPaths,
        [switch]$RealProductLike,
        [switch]$DocsOnly
    )

    $repo = Join-Path $rootFullPath $Name
    New-Item -ItemType Directory -Force -Path $repo | Out-Null
    & git init -b main $repo | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git init failed for $repo"
    }
    Invoke-Git -Repo $repo -Arguments @("config", "user.email", "fixture@example.invalid")
    Invoke-Git -Repo $repo -Arguments @("config", "user.name", "Fixture Ship")

    Write-TextFile -Path (Join-Path $repo "docs\codex\MISSION.md") -Lines @(
        "# Fixture Mission",
        "",
        "Keep this fixture small, safe, and deterministic."
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\RUN_POLICY.md") -Lines @(
        "# Fixture Run Policy",
        "",
        "- Build command must stay local.",
        "- Do not touch secrets, auth, deploys, package files, or generated output."
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\TASK_QUEUE.md") -Lines @(
        "# Fixture Task Queue",
        "",
        "## Tasks",
        "",
        "- [ ] Fixture safe task: improve one line of fixture copy. Do not touch secrets, auth, deploys, dependencies, or generated output.",
        "  - [ ] Fixture indented task: prove whitespace-tolerant task parsing. Do not touch secrets, auth, deploys, dependencies, or generated output.",
        "- [x] Fixture completed task: already done."
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\NIGHTLY_REPORT.md") -Lines @(
        "# Fixture Nightly Report",
        "",
        "## Baseline",
        "",
        "- Build result: Passed"
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\CHECKPOINT_REVIEW.md") -Lines @(
        "# Checkpoint Review",
        "",
        "## Verdict",
        "GREEN",
        "",
        "## Recommended Next Step",
        "continue"
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\SIMON_DESIGN_REVIEW.md") -Lines @(
        "# Simon Design Review",
        "",
        "## Verdict",
        "GREEN",
        "",
        "## Stop Or Continue",
        "continue"
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\JOEY_SECURITY_REVIEW.md") -Lines @(
        "# Joey Security Review",
        "",
        "## Verdict",
        "GREEN",
        "",
        "## Recommended Next Step",
        "continue"
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\VISUAL_BUGS.md") -Lines @(
        "# Visual Bug Report",
        "",
        "## Findings",
        "",
        "- No visual bugs detected by automated inspection."
    )
    Write-TextFile -Path (Join-Path $repo "scripts\codex-guardrails.ps1") -Lines @(
        "param([string]`$Stage = '', [string]`$Task = '')",
        "Write-Host `"fixture guardrails `$Stage`"",
        "exit 0"
    )

    if ($DocsOnly) {
        Write-TextFile -Path (Join-Path $repo "README.md") -Lines @("# $Name", "", "Fixture docs repo.")
    } elseif ($RealProductLike) {
        Write-TextFile -Path (Join-Path $repo "app-vNext\src\app.txt") -Lines @("fixture app")
        Write-TextFile -Path (Join-Path $repo "app-vNext\scripts\build-ok.ps1") -Lines @("Write-Host 'fixture real-product build ok'", "exit 0")
    } else {
        Write-TextFile -Path (Join-Path $repo "src\app.txt") -Lines @("fixture app")
        Write-TextFile -Path (Join-Path $repo "scripts\build-ok.ps1") -Lines @("Write-Host 'fixture static build ok'", "exit 0")
    }

    Invoke-Git -Repo $repo -Arguments @("add", "--", ".")
    Invoke-Git -Repo $repo -Arguments @("commit", "-m", "fixture baseline")
    Invoke-Git -Repo $repo -Arguments @("checkout", "-b", "codex/fixture-ready")

    Add-Content -Path (Join-Path $repo "docs\codex\NIGHTLY_REPORT.md") -Value @(
        "",
        "## Fixture branch",
        "",
        "- Build result: Passed"
    )
    Invoke-Git -Repo $repo -Arguments @("add", "--", "docs/codex/NIGHTLY_REPORT.md")
    Invoke-Git -Repo $repo -Arguments @("commit", "-m", "fixture branch update")

    return [pscustomobject]@{
        name = $Name
        repo = $repo
        rounds = 2
        briefScript = "scripts\codex-brief.ps1"
        loopScript = "scripts\codex-night-loop.ps1"
        profile = $Profile
        buildDirectory = $BuildDirectory
        buildCommand = $BuildCommand
        models = [pscustomobject]@{
            implement = @("gpt-fixture-primary", "gpt-fixture-fallback")
            review = @("gpt-fixture-review")
            planner = @("gpt-fixture-planner")
            checkpoint = @("gpt-fixture-checkpoint")
            simon = @("gpt-fixture-simon")
        }
        timeouts = [pscustomobject]@{
            codex = 60
            implement = 60
            review = 60
            build = 60
            planner = 60
            checkpoint = 60
            simon = 60
            visual = 60
            joey = 60
            debug = 60
            guardrails = 60
            rateLimitCooldownSeconds = 60
            rateLimitMaxCooldowns = 1
        }
        visualPaths = $VisualPaths
    }
}

$ships = @()
$ships += New-FixtureRepo -Name "FixtureStaticDemo" -Profile "frontend-static-demo" -BuildDirectory "." -BuildCommand "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-ok.ps1" -VisualPaths @("/", "/demo")
$ships += New-FixtureRepo -Name "FixtureDocsOnly" -Profile "docs-only" -BuildDirectory "." -BuildCommand "" -VisualPaths @("/") -DocsOnly
$ships += New-FixtureRepo -Name "FixtureRealProduct" -Profile "real-product" -BuildDirectory "app-vNext" -BuildCommand "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-ok.ps1" -VisualPaths @("/", "/settings") -RealProductLike

$configPath = Join-Path $rootFullPath "projects.fixture.json"
@($ships) | ConvertTo-Json -Depth 12 | Set-Content -Path $configPath

Write-Host "Fixture ships ready: $rootFullPath" -ForegroundColor Green
Write-Host "Fixture config: $configPath" -ForegroundColor Green
