#!/bin/bash
set -e

# =============================================================================
# Minimal Package Installation
# =============================================================================
# Fast provisioning (~10 minutes) with essential tools only.
# For a complete security toolkit, use PROVISIONING_MODE=full
# =============================================================================

export DEBIAN_FRONTEND=noninteractive

echo "=============================================="
echo "  MINIMAL PROVISIONING MODE"
echo "  Installing essential packages only"
echo "  For development & security tools: PROVISIONING_MODE=full"
echo "=============================================="

# Export CA bundle for current session
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# =============================================================================
# System Update
# =============================================================================
echo "[+] Updating package repositories..."
apt-get update
# apt-get upgrade -y

# =============================================================================
# Essential Packages
# =============================================================================
echo "[+] Installing essential packages..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/packages"

# Read packages from essential.txt (skip comments and empty lines)
if [ -f "${PACKAGES_DIR}/essential.txt" ]; then
    grep -v '^#' "${PACKAGES_DIR}/essential.txt" | grep -v '^$' | xargs apt-get install -y
else
    echo "[!] ERROR: ${PACKAGES_DIR}/essential.txt not found"
    exit 1
fi

# Store provisioning mode for runtime detection
echo "minimal" > /etc/vm-provision-mode

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
echo "  To add security tools later, run:"
echo "  PROVISIONING_MODE=full vagrant provision"
echo "=============================================="
