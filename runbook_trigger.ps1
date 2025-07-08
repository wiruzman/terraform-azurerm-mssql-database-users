[CmdletBinding(DefaultParameterSetName = 'None')]
param (
  [string]$AutomationAccountName,
  [string]$ResourceGroupName,
  [string]$RunbookName
)

$ErrorActionPreference = 'Stop'

# Check authentication methods in order of preference:
# 1. Federated tokens
# 2. Service principal with client secret
# 3. Current Azure CLI context (local development)

$hasFederatedTokens = $env:ARM_CLIENT_ID -and $env:ARM_OIDC_TOKEN -and $env:ARM_TENANT_ID
$hasServicePrincipal = $env:ARM_CLIENT_ID -and $env:ARM_CLIENT_SECRET -and $env:ARM_TENANT_ID

if ($hasFederatedTokens) {
  Write-Host "✅ Federated token environment detected - using OIDC authentication..."
  
  if (-not $env:ARM_SUBSCRIPTION_ID) {
    Write-Error "❌ ARM_SUBSCRIPTION_ID environment variable is not set"
    exit 1
  }
  
  Write-Host "🔐 Logging in to Azure CLI with federated token..."
  az login --service-principal `
    --username $env:ARM_CLIENT_ID `
    --federated-token $env:ARM_OIDC_TOKEN `
    --tenant $env:ARM_TENANT_ID | Out-Null
    
  Write-Host "📌 Setting subscription..."
  az account set --subscription $env:ARM_SUBSCRIPTION_ID
}
elseif ($hasServicePrincipal) {
  Write-Host "✅ Service principal environment detected - using client secret authentication..."
  
  if (-not $env:ARM_SUBSCRIPTION_ID) {
    Write-Error "❌ ARM_SUBSCRIPTION_ID environment variable is not set"
    exit 1
  }
  
  Write-Host "🔐 Logging in to Azure CLI with service principal and client secret..."
  az login --service-principal `
    --username $env:ARM_CLIENT_ID `
    --password $env:ARM_CLIENT_SECRET `
    --tenant $env:ARM_TENANT_ID | Out-Null
    
  Write-Host "📌 Setting subscription..."
  az account set --subscription $env:ARM_SUBSCRIPTION_ID
}
else {
  Write-Host "✅ Using current Azure CLI context (local development)..."
  
  $currentAccount = az account show --query "user.name" -o tsv 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $currentAccount) {
    Write-Error "❌ No active Azure CLI session found. Please run 'az login' first or set up service principal environment variables."
    Write-Host ""
    Write-Host "For federated tokens:"
    Write-Host "  Set these environment variables:"
    Write-Host "  - ARM_CLIENT_ID (Application ID)"
    Write-Host "  - ARM_TENANT_ID (Tenant ID)"
    Write-Host "  - ARM_SUBSCRIPTION_ID (Subscription ID)"
    Write-Host "  - ARM_OIDC_TOKEN (Federated token)"
    Write-Host ""
    Write-Host "For service principal with client secret:"
    Write-Host "  Set these environment variables:"
    Write-Host "  - ARM_CLIENT_ID (Application ID)"
    Write-Host "  - ARM_CLIENT_SECRET (Client Secret)"
    Write-Host "  - ARM_TENANT_ID (Tenant ID)"
    Write-Host "  - ARM_SUBSCRIPTION_ID (Subscription ID)"
    exit 1
  }
  
  Write-Host "👤 Authenticated as: $currentAccount"
  
  $currentSubscription = az account show --query "name" -o tsv
  Write-Host "📌 Using subscription: $currentSubscription"
}

Write-Host " Installing automation extension..."
az extension add --name automation --only-show-errors

Write-Host "🚀 Triggering runbook..."
$job = az automation runbook start `
  --automation-account-name $AutomationAccountName `
  --resource-group $ResourceGroupName `
  --name $RunbookName `
  --query jobId -o tsv

if (-not $job) {
  Write-Error "❌ Failed to retrieve runbook job ID"
  exit 1
}

Write-Host "⏳ Waiting for job $job to complete..."

$maxWaitMinutes = 10
$waitSeconds = 10
$elapsed = 0

while ($true) {
  Start-Sleep -Seconds $waitSeconds
  $elapsed += $waitSeconds

  $status = az automation job show `
    --automation-account-name $AutomationAccountName `
    --resource-group $ResourceGroupName `
    --job-name $job `
    --query status -o tsv `
    --only-show-errors

  Write-Host "⏱ Job status: $status ($elapsed seconds elapsed)"

  if ($status -eq "Completed") {
    Write-Host "✅ Runbook completed successfully"
    break
  }
  elseif ($status -in @("Failed", "Suspended", "Stopped")) {
    Write-Error "❌ Runbook ended with status: $status"
    exit 1
  }

  if ($elapsed -ge ($maxWaitMinutes * 60)) {
    Write-Error "❌ Timeout waiting for runbook to complete"
    exit 1
  }
}