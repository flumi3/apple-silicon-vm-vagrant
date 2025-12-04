#!/bin/bash
set -e

# =============================================================================
# Full Package Installation
# =============================================================================
# This script extends install-packages-minimal.sh with security and development
# tools. It should only run AFTER install-packages-minimal.sh has completed.
#
# Includes:
# - Kali Linux repository setup with APT pinning
# - Individual Kali tools (avoiding metapackage dependency conflicts)
# - Metasploit Framework via Docker (lazy-loading wrapper)
# - Python security packages via pipx/pip
# - Common wordlists
# =============================================================================

# Prevent interactive prompts during package installation
export DEBIAN_FRONTEND=noninteractive
# Prevent needrestart from prompting during automated provisioning
export NEEDRESTART_MODE=a
# Completely disable needrestart to prevent SSH restart killing Vagrant connection
export NEEDRESTART_SUSPEND=1
# Also disable via config file (belt and suspenders)
mkdir -p /etc/needrestart/conf.d
echo "\$nrconf{restart} = 'l';" > /etc/needrestart/conf.d/50-vagrant.conf

echo "=============================================="
echo "  FULL INSTALLATION"
echo "  Extending minimal setup with security and development tools"
echo "  This may take 10-15 minutes..."
echo "=============================================="

# Package lists are uploaded to /tmp/packages by Vagrant
PACKAGES_DIR="/tmp/packages"

# =============================================================================
# Kali Repository Setup
# =============================================================================
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

# =============================================================================
# Kali Tools Installation (Individual Packages)
# =============================================================================
# Install tools individually to avoid dependency conflicts from metapackages
install_kali_tools() {
    echo "[+] Installing Kali Security Tools (individual packages)..."
    
    if [ ! -f "${PACKAGES_DIR}/kali-tools.txt" ]; then
        echo "[!] WARN: ${PACKAGES_DIR}/kali-tools.txt not found, skipping Kali tools"
        return 0
    fi
    
    local failed_packages=""
    local success_count=0
    local fail_count=0
    
    while IFS= read -r package; do
        # Skip comments and empty lines
        [[ "$package" =~ ^#.*$ || -z "$package" ]] && continue
        
        echo "    Installing: $package"
        if apt-get install -y "$package" 2>/dev/null; then
            ((success_count++)) || true
        else
            echo "    [!] WARN: Failed to install $package"
            failed_packages="$failed_packages $package"
            ((fail_count++)) || true
        fi
    done < "${PACKAGES_DIR}/kali-tools.txt"
    
    echo "[+] Kali tools installation complete: $success_count succeeded, $fail_count failed"
    if [ -n "$failed_packages" ]; then
        echo "    Failed packages:$failed_packages"
    fi
}

# =============================================================================
# Metasploit Framework (Docker-based)
# =============================================================================
# Metasploit requires ruby 3.3+ and libc6 2.38+ which conflict with Debian 12.
# We use the official Docker image with a wrapper script for seamless usage.
install_metasploit_docker() {
    echo "[+] Setting up Metasploit Framework (Docker)..."
    
    # Ensure Docker is available
    if ! command -v docker &> /dev/null; then
        echo "[!] WARN: Docker not available, skipping Metasploit setup"
        echo "    Install docker.io package and re-run provisioning"
        return 1
    fi
    
    # Install wrapper scripts from config (uploaded to /tmp/scripts/system/)
    local scripts_dir="/tmp/scripts/system"
    
    for script in msfconsole msfvenom; do
        if [ -f "${scripts_dir}/${script}" ]; then
            cp "${scripts_dir}/${script}" "/usr/local/bin/${script}"
            chmod +x "/usr/local/bin/${script}"
        else
            echo "[!] WARN: ${scripts_dir}/${script} not found"
        fi
    done
    
    echo "[+] Metasploit wrapper scripts created"
    echo "    Run 'msfconsole' to start (image will download on first use)"
}

# =============================================================================
# Python Security Tools
# =============================================================================
install_python_security_tools() {
    echo "[+] Installing Python Security Packages..."

    # Ensure pipx is available and in PATH for the vagrant user
    export PATH="/home/vagrant/.local/bin:/root/.local/bin:$PATH"

    # Read Python tools from packages file
    if [ -f "${PACKAGES_DIR}/python-tools.txt" ]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            
            if [[ "$line" == pipx:* ]]; then
                package="${line#pipx:}"
                echo "    Installing $package with pipx (as vagrant)..."
                sudo -H -u vagrant bash -lc 'export PATH="$HOME/.local/bin:$PATH"; pipx install "'$package'"' || echo "    [!] WARN: Failed to install $package with pipx"
            elif [[ "$line" == pip:* ]]; then
                package="${line#pip:}"
                echo "    Installing $package with pip3..."
                pip3 install --user --break-system-packages "$package" || echo "    [!] WARN: Failed to install $package with pip3"
            fi
        done < "${PACKAGES_DIR}/python-tools.txt"
    else
        echo "[!] WARN: ${PACKAGES_DIR}/python-tools.txt not found, skipping Python tools"
    fi
}

# =============================================================================
# Wordlists Setup
# =============================================================================
setup_wordlists() {
    echo "[+] Setting up Wordlists..."
    mkdir -p /opt/wordlists
    
    # Download rockyou.txt if not present
    if [ ! -f "/opt/wordlists/rockyou.txt" ]; then
        echo "    Downloading rockyou.txt..."
        wget -q "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
            -O /opt/wordlists/rockyou.txt || echo "    [!] WARN: Failed to download rockyou.txt"
    fi
    
    # Set permissions
    chown -R vagrant:vagrant /opt/wordlists 2>/dev/null || true
}

# =============================================================================
# Docker Configuration
# =============================================================================
configure_docker() {
    echo "[+] Configuring Docker..."
    
    # Add vagrant user to docker group
    usermod -aG docker vagrant 2>/dev/null || true
    
    # Enable and start Docker service
    systemctl enable docker 2>/dev/null || true
    systemctl start docker 2>/dev/null || true
}

# =============================================================================
# Main Execution
# =============================================================================

# Update provisioning mode marker
echo "full" > /etc/vm-provision-mode

# Setup Kali repositories
setup_kali_repos

# Update package lists after adding Kali repos
echo "[+] Updating package lists..."
apt-get update

# Install full-mode extra packages (nodejs, docker, etc.)
echo "[+] Installing Full Mode Extra Packages..."
if [ -f "${PACKAGES_DIR}/full-extras.txt" ]; then
    grep -v '^#' "${PACKAGES_DIR}/full-extras.txt" | grep -v '^$' | xargs apt-get install -y || true
else
    echo "[!] WARN: ${PACKAGES_DIR}/full-extras.txt not found, skipping extras"
fi

# Configure Docker
configure_docker

# Install Kali tools individually
install_kali_tools

# Setup Metasploit via Docker
install_metasploit_docker

# Install Python security tools
install_python_security_tools

# Setup wordlists
setup_wordlists

echo ""
echo "=============================================="
echo "  FULL INSTALLATION COMPLETE"
echo ""
echo "  Installed:"
echo "  - Kali security tools (nmap, sqlmap, john, hydra, etc.)"
echo "  - Metasploit Framework (Docker-based, lazy-loaded)"
echo "  - Python security packages (impacket, bloodhound, etc.)"
echo "  - Common wordlists (rockyou.txt)"
echo ""
echo "  Note: Run 'msfconsole' to start Metasploit"
echo "        (Docker image downloads on first use)"
echo "=============================================="
