#!/usr/bin/env pwsh
# ================================================================
# Complete MDA RHEL VMSS Deployment Script with Prerequisites
# ================================================================
# This script handles the complete deployment including:
# 1. Resource group creation with proper naming conventions
# 2. Azure resource provider registration verification
# 3. Main VMSS infrastructure deployment
# 4. Post-deployment validation and instructions

param(
    [string]$ProjectName = "mda",
    [string]$Environment = "dev", 
    [string]$Location = "West US 2",
    [string]$PrerequisitesTemplate = "prerequisites.bicep",
    [string]$MainTemplate = "main.bicep",
    [string]$ParametersFile = "parameters.json",
    [switch]$WhatIf,
    [switch]$SkipPrerequisites
)

# ================================================================
# HELPER FUNCTIONS
# ================================================================

function Write-StepHeader {
    param([string]$Step, [string]$Description)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "STEP $Step : $Description" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
}

function Test-AzureCLI {
    try {
        $subscription = az account show --query "name" -o tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Not logged in to Azure. Run 'az login' first."
            return $false
        }
        Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
        Write-Host "📋 Current subscription: $subscription" -ForegroundColor Cyan
        return $true
    } catch {
        Write-Error "❌ Azure CLI not found. Please install Azure CLI."
        return $false
    }
}

function Get-LocationShort {
    param([string]$Location)
    
    $locationMap = @{
        "West US 2" = "wus2"
        "East US" = "eus"
        "East US 2" = "eus2"
        "Central US" = "cus"
        "West Central US" = "wcus"
        "South Central US" = "scus"
        "North Central US" = "ncus"
        "West US" = "wus"
        "West US 3" = "wus3"
        "Canada Central" = "cac"
        "Canada East" = "cae"
        "Brazil South" = "brs"
        "North Europe" = "neu"
        "West Europe" = "weu"
        "UK South" = "uks"
        "UK West" = "ukw"
        "France Central" = "frc"
        "Germany West Central" = "gwc"
        "Switzerland North" = "swn"
        "Norway East" = "noe"
        "Sweden Central" = "swc"
        "Australia East" = "aue"
        "Australia Southeast" = "ause"
        "Southeast Asia" = "sea"
        "East Asia" = "ea"
        "Japan East" = "jpe"
        "Japan West" = "jpw"
        "Korea Central" = "krc"
        "Korea South" = "krs"
        "India Central" = "inc"
        "India South" = "ins"
        "India West" = "inw"
    }
    
    if ($locationMap.ContainsKey($Location)) {
        return $locationMap[$Location]
    } else {
        return ($Location -replace ' ', '').ToLower().Substring(0, [Math]::Min(4, $Location.Length))
    }
}

function Test-RequiredProviders {
    Write-Host "🔍 Checking required Azure resource providers..." -ForegroundColor Yellow
    
    $requiredProviders = @(
        'Microsoft.Compute',
        'Microsoft.Network', 
        'Microsoft.Storage',
        'Microsoft.KeyVault',
        'Microsoft.Insights',
        'Microsoft.OperationalInsights',
        'Microsoft.OperationsManagement',
        'Microsoft.Security',
        'Microsoft.Authorization',
        'Microsoft.Resources',
        'Microsoft.ManagedIdentity',
        'Microsoft.AlertsManagement'
    )
    
    $notRegistered = @()
    
    foreach ($provider in $requiredProviders) {
        $status = az provider show --namespace $provider --query "registrationState" -o tsv 2>$null
        if ($status -ne "Registered") {
            $notRegistered += $provider
            Write-Host "⚠️  Provider $provider is not registered (Status: $status)" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Provider $provider is registered" -ForegroundColor Green
        }
    }
    
    if ($notRegistered.Count -gt 0) {
        Write-Host ""
        Write-Host "📋 Registering required providers (this may take a few minutes)..." -ForegroundColor Yellow
        
        foreach ($provider in $notRegistered) {
            Write-Host "   Registering $provider..." -ForegroundColor Cyan
            az provider register --namespace $provider --wait
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ $provider registered successfully" -ForegroundColor Green
            } else {
                Write-Warning "   ⚠️  Failed to register $provider - may register automatically during deployment"
            }
        }
    }
    
    Write-Host "✅ Provider registration check complete" -ForegroundColor Green
}

# ================================================================
# MAIN DEPLOYMENT SCRIPT
# ================================================================

Write-Host "🚀 MDA RHEL 8.10 VMSS Complete Deployment" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host "Project: $ProjectName" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan  
Write-Host "Location: $Location" -ForegroundColor Cyan

# Generate resource names
$LocationShort = Get-LocationShort -Location $Location
$ResourceGroupName = "rg-$ProjectName-vmss-$Environment-$LocationShort"

Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# STEP 1: VERIFY PREREQUISITES
# ================================================================

Write-StepHeader "1" "Verifying Prerequisites"

if (-not (Test-AzureCLI)) {
    exit 1
}

if (-not $SkipPrerequisites) {
    Test-RequiredProviders
}

# Validate template files exist
$templateFiles = @($PrerequisitesTemplate, $MainTemplate, $ParametersFile)
foreach ($file in $templateFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "❌ Required file not found: $file"
        exit 1
    }
    Write-Host "✅ Found template file: $file" -ForegroundColor Green
}

# ================================================================
# STEP 2: DEPLOY PREREQUISITES
# ================================================================

if (-not $SkipPrerequisites) {
    Write-StepHeader "2" "Deploying Prerequisites (Resource Group)"
    
    Write-Host "🏗️  Deploying prerequisites template..." -ForegroundColor Yellow
    
    $prereqDeploymentName = "prerequisites-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if ($WhatIf) {
        Write-Host "🔮 Running What-If analysis for prerequisites..." -ForegroundColor Yellow
        az deployment sub what-if `
            --location $Location `
            --template-file $PrerequisitesTemplate `
            --parameters projectName=$ProjectName environment=$Environment location="$Location"
    } else {
        az deployment sub create `
            --location $Location `
            --template-file $PrerequisitesTemplate `
            --parameters projectName=$ProjectName environment=$Environment location="$Location" `
            --name $prereqDeploymentName `
            --output table

        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Prerequisites deployment failed"
            exit 1
        }
        
        Write-Host "✅ Prerequisites deployed successfully" -ForegroundColor Green
        
        # Get deployment outputs
        $prereqOutputs = az deployment sub show `
            --name $prereqDeploymentName `
            --query "properties.outputs" -o json | ConvertFrom-Json
            
        Write-Host "📊 Prerequisites Summary:" -ForegroundColor Cyan
        Write-Host "   Resource Group: $($prereqOutputs.resourceGroupName.value)" -ForegroundColor White
        Write-Host "   Naming Prefix: $($prereqOutputs.namingPrefix.value)" -ForegroundColor White
        Write-Host "   Location: $($prereqOutputs.location.value)" -ForegroundColor White
    }
} else {
    Write-Host "⏭️  Skipping prerequisites deployment" -ForegroundColor Yellow
}

# ================================================================
# STEP 3: VALIDATE MAIN TEMPLATE  
# ================================================================

Write-StepHeader "3" "Validating Main Template"

Write-Host "🔍 Validating main Bicep template..." -ForegroundColor Yellow
az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $MainTemplate `
    --parameters "@$ParametersFile" `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Main template validation failed"
    exit 1
}

Write-Host "✅ Main template validation successful" -ForegroundColor Green

# ================================================================
# STEP 4: DEPLOY MAIN INFRASTRUCTURE
# ================================================================

if (-not $WhatIf) {
    Write-StepHeader "4" "Deploying Main Infrastructure"
    
    Write-Host "🚀 Starting main VMSS infrastructure deployment..." -ForegroundColor Yellow
    Write-Host "⏱️  This may take 15-20 minutes..." -ForegroundColor Cyan
    
    $mainDeploymentName = "vmss-main-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $MainTemplate `
        --parameters "@$ParametersFile" `
        --name $mainDeploymentName `
        --output table

    if ($LASTEXITCODE -eq 0) {
        Write-Host "🎉 Main deployment completed successfully!" -ForegroundColor Green
        
        # ================================================================
        # STEP 5: POST-DEPLOYMENT SUMMARY
        # ================================================================
        
        Write-StepHeader "5" "Deployment Summary & Instructions"
        
        # Get deployment outputs
        $outputs = az deployment group show `
            --resource-group $ResourceGroupName `
            --name $mainDeploymentName `
            --query "properties.outputs" -o json | ConvertFrom-Json
            
        Write-Host "📊 Infrastructure Summary:" -ForegroundColor Cyan
        Write-Host "   Resource Group: $($outputs.resourceGroupName.value)" -ForegroundColor White
        Write-Host "   VMSS Name: $($outputs.vmssName.value)" -ForegroundColor White  
        Write-Host "   Load Balancer IP: $($outputs.loadBalancerPublicIp.value)" -ForegroundColor White
        Write-Host "   Auto-scaling: $($outputs.autoScalingEnabled.value)" -ForegroundColor White
        
        if ($outputs.bastionName.value) {
            Write-Host "   Bastion Name: $($outputs.bastionName.value)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "🔗 Connection Instructions:" -ForegroundColor Green
        Write-Host "1. Azure Bastion (Recommended):" -ForegroundColor Yellow
        Write-Host "   → Go to Azure Portal → Virtual Machine Scale Sets" -ForegroundColor White
        Write-Host "   → Select your VMSS → Instances → Select instance → Connect → Bastion" -ForegroundColor White
        
        Write-Host ""
        Write-Host "2. SSH with X11 Forwarding:" -ForegroundColor Yellow
        Write-Host "   → $($outputs.sshConnectionCommand.value)" -ForegroundColor White
        
        Write-Host ""
        Write-Host "🖥️ X11 Desktop Features:" -ForegroundColor Green
        Write-Host "   ✅ GNOME Desktop Environment" -ForegroundColor White
        Write-Host "   ✅ VNC Server (port 5901)" -ForegroundColor White
        Write-Host "   ✅ XRDP Server (port 3389)" -ForegroundColor White
        Write-Host "   ✅ SSH X11 Forwarding enabled" -ForegroundColor White
        Write-Host "   ✅ Pre-installed GUI applications" -ForegroundColor White
        
        Write-Host ""
        Write-Host "⚠️ SECURITY NOTICE:" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host "Default VNC password: 'VncPassword123!'" -ForegroundColor Yellow
        Write-Host "CHANGE THIS PASSWORD IMMEDIATELY after first login!" -ForegroundColor Red
        
        Write-Host ""
        Write-Host "📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Connect to a VMSS instance via Azure Bastion" -ForegroundColor White
        Write-Host "2. Change the VNC password: vncpasswd" -ForegroundColor White  
        Write-Host "3. Test X11 applications: firefox, gnome-session" -ForegroundColor White
        Write-Host "4. Monitor resources in Azure Portal" -ForegroundColor White
        Write-Host "5. Review security recommendations in Security Center" -ForegroundColor White
        
    } else {
        Write-Error "❌ Main infrastructure deployment failed"
        
        Write-Host ""
        Write-Host "🔍 Troubleshooting Tips:" -ForegroundColor Yellow
        Write-Host "1. Check deployment logs in Azure Portal" -ForegroundColor White
        Write-Host "2. Verify SSH public key is correct in parameters.json" -ForegroundColor White
        Write-Host "3. Ensure sufficient quota for Standard_A10 VMs in region" -ForegroundColor White
        Write-Host "4. Check Azure service health for any regional issues" -ForegroundColor White
        
        exit 1
    }
} else {
    Write-Host "🔮 What-If analysis complete. Use -WhatIf:$false to proceed with deployment." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "✨ Deployment script completed!" -ForegroundColor Green