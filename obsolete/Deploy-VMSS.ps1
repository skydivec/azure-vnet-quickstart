#!/usr/bin/env pwsh
# ================================================================
# MDA RHEL VMSS Deployment Script
# ================================================================

param(
    [string]$ProjectName = "mda",
    [string]$Environment = "dev", 
    [string]$Location = "West US 2",
    [string]$TemplateFile = "main.bicep",
    [string]$ParametersFile = "parameters.json",
    [switch]$WhatIf
)

# Generate resource group name following Azure naming conventions
# Format: rg-{projectname}-{workload}-{environment}-{location}
$LocationShort = switch ($Location) {
    "West US 2" { "wus2" }
    "East US" { "eus" }
    "East US 2" { "eus2" }
    "Central US" { "cus" }
    "North Central US" { "ncus" }
    "South Central US" { "scus" }
    "West Central US" { "wcus" }
    "West US" { "wus" }
    "West US 3" { "wus3" }
    "Canada Central" { "cac" }
    "Canada East" { "cae" }
    "Brazil South" { "brs" }
    "North Europe" { "neu" }
    "West Europe" { "weu" }
    "UK South" { "uks" }
    "UK West" { "ukw" }
    "France Central" { "frc" }
    "Germany West Central" { "gwc" }
    "Switzerland North" { "swn" }
    "Norway East" { "noe" }
    "Sweden Central" { "swc" }
    "Australia East" { "aue" }
    "Australia Southeast" { "ause" }
    "Southeast Asia" { "sea" }
    "East Asia" { "ea" }
    "Japan East" { "jpe" }
    "Japan West" { "jpw" }
    "Korea Central" { "krc" }
    "Korea South" { "krs" }
    "India Central" { "inc" }
    "India South" { "ins" }
    "India West" { "inw" }
    default { ($Location -replace ' ', '').ToLower().Substring(0, [Math]::Min(4, $Location.Length)) }
}

$ResourceGroupName = "rg-$ProjectName-vmss-$Environment-$LocationShort"

Write-Host "🚀 MDA RHEL 8.10 VMSS with X11 Deployment" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Check Azure CLI authentication
try {
    $subscription = az account show --query "name" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Not logged in to Azure. Run 'az login' first."
        exit 1
    }
    Write-Host "📋 Current subscription: $subscription" -ForegroundColor Cyan
} catch {
    Write-Error "❌ Azure CLI not found. Please install Azure CLI."
    exit 1
}

# Create resource group
Write-Host "📁 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Failed to create resource group"
    exit 1
}

# Validate template
Write-Host "🔍 Validating Bicep template..." -ForegroundColor Yellow
az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $TemplateFile `
    --parameters "@$ParametersFile" `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Template validation failed"
    exit 1
}

Write-Host "✅ Template validation successful" -ForegroundColor Green

# Deploy or show what-if
if ($WhatIf) {
    Write-Host "🔮 Running What-If analysis..." -ForegroundColor Yellow
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file $TemplateFile `
        --parameters "@$ParametersFile"
} else {
    Write-Host "🚀 Starting deployment..." -ForegroundColor Yellow
    $deploymentName = "mda-vmss-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $TemplateFile `
        --parameters "@$ParametersFile" `
        --name $deploymentName `
        --output table

    if ($LASTEXITCODE -eq 0) {
        Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Get outputs
        Write-Host "📊 Deployment Outputs:" -ForegroundColor Cyan
        $outputs = az deployment group show `
            --resource-group $ResourceGroupName `
            --name $deploymentName `
            --query "properties.outputs" -o json | ConvertFrom-Json
            
        Write-Host "VMSS Name: $($outputs.vmssName.value)" -ForegroundColor White
        Write-Host "Load Balancer IP: $($outputs.loadBalancerPublicIp.value)" -ForegroundColor White
        Write-Host "Bastion Name: $($outputs.bastionName.value)" -ForegroundColor White
        Write-Host "Auto-scaling: $($outputs.autoScalingEnabled.value)" -ForegroundColor White
        
        Write-Host ""
        Write-Host "🔗 Connection Instructions:" -ForegroundColor Green
        Write-Host "1. Azure Bastion: Portal → VMSS → Connect → Bastion" -ForegroundColor White
        Write-Host "2. SSH: $($outputs.sshConnectionCommand.value)" -ForegroundColor White
        Write-Host "3. VNC: Connect via SSH first, then VNC client to localhost:5901" -ForegroundColor White
        
        Write-Host ""
        Write-Host "🖥️ X11 Features Available:" -ForegroundColor Green
        Write-Host "- GNOME Desktop Environment" -ForegroundColor White
        Write-Host "- VNC Server (port 5901)" -ForegroundColor White
        Write-Host "- XRDP Server (port 3389)" -ForegroundColor White
        Write-Host "- SSH X11 Forwarding" -ForegroundColor White
        
        Write-Host ""
        Write-Host "⚠️ IMPORTANT:" -ForegroundColor Red
        Write-Host "Default VNC password is 'VncPassword123!' - Change this immediately!" -ForegroundColor Yellow
        
    } else {
        Write-Error "❌ Deployment failed"
        exit 1
    }
}

Write-Host ""
Write-Host "ℹ️ Next Steps:" -ForegroundColor Cyan
Write-Host "- Update SSH public key in parameters.json before deployment" -ForegroundColor White
Write-Host "- Change default VNC password after first connection" -ForegroundColor White
Write-Host "- Monitor resources via Azure Portal" -ForegroundColor White
Write-Host "- Review security recommendations in Security Center" -ForegroundColor White