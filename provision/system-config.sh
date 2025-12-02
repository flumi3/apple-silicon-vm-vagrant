#!/bin/bash
set -e

# Get arguments (from Vagrantfile) with defaults
TIMEZONE=${1:-"Europe/Berlin"}
KEYBOARD=${2:-"de"}
LOCALE=${3:-"en_US.UTF-8"}


echo "[+] Starting System Configuration..."
echo "Timezone: $TIMEZONE"
echo "Keyboard: $KEYBOARD" 
echo "Locale: $LOCALE"

# Configure timezone
echo "[+] Configuring Timezone..."
timedatectl set-timezone "$TIMEZONE"
echo "Timezone set to: $(timedatectl show --property=Timezone --value)"

# Configure locale
echo "[+] Configuring Locale..."
locale-gen "$LOCALE"
localectl set-locale LANG="$LOCALE"

# Configure keyboard layout
echo "[+] Configuring Keyboard Layout..."

# Ensure required packages are installed (non-interactive)
export DEBIAN_FRONTEND=noninteractive
apt-get install -y keyboard-configuration console-setup >/dev/null 2>&1 || true

# Pre-seed debconf answers for keyboard-configuration to provide non-interactive answers before any package config
echo "keyboard-configuration keyboard-configuration/layoutcode string $KEYBOARD" | debconf-set-selections
echo "keyboard-configuration keyboard-configuration/xkb-keymap select $KEYBOARD" | debconf-set-selections
echo "keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)" | debconf-set-selections
echo "keyboard-configuration keyboard-configuration/variant select " | debconf-set-selections

# Write keyboard configuration file
cat > /etc/default/keyboard << EOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYBOARD"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# Apply console keyboard settings
setupcon --save-only >/dev/null 2>&1 || true

# Configure X11 keyboard layout to ensure the layout is applied in graphical sessions (e.g. XFCE, GNOME, etc.)
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$KEYBOARD"
    Option "XkbModel" "pc105"
EndSection
EOF

# Try to set via localectl (works if systemd is fully running)
localectl set-x11-keymap "$KEYBOARD" pc105 "" "" 2>/dev/null || true

echo "[+] Keyboard layout configured to: $KEYBOARD"
