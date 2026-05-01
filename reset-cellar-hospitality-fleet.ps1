[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ArchiveRoot = "C:\Dev\_archived_cellar_fleet",
    [string]$ArchiveLabel = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

if ([string]::IsNullOrWhiteSpace($ArchiveLabel)) {
    $ArchiveLabel = "hospitality-mode-reset-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")
}

$archivePath = Join-Path $ArchiveRoot $ArchiveLabel
$ships = @(
    [ordered]@{
        Name = "ShiftLedger"
        Repo = "C:\Dev\cellar-manager-brief"
        Port = 5302
        DemoName = "Manager Daily Brief"
        Title = "Urban Kitchen Shift Brief"
        Eyebrow = "Manager brief"
        Headline = "Friday dinner brief"
        Lede = "One calm pre-shift page for what matters tonight: 86s, VIPs, staffing, and the notes the floor should hear before doors open."
        PrimaryAction = "Open tonight's brief"
        SecondaryAction = "Review details"
        Surface = "internal"
        TruthRequired = @("Urban Kitchen", "Friday dinner brief")
        TruthForbidden = @("Cellar & Table", "sample dashboard", "all-in-one platform")
        FirstScreenJob = "Show the manager's Friday dinner brief with three service-critical notes and one send/share action."
        PrimaryContent = "Friday dinner brief, three service notes, send/share mock action."
        SecondaryContent = "86 list, staffing notes, maintenance, carryover tasks."
        DetailContent = "VIP notes, private-party details, maintenance context, task history."
        Hidden = "Training library, long staff explanations, software sales copy, full dashboard grids."
        Task = "User pain: managers need a brief that feels like one useful handoff, not a giant dashboard. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: build an atmospheric phone-first Urban Kitchen manager brief with today's three most important notes and quiet detail buttons below. First screen: Friday dinner brief, three notes, and one send/share mock action stay dominant. Remove/simplify: remove dashboard language, long staff-only detail blocks, and repeated headers. Guardrails: no backend, no auth, no payments, no package or dependency files, no deployment config, no real customer data, and no unrelated ships. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview shows the brief first and details only after an obvious tap. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]"
    }
    [ordered]@{
        Name = "OrderPilot"
        Repo = "C:\Dev\cellar-orderpilot-lite"
        Port = 5303
        DemoName = "Count & Order Sheet"
        Title = "Urban Kitchen OrderPilot"
        Eyebrow = "Count sheet"
        Headline = "Count once. Order cleaner."
        Lede = "A narrow count sheet that opens to the shelf count, then turns par gaps into a suggested order without pretending to be a full inventory platform."
        PrimaryAction = "Start count"
        SecondaryAction = "See order summary"
        Surface = "internal"
        TruthRequired = @("Urban Kitchen", "Count once. Order cleaner.")
        TruthForbidden = @("Cellar & Table", "inventory platform", "all-in-one")
        FirstScreenJob = "Show a count-by-category workflow with pars, needed quantities, and a clear suggest-order action."
        PrimaryContent = "Produce, dry, and bar count rows with on-hand, par, needed, and suggest-order action."
        SecondaryContent = "Vendor summary, approval notes, last ordered date."
        DetailContent = "Line item notes, special notes, manager approval checklist."
        Hidden = "Full inventory claims, vendor theory, long operational explanation."
        Task = "User pain: kitchen managers need a count sheet that opens to the count, not a wall of ordering explanation. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: rebuild the first screen as a short count-by-category workflow with pars, needed quantities, and a clear suggest-order action. First screen: produce/dry/bar count rows and suggest order stay dominant. Remove/simplify: demote vendor notes, theory, and long manager explanations into a compact summary below. Guardrails: no backend, no auth, no payments, no package or dependency files, no deployment config, no real vendor data, and no unrelated ships. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview lets someone understand the count flow in under 30 seconds. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]"
    }
    [ordered]@{
        Name = "EventBook"
        Repo = "C:\Dev\cellar-private-events"
        Port = 5304
        DemoName = "Private Events Intake"
        Title = "Urban Kitchen Private Events"
        Eyebrow = "Private dining"
        Headline = "Stop losing event leads."
        Lede = "A guest-facing inquiry path for dinners, tastings, and office gatherings, with the internal follow-up work kept out of the first screen."
        PrimaryAction = "Request an event"
        SecondaryAction = "View room options"
        Surface = "public"
        TruthRequired = @("Urban Kitchen", "Stop losing event leads.")
        TruthForbidden = @("Cellar & Table", "all-in-one platform")
        FirstScreenJob = "Show a polished private dining inquiry path with date, party size, occasion, and request-event action."
        PrimaryContent = "Private dining promise, short form preview, request-event action."
        SecondaryContent = "Room options, event styles, sample handoff."
        DetailContent = "Lead tracker, follow-up status, staff event handoff."
        Hidden = "Internal tracker, backend-sounding language, staff notes on the guest first screen."
        Task = "User pain: owners need a private-events page that captures a lead quickly without exposing the internal tracker up front. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: create a beautiful Urban Kitchen private dining inquiry first screen with date, party size, occasion, and request-event action. First screen: event promise, short form preview, and request-event action stay dominant. Remove/simplify: hide follow-up statuses, staff notes, and backend-sounding language below the guest path. Guardrails: no backend, no auth, no payments, no package or dependency files, no deployment config, no real guest data, no real form submission, and no unrelated ships. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview feels like a restaurant event page first and a manager tool second. [class:design risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]"
    }
    [ordered]@{
        Name = "LineupLab"
        Repo = "C:\Dev\cellar-training-hub"
        Port = 5305
        DemoName = "Staff Training Hub"
        Title = "Urban Kitchen Lineup Lab"
        Eyebrow = "Lineup notes"
        Headline = "Training without the binder."
        Lede = "A pre-shift lineup page for the few notes staff actually need tonight, with deeper menu training kept one tap away."
        PrimaryAction = "Review lineup"
        SecondaryAction = "Open training cards"
        Surface = "internal"
        TruthRequired = @("Urban Kitchen", "Training without the binder.")
        TruthForbidden = @("Cellar & Table", "all-in-one platform", "LMS")
        FirstScreenJob = "Show today's three lineup notes and one quick acknowledge action before training cards."
        PrimaryContent = "Today's three menu/service notes and quick acknowledge action."
        SecondaryContent = "Wine basics, dish cards, allergy notes, service standard cards."
        DetailContent = "Deeper menu descriptions, pairing notes, staff quiz/check."
        Hidden = "Full training library, long lesson copy, LMS language."
        Task = "User pain: staff need today's lineup notes fast, not a full training library dumped onto the first page. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: make the first screen a concise pre-shift lineup with three menu/service notes and a quick acknowledge action. First screen: today's three notes and quick check action stay dominant. Remove/simplify: hide library explanations, long lesson copy, and secondary training modules until selected. Guardrails: no backend, no auth, no payments, no package or dependency files, no deployment config, no real staff data, no tracking, and no unrelated ships. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview shows today's lineup before any training-library content. [class:design risk:low mode:single impact:showpiece surface:internal scope:index.html,src/,docs/codex/]"
    }
    [ordered]@{
        Name = "UrbanKitchenSite"
        Repo = "C:\Dev\cellar-urban-kitchen-site"
        Port = 5306
        DemoName = "Normal Restaurant Website"
        Title = "Urban Kitchen | Dinner, Wine, Private Events"
        Eyebrow = "Neighborhood restaurant and wine room"
        Headline = "Dinner, wine, and private rooms without the noise."
        Lede = "A fake Urban Kitchen homepage that feels like a real restaurant first: menus, hours, reservations, and private dining, with software-demo language kept off the first screen."
        PrimaryAction = "View menus"
        SecondaryAction = "Reserve a table"
        Surface = "public"
        TruthRequired = @("Urban Kitchen", "View menus", "Private dining")
        TruthForbidden = @("Cellar & Table", "dashboard", "all-in-one platform")
        FirstScreenJob = "Show the restaurant identity, food/beverage promise, and reserve/view-menu actions."
        PrimaryContent = "Urban Kitchen brand, restaurant promise, view menus, reserve, and private dining action."
        SecondaryContent = "Menu preview, hours/location, private dining entry."
        DetailContent = "Menu sections, room details, contact/reservation info."
        Hidden = "Staff tools, dashboard language, workflow explanations, software-demo claims."
        Task = "User pain: a restaurant website should feel like a real place first, not a bundle of software demos. Target: index.html, src/styles.css, docs/codex/INFORMATION_STAGING.md. Change: create a polished Urban Kitchen customer-facing homepage with a restrained hospitality hero, menu preview, hours/location, private dining entry, and reservation/contact actions. First screen: restaurant identity, food/beverage promise, and reserve/view-menu actions stay dominant. Remove/simplify: remove dashboard language, internal workflow copy, and any staff-tool content from the public first screen. Guardrails: no backend, no auth, no payments, no package or dependency files, no deployment config, no generated build output, no real restaurant data beyond fake demo branding, and no unrelated ships. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1. Check: mobile preview looks like a normal restaurant site before revealing any operations tools. [class:design risk:low mode:single impact:showpiece surface:public scope:index.html,src/,docs/codex/]"
    }
)

$ports = @($ships | ForEach-Object { $_.Port })
$repos = @($ships | ForEach-Object { [regex]::Escape($_.Repo) })

Get-CimInstance Win32_Process |
    Where-Object {
        $cmd = [string]$_.CommandLine
        ($ports | Where-Object { $cmd -match "\b$_\b" }).Count -gt 0 -and
        ($repos | Where-Object { $cmd -match $_ }).Count -gt 0
    } |
    ForEach-Object {
        Write-Host "Stopping preview/reset process $($_.ProcessId): $($_.Name)"
        Stop-Process -Id $_.ProcessId -Force
    }

New-Item -ItemType Directory -Force -Path $archivePath | Out-Null

function Write-File {
    param(
        [string]$Path,
        [string]$Value
    )
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    Set-Content -LiteralPath $Path -Value $Value -Encoding UTF8
}

function New-StaticCheck {
    return @'
$ErrorActionPreference = "Stop"
if (!(Test-Path -LiteralPath ".\index.html")) { throw "Missing index.html" }
if (!(Test-Path -LiteralPath ".\src\styles.css")) { throw "Missing src/styles.css" }
$html = Get-Content -LiteralPath ".\index.html" -Raw
if ($html -notmatch "<!doctype html>") { throw "index.html is missing doctype" }
if ($html -notmatch "Urban Kitchen") { throw "index.html is missing Urban Kitchen demo branding" }
if ($html -match "Cellar & Table") { throw "index.html still contains Cellar & Table" }
Write-Host "Static check passed."
'@
}

function New-IndexHtml {
    param([hashtable]$Ship)
    return @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$($Ship.Title)</title>
    <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%23531422'/%3E%3Cpath d='M17 19h30v6H17zm4 11h22v6H21zm-4 11h30v6H17z' fill='%23f7efe2'/%3E%3C/svg%3E" />
    <link rel="stylesheet" href="/src/styles.css" />
  </head>
  <body>
    <header class="site-header">
      <a class="brand" href="#top">Urban Kitchen</a>
      <nav aria-label="Demo sections">
        <a href="#primary">$($Ship.PrimaryAction)</a>
        <a href="#details">$($Ship.SecondaryAction)</a>
      </nav>
    </header>
    <main id="top">
      <section class="hero" aria-labelledby="hero-title">
        <p class="eyebrow">$($Ship.Eyebrow)</p>
        <h1 id="hero-title">$($Ship.Headline)</h1>
        <p class="lede">$($Ship.Lede)</p>
        <div class="actions">
          <a class="button primary" href="#primary">$($Ship.PrimaryAction)</a>
          <a class="button" href="#details">$($Ship.SecondaryAction)</a>
        </div>
      </section>
      <section class="panel" id="primary">
        <p class="eyebrow">First useful moment</p>
        <h2>$($Ship.FirstScreenJob)</h2>
        <p>$($Ship.PrimaryContent)</p>
      </section>
      <section class="split" id="details">
        <article>
          <p class="eyebrow">Secondary</p>
          <h2>Available after the first decision.</h2>
          <p>$($Ship.SecondaryContent)</p>
        </article>
        <article>
          <p class="eyebrow">Details</p>
          <h2>Depth when the user asks.</h2>
          <p>$($Ship.DetailContent)</p>
        </article>
      </section>
    </main>
  </body>
</html>
"@
}

function New-StylesCss {
    return @'
:root {
  color: #2c1515;
  background: #f7efe2;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

* { box-sizing: border-box; }
body { margin: 0; background: #f7efe2; color: #2c1515; }
.site-header {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  padding: 1.1rem clamp(1rem, 4vw, 4rem);
  border-bottom: 1px solid rgba(83, 20, 34, 0.18);
  background: rgba(247, 239, 226, 0.92);
  backdrop-filter: blur(16px);
}
.brand {
  color: #2c1515;
  font-family: Georgia, serif;
  font-size: 1.3rem;
  font-weight: 800;
  text-decoration: none;
}
nav { display: flex; gap: 1rem; flex-wrap: wrap; }
nav a { color: #5b2b32; font-size: 0.9rem; font-weight: 700; text-decoration: none; }
.hero {
  min-height: 72vh;
  display: grid;
  align-content: end;
  padding: clamp(4rem, 10vw, 8rem) clamp(1.2rem, 6vw, 6rem);
  background:
    linear-gradient(120deg, rgba(44, 21, 21, 0.92), rgba(83, 20, 34, 0.84)),
    radial-gradient(circle at 78% 12%, rgba(221, 174, 96, 0.42), transparent 28%);
  color: #fff8ec;
}
.eyebrow {
  margin: 0 0 0.8rem;
  color: #c99548;
  font-size: 0.76rem;
  font-weight: 900;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}
h1, h2 {
  margin: 0;
  font-family: Georgia, "Times New Roman", serif;
  line-height: 0.96;
}
h1 {
  max-width: 12ch;
  font-size: clamp(3.3rem, 12vw, 7.8rem);
}
h2 {
  max-width: 12ch;
  font-size: clamp(2rem, 5vw, 4rem);
}
.lede {
  max-width: 42rem;
  margin: 1.35rem 0 0;
  font-size: clamp(1rem, 2vw, 1.28rem);
  line-height: 1.65;
}
.actions { display: flex; gap: 0.8rem; flex-wrap: wrap; margin-top: 2rem; }
.button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 2.9rem;
  padding: 0.8rem 1.1rem;
  border: 1px solid currentColor;
  border-radius: 999px;
  color: inherit;
  font-weight: 900;
  text-decoration: none;
}
.button.primary { border-color: #d7a654; background: #d7a654; color: #271112; }
.panel, .split {
  margin: 0 auto;
  max-width: 1120px;
  padding: clamp(3rem, 7vw, 6rem) clamp(1.2rem, 4vw, 2rem);
}
.panel {
  border-bottom: 1px solid rgba(83, 20, 34, 0.16);
}
.panel p, .split p {
  max-width: 38rem;
  font-size: 1.05rem;
  line-height: 1.65;
}
.split {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: clamp(1.2rem, 4vw, 3rem);
}
.split article {
  min-height: 18rem;
  padding: clamp(1.2rem, 3vw, 2rem);
  border: 1px solid rgba(83, 20, 34, 0.18);
  background: rgba(255, 251, 242, 0.62);
}
@media (max-width: 720px) {
  .site-header { align-items: flex-start; flex-direction: column; }
  .hero { min-height: 78vh; }
  .split { grid-template-columns: 1fr; }
}
'@
}

function New-OperatingMode {
    param([hashtable]$Ship)
    return @"
# Operating Mode

Project: $($Ship.Name)

Mode: hospitality-studio

Label: Hospitality Studio

Lead reviewer: Simon and Robin

## Done Standard

Feels like a real restaurant or restaurant tool: atmospheric, restrained, useful in 30 seconds, and not feature-dumped.

## Planning Rules

Start with reference-quality composition, surface type, first-screen contract, progressive disclosure, and exact user path before coding.

## First Screen Contract

Brand/place feeling, one clear promise, one primary action, and one beautiful preview. Secondary details must be behind navigation, buttons, tabs, accordions, drawers, or detail pages.

## Forbidden Patterns

No dashboard dump, no all-in-one claims, no internal staff notes on guest pages, no generic SaaS hero, no walls of explanatory copy.

## Required Gates

Simon visual/taste review, Robin concrete hospitality copy review, visual screenshot check, product truth gate, information staging gate.
"@
}

function New-ReferenceBrief {
    param([hashtable]$Ship)
    return @"
# Creative Reference Brief

Project: $($Ship.Name)

Mode: hospitality-studio

Demo: $($Ship.DemoName)

## Surface Type

$($Ship.Surface) hospitality demo. Choose one surface before coding and keep the first screen loyal to that surface.

## Reference Qualities

- Atmospheric, editorial hospitality composition.
- Strong first-screen mood before feature proof.
- Confident whitespace and typographic hierarchy.
- Main content partially revealed with obvious paths to more, not all shown at once.
- Public restaurant pages should feel like restaurant pages first; internal tools should feel like one calm service surface first.
- Borrow quality, restraint, and rhythm only. Do not copy layouts, wording, brand marks, menus, images, or trade dress from reference sites.

## Emotional Target

The page should feel calm, specific, restaurant-grade, and worth showing to a real operator.

## First Screen Rules

- Show brand/place feeling.
- Show one primary promise.
- Show one primary action.
- Show one beautiful preview or detail.
- Hide secondary workflows, staff-only context, and implementation explanation until the user asks.
- For wine/menu work, the list or menu is primary; chooser/help tools are clear secondary actions.
- For manager tools, the working brief/count/event/lineup is primary; deeper operational detail opens after selection.

## Forbidden Patterns

- Dashboard dump.
- All features visible at once.
- "Everything on one page" proof layouts.
- Generic SaaS hero.
- Double headers or wrapper chrome.
- Long AI-brochure copy.
- Internal staff notes on a guest-facing first screen.
- Restaurant pages that look like admin software.

## Acceptance Lens

A stranger should understand the main restaurant job in under 30 seconds without feeling overloaded.
"@
}

foreach ($ship in $ships) {
    $repo = $ship.Repo
    if (Test-Path -LiteralPath $repo) {
        $destination = Join-Path $archivePath (Split-Path $repo -Leaf)
        if (Test-Path -LiteralPath $destination) {
            if (!$Force) { throw "Archive destination exists: $destination. Pass -Force to overwrite." }
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        Move-Item -LiteralPath $repo -Destination $destination
        Write-Host "Archived $($ship.Name) -> $destination"
    }

    New-Item -ItemType Directory -Force -Path $repo | Out-Null
    Write-File -Path (Join-Path $repo "index.html") -Value (New-IndexHtml -Ship $ship)
    Write-File -Path (Join-Path $repo "src\styles.css") -Value (New-StylesCss)
    Write-File -Path (Join-Path $repo "scripts\codex-static-check.ps1") -Value (New-StaticCheck)
    Write-File -Path (Join-Path $repo "docs\codex\OPERATING_MODE.md") -Value (New-OperatingMode -Ship $ship)
    Write-File -Path (Join-Path $repo "docs\codex\REFERENCE_BRIEF.md") -Value (New-ReferenceBrief -Ship $ship)
    Write-File -Path (Join-Path $repo "docs\codex\PRODUCT_TRUTH.md") -Value @"
# Product Truth - $($ship.Name)

## Required Visible Text

$(($ship.TruthRequired | ForEach-Object { "- $_" }) -join "`n")

## Forbidden Visible Text

$(($ship.TruthForbidden | ForEach-Object { "- $_" }) -join "`n")
"@
    Write-File -Path (Join-Path $repo "docs\codex\INFORMATION_STAGING.md") -Value @"
# Information Staging

## Surface Split

Public/customer-facing surface: $(if ($ship.Surface -eq "public") { $ship.FirstScreenJob } else { "Optional public demo wrapper, not the main working surface." })

Working app/internal tool surface: $(if ($ship.Surface -eq "internal") { $ship.FirstScreenJob } else { "Internal follow-up details stay below or behind a clear action." })

Internal/admin-only surface: implementation notes, fake data caveats, setup context, and staff-only details.

Rule: do not blend these surfaces on the same first screen.

## First Screen Contract

First screen job: $($ship.FirstScreenJob)

Primary content: $($ship.PrimaryContent)

Secondary actions: $($ship.SecondaryContent)

Detail content: $($ship.DetailContent)

Not visible at first: $($ship.Hidden)

How deeper information opens: clear buttons, section navigation, tabs, accordions, drawers, or detail views.

## Progressive Disclosure Rules

- Show the main restaurant job first.
- Keep the first screen calm and editorial.
- Move secondary and staff-only information below or behind an intentional action.
- Do not prove every feature at once.
"@
    Write-File -Path (Join-Path $repo "docs\codex\TASK_QUEUE.md") -Value @"
# Task Queue

- [ ] $($ship.Task)
"@
    Write-File -Path (Join-Path $repo "docs\codex\MISSION.md") -Value @"
# Mission

Build a clean Hospitality Studio demo for $($ship.DemoName). The demo should feel like an actual Urban Kitchen example, not a generic software dashboard.
"@
    Write-File -Path (Join-Path $repo "docs\codex\RUN_POLICY.md") -Value @"
# Run Policy

Allowed scope: index.html, src/, scripts/codex-static-check.ps1, docs/codex/.

Forbidden scope: package/dependency files, backend, auth, payments, deployment config, generated build output, real customer data, and unrelated repos.

Acceptance command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1
"@
    Write-File -Path (Join-Path $repo "docs\codex\EVALUATORS.md") -Value @"
# Evaluators

## Build Evaluator

Command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1

Expected result: command exits 0.

## Visual Evaluator

Routes or screens to inspect: /

What must be visible: Urban Kitchen branding, one dominant first-screen promise, one primary action, and restrained hospitality design.

What must not happen: dashboard dump, duplicate headers, broken styling, generic SaaS hero, or walls of explanatory copy.
"@
    Write-File -Path (Join-Path $repo "docs\codex\PHASE_STATE.md") -Value @"
# Phase State

Current Phase: shape
Audience: Restaurant operator or staff user for $($ship.DemoName).
Product Promise: $($ship.Lede)
Primary Action: $($ship.PrimaryAction)
Showable Moment: $($ship.FirstScreenJob)
What Not To Build: dashboard dump, full platform, backend, auth, payments, package changes, deployment config.
No More Features Lock: false
Complexity Budget: one first-screen path and one secondary detail layer.
Before/After Judgment: page feels like a real restaurant-grade demo instead of a software feature sheet.
Human Taste Note: Use restrained hospitality/editorial inspiration without copying reference sites.
Phase Model Policy: budget
Parking State: ACTIVE
Evidence Required: static check and screenshot review.
Done Signal: first screen is calm, obvious, and useful in under 30 seconds.
Next Phase Criteria: primary surface is believable and not overloaded.
Repair Trigger:
Repair Return Phase:
"@

    Push-Location $repo
    try {
        git init | Out-Null
        git add .
        git commit -m "Seed hospitality mode reset" | Out-Null
    } finally {
        Pop-Location
    }
    Write-Host "Seeded $($ship.Name) at $repo"
}

Write-Host "Archive root: $archivePath"
