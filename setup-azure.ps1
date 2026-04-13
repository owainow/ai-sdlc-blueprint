<#
.SYNOPSIS
    Provisions Azure resources and configures GitHub secrets for a stamped project.

.DESCRIPTION
    Run this ONCE after stamping a project. It creates:
    - Azure Container Registry (shared across environments)
    - Resource groups for dev, staging, and prod
    - Entra ID app registration with OIDC federation for GitHub Actions
    - Role assignments (Contributor on RGs, AcrPush on ACR)
    - GitHub secrets and variables so the CI/CD workflows work immediately

    Prerequisites:
    - Azure CLI authenticated: az login
    - GitHub CLI authenticated: gh auth login
    - Sufficient permissions: Owner or Contributor + User Access Admin on the subscription
    - The GitHub repo must already exist (run stamp.ps1 first, then gh repo create)

.PARAMETER ProjectName
    The project name (must match what you passed to stamp.ps1).

.PARAMETER GitHubRepo
    The GitHub repo in owner/repo format (e.g. "owainow/my-app").

.PARAMETER Location
    Azure region. Defaults to uksouth.

.PARAMETER SubscriptionId
    Azure subscription ID. Defaults to current az CLI subscription.

.PARAMETER SkipInfraProvision
    Skip creating resource groups and ACR (useful if they already exist).

.EXAMPLE
    .\setup-azure.ps1 -ProjectName "my-app" -GitHubRepo "owainow/my-app"

.EXAMPLE
    .\setup-azure.ps1 -ProjectName "my-app" -GitHubRepo "owainow/my-app" -Location "eastus2"
#>

param(
    [Parameter(Mandatory)]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [string]$GitHubRepo,

    [string]$Location = "uksouth",

    [string]$SubscriptionId,

    [switch]$SkipInfraProvision
)

$ErrorActionPreference = 'Stop'

# ── Colours ──────────────────────────────────────────
function Write-Step  { param([string]$msg) Write-Host "`n  ▸ $msg" -ForegroundColor Cyan }
function Write-Done  { param([string]$msg) Write-Host "    ✓ $msg" -ForegroundColor Green }
function Write-Skip  { param([string]$msg) Write-Host "    – $msg (skipped)" -ForegroundColor DarkYellow }
function Write-Info  { param([string]$msg) Write-Host "    $msg" -ForegroundColor DarkGray }

# ── Preflight checks ────────────────────────────────
Write-Host "`n  Azure Setup for: $ProjectName" -ForegroundColor White
Write-Host "  GitHub Repo:     $GitHubRepo" -ForegroundColor White
Write-Host "  Region:          $Location`n" -ForegroundColor White

# Check az CLI
try { $null = az account show 2>$null } catch {
    Write-Error "Azure CLI not authenticated. Run 'az login' first."
    return
}

# Check gh CLI
try { $null = gh auth status 2>$null } catch {
    Write-Error "GitHub CLI not authenticated. Run 'gh auth login' first."
    return
}

# Check repo exists
$repoCheck = gh repo view $GitHubRepo --json name 2>$null
if (-not $repoCheck) {
    Write-Error "GitHub repo '$GitHubRepo' not found. Create it first: gh repo create $GitHubRepo --push --source ."
    return
}

# ── Resolve subscription ────────────────────────────
if (-not $SubscriptionId) {
    $SubscriptionId = (az account show --query id -o tsv)
}
$TenantId = (az account show --query tenantId -o tsv)

Write-Info "Subscription: $SubscriptionId"
Write-Info "Tenant:       $TenantId"

# ── Naming ───────────────────────────────────────────
$acrName     = ($ProjectName -replace '[^a-zA-Z0-9]', '') + "acr"
$appName     = "$ProjectName-github-oidc"
$rgShared    = "rg-$ProjectName-shared"
$rgDev       = "rg-$ProjectName-dev"
$rgStaging   = "rg-$ProjectName-staging"
$rgProd      = "rg-$ProjectName-prod"
$environments = @(
    @{ Name = "dev";     RG = $rgDev }
    @{ Name = "staging"; RG = $rgStaging }
    @{ Name = "prod";    RG = $rgProd }
)

# ══════════════════════════════════════════════════════
# STEP 1: Resource Groups
# ══════════════════════════════════════════════════════
Write-Step "Creating resource groups"

if (-not $SkipInfraProvision) {
    foreach ($rg in @($rgShared, $rgDev, $rgStaging, $rgProd)) {
        $exists = az group exists --name $rg 2>$null
        if ($exists -eq "true") {
            Write-Skip "$rg (already exists)"
        } else {
            az group create --name $rg --location $Location --output none
            Write-Done "$rg"
        }
    }
} else {
    Write-Skip "All resource groups (--SkipInfraProvision)"
}

# ══════════════════════════════════════════════════════
# STEP 2: Azure Container Registry
# ══════════════════════════════════════════════════════
Write-Step "Creating Azure Container Registry: $acrName"

if (-not $SkipInfraProvision) {
    $acrExists = az acr show --name $acrName --query name -o tsv 2>$null
    if ($acrExists) {
        Write-Skip "$acrName (already exists)"
    } else {
        az acr create `
            --name $acrName `
            --resource-group $rgShared `
            --sku Basic `
            --admin-enabled false `
            --location $Location `
            --output none
        Write-Done "$acrName created in $rgShared"
    }
} else {
    Write-Skip "ACR (--SkipInfraProvision)"
}

# ══════════════════════════════════════════════════════
# STEP 3: Entra ID App Registration + Service Principal
# ══════════════════════════════════════════════════════
Write-Step "Creating Entra ID app registration: $appName"

$existingApp = az ad app list --display-name $appName --query "[0].appId" -o tsv 2>$null
if ($existingApp) {
    $clientId = $existingApp
    Write-Skip "$appName (already exists, appId: $clientId)"
} else {
    $clientId = az ad app create --display-name $appName --query appId -o tsv
    Write-Done "App created (appId: $clientId)"
}

# Ensure service principal exists
$spExists = az ad sp show --id $clientId --query id -o tsv 2>$null
if (-not $spExists) {
    az ad sp create --id $clientId --output none
    Write-Done "Service principal created"
} else {
    Write-Skip "Service principal (already exists)"
}

# ══════════════════════════════════════════════════════
# STEP 4: OIDC Federated Credentials
# ══════════════════════════════════════════════════════
Write-Step "Configuring OIDC federated credentials for GitHub Actions"

$repoOwner = ($GitHubRepo -split '/')[0]
$repoName  = ($GitHubRepo -split '/')[1]

$federatedCreds = @(
    @{
        Name    = "$ProjectName-main"
        Subject = "repo:${GitHubRepo}:ref:refs/heads/main"
        Desc    = "GitHub Actions - main branch"
    }
    @{
        Name    = "$ProjectName-pr"
        Subject = "repo:${GitHubRepo}:pull_request"
        Desc    = "GitHub Actions - pull requests"
    }
    @{
        Name    = "$ProjectName-env-dev"
        Subject = "repo:${GitHubRepo}:environment:dev"
        Desc    = "GitHub Actions - dev environment"
    }
    @{
        Name    = "$ProjectName-env-staging"
        Subject = "repo:${GitHubRepo}:environment:staging"
        Desc    = "GitHub Actions - staging environment"
    }
    @{
        Name    = "$ProjectName-env-prod"
        Subject = "repo:${GitHubRepo}:environment:prod"
        Desc    = "GitHub Actions - prod environment"
    }
)

foreach ($cred in $federatedCreds) {
    $existing = az ad app federated-credential list --id $clientId --query "[?name=='$($cred.Name)'].name" -o tsv 2>$null
    if ($existing) {
        Write-Skip "$($cred.Name) (already exists)"
    } else {
        $body = @{
            name        = $cred.Name
            issuer      = "https://token.actions.githubusercontent.com"
            subject     = $cred.Subject
            description = $cred.Desc
            audiences   = @("api://AzureADTokenExchange")
        } | ConvertTo-Json -Compress

        $body | az ad app federated-credential create --id $clientId --parameters "@-" --output none
        Write-Done "$($cred.Name) → $($cred.Subject)"
    }
}

# ══════════════════════════════════════════════════════
# STEP 5: Role Assignments
# ══════════════════════════════════════════════════════
Write-Step "Assigning roles to service principal"

$spObjectId = az ad sp show --id $clientId --query id -o tsv

# Contributor on each environment RG
foreach ($env in $environments) {
    $rgId = az group show --name $env.RG --query id -o tsv 2>$null
    if ($rgId) {
        $existing = az role assignment list --assignee $spObjectId --scope $rgId --role "Contributor" --query "[0].id" -o tsv 2>$null
        if ($existing) {
            Write-Skip "Contributor on $($env.RG)"
        } else {
            az role assignment create --assignee $spObjectId --role "Contributor" --scope $rgId --output none
            Write-Done "Contributor on $($env.RG)"
        }
    }
}

# AcrPush on the container registry
$acrId = az acr show --name $acrName --query id -o tsv 2>$null
if ($acrId) {
    $existing = az role assignment list --assignee $spObjectId --scope $acrId --role "AcrPush" --query "[0].id" -o tsv 2>$null
    if ($existing) {
        Write-Skip "AcrPush on $acrName"
    } else {
        az role assignment create --assignee $spObjectId --role "AcrPush" --scope $acrId --output none
        Write-Done "AcrPush on $acrName"
    }
}

# AcrPull also needed for Container Apps to pull images
if ($acrId) {
    $existing = az role assignment list --assignee $spObjectId --scope $acrId --role "AcrPull" --query "[0].id" -o tsv 2>$null
    if ($existing) {
        Write-Skip "AcrPull on $acrName"
    } else {
        az role assignment create --assignee $spObjectId --role "AcrPull" --scope $acrId --output none
        Write-Done "AcrPull on $acrName"
    }
}

# ══════════════════════════════════════════════════════
# STEP 6: GitHub Environments
# ══════════════════════════════════════════════════════
Write-Step "Creating GitHub environments"

foreach ($env in $environments) {
    # gh api creates the environment if it doesn't exist
    gh api -X PUT "repos/$GitHubRepo/environments/$($env.Name)" --silent 2>$null
    Write-Done "$($env.Name)"
}

# ══════════════════════════════════════════════════════
# STEP 7: GitHub Secrets & Variables
# ══════════════════════════════════════════════════════
Write-Step "Setting GitHub secrets"

gh secret set AZURE_CLIENT_ID        --repo $GitHubRepo --body $clientId
gh secret set AZURE_TENANT_ID        --repo $GitHubRepo --body $TenantId
gh secret set AZURE_SUBSCRIPTION_ID  --repo $GitHubRepo --body $SubscriptionId

Write-Done "AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"

Write-Step "Setting GitHub variables"

gh variable set ACR_NAME      --repo $GitHubRepo --body $acrName
gh variable set PROJECT_NAME  --repo $GitHubRepo --body $ProjectName

Write-Done "ACR_NAME=$acrName, PROJECT_NAME=$ProjectName"

# ══════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════
Write-Host "`n  ════════════════════════════════════════════" -ForegroundColor White
Write-Host "  ✓ Azure setup complete!" -ForegroundColor Green
Write-Host "  ════════════════════════════════════════════" -ForegroundColor White
Write-Host ""
Write-Host "  Azure Resources:" -ForegroundColor White
Write-Host "    ACR:            $acrName ($rgShared)" -ForegroundColor DarkGray
Write-Host "    Resource Groups: $rgDev, $rgStaging, $rgProd" -ForegroundColor DarkGray
Write-Host "    App Reg:        $appName (OIDC)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  GitHub Config ($GitHubRepo):" -ForegroundColor White
Write-Host "    Secrets:  AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID" -ForegroundColor DarkGray
Write-Host "    Variables: ACR_NAME=$acrName, PROJECT_NAME=$ProjectName" -ForegroundColor DarkGray
Write-Host "    Environments: dev, staging, prod" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Your CI/CD workflows are now ready to deploy." -ForegroundColor Green
Write-Host "  Push a commit to main or open a PR to trigger a build." -ForegroundColor DarkGray
Write-Host ""
