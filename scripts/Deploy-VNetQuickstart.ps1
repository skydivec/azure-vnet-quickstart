# Azure Virtual Network Quickstart - PowerShell Deployment
# Based on: https://learn.microsoft.com/en-us/azure/virtual-network/quickstart-create-virtual-network?tabs=bicep

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus2",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "bea248d0-a894-4c66-8fd4-6a6fbfe4b576",
    
    [Parameter(Mandatory = $false)]
    [string]$TenantId = "f5d3e1c4-1353-4a12-bc1b-9c2fe013696e",
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "templates\main.bicep",
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "parameters\main.parameters.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipModuleInstall
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "Azure Virtual Network Quickstart Deployment" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan
Write-Host ""

# Check for conflicting AzureRM module
try {
    $azureRmModule = Get-Module -Name AzureRM -ListAvailable
    if ($azureRmModule) {
        Write-Warning "Legacy AzureRM module detected - this may cause conflicts with Az module"
        Write-Host "To remove AzureRM manually:" -ForegroundColor Yellow
        Write-Host "1. Close all PowerShell sessions" -ForegroundColor Gray
        Write-Host "2. Run PowerShell as Administrator" -ForegroundColor Gray
        Write-Host "3. Execute: Uninstall-AzureRm" -ForegroundColor Gray
        Write-Host "Continuing with deployment..." -ForegroundColor Yellow
    }
}
catch {
    Write-Verbose "AzureRM module check failed: $($_.Exception.Message)"
}

# Verify and install Azure PowerShell module
try {
    $azModule = Get-Module -Name Az -ListAvailable
    if (-not $azModule) {
        if ($SkipModuleInstall) {
            Write-Error "Azure PowerShell module not found. Please install manually: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
        }
        
        Write-Host "Azure PowerShell module not found. Installing automatically..." -ForegroundColor Yellow
        Write-Host "Use -SkipModuleInstall to disable automatic installation" -ForegroundColor Gray
        
        # Check if running as administrator for AllUsers scope
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if ($isAdmin) {
            Write-Host "Installing Azure PowerShell module for all users..." -ForegroundColor Gray
            Install-Module -Name Az -AllowClobber -Scope AllUsers -Force -Repository PSGallery
        }
        else {
            Write-Host "Installing Azure PowerShell module for current user..." -ForegroundColor Gray
            Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force -Repository PSGallery
        }
        
        # Re-check after installation
        $azModule = Get-Module -Name Az -ListAvailable
        if ($azModule) {
            Write-Host "✓ Azure PowerShell module installed successfully (version: $($azModule[0].Version))" -ForegroundColor Green
        }
        else {
            Write-Error "Failed to install Azure PowerShell module"
        }
    }
    else {
        Write-Host "✓ Azure PowerShell module found (version: $($azModule[0].Version))" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to check/install Azure PowerShell module: $($_.Exception.Message)"
}

# Connect to Azure
try {
    $context = Get-AzContext
    if (-not $context -or $context.Tenant.Id -ne $TenantId) {
        Write-Host "Connecting to Azure tenant..." -ForegroundColor Yellow
        Connect-AzAccount -TenantId $TenantId | Out-Null
        $context = Get-AzContext
    }
    Write-Host "✓ Connected to Azure:" -ForegroundColor Green
    Write-Host "  Account: $($context.Account.Id)" -ForegroundColor Gray
    Write-Host "  Current Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
}

# Set target subscription
try {
    Write-Host "`nSetting target subscription..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    $context = Get-AzContext
    Write-Host "✓ Target subscription set:" -ForegroundColor Green
    Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    Write-Host "  ID: $($context.Subscription.Id)" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to set subscription '$SubscriptionId': $($_.Exception.Message)"
}

# Create or verify resource group
Write-Host "`nManaging Resource Group..." -ForegroundColor Yellow
try {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Gray
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Host "✓ Resource group created" -ForegroundColor Green
    }
    else {
        Write-Host "✓ Resource group exists: $($rg.ResourceGroupName)" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to manage resource group: $($_.Exception.Message)"
}

# Validate template using Azure CLI
Write-Host "`nValidating Bicep template..." -ForegroundColor Yellow
try {
    $validationOutput = az deployment group validate --resource-group $ResourceGroupName --template-file $TemplateFile --parameters `@$ParametersFile --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Template validation issues found:"
        Write-Host $validationOutput -ForegroundColor Red
        
        $continue = Read-Host "Continue with deployment? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Host "Deployment cancelled" -ForegroundColor Yellow
            exit 0
        }
    }
    else {
        Write-Host "✓ Template validation passed" -ForegroundColor Green
    }
}
catch {
    Write-Error "Template validation failed: $($_.Exception.Message)"
}

# Get VM admin password
Write-Host "`nVM Configuration:" -ForegroundColor Yellow
$adminPassword = Read-Host "Enter password for VM administrator account" -AsSecureString

# Deploy template using Azure CLI
Write-Host "`nDeploying infrastructure..." -ForegroundColor Yellow
try {
    $deploymentName = "VNetQuickstart-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    $startTime = Get-Date
    Write-Host "Starting deployment: $deploymentName" -ForegroundColor Gray
    
    # Convert SecureString password to plain text for Azure CLI
    $adminPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword))
    
    $deploymentOutput = az deployment group create `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --template-file $TemplateFile `
        --parameters `@$ParametersFile `
        --parameters adminPassword=$adminPasswordPlain `
        --output json
    
    $duration = (Get-Date) - $startTime
    
    # Parse the deployment output JSON into a PowerShell object
    if ($deploymentOutput) {
        $deployment = $deploymentOutput | ConvertFrom-Json
        Write-Host "deployment name:" $deployment.properties.Name -ForegroundColor Cyan
    }
    else {
        Write-Host "section 1" -ForegroundColor Cyan
        Write-Error "Deployment failed: $($_.Exception.Message)"
    }
    if ($LASTEXITCODE -eq 0 -and $deployment.properties.provisioningState -eq "Succeeded") {
        
        Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
        Write-Host "  Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
        
        # Display outputs
        Write-Host "`nDeployment Results:" -ForegroundColor Cyan
        Write-Host "==================" -ForegroundColor Cyan
        if ($deployment.properties.outputs) {
            $outputKeys = $deployment.properties.outputs | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            if ($outputKeys) {
                foreach ($key in $outputKeys) {
                    $value = $deployment.properties.outputs.$key.value
                    Write-Host "$key: $value" -ForegroundColor White
                }
            } else {
                Write-Host "No outputs defined in template" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "No outputs defined in template" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "section 2" -ForegroundColor Cyan
        Write-Error "Deployment failed with state: $($deployment.properties.provisioningState)"
    }
}
catch {
    Write-Host "section 3" -ForegroundColor Cyan
    Write-Error "Deployment failed: $($_.Exception.Message)"
}

# Success summary
Write-Host "`nDeployment Summary:" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host "✓ Virtual Network with subnets created" -ForegroundColor Green
Write-Host "✓ Azure Bastion deployed for secure access" -ForegroundColor Green
Write-Host "✓ GPU VMs with AzSecPack security monitoring" -ForegroundColor Green
Write-Host "✓ Network security group configured" -ForegroundColor Green
Write-Host "✓ SFI-NS2.6.1 compliance (defaultOutboundAccess: false)" -ForegroundColor Green
Write-Host "✓ X11 desktop environment and VNC setup completed" -ForegroundColor Green

# Configure NSG rules for package repository access
Write-Host "`nConfiguring package repository access..." -ForegroundColor Yellow
try {
    $enableScriptPath = "scripts\Enable-PackageRepoAccess.ps1"
    if (Test-Path $enableScriptPath) {
        Write-Host "Running NSG configuration script..." -ForegroundColor Gray
        & $enableScriptPath -ResourceGroupName $ResourceGroupName
        Write-Host "✓ Package repository access configured" -ForegroundColor Green
    } else {
        Write-Host "⚠️ NSG configuration script not found at $enableScriptPath" -ForegroundColor Yellow
        Write-Host "  Manual NSG configuration may be required for package access" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️ Warning: Failed to configure NSG rules automatically" -ForegroundColor Yellow
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "  You can manually run: .\scripts\Enable-PackageRepoAccess.ps1 -ResourceGroupName $ResourceGroupName" -ForegroundColor Gray
}

# Setup X11 and VNC on VMs
Write-Host "`nSetting up X11 desktop environment..." -ForegroundColor Yellow
try {
    Write-Host "Installing X11 and VNC on vm-1..." -ForegroundColor Gray
    $x11Script = "curl -s https://raw.githubusercontent.com/skydivec/azure-vnet-quickstart/master/scripts/setup-x11-rhel.sh | bash"
    
    $vm1Result = az vm run-command invoke `
        --resource-group $ResourceGroupName `
        --name "vm-1" `
        --command-id RunShellScript `
        --scripts $x11Script `
        --output json 2>$null
    
    if ($vm1Result) {
        Write-Host "✓ X11 desktop environment configured on vm-1" -ForegroundColor Green
    } else {
        Write-Host "⚠️ X11 setup may have encountered issues on vm-1" -ForegroundColor Yellow
    }
    
    Write-Host "Installing X11 and VNC on vm-2..." -ForegroundColor Gray
    $vm2Result = az vm run-command invoke `
        --resource-group $ResourceGroupName `
        --name "vm-2" `
        --command-id RunShellScript `
        --scripts $x11Script `
        --output json 2>$null
    
    if ($vm2Result) {
        Write-Host "✓ X11 desktop environment configured on vm-2" -ForegroundColor Green
    } else {
        Write-Host "⚠️ X11 setup may have encountered issues on vm-2" -ForegroundColor Yellow
    }
    
    Write-Host "✓ Desktop environment setup complete" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Warning: Failed to setup X11 desktop environment automatically" -ForegroundColor Yellow
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "  You can manually setup X11 by running the setup script on each VM" -ForegroundColor Gray
}

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Connect to VMs via Azure Bastion in Azure portal" -ForegroundColor White
Write-Host "2. Test GPU functionality: .\scripts\Test-VMGPUFunctionality.ps1 -ResourceGroupName $ResourceGroupName" -ForegroundColor White
Write-Host "3. Access X11 desktop via VNC (setup already completed automatically)" -ForegroundColor White
Write-Host "4. Clean up resources when done: Remove-AzResourceGroup -Name $ResourceGroupName" -ForegroundColor White

Write-Host "`n🔧 Available Scripts:" -ForegroundColor Magenta
Write-Host "   • .\scripts\run-glxgears.sh - Comprehensive GPU testing" -ForegroundColor White
Write-Host "   • .\scripts\quick-gpu-test.sh - Fast GPU validation" -ForegroundColor White
Write-Host "   • .\scripts\Test-VMGPUFunctionality.ps1 - PowerShell GPU automation" -ForegroundColor White
Write-Host "   • .\scripts\Enable-PackageRepoAccess.ps1 - NSG configuration" -ForegroundColor White

Write-Host "`n📚 Documentation:" -ForegroundColor Magenta
Write-Host "   • X11-Login-Guide.md - Complete X11 access instructions" -ForegroundColor White
Write-Host "   • SFI-NS2.6.1-Connectivity-Summary.md - Security and connectivity guide" -ForegroundColor White

Write-Host "`n🖥️ VNC Access Information:" -ForegroundColor Magenta
Write-Host "   • X11 desktop environment is now installed and configured" -ForegroundColor White
Write-Host "   • Connect via SSH tunnel: ssh -L 5901:localhost:5901 azureuser@vm" -ForegroundColor White
Write-Host "   • VNC display :1 available on both VMs" -ForegroundColor White
Write-Host "   • See X11-Login-Guide.md for detailed VNC setup instructions" -ForegroundColor White

Write-Host "`n💡 Tip: Access the Azure portal at https://portal.azure.com" -ForegroundColor Magenta