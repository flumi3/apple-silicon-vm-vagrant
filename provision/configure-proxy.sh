#!/bin/bash
set -e

# =============================================================================
# Corporate Proxy and Certificate Configuration
# =============================================================================
# This script configures corporate root CA certificates and proxy settings.
# It auto-detects all .crt files uploaded to /tmp/ and installs them.
#
# Supported certificates: Any valid root CA certificate in PEM format (.crt)
# Common examples: ZScaler, Netskope, Palo Alto, Forcepoint, etc.
#
# If running manually (not via Vagrant):
#   1. Place your certificate(s) in /tmp/ with .crt extension
#   2. Run: sudo ./configure-proxy.sh [HTTP_PROXY] [HTTPS_PROXY]
# =============================================================================

# Arguments passed from Vagrantfile
HTTP_PROXY=${1:-""}
HTTPS_PROXY=${2:-""}

# Helper function to add env var to /etc/environment idempotently
add_env_var() {
    local var_name="$1"
    local var_value="$2"
    if ! grep -q "^${var_name}=" /etc/environment 2>/dev/null; then
        echo "${var_name}=${var_value}" >> /etc/environment
    fi
}

# =============================================================================
# Certificate Installation
# =============================================================================
# Auto-detect and install all .crt files from /tmp/
CERTS_FOUND=0
for cert_file in /tmp/*.crt; do
    # Skip if no .crt files found (glob returns literal pattern)
    [ -e "$cert_file" ] || continue
    
    cert_name=$(basename "$cert_file")
    echo "[+] Installing certificate: $cert_name"
    
    # Install to system CA store
    cp "$cert_file" "/usr/local/share/ca-certificates/$cert_name"
    CERTS_FOUND=$((CERTS_FOUND + 1))
done

if [ "$CERTS_FOUND" -gt 0 ]; then
    echo "[+] Updating CA certificates store ($CERTS_FOUND certificate(s) added)..."
    update-ca-certificates
    
    # Verify certificates were installed
    for cert_file in /usr/local/share/ca-certificates/*.crt; do
        [ -e "$cert_file" ] || continue
        cert_name=$(basename "$cert_file")
        cert_hash=$(openssl x509 -in "$cert_file" -noout -hash 2>/dev/null || echo "unknown")
        
        if [ -f "/etc/ssl/certs/${cert_hash}.0" ]; then
            echo "[+] Certificate verified: $cert_name (hash: $cert_hash)"
        else
            echo "[!] WARNING: Certificate may not be properly installed: $cert_name"
        fi
    done
    
    # Configure certificate paths for various tools
    add_env_var "REQUESTS_CA_BUNDLE" "/etc/ssl/certs/ca-certificates.crt"
    add_env_var "SSL_CERT_FILE" "/etc/ssl/certs/ca-certificates.crt"
    add_env_var "NODE_EXTRA_CA_CERTS" "/etc/ssl/certs/ca-certificates.crt"
    add_env_var "CURL_CA_BUNDLE" "/etc/ssl/certs/ca-certificates.crt"
    
    # Export CA bundle for current session
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    
    echo "[+] Certificate configuration complete"
else
    echo "[*] No certificates found in /tmp/*.crt"
    echo "    Skipping corporate certificate configuration"
    echo ""
    echo "    If you're behind a corporate proxy, place your root CA certificate(s) in:"
    echo "    config/*.crt (any .crt file will be auto-detected)"
fi

# =============================================================================
# Proxy Configuration
# =============================================================================
if [ -n "$HTTP_PROXY" ]; then
    add_env_var "HTTP_PROXY" "$HTTP_PROXY"
    add_env_var "http_proxy" "$HTTP_PROXY"
    echo "[+] HTTP proxy configured: $HTTP_PROXY"
fi

if [ -n "$HTTPS_PROXY" ]; then
    add_env_var "HTTPS_PROXY" "$HTTPS_PROXY"
    add_env_var "https_proxy" "$HTTPS_PROXY"
    echo "[+] HTTPS proxy configured: $HTTPS_PROXY"
fi

if [ -z "$HTTP_PROXY" ] && [ -z "$HTTPS_PROXY" ]; then
    echo "[*] No proxy configuration specified"
fi

echo "[+] Proxy and certificate configuration complete"
