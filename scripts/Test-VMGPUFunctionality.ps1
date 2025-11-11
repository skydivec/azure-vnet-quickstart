# Test-VMGPUFunctionality.ps1
# PowerShell script for automated GPU testing on Azure VMs
# Supports both local and remote execution via Azure CLI

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VMName = "vm-1",
    
    [Parameter(Mandatory = $false)]
    [switch]$LocalTest,
    
    [Parameter(Mandatory = $false)]
    [switch]$InstallRequirements,
    
    [Parameter(Mandatory = $false)]
    [int]$TestDurationSeconds = 30
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to test local GPU functionality
function Test-LocalGPU {
    Write-ColorOutput "=== Local GPU Testing ===" -ForegroundColor "Cyan"
    
    try {
        # Check if we're on a Linux system
        if ($IsLinux) {
            Write-ColorOutput "Running on Linux system" -ForegroundColor "Green"
            
            # Make script executable and run
            $scriptPath = "/home/azureuser/run-glxgears.sh"
            if (Test-Path $scriptPath) {
                chmod +x $scriptPath
                bash $scriptPath
            } else {
                Write-ColorOutput "GPU test script not found at $scriptPath" -ForegroundColor "Red"
                return $false
            }
        } else {
            Write-ColorOutput "Local GPU testing only supported on Linux" -ForegroundColor "Yellow"
            return $false
        }
    } catch {
        Write-ColorOutput "Error during local GPU testing: $($_.Exception.Message)" -ForegroundColor "Red"
        return $false
    }
    
    return $true
}

# Function to test remote GPU functionality via Azure CLI
function Test-RemoteGPU {
    param(
        [string]$ResourceGroup,
        [string]$VirtualMachine
    )
    
    Write-ColorOutput "=== Remote GPU Testing via Azure CLI ===" -ForegroundColor "Cyan"
    Write-ColorOutput "Resource Group: $ResourceGroup" -ForegroundColor "Gray"
    Write-ColorOutput "VM Name: $VirtualMachine" -ForegroundColor "Gray"
    
    try {
        # Verify Azure CLI is available
        $azVersion = az --version 2>$null
        if (-not $azVersion) {
            Write-ColorOutput "Azure CLI not found. Please install Azure CLI." -ForegroundColor "Red"
            return $false
        }
        
        Write-ColorOutput "Azure CLI found" -ForegroundColor "Green"
        
        # Check if VM exists and get its status
        Write-ColorOutput "Checking VM status..." -ForegroundColor "Yellow"
        $vmStatus = az vm show --resource-group $ResourceGroup --name $VirtualMachine --query "powerState" --output tsv 2>$null
        
        if (-not $vmStatus) {
            Write-ColorOutput "VM '$VirtualMachine' not found in resource group '$ResourceGroup'" -ForegroundColor "Red"
            return $false
        }
        
        Write-ColorOutput "VM Status: $vmStatus" -ForegroundColor "Green"
        
        if ($vmStatus -ne "VM running") {
            Write-ColorOutput "VM is not running. Current state: $vmStatus" -ForegroundColor "Red"
            return $false
        }
        
        # Get VM size to verify it's GPU-enabled
        $vmSize = az vm show --resource-group $ResourceGroup --name $VirtualMachine --query "hardwareProfile.vmSize" --output tsv
        Write-ColorOutput "VM Size: $vmSize" -ForegroundColor "Green"
        
        # Check if it's a GPU VM size
        if ($vmSize -like "*NV*" -or $vmSize -like "*NC*" -or $vmSize -like "*ND*") {
            Write-ColorOutput "✅ Confirmed GPU-enabled VM size" -ForegroundColor "Green"
        } else {
            Write-ColorOutput "⚠️ VM size may not be GPU-enabled: $vmSize" -ForegroundColor "Yellow"
        }
        
        # Create the test script content
        $testScript = @'
#!/bin/bash
echo "=== GPU Test Execution Started ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"

# Basic GPU detection
echo "=== GPU Hardware Detection ==="
if lspci | grep -i nvidia; then
    echo "✅ NVIDIA GPU detected"
else
    echo "❌ No NVIDIA GPU found"
fi

# Check for NVIDIA driver
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✅ NVIDIA driver found"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
else
    echo "❌ NVIDIA driver not installed"
    echo "Installing NVIDIA drivers..."
    sudo dnf install -y nvidia-driver nvidia-settings
fi

# Install X11 and OpenGL if needed
if ! command -v glxgears >/dev/null 2>&1; then
    echo "Installing X11 and OpenGL packages..."
    sudo dnf groupinstall -y "X Window System"
    sudo dnf install -y mesa-demos mesa-dri-drivers xorg-x11-server-Xvfb
fi

# Setup virtual display
export DISPLAY=:1
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting virtual display..."
    Xvfb :1 -screen 0 1024x768x24 &
    sleep 3
fi

# Test OpenGL
if command -v glxinfo >/dev/null 2>&1; then
    echo "=== OpenGL Information ==="
    glxinfo -display :1 | grep -E "(OpenGL vendor|OpenGL renderer|OpenGL version)"
    
    if glxinfo -display :1 | grep -q "direct rendering: Yes"; then
        echo "✅ Direct rendering: Yes"
    else
        echo "❌ Direct rendering: No"
    fi
fi

# Run glxgears test
if command -v glxgears >/dev/null 2>&1; then
    echo "=== Running glxgears test (10 seconds) ==="
    timeout 10s glxgears -display :1 -info 2>&1 || echo "glxgears test completed"
else
    echo "❌ glxgears not available"
fi

echo "=== GPU Test Execution Complete ==="
'@
        
        # Execute the test script on the remote VM
        Write-ColorOutput "Executing GPU test script on VM..." -ForegroundColor "Yellow"
        
        $result = az vm run-command invoke `
            --resource-group $ResourceGroup `
            --name $VirtualMachine `
            --command-id RunShellScript `
            --scripts $testScript `
            --output json 2>$null
        
        if ($result) {
            $resultObj = $result | ConvertFrom-Json
            if ($resultObj.value -and $resultObj.value.Count -gt 0) {
                Write-ColorOutput "=== GPU Test Results ===" -ForegroundColor "Cyan"
                foreach ($output in $resultObj.value) {
                    if ($output.code -eq "ProvisioningState/succeeded") {
                        Write-ColorOutput "✅ Command executed successfully" -ForegroundColor "Green"
                    }
                    if ($output.message) {
                        Write-ColorOutput $output.message -ForegroundColor "White"
                    }
                }
            }
        } else {
            Write-ColorOutput "Failed to execute GPU test on remote VM" -ForegroundColor "Red"
            return $false
        }
        
    } catch {
        Write-ColorOutput "Error during remote GPU testing: $($_.Exception.Message)" -ForegroundColor "Red"
        return $false
    }
    
    return $true
}

# Function to install requirements on remote VM
function Install-RemoteRequirements {
    param(
        [string]$ResourceGroup,
        [string]$VirtualMachine
    )
    
    Write-ColorOutput "=== Installing Requirements on Remote VM ===" -ForegroundColor "Cyan"
    
    $installScript = @'
#!/bin/bash
echo "Installing GPU testing requirements..."

# Update system
sudo dnf update -y

# Install X Window System
sudo dnf groupinstall -y "X Window System"

# Install OpenGL and related packages
sudo dnf install -y mesa-demos mesa-dri-drivers xorg-x11-server-Xvfb \
                   xorg-x11-apps glx-utils tigervnc-server

# Install NVIDIA drivers if not present
if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "Installing NVIDIA drivers..."
    sudo dnf install -y nvidia-driver nvidia-settings
fi

echo "Requirements installation complete"
'@
    
    try {
        $result = az vm run-command invoke `
            --resource-group $ResourceGroup `
            --name $VirtualMachine `
            --command-id RunShellScript `
            --scripts $installScript `
            --output json
        
        if ($result) {
            Write-ColorOutput "✅ Requirements installed successfully" -ForegroundColor "Green"
            return $true
        }
    } catch {
        Write-ColorOutput "Error installing requirements: $($_.Exception.Message)" -ForegroundColor "Red"
    }
    
    return $false
}

# Main execution
function Main {
    Write-ColorOutput "=== Azure VM GPU Functionality Test ===" -ForegroundColor "Cyan"
    Write-ColorOutput "Test Duration: $TestDurationSeconds seconds" -ForegroundColor "Gray"
    Write-ColorOutput "Timestamp: $(Get-Date)" -ForegroundColor "Gray"
    
    $success = $false
    
    if ($LocalTest) {
        $success = Test-LocalGPU
    } else {
        # Validate parameters for remote testing
        if (-not $ResourceGroupName) {
            Write-ColorOutput "Resource group name is required for remote testing" -ForegroundColor "Red"
            Write-ColorOutput "Use -ResourceGroupName parameter or -LocalTest for local testing" -ForegroundColor "Yellow"
            return
        }
        
        # Install requirements if requested
        if ($InstallRequirements) {
            Install-RemoteRequirements -ResourceGroup $ResourceGroupName -VirtualMachine $VMName
        }
        
        $success = Test-RemoteGPU -ResourceGroup $ResourceGroupName -VirtualMachine $VMName
    }
    
    if ($success) {
        Write-ColorOutput "=== GPU Testing Completed Successfully ===" -ForegroundColor "Green"
    } else {
        Write-ColorOutput "=== GPU Testing Failed ===" -ForegroundColor "Red"
    }
}

# Execute main function
Main