<#
.SYNOPSIS
    Feature pipeline: scaffold a spec folder OR create an issue from an existing spec.

.DESCRIPTION
    Two modes:

    INIT MODE (default): Creates the spec folder and opens Copilot CLI
    for interactive spec generation. This is the starting point.

      .\new-feature.ps1 -Name "001-dashboard" -Prompt "Build a trading dashboard"

    ISSUE MODE (-CreateIssue): Takes an existing spec folder that already has
    spec.md, plan.md, and tasks.md, commits it, and creates a GitHub issue.

      .\new-feature.ps1 -Name "001-dashboard" -CreateIssue

    Run INIT first, do your specify/plan/tasks interactively, then run ISSUE.

.PARAMETER Name
    Spec folder name (e.g. "001-dashboard"). Created under specs/.

.PARAMETER Prompt
    Feature description in natural language. Used to seed the spec folder
    and displayed as guidance for the /specify step.

.PARAMETER CreateIssue
    Switch to issue-creation mode. Expects specs/Name/ to already contain
    tasks.md (and ideally spec.md, plan.md).

.PARAMETER Repo
    Target GitHub repo in owner/repo format. Auto-detected if not specified.

.PARAMETER NoCopilot
    Don't assign the GitHub Copilot coding agent to the issue.

.EXAMPLE
    # Phase 1: Scaffold and start specifying
    .\new-feature.ps1 -Name "001-dashboard" -Prompt "Build a real-time trading dashboard"

    # ... do /specify, /plan, /tasks interactively in Copilot CLI ...

    # Phase 2: Create the issue from the completed spec
    .\new-feature.ps1 -Name "001-dashboard" -CreateIssue
#>

param(
    [Parameter(Mandatory)]
    [string]$Name,

    [string]$Prompt,

    [switch]$CreateIssue,

    [string]$Repo,

    [switch]$NoCopilot
)

$ErrorActionPreference = 'Stop'

# -- Validate we're in a stamped project --
if (-not (Test-Path ".specify/constitution.md")) {
    Write-Error "Not in a stamped project directory. Run from a project root with .specify/constitution.md"
    return
}

$specDir = "specs/$Name"

# ================================================================
# MODE: CREATE ISSUE
# ================================================================
if ($CreateIssue) {
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "  CREATE ISSUE FROM SPEC" -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Validate spec folder has tasks.md
    if (-not (Test-Path "$specDir/tasks.md")) {
        Write-Error "No tasks.md found in $specDir. Run the init phase first and complete /specify, /plan, /tasks."
        return
    }

    # Show what we found
    $specFiles = Get-ChildItem $specDir -File | Select-Object -ExpandProperty Name
    Write-Host "  Spec folder: $specDir" -ForegroundColor White
    Write-Host "  Files found: $($specFiles -join ', ')" -ForegroundColor White
    Write-Host ""

    # Commit spec files
    Write-Host "  [1/2] Committing spec files..." -ForegroundColor Yellow
    git add $specDir 2>$null
    $hasChanges = git diff --cached --name-only 2>$null
    if ($hasChanges) {
        git commit -m "feat: add spec $Name" --quiet 2>$null
        git push --quiet 2>$null
        Write-Host "  [1] Committed and pushed." -ForegroundColor Green
    } else {
        Write-Host "  [1] Already committed." -ForegroundColor Green
    }

    # Create issue via speckit-to-issue
    Write-Host ""
    Write-Host "  [2/2] Creating GitHub issue..." -ForegroundColor Yellow

    $specFolderFull = (Resolve-Path $specDir).Path
    $assignCopilotPython = if (-not $NoCopilot) { "True" } else { "False" }

    # Try MCP (direct Python call)
    $mcpResult = $null
    try {
        $mcpResult = python -c @"
from speckit_to_issue.mcp_server import create_feature_issue
result = create_feature_issue(
    spec_folder=r'$specFolderFull',
    repo='$Repo',
    assign_copilot=$assignCopilotPython,
    dry_run=False
)
print(result)
"@ 2>$null
    } catch { }

    if ($mcpResult -and $mcpResult -match "Issue created") {
        $mcpResult -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    } else {
        # Fallback to CLI
        Write-Host "    Using CLI fallback..." -ForegroundColor DarkGray
        $cliArgs = @("create", "$specDir/tasks.md")
        if (-not $NoCopilot) { $cliArgs += "--assign-copilot" }
        if ($Repo) { $cliArgs += "--repo"; $cliArgs += $Repo }
        speckit-to-issue @cliArgs 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }

    Write-Host "  [2] Issue created." -ForegroundColor Green

    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Green
    Write-Host "  DONE - Issue created and assigned to coding agent" -ForegroundColor Green
    Write-Host "  ================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  The coding agent will now:" -ForegroundColor White
    Write-Host "    1. Read the issue (full spec context)" -ForegroundColor DarkGray
    Write-Host "    2. Create a branch and implement" -ForegroundColor DarkGray
    Write-Host "    3. Open a PR for your review" -ForegroundColor DarkGray
    Write-Host ""
    return
}

# ================================================================
# MODE: INIT (scaffold + guide)
# ================================================================

if (-not $Prompt) {
    Write-Error "Provide -Prompt with your feature description, e.g.: -Prompt 'Build a real-time dashboard'"
    return
}

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "  NEW FEATURE - INIT" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""

# Create spec folder
if (Test-Path $specDir) {
    Write-Host "  Spec folder already exists: $specDir" -ForegroundColor DarkYellow
} else {
    New-Item -ItemType Directory -Path $specDir -Force | Out-Null
    Write-Host "  Created: $specDir" -ForegroundColor Green
}

# Write a seed prompt file so Copilot has context
$seedContent = @"
# Feature: $Name

## Prompt
$Prompt

## Instructions
Use /specify with the prompt above to generate the spec.
Then use /plan and /tasks to complete the specification.
Read .specify/constitution.md for project standards.
"@

$seedPath = "$specDir/prompt.md"
if (-not (Test-Path $seedPath)) {
    Set-Content -Path $seedPath -Value $seedContent
    Write-Host "  Created: $seedPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "  READY - Now generate the spec interactively" -ForegroundColor Green
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Your prompt:" -ForegroundColor White
Write-Host "    $Prompt" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Run these in Copilot CLI (gh copilot) or your agent:" -ForegroundColor White
Write-Host ""
Write-Host "    /specify $Prompt" -ForegroundColor DarkGray
Write-Host "    /plan" -ForegroundColor DarkGray
Write-Host "    /tasks" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Save outputs to:" -ForegroundColor White
Write-Host "    $specDir/spec.md" -ForegroundColor DarkGray
Write-Host "    $specDir/plan.md" -ForegroundColor DarkGray
Write-Host "    $specDir/tasks.md" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  When done, create the issue:" -ForegroundColor White
Write-Host "    .\new-feature.ps1 -Name `"$Name`" -CreateIssue" -ForegroundColor Cyan
Write-Host ""
