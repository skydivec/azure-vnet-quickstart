#!/bin/bash

# X11 Desktop Environment Setup Script for RHEL 8.10
# This script installs GNOME desktop environment, VNC server, and configures remote access
# Run this script on the RHEL VM after connecting via Azure Bastion

set -e

echo "=============================================="
echo "X11 Desktop Environment Setup for RHEL 8.10"
echo "=============================================="
echo "This script will install:"
echo "- GNOME Desktop Environment"
echo "- TigerVNC Server"
echo "- Firefox browser"
echo "- Desktop utilities"
echo "- Firewall configuration for VNC"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Please do not run this script as root. Run as azureuser."
   exit 1
fi

# Update system packages
echo "📦 Updating system packages..."
sudo dnf update -y

# Install EPEL repository for additional packages
echo "📦 Installing EPEL repository..."
sudo dnf install -y epel-release

# Install GNOME Desktop Environment
echo "🖥️  Installing GNOME Desktop Environment (this may take several minutes)..."
sudo dnf groupinstall -y "Server with GUI"

# Install VNC server
echo "🔧 Installing VNC server..."
sudo dnf install -y tigervnc-server tigervnc-server-module

# Install additional desktop tools
echo "📱 Installing additional desktop applications..."
sudo dnf install -y firefox gedit file-roller nautilus gnome-terminal

# Install development tools (useful for GPU/CUDA work)
echo "🛠️  Installing development tools..."
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git wget curl nano vim

# Set up VNC server for the current user
echo "🔐 Setting up VNC server for user: $USER"

# Create VNC directory
mkdir -p ~/.vnc

# Set VNC password
echo "🔑 Setting up VNC password..."
echo "Please enter a VNC password (will be used to connect remotely):"
vncpasswd

# Create VNC startup script
echo "📝 Creating VNC startup script..."
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec gnome-session
EOF

chmod +x ~/.vnc/xstartup

# Configure VNC service
echo "⚙️  Configuring VNC service..."
sudo cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@:1.service

# Replace the user in the service file
sudo sed -i "s/<USER>/$USER/g" /etc/systemd/system/vncserver@:1.service

# Reload systemd and enable VNC service
sudo systemctl daemon-reload
sudo systemctl enable vncserver@:1.service

# Configure firewall
echo "🔥 Configuring firewall..."
sudo firewall-cmd --permanent --add-port=5901/tcp
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --reload

# Set graphical target as default
echo "🎯 Setting graphical target as default..."
sudo systemctl set-default graphical.target

# Enable and start required services
echo "🚀 Starting services..."
sudo systemctl enable gdm

# Start VNC server
echo "📺 Starting VNC server..."
systemctl --user enable vncserver@:1.service
vncserver :1

# Get VM's private IP for connection info
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "✅ X11 desktop environment installation completed!"
echo "=============================================="
echo "📋 Connection Information:"
echo "   VNC Server: Running on display :1"
echo "   VNC Port: 5901"
echo "   VM Private IP: $PRIVATE_IP"
echo "   VNC Connection: $PRIVATE_IP:5901"
echo ""
echo "🔧 Next Steps:"
echo "1. To connect via VNC from outside Azure:"
echo "   - You'll need to set up SSH tunneling through Bastion"
echo "   - Or use Azure Bastion's native VNC support (if available)"
echo ""
echo "2. To restart VNC server:"
echo "   vncserver -kill :1"
echo "   vncserver :1"
echo ""
echo "3. To change VNC password:"
echo "   vncpasswd"
echo ""
echo "4. To connect locally (from another VM in the same VNet):"
echo "   Use any VNC client to connect to $PRIVATE_IP:5901"
echo ""
echo "🖥️  Desktop Environment:"
echo "   - GNOME Desktop is now available"
echo "   - Firefox browser installed"
echo "   - Development tools available"
echo "   - File manager (Nautilus) installed"
echo ""
echo "⚠️  Security Notes:"
echo "   - VNC traffic is not encrypted by default"
echo "   - Consider using SSH tunneling for secure connections"
echo "   - Change default VNC password regularly"
echo ""
echo "🔄 System will be ready after next reboot, or you can start manually:"
echo "   sudo systemctl start gdm"
echo "=============================================="