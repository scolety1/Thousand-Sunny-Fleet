[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$FleetGroup = "CellarFleet",

    [string[]]$Project = @(),

    [switch]$AllowDirty
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function ConvertTo-ProjectList {
    param([string[]]$Values)
    return @(
        $Values |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_ -split "," } |
            ForEach-Object { $_.Trim() } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

function Get-ConfigValue {
    param([object]$Object, [string]$Name, [object]$Default = "")
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Get-TaskPack {
    param([string]$Name)

    $commonGuardrails = "do not add backend, auth, payments, analytics, package/dependency changes, deployment config, real restaurant data, external services, generated output, or unrelated ships"
    switch ($Name) {
        "Bottlelight" {
            return @(
                "- [ ] User pain: guests need the wine list to feel like a real restaurant beverage program with pages of depth, not one compressed demo screen. Target: index.html or existing frontend entry files, src/components/WineListDemo.tsx, src/styles.css, docs/codex/SITE_MAP.md, docs/codex/visual-routes.json, docs/codex/INFORMATION_STAGING.md. Change: create a frontend-only page split or in-page route structure for Wine List, Pairings, Staff Picks, and Bottle Detail using the existing app pattern; make navigation feel like a restaurant menu, not app chrome. First screen: the guest wine list, staff pick, filters, and first pour choice stay dominant before route/page detail content. Remove/simplify: demote QR and manager/process notes behind a secondary page or detail control. Guardrails: $commonGuardrails. Acceptance: npm.cmd run build; powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dev\codex-fleet\product-truth-gate.ps1 -Repo . -Write. Check: mobile and desktop previews make Bottlelight feel like a deep live wine list with separate useful pages. [class:feature risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/ accept:npm.cmd run build]",
                "- [ ] User pain: the list needs a gorgeous editorial restaurant mood, not only functional rows. Target: src/components/WineListDemo.tsx, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: add one visual storytelling layer using existing CSS and fictional beverage data, such as a cellar note, vintage highlight, pairing spotlight, or selected bottle story that supports the current pour choice. First screen: wine choice and staff pick remain dominant while richer editorial detail opens after selection or scroll. Remove/simplify: remove one software/demo label or boxy control treatment that fights the menu feeling. Guardrails: $commonGuardrails. Acceptance: npm.cmd run build; powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dev\codex-fleet\product-truth-gate.ps1 -Repo . -Write. Check: the page feels visually stunning and useful to a guest choosing a bottle. [class:design risk:low mode:single impact:showpiece surface:public scope:src/,docs/codex/ accept:npm.cmd run build]"
            )
        }
        "UrbanKitchenSite" {
            return @(
                "- [ ] User pain: Urban Kitchen should feel like a complete restaurant website, not a single polished landing section. Target: index.html, src/styles.css, docs/codex/SITE_MAP.md, docs/codex/visual-routes.json, docs/codex/INFORMATION_STAGING.md. Change: create frontend-only separate page sections or routes for Home, Menu, Reservations, Private Dining, and Visit using existing patterns; make navigation calm and restaurant-grade. First screen: restaurant identity, food/beverage promise, and reserve/view-menu actions stay dominant before deeper pages. Remove/simplify: demote any generic demo explanation or repeated hero copy into no visible first-screen space. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: desktop and mobile previews feel like a real multi-page restaurant site. [class:feature risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: a visitor should see enough atmosphere and concrete dining detail to trust the restaurant before clicking. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: add a visually rich menu/visit/private-dining depth pass with fictional seasonal dishes, hours/location, and one reservation confidence cue while preserving first-screen calm. First screen: Urban Kitchen name, primary promise, and reserve/view-menu actions remain dominant before detail content. Remove/simplify: one decorative or vague phrase that does not help a guest choose to visit or reserve. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: the site has gorgeous hospitality depth without feeling like software. [class:design risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]"
            )
        }
        "ShiftLedger" {
            return @(
                "- [ ] User pain: managers need a service brief with real working depth, not a pretty single-card summary. Target: index.html, src/styles.css, docs/codex/SITE_MAP.md, docs/codex/visual-routes.json, docs/codex/INFORMATION_STAGING.md. Change: create frontend-only separate sections or routes for Tonight, Staffing, 86 List, Guest Notes, and Closing Handoff using existing static patterns. First screen: the one useful manager brief for tonight stays dominant before deeper operational pages. Remove/simplify: demote any generic dashboard or status label that does not help a manager run service. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview feels like a calm manager tool with real service depth. [class:feature risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the brief should feel alive during service, not like a static mock report. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: add one operationally useful depth layer such as handoff timing, section pressure, prep risk, or closing-note flow using fictional data only. First screen: the current service decision and priority note stay dominant before details. Remove/simplify: one redundant metric label, decorative wrapper, or vague manager phrase. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: a manager can see what to do next and where to drill in. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]"
            )
        }
        "OrderPilot" {
            return @(
                "- [ ] User pain: kitchen managers need the count-to-order workflow to feel complete, not just one sample count screen. Target: index.html, src/styles.css, docs/codex/SITE_MAP.md, docs/codex/visual-routes.json, docs/codex/INFORMATION_STAGING.md. Change: create frontend-only separate sections or routes for Count Sheet, Suggested Order, Vendor Prep, and Receiving Notes using existing static patterns. First screen: count rows, needed quantities, and suggest-order action stay dominant before vendor or receiving detail pages. Remove/simplify: demote one generic tool/product phrase or repeated header label. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview shows a useful restaurant ordering flow with real depth. [class:feature risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the suggested order needs stronger decision support than static rows. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: add a gorgeous but practical order-ready summary with fictional par gaps, priority items, and receiving notes that appears after or beside the suggest-order action. First screen: current count and next ordering action remain dominant before deeper vendor details. Remove/simplify: one vague operational phrase or low-value chrome element. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: a manager can understand what to order and why in under 10 seconds. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]"
            )
        }
        "EventBook" {
            return @(
                "- [ ] User pain: private dining should feel like a complete guest journey, not a single inquiry form. Target: index.html, src/styles.css, docs/codex/SITE_MAP.md, docs/codex/visual-routes.json, docs/codex/INFORMATION_STAGING.md. Change: create frontend-only separate sections or routes for Event Inquiry, Rooms, Menus, Timeline, and Host Follow-up using existing static patterns. First screen: event promise, date/party/occasion preview, and request-event action stay dominant before room/menu/timeline pages. Remove/simplify: demote one backend-sounding or tracker-like phrase from guest-facing space. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile and desktop previews feel like a real restaurant private dining site. [class:feature risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: guests need confidence that a host will follow up with a real plan. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: add a polished event-planning depth layer with fictional room fit, sample menu direction, and next-step timing while keeping the inquiry path short. First screen: inquiry preview and request-event action remain dominant before room/menu details. Remove/simplify: one generic form label, oversized wrapper, or internal note that weakens the guest experience. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: the page feels like a human event host will respond with a plan. [class:design risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]"
            )
        }
        "LineupLab" {
            return @(
                "- [ ] User pain: pre-shift training should feel like a working lineup system with depth, not one beautiful screen. Target: index.html, src/styles.css, docs/codex/SITE_MAP.md, docs/codex/visual-routes.json, docs/codex/INFORMATION_STAGING.md. Change: create frontend-only separate sections or routes for Today Lineup, Menu Notes, Role Drill, Quiz, and Manager Review using existing static patterns. First screen: today lineup, one service cue, and start-lineup action stay dominant before drills and review pages. Remove/simplify: demote one generic training/platform label or repeated header. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview feels like a real restaurant lineup tool with separate useful surfaces. [class:feature risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the lineup needs more operational magic after the first screen. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: add a polished drill or quiz depth layer with fictional menu notes, service language, and manager review cues that feels useful during pre-shift. First screen: the live lineup and primary action remain dominant before training details. Remove/simplify: one ornamental or vague phrase that makes the tool feel less restaurant-specific. Guardrails: $commonGuardrails. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: a manager can run a short pre-shift lineup from the page. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]"
            )
        }
        default { return @() }
    }
}

function Get-MagicMission {
    param([string]$Name, [string]$DemoName)

    return @"
# Magic Mission

Ship name: $Name
Demo name: $DemoName

Build this Cellar Fleet ship until it feels like a polished hospitality product, not a seed demo.

The desired end state is a gorgeous, useful, visually rich restaurant-grade surface with separate pages or clearly separated views, enough depth for a real operator or guest to understand the value, and a calm first screen that does one primary job beautifully.

Use fictional Urban Kitchen / Cellar & Table sample data only. Stay frontend-only. Favor real page/view depth, meaningful navigation, strong typography, restrained hospitality mood, and concrete service details over generic SaaS language or one-screen feature dumping.

Do not build backend, auth, payments, analytics, external services, production deployment, scraping, real restaurant data, or new dependencies unless explicitly approved.
"@
}

function Get-WorkPacks {
    param([string]$Name)

    return @"
# Work Packs

- Pack 1 - Hospitality Site Depth: ACTIVE
- Pack 2 - Visual Atmosphere And Useful Detail: PENDING
- Pack 3 - Mobile Proof And Final Polish: PENDING

## Pack 1 - Hospitality Site Depth

Goal: split overloaded one-page demos into real frontend-only pages, sections, tabs, or route-like views when that makes the product clearer.

Rules:
- first screen keeps one primary job dominant
- separate guest-facing pages from staff/internal tools
- update SITE_MAP.md and visual-routes.json when page/view structure changes
- no backend, dependencies, payments, auth, analytics, deployment, or real data

## Pack 2 - Visual Atmosphere And Useful Detail

Goal: add concrete hospitality detail, editorial rhythm, and operator/guest usefulness without crowding the first screen.

## Pack 3 - Mobile Proof And Final Polish

Goal: make the mobile and desktop previews look finished, legible, and ready to show.
"@
}

$resolvedConfig = Resolve-Path -LiteralPath $ConfigPath -ErrorAction SilentlyContinue
if (!$resolvedConfig) { Stop-WithMessage "Config not found: $ConfigPath" }

$parsed = Get-Content -LiteralPath $resolvedConfig.Path -Raw | ConvertFrom-Json
$projects = if ($parsed -is [array]) { @($parsed) } elseif ($parsed.PSObject.Properties.Name -contains "value") { @($parsed.value) } else { @($parsed) }
$selectedNames = @(ConvertTo-ProjectList -Values $Project)
$ships = @($projects | Where-Object {
    [string](Get-ConfigValue -Object $_ -Name "fleetGroup" -Default "") -eq $FleetGroup -and
    ($selectedNames.Count -eq 0 -or $selectedNames -contains [string](Get-ConfigValue -Object $_ -Name "name" -Default ""))
})

if ($ships.Count -eq 0) { Stop-WithMessage "No selected ships found." }

foreach ($ship in $ships) {
    $name = [string](Get-ConfigValue -Object $ship -Name "name" -Default "")
    $demoName = [string](Get-ConfigValue -Object $ship -Name "demoName" -Default $name)
    $repoValue = [string](Get-ConfigValue -Object $ship -Name "repo" -Default "")
    $repo = Resolve-Path -LiteralPath $repoValue -ErrorAction SilentlyContinue
    if (!$repo) {
        Write-Host "${name}: skipped, repo not found ($repoValue)" -ForegroundColor Yellow
        continue
    }

    Push-Location $repo.Path
    $dirty = @(git status --short 2>$null)
    if ($dirty.Count -gt 0 -and !$AllowDirty) {
        Write-Host "${name}: skipped, working tree dirty" -ForegroundColor Yellow
        Pop-Location
        continue
    }

    New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
    Set-Content -LiteralPath "docs/codex/MAGIC_MISSION.md" -Encoding UTF8 -Value (Get-MagicMission -Name $name -DemoName $demoName)
    Set-Content -LiteralPath "docs/codex/WORK_PACKS.md" -Encoding UTF8 -Value (Get-WorkPacks -Name $name)

    $queuePath = "docs/codex/TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $queuePath)) {
        Set-Content -LiteralPath $queuePath -Encoding UTF8 -Value "# Codex Task Queue`n`n## Tasks`n"
    }
    Add-Content -LiteralPath $queuePath -Encoding UTF8 -Value "`n## Cellar Showpiece Backlog $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    foreach ($task in @(Get-TaskPack -Name $name)) {
        Add-Content -LiteralPath $queuePath -Encoding UTF8 -Value $task
    }

    git add docs/codex/MAGIC_MISSION.md docs/codex/WORK_PACKS.md docs/codex/TASK_QUEUE.md | Out-Null
    $pending = @(git diff --cached --name-only)
    if ($pending.Count -gt 0) {
        git commit -m "Seed Cellar showpiece backlog" | Out-Host
    } else {
        Write-Host "${name}: no backlog changes to commit" -ForegroundColor DarkGray
    }
    Pop-Location
}
