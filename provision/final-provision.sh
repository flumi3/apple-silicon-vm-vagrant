#!/bin/bash
set -e

CONFIG_DIR="/tmp/scripts/system"

echo "[+] Final System Configuration..."

# Clean up package cache
echo "[+] Cleaning up package cache..."
apt-get autoremove -y
apt-get autoclean

# Configure system services
echo "[+] Configuring Services..."

# Disable unnecessary services for security VM
systemctl disable avahi-daemon || true

# Enable useful services
systemctl enable ssh
# systemctl enable docker

# Configure SSH for better security
echo "[+] Configuring SSH..."
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Copy MOTD from config directory
echo "[+] Creating MOTD..."
if [ -f "${CONFIG_DIR}/motd" ]; then
    cp "${CONFIG_DIR}/motd" /etc/motd
else
    echo "[!] WARN: ${CONFIG_DIR}/motd not found"
fi

# Set file permissions
echo "[+] Setting File Permissions..."
chmod 755 /opt/tools 2>/dev/null || true
chmod 755 /opt/wordlists 2>/dev/null || true
chown -R vagrant:vagrant /opt/go 2>/dev/null || true

# Configure firewall (UFW)
echo "[+] Configuring Firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8080  # Burp/ZAP
ufw allow 4444  # Metasploit
ufw allow 8000  # HTTP server
ufw --force enable

# Copy system scripts from config directory
echo "[+] Installing System Scripts..."
for script in sysinfo backup-config helpme verify-setup; do
    if [ -f "${CONFIG_DIR}/${script}" ]; then
        cp "${CONFIG_DIR}/${script}" "/usr/local/bin/${script}"
        chmod +x "/usr/local/bin/${script}"
    else
        echo "[!] WARN: ${CONFIG_DIR}/${script} not found"
    fi
done

# Configure log rotation for security tools
echo "[+] Configuring Log Rotation..."
cat > /etc/logrotate.d/security-tools << 'EOF'
/home/vagrant/projects/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644 vagrant vagrant
}

/opt/tools/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644 vagrant vagrant
}
EOF

# Run verification script
echo "[+] Verifying setup..."
echo ""
/usr/local/bin/verify-setup
echo ""

# Run sysinfo
/usr/local/bin/sysinfo
echo ""

echo "[+] Final configuration complete..."
echo "VM is ready for use!"
echo "Run 'helpme' for detailed VM guide"
echo "Run 'sysinfo' for system information"
echo "Run 'verify-setup' to verify installation"
echo "----------------------------------"
upgradable_count=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
echo "The system has $upgradable_count upgradable packages."
echo "Consider upgrading the system with 'sudo apt update && sudo apt-get upgrade'"
