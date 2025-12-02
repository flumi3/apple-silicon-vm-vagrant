#!/bin/bash
set -e

# =============================================================================
# Minimal Package Installation
# =============================================================================
# Fast provisioning (~5-10 minutes) with essential tools only.
# For a complete security toolkit, use PROVISIONING_MODE=full
# =============================================================================

export DEBIAN_FRONTEND=noninteractive

echo "=============================================="
echo "  MINIMAL PROVISIONING MODE"
echo "  Installing essential packages only"
echo "  For full security tools: PROVISIONING_MODE=full"
echo "=============================================="

# Export CA bundle for current session
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# =============================================================================
# System Update
# =============================================================================
echo "[+] Updating system..."
apt-get update
apt-get upgrade -y

# =============================================================================
# Essential Packages
# =============================================================================
echo "[+] Installing essential packages..."
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
    python3-venv \
    pipx \
    nodejs \
    npm \
    ca-certificates \
    gnupg \
    software-properties-common \
    openvpn \
    tmux \
    jq

# =============================================================================
# Configure Tools
# =============================================================================

# Configure pip and npm to use system CA bundle
echo "[+] Configuring pip and npm trust stores..."
pip3 config set global.cert /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true
npm config set -g cafile /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true

# Configure Git
echo "[+] Configuring Git..."
git config --system init.defaultBranch main
git config --system pull.rebase false

# Configure pipx
echo "[+] Configuring pipx..."
pipx ensurepath 2>/dev/null || true
sudo pipx ensurepath --global 2>/dev/null || true

echo ""
echo "=============================================="
echo "  MINIMAL INSTALLATION COMPLETE"
echo ""
echo "  Installed: curl, wget, git, vim, zsh, htop,"
echo "  openvpn, python3, nodejs, tmux"
echo ""
echo "  To add security tools later, run:"
echo "  PROVISIONING_MODE=full vagrant provision"
echo "=============================================="
