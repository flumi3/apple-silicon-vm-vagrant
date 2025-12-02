#!/bin/bash
set -e

# Set DEBIAN_FRONTEND to noninteractive to prevent any prompts
export DEBIAN_FRONTEND=noninteractive

# Setup Kali Linux repositories with APT pinning
# Priority 100 ensures Debian packages are preferred, Kali only used for tools not in Debian
setup_kali_repos() {
    echo "[+] Setting up Kali Linux repositories..."
    
    # Idempotency check - skip if already configured
    if [ -f /etc/apt/sources.list.d/kali.sources ]; then
        echo "[*] Kali repositories already configured, skipping..."
        return 0
    fi
    
    # Download and install Kali GPG key
    echo "[+] Adding Kali GPG key..."
    wget -q -O /tmp/kali-archive-key.asc https://archive.kali.org/archive-key.asc
    gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg /tmp/kali-archive-key.asc
    rm /tmp/kali-archive-key.asc
    
    # Create Kali sources file (deb822 format)
    echo "[+] Adding Kali repository..."
    cat > /etc/apt/sources.list.d/kali.sources << 'EOF'
Types: deb
URIs: http://http.kali.org/kali
Suites: kali-rolling
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF
    
    # Create APT pinning to prefer Debian packages over Kali
    # Priority 100 means: only use Kali packages if not available in Debian
    echo "[+] Configuring APT pinning..."
    cat > /etc/apt/preferences.d/kali.pref << 'EOF'
# Prefer Debian packages over Kali to maintain system stability
# Kali packages only used when not available in Debian repos
Package: *
Pin: release o=Kali
Pin-Priority: 100
EOF
    
    echo "[+] Kali repositories configured successfully"
}
setup_kali_repos

# Update system
echo "[+] Updating System..."
apt-get update
apt-get upgrade -y

# Install essential packages
echo "[+] Installing Essential Packages..."
apt-get install -y \
    ufw \
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
    pipx \
    nodejs \
    npm \
    docker.io \
    docker-compose \
    ca-certificates \
    gnupg \
    software-properties-common \
    openvpn

# Configure pip and npm trust store. This has to be done if using a custom certificate (e.g. Zscaler) because npm and
# pip maintain their own certificate stores.
pip3 config set global.cert /etc/ssl/certs/ca-certificates.crt
npm config set -g cafile /etc/ssl/certs/ca-certificates.crt

# Configure Docker
echo "[+] Configuring Docker..."
usermod -aG docker vagrant
# systemctl enable docker
# systemctl start docker

# Configure Git globally
echo "[+] Configuring Git..."
git config --system init.defaultBranch main
git config --system pull.rebase false

# Install Oh My Zsh for root (will be installed for the user in user-provision.sh)
# echo "=== Installing Oh My Zsh for root ==="
# if [ ! -d "/root/.oh-my-zsh" ]; then
#     sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
#     # Don't change root shell to avoid Vagrant SSH issues
#     # chsh -s "$(which zsh)" root
# fi

# # Install Go (for modern security tools)
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

# Install Kali security tools (via metapackage)
# kali-tools-top10 includes: nmap, sqlmap, john, hydra, wireshark, aircrack-ng, burpsuite, etc.
echo "[+] Installing Kali Security Tools (top10 metapackage)..."
apt-get install -y kali-tools-top10 || echo "[!] WARN: Some kali-tools-top10 packages may have failed"

# Install Python security tools
install_python_security_tools() {
    echo "[+] Installing Python Security Packages..."

    # Ensure pipx is properly configured
    pipx ensurepath || echo "[!] WARN: Failed to configure pipx ensurepath"
    sudo pipx ensurepath --global || echo "[!] WARN: Failed to configure pipx ensurepath --global" # optional to allow pipx actions with --global argument
    pipx completions || echo "[!] WARN: Failed to configure pipx completions"

    # Install packages that work well with pipx (command-line tools)
    local pipx_packages=(
        "impacket"
        "bloodhound"
        "droopescan"
        "wpscan"
        "subfinder"
        "crackmapexec"
        "scapy"
    )
    
    for package in "${pipx_packages[@]}"; do
        echo "Installing $package with pipx..."
        pipx install "$package" || echo "WARN: Failed to install $package with pipx"
    done

    # TODO: Change this in case it makes problems
    # Install libraries with pip3 (these are typically used as libraries, not CLI tools)
    # Using --break-system-packages since this is a controlled VM environment
    local pip3_packages=(
        "requests"
        "beautifulsoup4"
        "pwntools"
    )
    
    for package in "${pip3_packages[@]}"; do
        echo "Installing $package with pip3..."
        pip3 install --user --break-system-packages "$package" || echo "WARN: Failed to install $package with pip3"
    done
}
install_python_security_tools

# # Install Go security tools
# echo "=== Installing Go Security Tools ==="
# export PATH=$PATH:/usr/local/go/bin
# export GOPATH=/opt/go

# if [ -d "/usr/local/go" ]; then
#     go install github.com/ffuf/ffuf@latest
#     go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
#     go install github.com/projectdiscovery/httpx/cmd/httpx@latest
#     go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
#     go install github.com/tomnomnom/assetfinder@latest
#     go install github.com/tomnomnom/waybackurls@latest
    
#     # Add Go bin to PATH in shell configs
#     echo 'export PATH=$PATH:/opt/go/bin' >> ~/.zshrc
#     echo 'export PATH=$PATH:/opt/go/bin' >> ~/.bashrc
# fi

echo "[+] Installation complete"
