#!/bin/bash
set -e

# =============================================================================
# Desktop Environment Installation
# =============================================================================
# Installs the selected desktop environment (Xfce, GNOME, or KDE).
# This script is only run if DESKTOP_ENVIRONMENT is not "none".

export DEBIAN_FRONTEND=noninteractive

DESKTOP_ENVIRONMENT=${1:-"none"}

# Exit early if no desktop environment selected
if [ "$DESKTOP_ENVIRONMENT" = "none" ] || [ -z "$DESKTOP_ENVIRONMENT" ]; then
    echo "[+] No desktop environment selected, skipping..."
    echo "none" > /etc/vm-desktop
    exit 0
fi

echo "=============================================="
echo "  INSTALLING DESKTOP ENVIRONMENT"
echo "  Selected: $DESKTOP_ENVIRONMENT"
echo "=============================================="

# Store desktop environment for runtime detection
echo "$DESKTOP_ENVIRONMENT" > /etc/vm-desktop

# Install the appropriate desktop environment
case "$DESKTOP_ENVIRONMENT" in
    xfce)
        echo "[+] Installing Xfce (Kali's default, lightweight)..."
        apt-get update
        
        # Install Xfce desktop
        apt-get install -y \
            kali-desktop-xfce \
            lightdm \
            lightdm-gtk-greeter \
            xfce4-terminal \
            || apt-get install -y \
                xfce4 \
                xfce4-goodies \
                lightdm \
                lightdm-gtk-greeter \
                xfce4-terminal
        
        # Set lightdm as default display manager
        echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
        DISPLAY_MANAGER="lightdm"
        ;;
    
    gnome)
        echo "[+] Installing GNOME (modern, polished)..."
        apt-get update
        
        # Install GNOME desktop
        apt-get install -y \
            kali-desktop-gnome \
            gdm3 \
            gnome-terminal \
            || apt-get install -y \
                gnome-core \
                gdm3 \
                gnome-terminal \
                gnome-tweaks
        
        # Set gdm3 as default display manager
        echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager
        DISPLAY_MANAGER="gdm3"
        ;;
    
    kde)
        echo "[+] Installing KDE Plasma (feature-rich, customizable)..."
        apt-get update
        
        # Install KDE Plasma desktop
        apt-get install -y \
            kali-desktop-kde \
            sddm \
            konsole \
            || apt-get install -y \
                kde-plasma-desktop \
                sddm \
                konsole \
                dolphin
        
        # Set sddm as default display manager
        echo "/usr/sbin/sddm" > /etc/X11/default-display-manager
        DISPLAY_MANAGER="sddm"
        ;;
    
    *)
        echo "[!] Unknown desktop environment: $DESKTOP_ENVIRONMENT"
        echo "none" > /etc/vm-desktop
        exit 1
        ;;
esac

# Configure auto-login for vagrant user
echo "[+] Configuring auto-login for vagrant user..."

case "$DISPLAY_MANAGER" in
    lightdm)
        mkdir -p /etc/lightdm/lightdm.conf.d
        cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << 'EOF'
[Seat:*]
autologin-user=vagrant
autologin-user-timeout=0
EOF
        ;;
    
    gdm3)
        mkdir -p /etc/gdm3
        cat > /etc/gdm3/custom.conf << 'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=vagrant

[security]

[xdmcp]

[chooser]

[debug]
EOF
        ;;
    
    sddm)
        mkdir -p /etc/sddm.conf.d
        cat > /etc/sddm.conf.d/autologin.conf << 'EOF'
[Autologin]
User=vagrant
Session=plasma
EOF
        ;;
esac

# Enable the display manager
echo "[+] Enabling display manager: $DISPLAY_MANAGER..."
systemctl enable "$DISPLAY_MANAGER" || true

# Set graphical target as default
echo "[+] Setting graphical target as default..."
systemctl set-default graphical.target

echo ""
echo "=============================================="
echo "  DESKTOP INSTALLATION COMPLETE"
echo ""
echo "  Desktop: $DESKTOP_ENVIRONMENT"
echo "  Display Manager: $DISPLAY_MANAGER"
echo "  Auto-login: vagrant"
echo ""
echo "  The VM will boot to the graphical desktop."
echo "=============================================="
