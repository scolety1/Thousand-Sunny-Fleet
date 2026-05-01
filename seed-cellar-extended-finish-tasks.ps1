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

function Get-Tasks {
    param([string]$Name)

    $common = "Guardrails: frontend UI/copy/style only; no backend, auth, payments, analytics, dependencies, package files, deployment config, generated output, real restaurant data, new routes unless explicitly named, or unrelated files."

    switch ($Name) {
        "Bottlelight" {
            return @(
                "- [ ] User pain: Bottlelight is close, but it still needs a final guest-facing finish pass so the wine list feels worth lingering over, not just usable. Target: src/components/WineListDemo.tsx, src/styles.css, and docs/codex/INFORMATION_STAGING.md. Change: refine one above-the-fold hospitality moment and one below-the-fold bottle/detail moment so the guest can scan quickly, then discover richer pairing or bottle story without extra software chrome. First screen: Urban Kitchen wine list, staff pick, search/filter access, and first visible wine rows remain dominant before pairing stories, QR/table cues, or manager context. Remove/simplify: one remaining repeated label, helper wrapper, or explanation that competes with the list. $common Acceptance: npm.cmd run build; product truth gate stays GREEN. Check: mobile preview feels like a real restaurant wine list with a polished second layer. [class:design risk:low mode:single impact:showpiece surface:public scope:src/,docs/codex/ accept:npm.cmd run build]",
                "- [ ] User pain: the beverage page needs proof-quality mobile polish before it is called done. Target: src/components/WineListDemo.tsx and src/styles.css. Change: inspect the current mobile first screen and make one concrete readability or tap-target repair for wine rows, filter controls, staff-pick treatment, or selected-bottle detail. First screen: list scanning and first pour choice stay faster than help or detail exploration. Remove/simplify: one crowded mobile row, oversized helper block, or low-value decorative treatment; preserve content, filters, selected state, and anchors. $common Acceptance: npm.cmd run build; product truth gate stays GREEN. Check: 390px mobile has no clipped text and no obvious cramped wine row. [class:bugfix risk:low mode:single impact:visible surface:public scope:src/ accept:npm.cmd run build]"
            )
        }
        "UrbanKitchenSite" {
            return @(
                "- [ ] User pain: Urban Kitchen now has the right shape, but the restaurant still needs a final sense-of-place pass before it feels done. Target: index.html, src/styles.css, and docs/codex/INFORMATION_STAGING.md. Change: strengthen one concrete hospitality layer across menu, visit, or private dining using fictional details already consistent with Urban Kitchen, while keeping the homepage calm. First screen: restaurant name, short promise, View the menu, Reserve a table, and tonight cue stay dominant before deeper detail. Remove/simplify: one generic phrase, repeated eyebrow, or decorative wrapper that makes the site feel like a template. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile and desktop feel like a real restaurant site with richer depth after the first screen. [class:design risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the public site needs proof-quality polish so navigation and sections feel finished on phone. Target: index.html and src/styles.css. Change: make one mobile polish repair for nav spacing, CTA hit areas, menu card density, visit details, or private-dining cards. First screen: brand, promise, and primary actions stay visible sooner than section chrome. Remove/simplify: one cramped row, loud active state, repeated label, or oversized section gap; preserve anchors, current content, and desktop atmosphere. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: 390px mobile has comfortable tap targets and no first-screen visual clutter. [class:bugfix risk:low mode:single impact:visible surface:public scope:index.html,src/]"
            )
        }
        "ShiftLedger" {
            return @(
                "- [ ] User pain: ShiftLedger is strong, but it needs final manager-tool usefulness after the visual rescue. Target: index.html, src/styles.css, and docs/codex/INFORMATION_STAGING.md. Change: sharpen one operational detail layer such as closing handoff, staffing pressure, 86 list priority, or room-note escalation so a manager knows the next action during service. First screen: current service decision, three service-critical notes, Send brief, and next checks remain dominant before deeper detail. Remove/simplify: one vague manager phrase, redundant metric label, or decorative divider that slows scanning. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: the manager can identify the next operational action in under 10 seconds. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the manager brief needs proof-quality mobile polish after the density repair. Target: index.html and src/styles.css. Change: make one concrete mobile readability or tap-target repair for detail links, Send brief, next checks, service notes, or section navigation without adding new content. First screen: the brief and primary action remain quicker to read than secondary detail navigation. Remove/simplify: one cramped row, small touch target, or oversized spacing pocket; preserve current content and warm manager-brief mood. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: 390px mobile reads as a one-hand pre-service brief with comfortable controls. [class:bugfix risk:low mode:single impact:visible surface:internal scope:index.html,src/]"
            )
        }
        "OrderPilot" {
            return @(
                "- [ ] User pain: OrderPilot needs a final operator-confidence pass so the count-to-order flow feels like a tool someone would use before calling a vendor. Target: index.html, src/styles.css, and docs/codex/INFORMATION_STAGING.md. Change: strengthen one order decision layer such as par-gap summary, urgent items, vendor prep, or receiving note using fictional data only. First screen: count rows, needed quantities, and Start count/Suggest order remain dominant before vendor or receiving detail. Remove/simplify: one generic operations phrase, repeated status label, or decorative wrapper that does not help the order decision. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: a kitchen manager can see what to order and why in under 10 seconds. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the ordering tool needs proof-quality mobile polish so count rows and order actions are impossible to misread. Target: index.html and src/styles.css. Change: make one mobile repair for count-row labels, quantity alignment, CTA spacing, route pills, or receiving/vendor detail cards. First screen: labeled count records and primary order action stay dominant before detail pages. Remove/simplify: one cramped number row, small touch target, or over-loud route control; preserve current static sections and fictional sample data. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: 390px mobile has adjacent labels for quantities and no clipped controls. [class:bugfix risk:low mode:single impact:visible surface:internal scope:index.html,src/]"
            )
        }
        "EventBook" {
            return @(
                "- [ ] User pain: EventBook needs a final private-dining confidence pass so the guest believes a real host will shape the event. Target: index.html, src/styles.css, and docs/codex/INFORMATION_STAGING.md. Change: refine one guest-facing planning layer such as room fit, menu direction, timeline, or host follow-up so it feels elegant and concrete without lengthening the first screen. First screen: private dining promise, date/party/occasion cue, and Request event action remain dominant before room/menu/timeline detail. Remove/simplify: one form-instruction phrase, internal note, repeated label, or oversized wrapper. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile and desktop feel like a polished restaurant private-events page. [class:design risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the private-events page needs proof-quality mobile polish so inquiry details are easy to tap and scan. Target: index.html and src/styles.css. Change: make one mobile repair for the inquiry preview, Request event action, section navigation, room/menu cards, or timeline spacing. First screen: event promise, inquiry cue, and request action stay faster to read than deeper host details. Remove/simplify: one cramped card, small touch target, clipped label, or excessive vertical gap; preserve current sections and fictional event details. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: 390px mobile looks calm, tappable, and guest-facing. [class:bugfix risk:low mode:single impact:visible surface:public scope:index.html,src/]"
            )
        }
        "LineupLab" {
            return @(
                "- [ ] User pain: LineupLab needs a final manager-usefulness pass so it feels like a real pre-shift tool, not only a polished training page. Target: index.html, src/styles.css, and docs/codex/INFORMATION_STAGING.md. Change: strengthen one operational layer such as menu note, role drill, quiz result, or manager review cue with fictional service detail that helps run lineup. First screen: Urban Kitchen, tonight's lineup, three notes, Acknowledge lineup, and staff acknowledged status remain dominant before training details. Remove/simplify: one generic training phrase, repeated label, or decorative wrapper that does not help the manager run pre-shift. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: a manager can run a short pre-shift lineup from the page. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]",
                "- [ ] User pain: the lineup page needs proof-quality mobile polish after the nav/status repairs. Target: index.html and src/styles.css. Change: make one mobile repair for route labels, acknowledge/status pairing, note card density, quiz/drill cards, or manager-review spacing. First screen: tonight's lineup and acknowledge action stay easier to scan than secondary practice content. Remove/simplify: one cramped card, small touch target, clipped nav label, or loud active state; preserve current sections and fictional sample data. $common Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: 390px mobile has no clipped nav labels and the CTA/status relationship is obvious. [class:bugfix risk:low mode:single impact:visible surface:internal scope:index.html,src/]"
            )
        }
        default { return @() }
    }
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
    $queuePath = "docs/codex/TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $queuePath)) {
        Set-Content -LiteralPath $queuePath -Encoding UTF8 -Value "# Codex Task Queue`n`n## Tasks`n"
    }
    Add-Content -LiteralPath $queuePath -Encoding UTF8 -Value "`n## Cellar Extended Finish Run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    foreach ($task in @(Get-Tasks -Name $name)) {
        Add-Content -LiteralPath $queuePath -Encoding UTF8 -Value $task
    }

    git add docs/codex/TASK_QUEUE.md | Out-Null
    $pending = @(git diff --cached --name-only)
    if ($pending.Count -gt 0) {
        git commit -m "Seed Cellar extended finish tasks" | Out-Host
    } else {
        Write-Host "${name}: no task changes to commit" -ForegroundColor DarkGray
    }
    Pop-Location
}
