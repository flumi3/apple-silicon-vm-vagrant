#!/bin/bash
set -e

# =============================================================================
# Minimal Package Installation
# =============================================================================
# Fast provisioning (~10 minutes) with essential tools only.
# For a complete security toolkit, use PROVISIONING_MODE=full
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
echo "  MINIMAL INSTALLATION"
echo "  Installing essential packages"
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
PACKAGES_DIR="/tmp/packages"

# Read packages from essential.txt (skip comments and empty lines)
if [ -f "${PACKAGES_DIR}/essential.txt" ]; then
    grep -v '^#' "${PACKAGES_DIR}/essential.txt" | grep -v '^$' | xargs apt-get install -y
else
    echo "[!] ERROR: ${PACKAGES_DIR}/essential.txt not found"
    exit 1
fi

# Install pipx via pip to get latest version (Debian's apt version is outdated)
echo "[+] Installing pipx via pip..."
python3 -m pip install --user pipx --break-system-packages || echo "[!] WARN: Failed to install pipx"
export PATH="$HOME/.local/bin:$PATH"

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
# Ensure pipx is properly configured
python3 -m pipx ensurepath || echo "[!] WARN: Failed to configure pipx ensurepath"
pipx completions || echo "[!] WARN: Failed to configure pipx completions"
# Enable pipx autocompletion for bash (idempotent - check before adding)
if ! grep -q "register-python-argcomplete pipx" ~/.bashrc 2>/dev/null; then
    echo "eval '\$(register-python-argcomplete pipx)'" >> ~/.bashrc
fi
# TODO: enable autocompletion for zsh as well:
# To activate completions for zsh you need to have bashcompinit enabled in zsh:
#   autoload -U bashcompinit
#   bashcompinit
# Afterwards you can enable completion for pipx:
#   echo "eval '$(register-python-argcomplete pipx)'" >> ~/.zshrc

echo ""
echo "=============================================="
echo "  MINIMAL INSTALLATION COMPLETE"
echo ""
echo "  To add security tools later, run:"
echo "  PROVISIONING_MODE=full vagrant provision"
echo "=============================================="
