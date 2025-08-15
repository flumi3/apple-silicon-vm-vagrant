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

# FIXME: keyboard config
# # Configure keyboard
# echo "=== Configuring Keyboard Layout ==="

# # Set DEBIAN_FRONTEND to noninteractive to prevent any prompts
# export DEBIAN_FRONTEND=noninteractive
# apt-get install -y console-setup keyboard-configuration kbd

# cat > /etc/default/keyboard << EOF
# XKBMODEL="pc105"
# XKBLAYOUT="$KEYBOARD"
# XKBVARIANT=""
# XKBOPTIONS=""
# BACKSPACE="guess"
# EOF

# # Apply keyboard settings
# setupcon -k --force || true
# localectl set-keymap "$KEYBOARD"
