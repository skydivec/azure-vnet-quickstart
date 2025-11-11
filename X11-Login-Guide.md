# X11 Login Guide for Azure GPU VMs

This guide explains how to access X11 desktop environments on Azure GPU VMs deployed with our infrastructure.

## Overview

Our Azure GPU VM deployment includes automated X11 desktop environment setup with VNC access for graphical applications and GPU testing.

## Prerequisites

- Azure GPU VM deployed using our Bicep template
- VM running RHEL 8.10 with GPU drivers installed
- Azure Bastion or SSH access to the VM
- VNC viewer client on your local machine

## Access Methods

### Method 1: Direct SSH with X11 Forwarding (Recommended)

If you have direct SSH access to the VM:

```bash
# Connect with X11 forwarding enabled
ssh -X azureuser@<vm-public-ip>

# Test X11 forwarding
xeyes &
```

### Method 2: Azure Bastion + VNC (Most Secure)

1. **Connect via Azure Bastion:**
   ```bash
   # Use Azure Bastion to connect securely
   az network bastion ssh --name "bastion-main" --resource-group "<resource-group>" --target-resource-id "<vm-resource-id>" --auth-type "ssh-key" --username "azureuser" --ssh-key "<path-to-private-key>"
   ```

2. **Setup VNC Server:**
   ```bash
   # Run the X11 setup script (if not already done)
   curl -s https://raw.githubusercontent.com/skydivec/azure-vnet-quickstart/master/scripts/setup-x11-rhel.sh | bash
   
   # Start VNC server
   vncserver :1 -geometry 1024x768
   
   # Set VNC password when prompted
   ```

3. **Create SSH Tunnel:**
   ```bash
   # From your local machine, create SSH tunnel through Bastion
   # (This requires additional Bastion configuration for tunneling)
   ssh -L 5901:localhost:5901 azureuser@<bastion-connection>
   ```

4. **Connect with VNC Viewer:**
   - Open your VNC viewer client
   - Connect to: `localhost:5901`
   - Enter the VNC password you set

### Method 3: Virtual Display for Headless Testing

For automated testing without GUI display:

```bash
# Start virtual display
export DISPLAY=:99
Xvfb :99 -screen 0 1024x768x24 &

# Run GUI applications
glxgears -display :99 &
```

## X11 Desktop Environment Details

### Installed Components

Our setup script installs:
- **X Window System**: Core X11 display server
- **GNOME Desktop**: Full desktop environment
- **VNC Server**: Remote desktop access
- **GPU Tools**: NVIDIA drivers, OpenGL utilities
- **Development Tools**: Mesa demos, glxgears, glxinfo

### Desktop Features

- **Full GNOME Desktop**: Complete graphical desktop environment
- **GPU Acceleration**: Hardware-accelerated graphics
- **OpenGL Support**: Full OpenGL rendering capabilities
- **Terminal Access**: Multiple terminal applications
- **File Manager**: Graphical file browsing
- **Web Browser**: Firefox for web access

## GPU Testing with X11

### Quick GPU Test
```bash
# Run quick GPU functionality test
./scripts/quick-gpu-test.sh
```

### Comprehensive GPU Test
```bash
# Run full GPU test suite
./scripts/run-glxgears.sh
```

### Manual GPU Testing
```bash
# Check GPU hardware
lspci | grep -i nvidia
nvidia-smi

# Test OpenGL
glxinfo | grep -E "(OpenGL vendor|OpenGL renderer|OpenGL version)"
glxgears &

# Test direct rendering
glxinfo | grep "direct rendering"
```

## Common Applications

### Graphics Development
```bash
# Install additional graphics tools
sudo dnf install -y gimp inkscape blender

# Install development environments
sudo dnf install -y code gedit
```

### Scientific Computing
```bash
# Install scientific Python stack
sudo dnf install -y python3-numpy python3-matplotlib python3-scipy
pip3 install --user jupyter

# Run Jupyter with graphics
jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser
```

## Troubleshooting

### X11 Not Starting
```bash
# Check X11 service status
systemctl status gdm

# Restart display manager
sudo systemctl restart gdm

# Check for display issues
echo $DISPLAY
xset -display :0 q
```

### VNC Connection Issues
```bash
# Check VNC server status
vncserver -list

# Restart VNC server
vncserver -kill :1
vncserver :1

# Check VNC logs
tail -f ~/.vnc/*.log
```

### GPU Not Detected
```bash
# Reinstall NVIDIA drivers
sudo dnf remove -y nvidia*
sudo dnf install -y nvidia-driver nvidia-settings

# Reboot VM
sudo reboot
```

### Performance Issues
```bash
# Check GPU utilization
nvidia-smi -l 1

# Check memory usage
free -h
top

# Check graphics performance
glxgears -info
```

## Security Considerations

### VNC Security
- Always use SSH tunneling for VNC connections
- Set strong VNC passwords
- Consider using SSH key authentication
- Limit VNC server to localhost binding

### Firewall Configuration
```bash
# Check firewall status
sudo firewall-cmd --list-all

# Allow VNC through firewall (if needed)
sudo firewall-cmd --add-port=5901/tcp --permanent
sudo firewall-cmd --reload
```

## Advanced Configuration

### Custom Display Resolution
```bash
# Set custom VNC resolution
vncserver :1 -geometry 1920x1080

# Add custom resolution to X11
xrandr --newmode "1920x1080" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
xrandr --addmode Virtual-1 "1920x1080"
xrandr --output Virtual-1 --mode "1920x1080"
```

### Multiple Displays
```bash
# Start multiple VNC sessions
vncserver :1  # Port 5901
vncserver :2  # Port 5902
vncserver :3  # Port 5903

# List active sessions
vncserver -list
```

### Desktop Environment Alternatives
```bash
# Install lightweight alternatives
sudo dnf install -y xfce4 lxde

# Configure VNC to use different desktop
echo "exec startxfce4" > ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup
```

## Automation Scripts

Our deployment includes several automation scripts:

- **`setup-x11-rhel.sh`**: Complete X11 environment setup
- **`run-glxgears.sh`**: Comprehensive GPU testing
- **`Test-VMGPUFunctionality.ps1`**: PowerShell GPU testing
- **`quick-gpu-test.sh`**: Fast GPU validation

## Support and Resources

### Log Locations
- X11 logs: `/var/log/Xorg.*.log`
- VNC logs: `~/.vnc/*.log`
- GNOME logs: `journalctl --user -u gnome-session`
- GPU logs: `dmesg | grep -i nvidia`

### Useful Commands
```bash
# Monitor GPU usage
watch -n 1 nvidia-smi

# Check X11 processes
ps aux | grep -E "(X|gnome|vnc)"

# Test graphics stack
glxinfo | head -20
```

### Getting Help
- Check VM serial console in Azure portal
- Review deployment logs in Azure Activity Log
- Use Azure Monitor for performance metrics
- Contact support with VM resource ID and logs

## Best Practices

1. **Always use SSH tunneling** for VNC connections
2. **Set strong passwords** for VNC access
3. **Monitor GPU utilization** during graphics workloads
4. **Regular backups** of important data
5. **Keep drivers updated** for optimal performance
6. **Use virtual displays** for automated testing
7. **Limit VNC access** to required users only

This guide provides comprehensive instructions for accessing and using X11 desktop environments on your Azure GPU VMs. For additional support, refer to the Azure documentation or contact your system administrator.