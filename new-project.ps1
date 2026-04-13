<#
.SYNOPSIS
    One-command project creation pipeline. Stamp, repo, Azure - all in one shot.

.DESCRIPTION
    Chains: stamp.ps1 -> gh repo create -> setup-azure.ps1
    Run this from the blueprint directory.

.PARAMETER ProjectName
    Project name in kebab-case (e.g. "marketpulse-ai").

.PARAMETER Description
    One-line project description.

.PARAMETER GitHubOrg
    GitHub organisation or username (e.g. "owainow").

.PARAMETER Location
    Azure region. Defaults to uksouth.

.PARAMETER OutputPath
    Where to create the project directory. Defaults to parent of blueprint dir.

.PARAMETER Visibility
    GitHub repo visibility: public or private. Defaults to public.

.PARAMETER SkipAzure
    Skip Azure provisioning (just stamp + create repo).

.PARAMETER SkipSpecKitInit
    Skip running specify init.

.EXAMPLE
    .\new-project.ps1 -ProjectName "marketpulse-ai" -Description "AI commodity intelligence" -GitHubOrg "owainow"

.EXAMPLE
    .\new-project.ps1 -ProjectName "my-app" -Description "My app" -GitHubOrg "owainow" -SkipAzure -Visibility "private"
#>

param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [string]$Description,

    [Parameter(Mandatory)]
    [string]$GitHubOrg,

    [string]$Location = "uksouth",

    [string]$OutputPath,

    [ValidateSet("public", "private")]
    [string]$Visibility = "public",

    [switch]$SkipAzure,

    [switch]$SkipSpecKitInit
)

$ErrorActionPreference = 'Stop'
$blueprintDir = $PSScriptRoot

if (-not $OutputPath) {
    $OutputPath = Split-Path $blueprintDir -Parent
}

$projectDir = Join-Path $OutputPath $ProjectName
$githubRepo = "$GitHubOrg/$ProjectName"

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "  NEW PROJECT PIPELINE" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Project:    $ProjectName" -ForegroundColor White
Write-Host "  Repo:       $githubRepo" -ForegroundColor White
Write-Host "  Location:   $Location" -ForegroundColor White
Write-Host "  Output:     $projectDir" -ForegroundColor White
Write-Host "  Azure:      $(if ($SkipAzure) { 'Skipped' } else { 'Yes' })" -ForegroundColor White
Write-Host ""

# ================================================================
# STEP 1: Stamp
# ================================================================
Write-Host "  [1/$(if ($SkipAzure) { '3' } else { '4' })] Stamping project..." -ForegroundColor Yellow

$stampArgs = @{
    ProjectName    = $ProjectName
    Description    = $Description
    GitHubOrg      = $GitHubOrg
    OutputPath     = $OutputPath
}
if ($SkipSpecKitInit) { $stampArgs['SkipSpecKitInit'] = $true }

& "$blueprintDir\stamp.ps1" @stampArgs

if (-not (Test-Path $projectDir)) {
    Write-Error "Stamp failed: $projectDir not created."
    return
}
Write-Host "  [1] Stamp complete." -ForegroundColor Green

# ================================================================
# STEP 2: Copy setup-azure.ps1 into the project (for future use)
# ================================================================
Copy-Item "$blueprintDir\setup-azure.ps1" -Destination $projectDir -Force
Copy-Item "$blueprintDir\new-feature.ps1" -Destination $projectDir -Force -ErrorAction SilentlyContinue

# ================================================================
# STEP 3: Create GitHub repo and push
# ================================================================
Write-Host ""
Write-Host "  [2/$(if ($SkipAzure) { '3' } else { '4' })] Creating GitHub repo..." -ForegroundColor Yellow

Push-Location $projectDir
try {
    $output = gh repo create $githubRepo --$Visibility --push --source . 2>&1
    $output | Where-Object { $_ -notmatch '^(To |remote:|\s*\*)' } | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
} finally {
    Pop-Location
}
Write-Host "  [2] GitHub repo created: https://github.com/$githubRepo" -ForegroundColor Green

# ================================================================
# STEP 3: Setup Azure (optional)
# ================================================================
if (-not $SkipAzure) {
    Write-Host ""
    Write-Host "  [3/4] Provisioning Azure resources..." -ForegroundColor Yellow

    & "$blueprintDir\setup-azure.ps1" -ProjectName $ProjectName -GitHubRepo $githubRepo -Location $Location

    Write-Host "  [3] Azure setup complete." -ForegroundColor Green

    # STEP 4: Summary
    $step = 4
} else {
    $step = 3
}

# ================================================================
# FINAL: Summary
# ================================================================
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "  [$step/$step] PROJECT READY" -ForegroundColor Green
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Project:  $projectDir" -ForegroundColor White
Write-Host "  Repo:     https://github.com/$githubRepo" -ForegroundColor White
if (-not $SkipAzure) {
    Write-Host "  Azure:    Resource groups, ACR, OIDC - all configured" -ForegroundColor White
    Write-Host "  CI/CD:    Push to main or open a PR to trigger deploy" -ForegroundColor White
}
Write-Host ""
Write-Host "  Next: create your first feature" -ForegroundColor Cyan
Write-Host "    cd $projectDir" -ForegroundColor DarkGray
Write-Host "    .\new-feature.ps1 -Name '001-dashboard' -Prompt 'Build a real-time dashboard'" -ForegroundColor DarkGray
Write-Host ""
