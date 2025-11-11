# Enable-PackageRepoAccess.ps1
# Script to configure NSG rules for package repository access
# Enables secure access to package repositories while maintaining SFI-NS2.6.1 compliance

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$NSGName = "nsg-main",
    
    [Parameter(Mandatory = $false)]
    [switch]$RemoveRules,
    
    [Parameter(Mandatory = $false)]
    [switch]$ListRules
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to check if Azure CLI is available
function Test-AzureCLI {
    try {
        $azVersion = az --version 2>$null
        if (-not $azVersion) {
            Write-ColorOutput "Azure CLI not found. Please install Azure CLI." -ForegroundColor "Red"
            return $false
        }
        Write-ColorOutput "✅ Azure CLI found" -ForegroundColor "Green"
        return $true
    } catch {
        Write-ColorOutput "Error checking Azure CLI: $($_.Exception.Message)" -ForegroundColor "Red"
        return $false
    }
}

# Function to verify NSG exists
function Test-NSGExists {
    param([string]$ResourceGroup, [string]$NSGName)
    
    try {
        $nsgExists = az network nsg show --resource-group $ResourceGroup --name $NSGName --query "name" --output tsv 2>$null
        if ($nsgExists) {
            Write-ColorOutput "✅ NSG '$NSGName' found in resource group '$ResourceGroup'" -ForegroundColor "Green"
            return $true
        } else {
            Write-ColorOutput "❌ NSG '$NSGName' not found in resource group '$ResourceGroup'" -ForegroundColor "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "Error checking NSG: $($_.Exception.Message)" -ForegroundColor "Red"
        return $false
    }
}

# Function to list existing NSG rules
function Get-NSGRules {
    param([string]$ResourceGroup, [string]$NSGName)
    
    Write-ColorOutput "=== Current NSG Rules ===" -ForegroundColor "Cyan"
    
    try {
        $rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NSGName --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Protocol:protocol, SourcePort:sourcePortRange, DestinationPort:destinationPortRange, Source:sourceAddressPrefix, Destination:destinationAddressPrefix}" --output table
        
        if ($rules) {
            Write-ColorOutput $rules -ForegroundColor "White"
        } else {
            Write-ColorOutput "No rules found or error retrieving rules" -ForegroundColor "Yellow"
        }
    } catch {
        Write-ColorOutput "Error listing NSG rules: $($_.Exception.Message)" -ForegroundColor "Red"
    }
}

# Function to add package repository access rules
function Add-PackageRepoRules {
    param([string]$ResourceGroup, [string]$NSGName)
    
    Write-ColorOutput "=== Adding Package Repository Access Rules ===" -ForegroundColor "Cyan"
    
    $rules = @(
        @{
            Name = "AllowHTTPS"
            Priority = 100
            Protocol = "Tcp"
            Access = "Allow"
            Direction = "Outbound"
            SourceAddressPrefix = "*"
            SourcePortRange = "*"
            DestinationAddressPrefix = "Internet"
            DestinationPortRange = "443"
            Description = "Allow HTTPS traffic for package repositories"
        },
        @{
            Name = "AllowHTTP"
            Priority = 110
            Protocol = "Tcp"
            Access = "Allow"
            Direction = "Outbound"
            SourceAddressPrefix = "*"
            SourcePortRange = "*"
            DestinationAddressPrefix = "Internet"
            DestinationPortRange = "80"
            Description = "Allow HTTP traffic for package repositories"
        },
        @{
            Name = "AllowDNS"
            Priority = 120
            Protocol = "Udp"
            Access = "Allow"
            Direction = "Outbound"
            SourceAddressPrefix = "*"
            SourcePortRange = "*"
            DestinationAddressPrefix = "Internet"
            DestinationPortRange = "53"
            Description = "Allow DNS resolution"
        },
        @{
            Name = "AllowNTP"
            Priority = 130
            Protocol = "Udp"
            Access = "Allow"
            Direction = "Outbound"
            SourceAddressPrefix = "*"
            SourcePortRange = "*"
            DestinationAddressPrefix = "Internet"
            DestinationPortRange = "123"
            Description = "Allow NTP time synchronization"
        },
        @{
            Name = "AllowRHELRepos"
            Priority = 150
            Protocol = "Tcp"
            Access = "Allow"
            Direction = "Outbound"
            SourceAddressPrefix = "*"
            SourcePortRange = "*"
            DestinationAddressPrefixes = @("23.32.16.0/20", "23.218.128.0/17", "96.16.108.0/22", "104.16.0.0/12", "151.101.0.0/16")
            DestinationPortRanges = @("80", "443")
            Description = "Allow access to Red Hat package repositories"
        }
    )
    
    foreach ($rule in $rules) {
        try {
            Write-ColorOutput "Adding rule: $($rule.Name)" -ForegroundColor "Yellow"
            
            # Check if rule already exists
            $existingRule = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NSGName --name $rule.Name --query "name" --output tsv 2>$null
            
            if ($existingRule) {
                Write-ColorOutput "  Rule '$($rule.Name)' already exists - updating..." -ForegroundColor "Gray"
                $action = "update"
            } else {
                Write-ColorOutput "  Creating new rule '$($rule.Name)'..." -ForegroundColor "Gray"
                $action = "create"
            }
            
            # Build command parameters
            $params = @(
                "network", "nsg", "rule", $action,
                "--resource-group", $ResourceGroup,
                "--nsg-name", $NSGName,
                "--name", $rule.Name,
                "--priority", $rule.Priority,
                "--protocol", $rule.Protocol,
                "--access", $rule.Access,
                "--direction", $rule.Direction,
                "--source-address-prefix", $rule.SourceAddressPrefix,
                "--source-port-range", $rule.SourcePortRange,
                "--description", "`"$($rule.Description)`""
            )
            
            # Add destination parameters based on rule type
            if ($rule.DestinationAddressPrefixes) {
                $params += "--destination-address-prefixes"
                $params += $rule.DestinationAddressPrefixes -join " "
                $params += "--destination-port-ranges"
                $params += $rule.DestinationPortRanges -join " "
            } else {
                $params += "--destination-address-prefix"
                $params += $rule.DestinationAddressPrefix
                $params += "--destination-port-range"
                $params += $rule.DestinationPortRange
            }
            
            # Execute the command
            $result = & az @params 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "  ✅ Rule '$($rule.Name)' configured successfully" -ForegroundColor "Green"
            } else {
                Write-ColorOutput "  ❌ Failed to configure rule '$($rule.Name)'" -ForegroundColor "Red"
            }
            
        } catch {
            Write-ColorOutput "  ❌ Error configuring rule '$($rule.Name)': $($_.Exception.Message)" -ForegroundColor "Red"
        }
    }
}

# Function to remove package repository access rules
function Remove-PackageRepoRules {
    param([string]$ResourceGroup, [string]$NSGName)
    
    Write-ColorOutput "=== Removing Package Repository Access Rules ===" -ForegroundColor "Cyan"
    
    $ruleNames = @("AllowHTTPS", "AllowHTTP", "AllowDNS", "AllowNTP", "AllowRHELRepos")
    
    foreach ($ruleName in $ruleNames) {
        try {
            Write-ColorOutput "Removing rule: $ruleName" -ForegroundColor "Yellow"
            
            $result = az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NSGName --name $ruleName 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "  ✅ Rule '$ruleName' removed successfully" -ForegroundColor "Green"
            } else {
                Write-ColorOutput "  ⚠️ Rule '$ruleName' not found or already removed" -ForegroundColor "Yellow"
            }
            
        } catch {
            Write-ColorOutput "  ❌ Error removing rule '$ruleName': $($_.Exception.Message)" -ForegroundColor "Red"
        }
    }
}

# Function to test package repository access
function Test-PackageRepoAccess {
    param([string]$ResourceGroup)
    
    Write-ColorOutput "=== Testing Package Repository Access ===" -ForegroundColor "Cyan"
    
    # Find VMs in the resource group
    $vms = az vm list --resource-group $ResourceGroup --query "[].name" --output tsv 2>$null
    
    if (-not $vms) {
        Write-ColorOutput "No VMs found in resource group '$ResourceGroup'" -ForegroundColor "Yellow"
        return
    }
    
    $vmArray = $vms -split "`n" | Where-Object { $_ }
    $testVM = $vmArray[0]
    
    Write-ColorOutput "Testing connectivity on VM: $testVM" -ForegroundColor "Gray"
    
    $testScript = @'
#!/bin/bash
echo "=== Package Repository Connectivity Test ==="

# Test DNS resolution
echo "--- DNS Test ---"
if nslookup cdn.redhat.com >/dev/null 2>&1; then
    echo "✅ DNS resolution working (cdn.redhat.com)"
else
    echo "❌ DNS resolution failed"
fi

# Test HTTPS connectivity
echo "--- HTTPS Connectivity Test ---"
if curl -s --connect-timeout 10 https://cdn.redhat.com >/dev/null 2>&1; then
    echo "✅ HTTPS connectivity working (cdn.redhat.com)"
else
    echo "❌ HTTPS connectivity failed"
fi

# Test package manager
echo "--- Package Manager Test ---"
if timeout 30s sudo dnf check-update >/dev/null 2>&1; then
    echo "✅ Package manager connectivity working"
else
    echo "❌ Package manager connectivity failed"
fi

echo "=== Connectivity Test Complete ==="
'@
    
    try {
        $result = az vm run-command invoke `
            --resource-group $ResourceGroup `
            --name $testVM `
            --command-id RunShellScript `
            --scripts $testScript `
            --output json 2>$null
        
        if ($result) {
            $resultObj = $result | ConvertFrom-Json
            if ($resultObj.value -and $resultObj.value.Count -gt 0) {
                foreach ($output in $resultObj.value) {
                    if ($output.message) {
                        Write-ColorOutput $output.message -ForegroundColor "White"
                    }
                }
            }
        } else {
            Write-ColorOutput "Failed to execute connectivity test" -ForegroundColor "Red"
        }
    } catch {
        Write-ColorOutput "Error during connectivity test: $($_.Exception.Message)" -ForegroundColor "Red"
    }
}

# Main execution
function Main {
    Write-ColorOutput "=== Package Repository Access Configuration ===" -ForegroundColor "Cyan"
    Write-ColorOutput "Resource Group: $ResourceGroupName" -ForegroundColor "Gray"
    Write-ColorOutput "NSG Name: $NSGName" -ForegroundColor "Gray"
    Write-ColorOutput "Timestamp: $(Get-Date)" -ForegroundColor "Gray"
    Write-ColorOutput ""
    
    # Check prerequisites
    if (-not (Test-AzureCLI)) {
        return
    }
    
    if (-not (Test-NSGExists -ResourceGroup $ResourceGroupName -NSGName $NSGName)) {
        return
    }
    
    # Execute requested action
    if ($ListRules) {
        Get-NSGRules -ResourceGroup $ResourceGroupName -NSGName $NSGName
    } elseif ($RemoveRules) {
        Remove-PackageRepoRules -ResourceGroup $ResourceGroupName -NSGName $NSGName
        Write-ColorOutput ""
        Get-NSGRules -ResourceGroup $ResourceGroupName -NSGName $NSGName
    } else {
        Add-PackageRepoRules -ResourceGroup $ResourceGroupName -NSGName $NSGName
        Write-ColorOutput ""
        Get-NSGRules -ResourceGroup $ResourceGroupName -NSGName $NSGName
        Write-ColorOutput ""
        Test-PackageRepoAccess -ResourceGroup $ResourceGroupName
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "=== Configuration Complete ===" -ForegroundColor "Green"
}

# Execute main function
Main