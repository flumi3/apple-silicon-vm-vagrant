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
    
    # Ensure gnupg and wget are available for key handling
    echo "[+] Installing prerequisites for Kali repo setup..."
    apt-get update
    apt-get install -y gnupg wget
    
    # Download and install Kali GPG key
    echo "[+] Adding Kali GPG key..."
    mkdir -p /usr/share/keyrings
    
    # Export CA bundle for current session (in case /etc/environment isn't loaded yet)
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    
    # Install curl if not present
    apt-get install -y curl >/dev/null 2>&1 || true
    
    key_downloaded=false
    
    # Try downloading from official Kali server first
    echo "[+] Downloading Kali GPG key from archive.kali.org..."
    if curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL -A "Mozilla/5.0" -o /tmp/kali-archive-key.asc https://archive.kali.org/archive-key.asc 2>/dev/null && [ -s /tmp/kali-archive-key.asc ]; then
        gpg --dearmor --yes -o /usr/share/keyrings/kali-archive-keyring.gpg /tmp/kali-archive-key.asc
        rm -f /tmp/kali-archive-key.asc
        key_downloaded=true
    else
        echo "    [!] Official server blocked, trying mirrors..."
    fi
    
    # Try downloading keyring package from mirrors
    if [ "$key_downloaded" = false ]; then
        for url in "https://ftp.halifax.rwth-aachen.de/kali/pool/main/k/kali-archive-keyring/kali-archive-keyring_2024.1_all.deb" \
                   "https://mirror.karneval.cz/pub/linux/kali/pool/main/k/kali-archive-keyring/kali-archive-keyring_2024.1_all.deb"; do
            if curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL -A "Mozilla/5.0" -o /tmp/kali-keyring.deb "$url" 2>/dev/null && [ -s /tmp/kali-keyring.deb ]; then
                dpkg-deb -x /tmp/kali-keyring.deb /tmp/kali-keyring
                if [ -f /tmp/kali-keyring/usr/share/keyrings/kali-archive-keyring.gpg ]; then
                    cp /tmp/kali-keyring/usr/share/keyrings/kali-archive-keyring.gpg /usr/share/keyrings/kali-archive-keyring.gpg
                    rm -rf /tmp/kali-keyring /tmp/kali-keyring.deb
                    echo "[+] Downloaded keyring from mirror"
                    key_downloaded=true
                    break
                fi
                rm -rf /tmp/kali-keyring /tmp/kali-keyring.deb
            fi
        done
        
        if [ "$key_downloaded" = false ]; then
            echo "    [!] Mirror download also failed, checking for local fallback..."
        fi
    fi
    
    # FALLBACK: Use bundled keyring file if all downloads failed
    if [ "$key_downloaded" = false ]; then
        for keyfile in "/vagrant/config/kali-archive-keyring.gpg" "/tmp/kali-archive-keyring.gpg"; do
            if [ -f "$keyfile" ] && [ -s "$keyfile" ]; then
                echo "[+] Using bundled keyring fallback: $keyfile"
                # Check if it's armored (ASCII) or binary
                if head -1 "$keyfile" | grep -q "BEGIN PGP"; then
                    gpg --dearmor --yes -o /usr/share/keyrings/kali-archive-keyring.gpg "$keyfile"
                else
                    cp "$keyfile" /usr/share/keyrings/kali-archive-keyring.gpg
                fi
                key_downloaded=true
                break
            fi
        done
    fi

    echo "[+] Kali GPG key installed successfully"
    
    # Find an accessible Kali mirror
    # Corporate proxies often block kali.org domains, so we try university mirrors first
    echo "[+] Finding accessible Kali mirror..."
    
    KALI_MIRROR=""
    declare -A MIRROR_NAMES=(
        ["https://ftp.halifax.rwth-aachen.de/kali"]="RWTH Aachen (Germany)"
        ["https://mirror.karneval.cz/pub/linux/kali"]="Karneval (Czech Republic)"
        ["https://ftp.acc.umu.se/mirror/kali.org/kali"]="Umeå University (Sweden)"
        ["http://http.kali.org/kali"]="Official Kali"
    )
    
    for mirror in "https://ftp.halifax.rwth-aachen.de/kali" \
                  "https://mirror.karneval.cz/pub/linux/kali" \
                  "https://ftp.acc.umu.se/mirror/kali.org/kali" \
                  "http://http.kali.org/kali"; do
        if curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL -A "Mozilla/5.0" -o /dev/null "$mirror/dists/kali-rolling/InRelease" 2>/dev/null; then
            KALI_MIRROR="$mirror"
            echo "[+] Using mirror: ${MIRROR_NAMES[$mirror]} ($mirror)"
            break
        fi
    done
    
    if [ -z "$KALI_MIRROR" ]; then
        echo ""
        echo "[!] ERROR: No accessible Kali mirror found"
        echo ""
        echo "    Your network appears to be blocking all Kali repository mirrors."
        echo "    This is common in corporate environments with strict firewall policies."
        echo ""
        echo "    SOLUTIONS:"
        echo "    1. Request your IT team to whitelist one of these domains:"
        echo "       - ftp.halifax.rwth-aachen.de (RWTH Aachen University)"
        echo "       - mirror.karneval.cz"
        echo "       - ftp.acc.umu.se"
        echo "       - http.kali.org"
        echo ""
        echo "    2. Or run 'vagrant up' while disconnected from corporate network"
        echo ""
        exit 1
    fi
    
    cat > /etc/apt/sources.list.d/kali.sources << EOF
Types: deb
URIs: $KALI_MIRROR
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

# Install Kali security tools (via metapackage)
# kali-tools-top10 includes: nmap, sqlmap, john, hydra, wireshark, aircrack-ng, burpsuite, etc.
# See https://www.kali.org/tools/kali-meta/
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

echo "[+] Installation complete"
