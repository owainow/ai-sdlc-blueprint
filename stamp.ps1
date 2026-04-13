<#
.SYNOPSIS
    Stamps a new project from the ai-sdlc-blueprint template.

.DESCRIPTION
    Copies the blueprint to a new directory, replaces all {{PLACEHOLDER}} tokens
    with project-specific values, initialises git, and optionally runs spec-kit init.

.PARAMETER ProjectName
    The name of the new project (kebab-case, e.g. "marketpulse-ai").

.PARAMETER Description
    A one-line description of the project.

.PARAMETER GitHubOrg
    The GitHub organisation or user (e.g. "owainow").

.PARAMETER OutputPath
    Where to create the project. Defaults to the current directory.

.PARAMETER SkipSpecKitInit
    Skip running 'specify init' after stamping.

.EXAMPLE
    .\stamp.ps1 -ProjectName "marketpulse-ai" -Description "AI-powered commodity trading intelligence platform" -GitHubOrg "owainow"
#>

param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [string]$Description,

    [Parameter(Mandatory)]
    [string]$GitHubOrg,

    [string]$OutputPath = (Get-Location).Path,

    [switch]$SkipSpecKitInit
)

$ErrorActionPreference = 'Stop'

$targetDir = Join-Path $OutputPath $ProjectName
$blueprintDir = $PSScriptRoot

# ── Guard ────────────────────────────────────────────
if (Test-Path $targetDir) {
    Write-Error "Directory '$targetDir' already exists. Aborting."
    return
}

Write-Host "`n  Stamping new project: $ProjectName" -ForegroundColor Cyan
Write-Host "  Target: $targetDir`n"

# ── Copy blueprint (exclude .git, stamp script, node_modules) ──
$excludeDirs = @('.git', 'node_modules', '.venv', '__pycache__')
$excludeFiles = @('stamp.ps1')

function Copy-Blueprint {
    param([string]$Source, [string]$Dest)

    Get-ChildItem -Path $Source -Force | ForEach-Object {
        $name = $_.Name
        if ($_.PSIsContainer) {
            if ($name -notin $excludeDirs) {
                $newDest = Join-Path $Dest $name
                New-Item -ItemType Directory -Path $newDest -Force | Out-Null
                Copy-Blueprint -Source $_.FullName -Dest $newDest
            }
        } else {
            if ($name -notin $excludeFiles) {
                $destFile = Join-Path $Dest $name
                Copy-Item $_.FullName -Destination $destFile -Force
            }
        }
    }
}

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Copy-Blueprint -Source $blueprintDir -Dest $targetDir

# ── Token replacement ────────────────────────────────
$replacements = @{
    '{{PROJECT_NAME}}'        = $ProjectName
    '{{PROJECT_DESCRIPTION}}' = $Description
    '{{GITHUB_ORG}}'          = $GitHubOrg
}

$textExtensions = @('.md', '.yml', '.yaml', '.json', '.bicep', '.bicepparam', '.ps1', '.sh', '.ts', '.js', '.py', '.toml', '.cfg', '.txt', '.env', '.dockerfile')

Get-ChildItem -Path $targetDir -Recurse -File | Where-Object {
    $textExtensions -contains $_.Extension.ToLower()
} | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $changed = $false
        foreach ($token in $replacements.Keys) {
            if ($content.Contains($token)) {
                $content = $content.Replace($token, $replacements[$token])
                $changed = $true
            }
        }
        if ($changed) {
            Set-Content $_.FullName -Value $content -NoNewline
            Write-Host "  Replaced tokens in: $($_.FullName.Replace($targetDir, '.'))" -ForegroundColor DarkGray
        }
    }
}

# ── Git init ─────────────────────────────────────────
Push-Location $targetDir
try {
    git init --quiet
    git add -A
    git commit -m "chore: initial stamp from ai-sdlc-blueprint" --quiet
    Write-Host "`n  Git repository initialised." -ForegroundColor Green
} finally {
    Pop-Location
}

# ── Spec Kit init (optional) ─────────────────────────
if (-not $SkipSpecKitInit) {
    Write-Host "`n  Running spec-kit init..." -ForegroundColor Yellow
    try {
        Push-Location $targetDir
        uvx --from "git+https://github.com/github/spec-kit.git" specify init $ProjectName 2>$null
        Write-Host "  Spec Kit initialised." -ForegroundColor Green
    } catch {
        Write-Host "  Spec Kit init skipped (not installed or failed). Run manually:" -ForegroundColor DarkYellow
        Write-Host "    uvx --from 'git+https://github.com/github/spec-kit.git' specify init $ProjectName" -ForegroundColor DarkGray
    } finally {
        Pop-Location
    }
}

# ── Summary ──────────────────────────────────────────
Write-Host "`n  ✓ Project '$ProjectName' stamped successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. cd $targetDir" -ForegroundColor DarkGray
Write-Host "    2. Update .specify/constitution.md with project-specific details" -ForegroundColor DarkGray
Write-Host "    3. gh copilot ""/specify <describe what you want to build>""" -ForegroundColor DarkGray
Write-Host "    4. speckit-to-issue create specs/001-feature/tasks.md --assign-copilot" -ForegroundColor DarkGray
Write-Host "    5. Push to GitHub: gh repo create $GitHubOrg/$ProjectName --push --source ." -ForegroundColor DarkGray
Write-Host ""
