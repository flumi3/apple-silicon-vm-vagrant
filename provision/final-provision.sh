#!/bin/bash
set -e

echo "=== Final System Configuration ==="

# Clean up package cache
echo "=== Cleaning up package cache ==="
apt-get autoremove -y
apt-get autoclean

# Update locate database
echo "=== Updating locate database ==="
updatedb

# Configure system services
echo "=== Configuring Services ==="

# Disable unnecessary services for security VM
systemctl disable bluetooth
systemctl disable cups
systemctl disable avahi-daemon || true

# Enable useful services
systemctl enable ssh
# systemctl enable docker

# Configure SSH for better security
echo "=== Configuring SSH ==="
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create a simple motd
echo "=== Creating MOTD ==="
cat > /etc/motd << 'EOF'

 ██╗  ██╗ █████╗ ██╗     ██╗    ██╗   ██╗███╗   ███╗
 ██║ ██╔╝██╔══██╗██║     ██║    ██║   ██║████╗ ████║
 █████╔╝ ███████║██║     ██║    ██║   ██║██╔████╔██║
 ██╔═██╗ ██╔══██║██║     ██║    ╚██╗ ██╔╝██║╚██╔╝██║
 ██║  ██╗██║  ██║███████╗██║     ╚████╔╝ ██║ ╚═╝ ██║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝      ╚═══╝  ╚═╝     ╚═╝

 Security Research & Training Environment
 ========================================
 
 Quick Start:
 - Projects: ~/projects/
 - Shared:   ~/shared/
 - Tools:    /opt/tools/
 - Wordlists: /opt/wordlists/
 
 Useful Commands:
 - serve [port]     # Start HTTP server
 - revshell [ip] [port] # Generate reverse shells
 - gobuster-dir [url] # Quick directory busting

 Happy Hacking!

EOF

# Set file permissions
echo "=== Setting File Permissions ==="
chmod 755 /opt/tools
chmod 755 /opt/wordlists
chown -R vagrant:vagrant /opt/go 2>/dev/null || true

# Configure firewall (UFW)
echo "=== Configuring Firewall ==="
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8080  # Burp/ZAP
ufw allow 4444  # Metasploit
ufw allow 8000  # HTTP server
ufw --force enable

# Create system info script
echo "=== Creating System Info Script ==="
cat > /usr/local/bin/sysinfo << 'EOF'
#!/bin/bash
echo "=== Kali Linux VM System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo "IP Address: $(ip route get 1 | awk '{print $NF;exit}')"
echo ""
echo "=== Installed Security Tools ==="
echo "Nmap: $(nmap --version | head -1)"
echo "Metasploit: $(msfconsole -v 2>/dev/null | head -1 || echo 'Not available')"
echo "Burp Suite: $(which burpsuite >/dev/null && echo 'Installed' || echo 'Not found')"
echo "Gobuster: $(gobuster version 2>/dev/null || echo 'Not available')"
echo ""
echo "=== Custom Aliases Available ==="
echo "- serve [port]     # Start HTTP server"
echo "- revshell [ip] [port] # Generate reverse shells"
echo "- gobuster-dir [url] # Quick directory busting"
echo "- nmap-quick/nmap-full # Quick nmap scans"
EOF
chmod +x /usr/local/bin/sysinfo

# Configure log rotation for security tools
echo "=== Configuring Log Rotation ==="
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

# Create backup script for important configurations
echo "=== Creating Backup Script ==="
cat > /usr/local/bin/backup-config << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/vagrant/shared/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Creating configuration backup..."
mkdir -p "$BACKUP_DIR"

# Backup important configs
tar -czf "$BACKUP_DIR/vm-config-$DATE.tar.gz" \
    /home/vagrant/.zshrc \
    /home/vagrant/.vimrc \
    /home/vagrant/.tmux.conf \
    /home/vagrant/.gitconfig \
    /etc/hosts \
    /etc/ssh/sshd_config \
    2>/dev/null

echo "Backup created: $BACKUP_DIR/vm-config-$DATE.tar.gz"
EOF
chmod +x /usr/local/bin/backup-config

# Set correct shell for vagrant user
usermod -s /usr/bin/zsh vagrant

# Create a quick setup verification script
echo "=== Creating Setup Verification ==="
cat > /home/vagrant/verify-setup.sh << 'EOF'
#!/bin/bash
echo "=== Kali VM Setup Verification ==="
echo ""

# Check timezone
echo "Timezone: $(timedatectl show --property=Timezone --value)"

# Check keyboard
echo "Keyboard: $(localectl status | grep "X11 Layout" | cut -d: -f2 | xargs)"

# Check locale
echo "Locale: $(localectl status | grep "System Locale" | cut -d= -f2)"

# Check Zscaler cert
if [ -f "/usr/local/share/ca-certificates/zscaler-root.crt" ]; then
    echo "Zscaler cert: Installed"
else
    echo "Zscaler cert: Not installed"
fi

# Check important tools
echo ""
echo "=== Tool Check ==="
for tool in nmap gobuster burpsuite msfconsole docker go python3 pip3; do
    if command -v $tool >/dev/null 2>&1; then
        echo "$tool: Available"
    else
        echo "$tool: Not found"
    fi
done

# Check custom aliases
echo ""
echo "=== Custom Commands ==="
for cmd in serve revshell sysinfo backup-config; do
    if command -v $cmd >/dev/null 2>&1; then
        echo "$cmd: Available"
    else
        echo "$cmd: Not found"
    fi
done

echo ""
echo "=== Directory Structure ==="
for dir in /opt/tools /opt/wordlists ~/projects ~/shared; do
    if [ -d "$dir" ]; then
        echo "$dir: Exists"
    else
        echo "$dir: Missing"
    fi
done

echo ""
echo "Setup verification complete!"
EOF
chmod +x /home/vagrant/verify-setup.sh
chown vagrant:vagrant /home/vagrant/verify-setup.sh

echo "=== Final Configuration Complete ==="
echo "VM is ready for use!"
echo "Run 'sysinfo' for system information"
echo "Run '~/verify-setup.sh' to verify installation"
