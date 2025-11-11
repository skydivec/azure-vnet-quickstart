#!/bin/bash
# GPU Testing Script - run-glxgears.sh
# Comprehensive GPU testing with X11 validation for RHEL systems

set -e

echo "=== GPU Testing Suite - Starting ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install required packages
install_requirements() {
    echo "=== Installing Required Packages ==="
    
    # Update package cache
    sudo dnf update -y
    
    # Install X11 and OpenGL packages
    sudo dnf groupinstall -y "X Window System"
    sudo dnf install -y mesa-demos mesa-dri-drivers xorg-x11-server-Xvfb \
                        xorg-x11-apps glx-utils tigervnc-server \
                        nvidia-driver nvidia-settings
    
    echo "Package installation complete"
}

# Function to setup X11 environment
setup_x11() {
    echo "=== Setting up X11 Environment ==="
    
    # Set display
    export DISPLAY=:1
    
    # Start Xvfb if not running
    if ! pgrep -x "Xvfb" > /dev/null; then
        echo "Starting Xvfb..."
        Xvfb :1 -screen 0 1024x768x24 &
        sleep 2
    fi
    
    # Verify DISPLAY is available
    if xset -display :1 q >/dev/null 2>&1; then
        echo "X11 display :1 is available"
    else
        echo "Failed to setup X11 display"
        return 1
    fi
}

# Function to test GPU hardware detection
test_gpu_detection() {
    echo "=== GPU Hardware Detection ==="
    
    # Check for NVIDIA GPU
    if lspci | grep -i nvidia; then
        echo "✅ NVIDIA GPU detected via lspci"
    else
        echo "❌ No NVIDIA GPU found via lspci"
    fi
    
    # Check NVIDIA driver
    if command_exists nvidia-smi; then
        echo "✅ NVIDIA driver installed"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
    else
        echo "❌ NVIDIA driver not found"
    fi
    
    # Check OpenGL support
    if command_exists glxinfo; then
        echo "=== OpenGL Information ==="
        glxinfo -display :1 | grep -E "(OpenGL vendor|OpenGL renderer|OpenGL version)"
    fi
}

# Function to run glxgears test
run_glxgears() {
    echo "=== Running glxgears GPU Test ==="
    
    if command_exists glxgears; then
        echo "Starting glxgears test (30 second duration)..."
        timeout 30s glxgears -display :1 -info 2>&1 || {
            echo "glxgears test completed (or timed out after 30s)"
        }
    else
        echo "❌ glxgears not available"
        return 1
    fi
}

# Function to run additional GPU tests
run_additional_tests() {
    echo "=== Additional GPU Tests ==="
    
    # Test glxinfo
    if command_exists glxinfo; then
        echo "--- Direct Rendering Test ---"
        if glxinfo -display :1 | grep -q "direct rendering: Yes"; then
            echo "✅ Direct rendering: Yes"
        else
            echo "❌ Direct rendering: No"
        fi
    fi
    
    # Test es2_info if available
    if command_exists es2_info; then
        echo "--- OpenGL ES 2.0 Info ---"
        es2_info -display :1 2>/dev/null || echo "OpenGL ES 2.0 test skipped"
    fi
    
    # GPU memory test
    echo "--- GPU Memory Information ---"
    if command_exists nvidia-smi; then
        nvidia-smi --query-gpu=memory.used,memory.free,memory.total --format=csv,noheader,nounits
    fi
}

# Function to create test report
create_report() {
    local report_file="/tmp/gpu_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "=== Creating Test Report ==="
    {
        echo "GPU Test Report - $(date)"
        echo "================================"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo "OS: $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
        echo ""
        echo "=== Hardware Detection ==="
        lspci | grep -i nvidia || echo "No NVIDIA GPU found"
        echo ""
        echo "=== Driver Information ==="
        nvidia-smi --query-gpu=name,driver_version --format=csv 2>/dev/null || echo "NVIDIA driver not available"
        echo ""
        echo "=== OpenGL Information ==="
        glxinfo -display :1 | grep -E "(OpenGL vendor|OpenGL renderer|OpenGL version)" 2>/dev/null || echo "OpenGL info not available"
        echo ""
        echo "=== Direct Rendering ==="
        glxinfo -display :1 | grep "direct rendering" 2>/dev/null || echo "Direct rendering info not available"
    } > "$report_file"
    
    echo "Test report saved to: $report_file"
    echo "Report contents:"
    cat "$report_file"
}

# Main execution
main() {
    echo "=== GPU Testing Suite Started ==="
    
    # Install requirements if needed
    if ! command_exists glxgears || ! command_exists glxinfo; then
        install_requirements
    fi
    
    # Setup X11
    setup_x11
    
    # Run tests
    test_gpu_detection
    run_glxgears
    run_additional_tests
    
    # Create report
    create_report
    
    echo "=== GPU Testing Suite Complete ==="
}

# Run main function
main "$@"