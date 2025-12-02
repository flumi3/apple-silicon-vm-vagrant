#!/bin/bash
set -e

# This script configures the Zscaler root certificate and proxy settings for a debian based system.
#
# IMPORTANT: This script assumes that the Zscaler root certificate is already downloaded to /tmp/ZscalerRootCertificate-2048-SHA256.crt
# If you are using Vagrant, this is done automatically through the Vagrantfile.
#
# If you are running this script manually, you have to place the certificate into the /tmp directory of the target machine.
# In case you do not have internet access, you can transfer the file using a Python HTTP server:
# 1. On your host machine, navigate to the directory containing the certificate:
#    cd /path/to/certificate
# 2. Start a simple HTTP server:
#    python3 -m http.server 8000
# 3. On the target machine, get the host ip address:
#    ip addr show
#    If your guest's IP is something like 192.168.64.2, then the host is typically at .1 in that subnet (192.168.64.1)
# 4. On the target machine, use wget to download the certificate:
#    wget http://<host-ip>:8000/ZscalerRootCertificate-2048-SHA256.crt -O /tmp/ZscalerRootCertificate-2048-SHA256.crt

# Arguments passed from Vagrantfile: args: [HTTP_PROXY, HTTPS_PROXY]
HTTP_PROXY=${1:-""}
HTTPS_PROXY=${2:-""}

ZSCALER_ROOT_CERT_NAME="ZscalerRootCertificate-2048-SHA256.crt"

# Helper function to add env var to /etc/environment idempotently
add_env_var() {
    local var_name="$1"
    local var_value="$2"
    if ! grep -q "^${var_name}=" /etc/environment 2>/dev/null; then
        echo "${var_name}=${var_value}" >> /etc/environment
    fi
}

if [ -f "/tmp/$ZSCALER_ROOT_CERT_NAME" ]; then
    echo "[+] Configuring Zscaler Certificate..."
    
    # Install system-wide (idempotent - cp overwrites if exists)
    cp /tmp/$ZSCALER_ROOT_CERT_NAME /usr/local/share/ca-certificates/$ZSCALER_ROOT_CERT_NAME
    update-ca-certificates

    # Verify certificate was installed
    if openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /usr/local/share/ca-certificates/$ZSCALER_ROOT_CERT_NAME >/dev/null 2>&1; then
        echo "[+] Zscaler certificate verified successfully"
    else
        echo "[!] WARN: Certificate installed but verification skipped (self-signed root CA)"
    fi

    # Proxy configuration (idempotent)
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
    
    # Configure certificate paths for various tools (idempotent)
    add_env_var "REQUESTS_CA_BUNDLE" "/etc/ssl/certs/ca-certificates.crt"
    add_env_var "SSL_CERT_FILE" "/etc/ssl/certs/ca-certificates.crt"
    add_env_var "NODE_EXTRA_CA_CERTS" "/etc/ssl/certs/ca-certificates.crt"
    add_env_var "CURL_CA_BUNDLE" "/etc/ssl/certs/ca-certificates.crt"
    
    echo "[+] Zscaler certificate configured successfully"
    
    # Export CA bundle for current session (since /etc/environment isn't loaded yet)
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    
    # Verify Zscaler cert is in the CA bundle
    zscaler_hash=$(openssl x509 -in /usr/local/share/ca-certificates/$ZSCALER_ROOT_CERT_NAME -noout -hash 2>/dev/null)
    if [ -f "/etc/ssl/certs/${zscaler_hash}.0" ]; then
        echo "[+] Zscaler certificate verified in CA bundle (hash: $zscaler_hash)"
    else
        echo "[!] WARNING: Zscaler certificate may not be properly installed"
        echo "    This could cause SSL verification failures when downloading packages"
    fi
else
    echo "[*] No Zscaler certificate found at /tmp/$ZSCALER_ROOT_CERT_NAME"
    echo "    Skipping corporate certificate configuration"
    echo "    If you're behind a corporate proxy, place your root CA certificate at:"
    echo "    config/ZscalerRootCertificate-2048-SHA256.crt"
fi
