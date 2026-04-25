[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [ValidateSet("vite-react", "next-js", "express-api", "electron-desktop", "python-cli", "library-js", "test-harness")]
    [string]$ScaffoldType = "vite-react",

    [string]$Name = "",

    [ValidateSet("real-product", "frontend-static-demo", "docs-only", "experimental-prototype")]
    [string]$Profile = "frontend-static-demo",

    [ValidateSet("marketing-site", "full-stack-web", "desktop-app", "cli-tool", "library", "data-pipeline", "ai-workflow", "mobile-app", "game", "documentation", "sandbox-prototype")]
    [string]$ProjectType = "marketing-site",

    [ValidateSet("sandbox", "local-only", "staging", "production-adjacent", "production")]
    [string]$RiskTier = "local-only",

    [switch]$Register,

    [switch]$Force,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Test-ArchitectureApproved {
    param([string]$RepoPath)

    $approvalPath = Join-Path $RepoPath "docs\codex\ARCHITECTURE_APPROVAL.md"
    if (!(Test-Path -LiteralPath $approvalPath)) {
        return $false
    }

    $approval = Get-Content -LiteralPath $approvalPath -Raw
    return ($approval -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Value
    )

    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    if ((Test-Path -LiteralPath $Path) -and !$Force) {
        Stop-WithMessage "Refusing to overwrite existing file without -Force: $Path"
    }

    Set-Content -LiteralPath $Path -Value $Value
}

function Write-DependencyProposal {
    param(
        [string]$RepoPath,
        [string[]]$Dependencies
    )

    $proposalPath = Join-Path $RepoPath "docs\codex\DEPENDENCY_PROPOSAL.md"
    $approvalPath = Join-Path $RepoPath "docs\codex\DEPENDENCY_APPROVAL.md"
    $lines = @(
        "# Dependency Proposal",
        "",
        "Status: DRAFT",
        "",
        "## Proposed Dependencies",
        ""
    )
    foreach ($dependency in $Dependencies) {
        $lines += "- Name: $dependency"
        $lines += "  Purpose: Required by the approved scaffold."
        $lines += "  License: TODO"
        $lines += "  Maintenance status: TODO"
        $lines += "  Known risks: TODO"
        $lines += "  Alternatives: TODO"
    }
    $lines += ""
    $lines += "## Approval Notes"
    $lines += ""
    $lines += "- Human review required before package edits are treated as normal implementation work."

    Write-TextFile -Path $proposalPath -Value ($lines -join "`n")
    Write-TextFile -Path $approvalPath -Value @"
# Dependency Approval

Status: DRAFT
Approved by:
Approved at:

Notes:
- Change Status to APPROVED only after dependency review.
"@
}

function Write-Scaffold {
    param(
        [string]$RepoPath,
        [string]$AppName,
        [string]$Type
    )

    switch ($Type) {
        "vite-react" {
            Write-DependencyProposal -RepoPath $RepoPath -Dependencies @("@vitejs/plugin-react", "vite", "react", "react-dom")
            Write-TextFile -Path (Join-Path $RepoPath "package.json") -Value @"
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@vitejs/plugin-react": "latest",
    "vite": "latest",
    "react": "latest",
    "react-dom": "latest"
  },
  "devDependencies": {}
}
"@
            Write-TextFile -Path (Join-Path $RepoPath "index.html") -Value "<div id=`"root`"></div><script type=`"module`" src=`"/src/main.jsx`"></script>"
            Write-TextFile -Path (Join-Path $RepoPath "src\App.jsx") -Value "export default function App() {`n  return <main><h1>$AppName</h1></main>;`n}`n"
            Write-TextFile -Path (Join-Path $RepoPath "src\main.jsx") -Value "import React from 'react';`nimport { createRoot } from 'react-dom/client';`nimport App from './App.jsx';`ncreateRoot(document.getElementById('root')).render(<App />);`n"
        }
        "next-js" {
            Write-DependencyProposal -RepoPath $RepoPath -Dependencies @("next", "react", "react-dom")
            Write-TextFile -Path (Join-Path $RepoPath "package.json") -Value @"
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "latest",
    "react": "latest",
    "react-dom": "latest"
  },
  "devDependencies": {}
}
"@
            Write-TextFile -Path (Join-Path $RepoPath "app\layout.jsx") -Value "export default function RootLayout({ children }) {`n  return <html lang=`"en`"><body>{children}</body></html>;`n}`n"
            Write-TextFile -Path (Join-Path $RepoPath "app\page.jsx") -Value "export default function Page() {`n  return <main><h1>$AppName</h1></main>;`n}`n"
        }
        "express-api" {
            Write-DependencyProposal -RepoPath $RepoPath -Dependencies @("express")
            Write-TextFile -Path (Join-Path $RepoPath "package.json") -Value @"
{
  "scripts": {
    "dev": "node src/server.js",
    "start": "node src/server.js",
    "build": "node --check src/server.js"
  },
  "dependencies": {
    "express": "latest"
  },
  "devDependencies": {}
}
"@
            Write-TextFile -Path (Join-Path $RepoPath "src\server.js") -Value "const express = require('express');`nconst app = express();`napp.get('/health', (req, res) => res.json({ ok: true, app: '$AppName' }));`napp.listen(process.env.PORT || 3000);`n"
        }
        "electron-desktop" {
            Write-DependencyProposal -RepoPath $RepoPath -Dependencies @("electron")
            Write-TextFile -Path (Join-Path $RepoPath "package.json") -Value @"
{
  "main": "src/main.js",
  "scripts": {
    "dev": "electron .",
    "build": "node --check src/main.js && node --check src/renderer.js"
  },
  "dependencies": {
    "electron": "latest"
  },
  "devDependencies": {}
}
"@
            Write-TextFile -Path (Join-Path $RepoPath "index.html") -Value "<main><h1>$AppName</h1><script src=`"src/renderer.js`"></script></main>"
            Write-TextFile -Path (Join-Path $RepoPath "src\main.js") -Value "const { app, BrowserWindow } = require('electron');`nfunction createWindow() { new BrowserWindow({ width: 1000, height: 700 }).loadFile('index.html'); }`napp.whenReady().then(createWindow);`n"
            Write-TextFile -Path (Join-Path $RepoPath "src\renderer.js") -Value "console.log('$AppName ready');`n"
        }
        "python-cli" {
            Write-TextFile -Path (Join-Path $RepoPath "pyproject.toml") -Value "[project]`nname = `"$($AppName.ToLowerInvariant() -replace '[^a-z0-9_-]+','-')`"`nversion = `"0.1.0`"`n"
            Write-TextFile -Path (Join-Path $RepoPath "src\app.py") -Value "def main():`n    print('$AppName')`n`nif __name__ == '__main__':`n    main()`n"
        }
        "library-js" {
            Write-TextFile -Path (Join-Path $RepoPath "package.json") -Value @"
{
  "scripts": {
    "build": "node --check src/index.js",
    "test": "node --test"
  },
  "dependencies": {},
  "devDependencies": {}
}
"@
            Write-TextFile -Path (Join-Path $RepoPath "src\index.js") -Value "export function name() {`n  return '$AppName';`n}`n"
            Write-TextFile -Path (Join-Path $RepoPath "test\index.test.js") -Value "import test from 'node:test';`nimport assert from 'node:assert/strict';`nimport { name } from '../src/index.js';`ntest('name', () => assert.equal(name(), '$AppName'));`n"
        }
        "test-harness" {
            Write-TextFile -Path (Join-Path $RepoPath "README.md") -Value "# $AppName`n`nTest harness scaffold.`n"
            Write-TextFile -Path (Join-Path $RepoPath "tests\smoke.md") -Value "# Smoke Tests`n`n- [ ] Define the first smoke test.`n"
        }
    }
}

$repoFullPath = [System.IO.Path]::GetFullPath($Repo)
if (!(Test-Path -LiteralPath $repoFullPath)) {
    New-Item -ItemType Directory -Force -Path $repoFullPath | Out-Null
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = Split-Path -Leaf $repoFullPath
}

Push-Location $repoFullPath
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) {
    git init | Out-Null
}

if (!(Test-ArchitectureApproved -RepoPath $repoFullPath)) {
    Pop-Location
    Stop-WithMessage "Architecture is not approved. Run fleet-plan.ps1 first and set ARCHITECTURE_APPROVAL.md to Status: APPROVED after human review."
}

if ($ValidateOnly) {
    Pop-Location
    Write-Host "Scaffold gate passed for $Name ($ScaffoldType)." -ForegroundColor Green
    exit 0
}

$dirty = @(git status --porcelain)
if ($dirty.Count -gt 0 -and !$Force) {
    Pop-Location
    Write-Host "Repo has uncommitted changes. Re-run with -Force only if this scaffold should add to current work." -ForegroundColor Red
    $dirty | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Scaffold -RepoPath $repoFullPath -AppName $Name -Type $ScaffoldType

if (!(Test-Path -LiteralPath (Join-Path $repoFullPath "docs\codex\MISSION.md"))) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "install-harness.ps1") -Repo $repoFullPath -Profile $Profile -Force
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Stop-WithMessage "Harness install failed after scaffold."
    }
}
Pop-Location

if ($Register) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "add-project.ps1") -Name $Name -Repo $repoFullPath -Profile $Profile -ProjectType $ProjectType -RiskTier $RiskTier -Force -SkipInstall
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Project registration failed after scaffold."
    }
}

Write-Host "Scaffold written: $Name ($ScaffoldType)" -ForegroundColor Green
Write-Host "Dependency proposal is DRAFT when package dependencies were added." -ForegroundColor Yellow
exit 0
