#!/bin/bash
# ================================================================
# X11 and GUI Setup Script for RHEL 8.10
# ================================================================
# This script configures X11 forwarding, VNC server, and GUI components
# Runs during VM initialization via cloud-init

set -e

LOG_FILE="/var/log/x11-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "================================================"
echo "Starting X11 and GUI setup for RHEL 8.10"
echo "Time: $(date)"
echo "================================================"

# ================================================================
# System Updates and Package Installation
# ================================================================

echo "[INFO] Updating system packages..."
dnf update -y

echo "[INFO] Installing EPEL repository..."
dnf install -y epel-release

echo "[INFO] Installing X11 and GUI packages..."
dnf groupinstall -y "Server with GUI"
dnf install -y \
    xorg-x11-server-Xorg \
    xorg-x11-xauth \
    xorg-x11-apps \
    firefox \
    gnome-session \
    gnome-shell \
    gdm \
    tigervnc-server \
    tigervnc-server-module \
    xrdp \
    openssh-server \
    git \
    wget \
    curl \
    vim \
    htop \
    net-tools

# ================================================================
# SSH Configuration for X11 Forwarding
# ================================================================

echo "[INFO] Configuring SSH for X11 forwarding..."
sed -i 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/' /etc/ssh/sshd_config
sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/' /etc/ssh/sshd_config

# Enable SSH service
systemctl enable sshd
systemctl restart sshd

# ================================================================
# VNC Server Configuration
# ================================================================

echo "[INFO] Configuring VNC server..."

# Create VNC directory for azureuser
VNC_USER="azureuser"
sudo -u $VNC_USER mkdir -p /home/$VNC_USER/.vnc

# Set VNC password (change this in production!)
echo "[INFO] Setting VNC password..."
sudo -u $VNC_USER bash -c 'echo "VncPassword123!" | vncpasswd -f > /home/$VNC_USER/.vnc/passwd'
sudo -u $VNC_USER chmod 600 /home/$VNC_USER/.vnc/passwd

# Create VNC startup script
sudo -u $VNC_USER tee /home/$VNC_USER/.vnc/xstartup > /dev/null << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
/etc/X11/xinit/xinitrc
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
# Start GNOME session
gnome-session &
EOF

sudo -u $VNC_USER chmod +x /home/$VNC_USER/.vnc/xstartup

# Configure VNC service
tee /etc/systemd/system/vncserver@.service > /dev/null << EOF
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking
User=$VNC_USER
Group=$VNC_USER
WorkingDirectory=/home/$VNC_USER
ExecStartPre=-/usr/bin/vncserver -kill :%i
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24
ExecStop=/usr/bin/vncserver -kill :%i
PIDFile=/home/$VNC_USER/.vnc/%H:%i.pid
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start VNC server
systemctl daemon-reload
systemctl enable vncserver@1.service

# ================================================================
# XRDP Configuration
# ================================================================

echo "[INFO] Configuring XRDP for RDP access..."
systemctl enable xrdp
systemctl start xrdp

# Configure XRDP to use GNOME
echo "gnome-session" > /home/$VNC_USER/.xsession
chown $VNC_USER:$VNC_USER /home/$VNC_USER/.xsession

# Allow RDP through firewall
firewall-cmd --permanent --add-port=3389/tcp
firewall-cmd --reload

# ================================================================
# Firewall Configuration
# ================================================================

echo "[INFO] Configuring firewall for X11 and VNC..."
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=5901/tcp   # VNC
firewall-cmd --permanent --add-port=6000-6010/tcp  # X11
firewall-cmd --reload

# ================================================================
# SELinux Configuration
# ================================================================

echo "[INFO] Configuring SELinux for VNC and X11..."
setsebool -P use_nfs_home_dirs 1
setsebool -P xserver_object_manager 1

# ================================================================
# GNOME Configuration
# ================================================================

echo "[INFO] Configuring GNOME desktop environment..."

# Set default target to graphical
systemctl set-default graphical.target

# Configure GDM for better remote access
mkdir -p /etc/gdm
tee /etc/gdm/custom.conf > /dev/null << EOF
[daemon]
AutomaticLoginEnable=false
DefaultSession=gnome-xorg.desktop
WaylandEnable=false

[security]

[xdmcp]
Enable=false

[chooser]

[debug]
EOF

# ================================================================
# Security Hardening
# ================================================================

echo "[INFO] Applying security hardening..."

# Disable unused services
systemctl disable bluetooth
systemctl disable cups

# Configure automatic security updates
dnf install -y dnf-automatic
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic.timer

# Install and configure fail2ban
dnf install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# ================================================================
# User Environment Setup
# ================================================================

echo "[INFO] Setting up user environment..."

# Add useful aliases for azureuser
sudo -u $VNC_USER tee -a /home/$VNC_USER/.bashrc > /dev/null << 'EOF'

# X11 and VNC aliases
alias startvnc='vncserver :1 -geometry 1920x1080 -depth 24'
alias stopvnc='vncserver -kill :1'
alias vncstatus='ps aux | grep vnc'

# System monitoring
alias sysinfo='echo "=== System Information ==="; hostnamectl; echo; echo "=== Memory Usage ==="; free -h; echo; echo "=== Disk Usage ==="; df -h'
alias ports='netstat -tuln'

echo "X11 and VNC server configured successfully!"
echo "VNC Password: VncPassword123! (Please change this!)"
echo "To start VNC server: vncserver :1"
echo "To connect via SSH with X11: ssh -X username@hostname"
EOF

# ================================================================
# Create Desktop Shortcuts
# ================================================================

echo "[INFO] Creating desktop shortcuts..."
sudo -u $VNC_USER mkdir -p /home/$VNC_USER/Desktop

sudo -u $VNC_USER tee /home/$VNC_USER/Desktop/Firefox.desktop > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox
Comment=Web Browser
Exec=firefox
Icon=firefox
Terminal=false
Categories=Application;Network;
EOF

sudo -u $VNC_USER chmod +x /home/$VNC_USER/Desktop/Firefox.desktop

# ================================================================
# Final Configuration
# ================================================================

echo "[INFO] Performing final configuration..."

# Start VNC server
sudo -u $VNC_USER vncserver :1 -geometry 1920x1080 -depth 24

# Create status file
tee /var/log/x11-setup-complete > /dev/null << EOF
X11 and GUI Setup Completed Successfully
Time: $(date)
VNC Server: Running on port 5901
XRDP: Running on port 3389
X11 Forwarding: Enabled
GUI: GNOME Desktop Environment
User: $VNC_USER
EOF

echo "================================================"
echo "X11 and GUI setup completed successfully!"
echo "================================================"
echo "Services configured:"
echo "  - SSH with X11 forwarding (port 22)"
echo "  - VNC server (port 5901)"
echo "  - XRDP server (port 3389)"
echo "  - GNOME desktop environment"
echo ""
echo "Connection methods:"
echo "  1. SSH with X11: ssh -X $VNC_USER@<vm-ip>"
echo "  2. VNC client: connect to <vm-ip>:5901"
echo "  3. RDP client: connect to <vm-ip>:3389"
echo ""
echo "Default VNC password: VncPassword123!"
echo "Please change this password for security!"
echo "================================================"

# Reboot to ensure all services start correctly
echo "[INFO] Scheduling reboot in 2 minutes..."
shutdown -r +2 "Rebooting to complete X11 setup"

exit 0