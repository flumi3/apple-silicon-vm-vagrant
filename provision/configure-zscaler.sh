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

HTTP_PROXY=${4:-""}
HTTPS_PROXY=${5:-""}

ZSCALER_ROOT_CERT_NAME="ZscalerRootCertificate-2048-SHA256.crt"

if [ -f "/tmp/$ZSCALER_ROOT_CERT_NAME" ]; then
    echo "=== Configuring Zscaler Certificate ==="
    
    # Install system-wide
    cp /tmp/$ZSCALER_ROOT_CERT_NAME /usr/local/share/ca-certificates/$ZSCALER_ROOT_CERT_NAME
    update-ca-certificates

    # Proxy configuration
    if [ -n "$HTTP_PROXY" ]; then
        echo "HTTP_PROXY=$HTTP_PROXY" >> /etc/environment
    fi

    if [ -n "$HTTPS_PROXY" ]; then
        echo "HTTPS_PROXY=$HTTPS_PROXY" >> /etc/environment
    fi
    
    # Python configuration
    echo "REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" >> /etc/environment
    echo "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt" >> /etc/environment
    
    # Set Node.js certificate environment
    echo "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt" >> /etc/environment
    
    # Configure curl and wget
    echo "CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" >> /etc/environment
    
    echo "Zscaler certificate configured successfully"
else
    echo "No Zscaler certificate found, skipping corporate cert configuration"
fi
