#!/bin/bash
# quick-gpu-test.sh - Simple and fast GPU functionality test
# Designed for quick validation of GPU setup

echo "=== Quick GPU Test ==="
echo "Date: $(date)"

# Check for NVIDIA GPU hardware
echo "--- Hardware Detection ---"
if lspci | grep -i nvidia; then
    echo "✅ NVIDIA GPU detected"
else
    echo "❌ No NVIDIA GPU found"
    exit 1
fi

# Check NVIDIA driver
echo "--- Driver Status ---"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✅ NVIDIA driver available"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    echo "❌ NVIDIA driver not found"
    echo "Installing NVIDIA driver..."
    sudo dnf install -y nvidia-driver
fi

# Quick X11 test
echo "--- X11 Setup ---"
export DISPLAY=:99
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 &
    sleep 2
fi

# Test OpenGL if available
echo "--- OpenGL Test ---"
if command -v glxinfo >/dev/null 2>&1; then
    echo "OpenGL Vendor: $(glxinfo -display :99 2>/dev/null | grep "OpenGL vendor" | cut -d':' -f2 | xargs)"
    echo "OpenGL Renderer: $(glxinfo -display :99 2>/dev/null | grep "OpenGL renderer" | cut -d':' -f2 | xargs)"
    
    if glxinfo -display :99 2>/dev/null | grep -q "direct rendering: Yes"; then
        echo "✅ Direct rendering: Yes"
    else
        echo "❌ Direct rendering: No"
    fi
else
    echo "⚠️ glxinfo not available - installing mesa-demos"
    sudo dnf install -y mesa-demos
fi

# Quick glxgears test (5 seconds)
echo "--- Quick glxgears Test ---"
if command -v glxgears >/dev/null 2>&1; then
    echo "Running 5-second glxgears test..."
    timeout 5s glxgears -display :99 >/dev/null 2>&1 && echo "✅ glxgears test passed" || echo "⚠️ glxgears test had issues"
else
    echo "❌ glxgears not available"
fi

echo "=== Quick GPU Test Complete ==="