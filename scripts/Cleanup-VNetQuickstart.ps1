# Azure Virtual Network Quickstart - Cleanup Script
# Safely removes all resources created by the VNet quickstart deployment

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "Azure Virtual Network Quickstart - Resource Cleanup" -ForegroundColor Red
Write-Host "=================================================" -ForegroundColor Red

if ($WhatIf) {
    Write-Host "PREVIEW MODE - No resources will be deleted" -ForegroundColor Yellow
    Write-Host ""
}

# Connect to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Connecting to Azure..." -ForegroundColor Yellow
        Connect-AzAccount | Out-Null
    }
    Write-Host "✓ Connected as: $($context.Account.Id)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
}

# Check if resource group exists
Write-Host "`nChecking resource group: $ResourceGroupName" -ForegroundColor Cyan
try {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "Resource group '$ResourceGroupName' not found" -ForegroundColor Yellow
        Write-Host "Nothing to clean up!" -ForegroundColor Green
        exit 0
    }
    
    Write-Host "✓ Found resource group in location: $($rg.Location)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to check resource group: $($_.Exception.Message)"
}

# List resources
Write-Host "`nInventorying resources to delete..." -ForegroundColor Cyan
try {
    $resources = Get-AzResource -ResourceGroupName $ResourceGroupName
    
    if ($resources) {
        Write-Host "`nResources that will be deleted:" -ForegroundColor Yellow
        Write-Host "==============================" -ForegroundColor Yellow
        
        $resources | Group-Object ResourceType | ForEach-Object {
            $resourceType = $_.Name
            $count = $_.Count
            Write-Host "  $resourceType ($count)" -ForegroundColor White
            
            $_.Group | ForEach-Object {
                Write-Host "    - $($_.Name)" -ForegroundColor Gray
            }
        }
        
        Write-Host "`nTotal resources: $($resources.Count)" -ForegroundColor Cyan
        
        # Calculate estimated cost savings (rough estimates)
        $monthlyCost = 0
        $resources | ForEach-Object {
            switch -Wildcard ($_.ResourceType) {
                "*bastionHosts*" { $monthlyCost += 140 }
                "*virtualMachines*" { $monthlyCost += 30 }
                "*publicIPAddresses*" { $monthlyCost += 3.50 }
                "*disks*" { $monthlyCost += 5 }
            }
        }
        
        if ($monthlyCost -gt 0) {
            Write-Host "💰 Estimated monthly cost savings: ~$$$monthlyCost USD" -ForegroundColor Green
        }
    }
    else {
        Write-Host "No resources found in resource group" -ForegroundColor Green
        Write-Host "Only the empty resource group will be deleted" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "Could not list resources: $($_.Exception.Message)"
}

# Confirmation (unless -Force or -WhatIf)
if (-not $Force -and -not $WhatIf) {
    Write-Host "`n⚠️  WARNING: This action cannot be undone!" -ForegroundColor Red
    Write-Host "All resources in '$ResourceGroupName' will be permanently deleted." -ForegroundColor Red
    
    do {
        $response = Read-Host "`nType 'DELETE' to confirm deletion, or 'cancel' to abort"
    } while ($response -notin @('DELETE', 'cancel', 'CANCEL'))
    
    if ($response -like 'cancel') {
        Write-Host "Cleanup cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

# Perform deletion
if ($WhatIf) {
    Write-Host "`n[PREVIEW] Would delete resource group: $ResourceGroupName" -ForegroundColor Magenta
    Write-Host "[PREVIEW] No actual deletion performed" -ForegroundColor Magenta
}
else {
    Write-Host "`nDeleting resource group and all contents..." -ForegroundColor Red
    
    try {
        $startTime = Get-Date
        
        # Delete with progress indication
        $job = Remove-AzResourceGroup -Name $ResourceGroupName -Force -AsJob
        
        Write-Host "Deletion started (Job ID: $($job.Id))" -ForegroundColor Gray
        Write-Host "This may take several minutes..." -ForegroundColor Gray
        
        # Monitor progress
        do {
            Start-Sleep -Seconds 10
            Write-Host "." -NoNewline -ForegroundColor Gray
        } while ($job.State -eq "Running")
        
        Write-Host ""
        
        if ($job.State -eq "Completed") {
            $duration = (Get-Date) - $startTime
            Write-Host "✓ Resource group '$ResourceGroupName' deleted successfully!" -ForegroundColor Green
            Write-Host "  Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
        }
        else {
            Write-Error "Deletion failed. Job state: $($job.State)"
        }
    }
    catch {
        Write-Error "Failed to delete resource group: $($_.Exception.Message)"
    }
}

Write-Host "`nCleanup Summary:" -ForegroundColor Green
Write-Host "===============" -ForegroundColor Green

if ($WhatIf) {
    Write-Host "✓ Preview completed - no resources were deleted" -ForegroundColor Green
    Write-Host "✓ Run without -WhatIf to perform actual deletion" -ForegroundColor Green
}
else {
    Write-Host "✓ All resources removed from Azure subscription" -ForegroundColor Green
    Write-Host "✓ Monthly billing charges eliminated" -ForegroundColor Green
    Write-Host "✓ Cleanup completed successfully" -ForegroundColor Green
}

Write-Host ""