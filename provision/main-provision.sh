#!/bin/bash
set -e

# Get arguments (from Vagrantfile) with defaults
TIMEZONE=${1:-"Europe/Berlin"}
KEYBOARD=${2:-"de"}
LOCALE=${3:-"en_US.UTF-8"}


echo "=== Starting System Configuration ==="
echo "Timezone: $TIMEZONE"
echo "Keyboard: $KEYBOARD" 
echo "Locale: $LOCALE"

# Update system
echo "=== Updating System ==="
apt-get update
apt-get upgrade -y

# Install essential packages
echo "=== Installing Essential Packages ==="
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    zsh \
    htop \
    tree \
    unzip \
    build-essential \
    python3-pip \
    nodejs \
    npm \
    docker.io \
    docker-compose \
    ca-certificates \
    gnupg \
    software-properties-common

# Configure timezone
echo "=== Configuring Timezone ==="
timedatectl set-timezone $TIMEZONE
echo "Timezone set to: $(timedatectl show --property=Timezone --value)"

# Configure keyboard
echo "=== Configuring Keyboard Layout ==="
cat > /etc/default/keyboard << EOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYBOARD"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# Apply keyboard settings
setupcon -k --force || true
localectl set-keymap $KEYBOARD

# Configure locale
echo "=== Configuring Locale ==="
locale-gen $LOCALE
localectl set-locale LANG=$LOCALE

# Configure Docker
echo "=== Configuring Docker ==="
usermod -aG docker vagrant
# systemctl enable docker
# systemctl start docker

# Create useful directories
echo "=== Setting up Directory Structure ==="
mkdir -p /opt/tools
mkdir -p /opt/wordlists
mkdir -p /home/vagrant/Desktop
mkdir -p /home/vagrant/.config
chown -R vagrant:vagrant /home/vagrant

# Install Oh My Zsh for root (will be installed for vagrant user in user-provision.sh)
echo "=== Installing Oh My Zsh for root ==="
if [ ! -d "/root/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    chsh -s $(which zsh) root
fi

# Configure Git globally
echo "=== Configuring Git ==="
git config --system init.defaultBranch main
git config --system pull.rebase false

# Install additional security tools
echo "=== Installing Additional Security Tools ==="
apt-get install -y \
    nmap \
    masscan \
    gobuster \
    dirbuster \
    nikto \
    sqlmap \
    hashcat \
    john \
    hydra \
    aircrack-ng \
    wireshark \
    tcpdump \
    netcat-traditional \
    socat \
    proxychains4 \
    tor \
    burpsuite \
    zaproxy

# Install Go (for modern security tools)
# echo "=== Installing Go ==="
# if [ ! -d "/usr/local/go" ]; then
#     GO_VERSION="1.21.6"
#     wget -q "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
#     tar -C /usr/local -xzf /tmp/go.tar.gz
#     echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/environment
#     echo "export GOPATH=/opt/go" >> /etc/environment
#     mkdir -p /opt/go
#     chown vagrant:vagrant /opt/go
#     rm /tmp/go.tar.gz
# fi

# Download common wordlists
echo "=== Setting up Wordlists ==="
if [ ! -f "/opt/wordlists/rockyou.txt" ]; then
    wget -q "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" -O /opt/wordlists/rockyou.txt
fi

if [ ! -d "/opt/wordlists/SecLists" ]; then
    git clone https://github.com/danielmiessler/SecLists.git /opt/wordlists/SecLists
fi

chown -R vagrant:vagrant /opt/wordlists

echo "=== System Configuration Complete ==="
