<#
.SYNOPSIS
    Feature creation pipeline. Idea to GitHub issue in one command.

.DESCRIPTION
    Chains: specify -> plan -> tasks -> create issue (via speckit-to-issue).
    Run this from a stamped project directory.

    The pipeline creates a spec folder, generates the spec/plan/tasks using
    Copilot CLI, then creates a GitHub issue with full context.

    You can run interactively (review each stage) or automated (--Auto).

.PARAMETER Name
    Spec folder name (e.g. "001-dashboard", "002-auth"). Will be created
    under specs/.

.PARAMETER Prompt
    The feature description to pass to /specify. This is your idea in
    natural language.

.PARAMETER Auto
    Run all stages without pausing for review between steps.
    Default is interactive (pauses after specify, plan, and tasks).

.PARAMETER SkipIssue
    Generate the spec but don't create a GitHub issue. Useful for
    reviewing specs before pushing.

.PARAMETER Repo
    Target GitHub repo in owner/repo format. Auto-detected from git remote
    if not specified.

.PARAMETER NoCopilot
    Don't assign the GitHub Copilot coding agent to the issue.

.EXAMPLE
    .\new-feature.ps1 -Name "001-dashboard" -Prompt "Build a real-time commodity trading dashboard with event predictions"

.EXAMPLE
    .\new-feature.ps1 -Name "002-auth" -Prompt "Add Microsoft Entra ID authentication" -Auto

.EXAMPLE
    .\new-feature.ps1 -Name "003-api" -Prompt "Create REST API for event data" -SkipIssue
#>

param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Prompt,

    [switch]$Auto,

    [switch]$SkipIssue,

    [string]$Repo,

    [switch]$NoCopilot
)

$ErrorActionPreference = 'Stop'

# -- Validate we're in a stamped project --
if (-not (Test-Path ".specify/constitution.md")) {
    Write-Error "Not in a stamped project directory. Run from a project root that has .specify/constitution.md"
    return
}

$specDir = "specs/$Name"

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "  NEW FEATURE PIPELINE" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Spec:     $specDir" -ForegroundColor White
Write-Host "  Prompt:   $Prompt" -ForegroundColor White
Write-Host "  Mode:     $(if ($Auto) { 'Automated' } else { 'Interactive' })" -ForegroundColor White
Write-Host ""

# -- Create spec folder --
if (Test-Path $specDir) {
    Write-Host "  Spec folder already exists: $specDir" -ForegroundColor DarkYellow
} else {
    New-Item -ItemType Directory -Path $specDir -Force | Out-Null
}

# ================================================================
# STEP 1: Specify
# ================================================================
Write-Host "  [1/4] Running /specify..." -ForegroundColor Yellow
Write-Host "    Prompt: $Prompt" -ForegroundColor DarkGray
Write-Host ""

# Use Copilot CLI to generate the spec
$specifyPrompt = @"
/specify $Prompt

Save the output to $specDir/spec.md
"@

gh copilot -- $specifyPrompt 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

if (-not $Auto) {
    Write-Host ""
    Write-Host "  Review: $specDir/spec.md" -ForegroundColor Cyan
    $continue = Read-Host "  Continue to /plan? (Y/n)"
    if ($continue -eq 'n') {
        Write-Host "  Paused. Edit the spec and re-run with -Auto to continue." -ForegroundColor Yellow
        return
    }
}
Write-Host "  [1] Specify complete." -ForegroundColor Green

# ================================================================
# STEP 2: Plan
# ================================================================
Write-Host ""
Write-Host "  [2/4] Running /plan..." -ForegroundColor Yellow

$planPrompt = @"
/plan

Read the spec from $specDir/spec.md and the constitution from .specify/constitution.md.
Save the plan to $specDir/plan.md
"@

gh copilot -- $planPrompt 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

if (-not $Auto) {
    Write-Host ""
    Write-Host "  Review: $specDir/plan.md" -ForegroundColor Cyan
    $continue = Read-Host "  Continue to /tasks? (Y/n)"
    if ($continue -eq 'n') {
        Write-Host "  Paused. Edit the plan and re-run with -Auto to continue." -ForegroundColor Yellow
        return
    }
}
Write-Host "  [2] Plan complete." -ForegroundColor Green

# ================================================================
# STEP 3: Tasks
# ================================================================
Write-Host ""
Write-Host "  [3/4] Running /tasks..." -ForegroundColor Yellow

$tasksPrompt = @"
/tasks

Read the spec from $specDir/spec.md and plan from $specDir/plan.md.
Save the tasks to $specDir/tasks.md
"@

gh copilot -- $tasksPrompt 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

if (-not $Auto) {
    Write-Host ""
    Write-Host "  Review: $specDir/tasks.md" -ForegroundColor Cyan
    $continue = Read-Host "  Continue to create issue? (Y/n)"
    if ($continue -eq 'n') {
        Write-Host "  Paused. Edit the tasks and re-run with -Auto to continue." -ForegroundColor Yellow
        return
    }
}
Write-Host "  [3] Tasks complete." -ForegroundColor Green

# ================================================================
# STEP 4: Create GitHub Issue
# ================================================================
if ($SkipIssue) {
    Write-Host ""
    Write-Host "  [4/4] Skipped issue creation (--SkipIssue)." -ForegroundColor DarkYellow
} else {
    Write-Host ""
    Write-Host "  [4/4] Creating GitHub issue..." -ForegroundColor Yellow

    # Commit the spec files first so they're in the repo
    git add $specDir 2>$null
    git commit -m "feat: add spec $Name" --quiet 2>$null
    git push --quiet 2>$null

    # Build CLI args
    $issueArgs = @("create", "$specDir/tasks.md")
    if (-not $NoCopilot) { $issueArgs += "--assign-copilot" }
    if ($Repo) { $issueArgs += "--repo"; $issueArgs += $Repo }

    # Try MCP first (via direct Python call), fall back to CLI
    $specFolderFull = (Resolve-Path $specDir).Path
    $mcpResult = python -c "
from speckit_to_issue.mcp_server import create_feature_issue
result = create_feature_issue(
    spec_folder=r'$specFolderFull',
    repo='$Repo',
    assign_copilot=$(-not $NoCopilot ? '$true' : '$false').Replace('$true','True').Replace('$false','False'),
    dry_run=False
)
print(result)
" 2>$null

    if ($LASTEXITCODE -eq 0 -and $mcpResult -match "Issue created") {
        Write-Host "    $mcpResult" -ForegroundColor DarkGray
    } else {
        # Fallback to CLI
        Write-Host "    MCP not available, using CLI..." -ForegroundColor DarkGray
        speckit-to-issue @issueArgs 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }

    Write-Host "  [4] Issue created and assigned." -ForegroundColor Green
}

# ================================================================
# FINAL: Summary
# ================================================================
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "  FEATURE PIPELINE COMPLETE" -ForegroundColor Green
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Spec:    $specDir/" -ForegroundColor White
Write-Host "  Files:   spec.md, plan.md, tasks.md" -ForegroundColor White
if (-not $SkipIssue) {
    Write-Host "  Issue:   Created and assigned to coding agent" -ForegroundColor White
    Write-Host ""
    Write-Host "  The coding agent will now:" -ForegroundColor Cyan
    Write-Host "    1. Read the issue (full spec context)" -ForegroundColor DarkGray
    Write-Host "    2. Create a branch and implement" -ForegroundColor DarkGray
    Write-Host "    3. Open a PR for your review" -ForegroundColor DarkGray
}
Write-Host ""
