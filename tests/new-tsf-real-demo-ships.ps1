[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$OutputRoot = ".codex-local\tsf-real-demos",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$rootFullPath = [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $OutputRoot))
$allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $fleetRoot ".codex-local\tsf-real-demos"))

if (!$rootFullPath.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create TSF real demos outside ${allowedRoot}: $rootFullPath"
}

if ((Test-Path $rootFullPath) -and $Force) {
    Remove-Item -LiteralPath $rootFullPath -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $rootFullPath | Out-Null

function Invoke-Git {
    param([string]$Repo, [string[]]$Arguments)
    & git -C $Repo @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $Repo"
    }
}

function Write-TextFile {
    param([string]$Path, [string[]]$Lines)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    Set-Content -Path $Path -Value $Lines -Encoding UTF8
}

function New-StaticShip {
    param(
        [string]$Name,
        [string]$Title,
        [string]$Profile,
        [string]$Task,
        [string[]]$IndexLines,
        [switch]$HasJavaScript
    )

    $repo = Join-Path $rootFullPath $Name
    New-Item -ItemType Directory -Force -Path $repo | Out-Null
    & git init -b main $repo | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git init failed for $repo" }
    Invoke-Git -Repo $repo -Arguments @("config", "user.email", "tsf-demo@example.invalid")
    Invoke-Git -Repo $repo -Arguments @("config", "user.name", "TSF Demo Ship")

    Write-TextFile -Path (Join-Path $repo "README.md") -Lines @(
        "# $Title",
        "",
        "Disposable Thousand Sunny Fleet real-output demo ship.",
        "The fleet must turn this into a visible, screenshot-worthy localhost demo."
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\MISSION.md") -Lines @(
        "# Mission",
        "",
        "Build a real, visible, presentation-worthy demo. Blank pages, placeholder-only copy, or report-only changes do not count."
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\RUN_POLICY.md") -Lines @(
        "# Run Policy",
        "",
        "- Static/local only.",
        "- Do not add dependencies or package files.",
        "- Do not add backend, auth, payments, deployment config, secrets, or generated build output.",
        "- Real visible HTML/CSS/JS changes are required."
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\TASK_QUEUE.md") -Lines @(
        "# Task Queue",
        "",
        "## Tasks",
        "",
        "- [ ] $Task"
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\NIGHTLY_REPORT.md") -Lines @(
        "# Nightly Report",
        "",
        "- Baseline: tiny static shell.",
        "- Required outcome: real localhost demo with screenshot evidence."
    )
    Write-TextFile -Path (Join-Path $repo "docs\codex\CHECKPOINT_REVIEW.md") -Lines @("# Checkpoint Review", "", "## Verdict", "GREEN", "", "## Recommended Next Step", "continue")
    Write-TextFile -Path (Join-Path $repo "docs\codex\SIMON_DESIGN_REVIEW.md") -Lines @("# Simon Design Review", "", "## Verdict", "GREEN", "", "## Stop Or Continue", "continue")
    Write-TextFile -Path (Join-Path $repo "docs\codex\ROBIN_COPY_REVIEW.md") -Lines @("# Robin Copy Review", "", "## Verdict", "GREEN", "", "## Stop Or Continue", "continue")
    Write-TextFile -Path (Join-Path $repo "docs\codex\VISUAL_BUGS.md") -Lines @("# Visual Bugs", "", "- Baseline not inspected yet.")
    Write-TextFile -Path (Join-Path $repo "docs\codex\JOEY_SECURITY_REVIEW.md") -Lines @("# Security Review", "", "## Verdict", "GREEN")
    Write-TextFile -Path (Join-Path $repo "scripts\codex-static-check.ps1") -Lines @(
        '$ErrorActionPreference = "Stop"',
        '$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)',
        '$index = Join-Path $root "index.html"',
        '$style = Join-Path $root "style.css"',
        'if (!(Test-Path $index)) { throw "Missing index.html" }',
        'if (!(Test-Path $style)) { throw "Missing style.css" }',
        '$html = Get-Content $index -Raw',
        '$css = Get-Content $style -Raw',
        'if ($html.Length -lt 1500) { throw "index.html is too small to be a real demo" }',
        'if ($css.Length -lt 1200) { throw "style.css is too small to be a real design" }',
        'if ($html -notmatch "<main|<section") { throw "Missing semantic page structure" }',
        'Write-Host "TSF static demo check passed"'
    )
    Write-TextFile -Path (Join-Path $repo "index.html") -Lines $IndexLines
    if ($HasJavaScript) {
        Write-TextFile -Path (Join-Path $repo "app.js") -Lines @(
            "console.log('$Name seed');"
        )
    }
    Write-TextFile -Path (Join-Path $repo "style.css") -Lines @(
        ":root { color-scheme: light; }",
        "* { box-sizing: border-box; }",
        "body { margin: 0; font-family: Arial, sans-serif; background: #f7f1e7; color: #241610; }",
        "main { min-height: 100vh; padding: 48px; }",
        ".seed { max-width: 760px; padding: 32px; border: 1px solid #d9c9b0; background: #fffaf0; }",
        "h1 { margin: 0 0 16px; font-family: Georgia, serif; font-size: clamp(44px, 9vw, 96px); line-height: .92; }",
        "p { font-size: 18px; line-height: 1.55; }"
    )

    Invoke-Git -Repo $repo -Arguments @("add", "--", ".")
    Invoke-Git -Repo $repo -Arguments @("commit", "-m", "tsf real demo baseline")
    Invoke-Git -Repo $repo -Arguments @("checkout", "-b", "codex/tsf-real-demo")

    return [pscustomobject]@{
        name = $Name
        repo = $repo
        rounds = 99
        briefScript = "scripts\codex-brief.ps1"
        loopScript = "scripts\codex-night-loop.ps1"
        buildDirectory = "."
        buildCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1"
        visualServeDirectory = "."
        profile = $Profile
        projectType = "marketing-site"
        riskTier = "local-only"
        branchPrefix = "codex/$($Name.ToLowerInvariant())"
        cheapModelEligible = $true
        models = [pscustomobject]@{
            implement = @("gpt-5.5", "gpt-5.4")
            review = @("gpt-5.5", "gpt-5.4")
            planner = @("gpt-5.5", "gpt-5.4")
            checkpoint = @("gpt-5.5", "gpt-5.4")
            simon = @("gpt-5.5", "gpt-5.4")
            robin = @("gpt-5.5", "gpt-5.4")
        }
        timeouts = [pscustomobject]@{
            codex = 1800
            implement = 1800
            review = 900
            build = 300
            planner = 600
            checkpoint = 600
            simon = 600
            robin = 600
            visual = 900
            joey = 240
            debug = 240
            guardrails = 120
            rateLimitCooldownSeconds = 1800
            rateLimitMaxCooldowns = 2
        }
        visualPaths = @("/")
        capabilities = [pscustomobject]@{
            canEditPackageFiles = $false
            canAddDependencies = $false
            canEditBackendCode = $false
            canEditMigrations = $false
            canEditAuthPolicy = $false
            canEditDeploymentConfig = $false
            canUseNetworkApis = $false
            canOpenPullRequests = $false
            canDeploy = $false
        }
    }
}

$ships = @()
$ships += New-StaticShip -Name "TSF-SaffronLanding" -Title "Saffron Room Landing" -Profile "frontend-static-demo" -Task "Build a complete beautiful one-page restaurant/cafe website inspired by the warmth and editorial confidence of Dishoom without copying it. Must be startup-usable: immersive hero, menu/offers, private events or catering CTA, contact/location block, mobile-first responsive design, refined cream/burgundy/gold palette, large serif display type, rich but clear copy, and no blank/placeholder sections. Acceptance: index.html and style.css are real visible pages, local static check passes, visual screenshots show a polished desktop and mobile page. [class:design risk:low mode:single impact:visible scope:index.html,style.css,docs/codex/]" -IndexLines @(
    '<!doctype html>',
    '<html lang="en">',
    '<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Saffron Room</title><link rel="stylesheet" href="style.css"></head>',
    '<body><main><section class="seed"><p>Thousand Sunny Fleet Worker 1</p><h1>Saffron Room</h1><p>Turn this seed into a beautiful restaurant landing page with warmth, hospitality, and editorial polish.</p></section></main></body>',
    '</html>'
)
$ships += New-StaticShip -Name "TSF-ServiceBrief" -Title "Service Brief App" -Profile "frontend-static-demo" -Task "Build a complete phone-friendly interactive manager brief demo for restaurants. Must feel refined and useful, not wordy: today board, 86 list, VIP/private party notes, staffing gaps, carryover tasks, pre-shift talking points, and a mock Send Brief interaction with local JavaScript only. Use the same warm hospitality direction as the landing site but keep it app-like and scannable. Acceptance: actual interactive UI, clear mobile layout, no backend/dependencies, local static check passes, screenshots show useful product. [class:feature risk:low mode:single impact:visible scope:index.html,style.css,app.js,docs/codex/]" -HasJavaScript -IndexLines @(
    '<!doctype html>',
    '<html lang="en">',
    '<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Service Brief</title><link rel="stylesheet" href="style.css"></head>',
    '<body><main><section class="seed"><p>Thousand Sunny Fleet Worker 2</p><h1>Service Brief</h1><p>Turn this seed into an interactive manager shift brief app with useful sections and local interaction.</p></section></main><script src="app.js"></script></body>',
    '</html>'
)
$ships += New-StaticShip -Name "TSF-KeeperLab" -Title "Keeper Lab Dashboard" -Profile "real-product" -Task "Build a complete visible analytical dashboard demo for a fantasy keeper/drop model. Must include sample data, deterministic visible formulas, score table, recommendation labels, explanation panel, and a simple local JavaScript recalculation or filter/sort interaction. The page should look credible enough to show a professor: clean data table, formula cards, caveats, and no fake precision. Acceptance: index.html/style.css/app.js form a real dashboard, local static check passes, screenshots show analytical software not a blank report. [class:formula risk:medium mode:single impact:visible scope:index.html,style.css,app.js,docs/codex/]" -HasJavaScript -IndexLines @(
    '<!doctype html>',
    '<html lang="en">',
    '<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Keeper Lab</title><link rel="stylesheet" href="style.css"></head>',
    '<body><main><section class="seed"><p>Thousand Sunny Fleet Worker 3</p><h1>Keeper Lab</h1><p>Turn this seed into an analytical keeper/drop scoring dashboard with formulas, sample data, and visible decisions.</p></section></main><script src="app.js"></script></body>',
    '</html>'
)

$configPath = Join-Path $rootFullPath "projects.tsf-real.json"
@($ships) | ConvertTo-Json -Depth 14 | Set-Content -Path $configPath -Encoding UTF8

$manifest = [pscustomobject]@{
    experimentName = "thousand-sunny-real-output-demo"
    selectedShips = @("TSF-SaffronLanding", "TSF-ServiceBrief", "TSF-KeeperLab")
    workloadClass = "real-visible-website-software-demo"
    sharedTaskParameters = "Each ship must produce a real visible localhost page with screenshot evidence. Blank, placeholder-only, or docs-only output is failure."
    loopPhase = "shape"
    modelBudget = "balanced"
    batchSize = 1
    maxBatches = 4
    maxRuntimeMinutes = 300
    baselineSerialMinutes = 300
    reviewerCadence = [pscustomobject]@{
        visualInspectEvery = 1
        simonEvery = 1
        robinEvery = 1
        accessibilityEvery = 1
        performanceEvery = 1
        joeyEvery = 0
    }
    successCriteria = @(
        "All three TSF real demo ships produce actual visible pages.",
        "Screenshots exist for each ship.",
        "Local static checks pass.",
        "No real product ship is touched.",
        "Final report compares sequential baseline plan with parallel runtime and notes any repair overhead."
    )
    perShipRuntimeMinutes = [pscustomobject]@{
        "TSF-SaffronLanding" = 60
        "TSF-ServiceBrief" = 90
        "TSF-KeeperLab" = 150
    }
}
$manifestPath = Join-Path $rootFullPath "thousand-sunny-real-output-manifest.json"
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host "TSF real demo ships ready: $rootFullPath" -ForegroundColor Green
Write-Host "TSF real demo config: $configPath" -ForegroundColor Green
Write-Host "TSF real demo manifest: $manifestPath" -ForegroundColor Green
