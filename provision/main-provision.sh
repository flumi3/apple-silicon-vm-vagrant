#!/bin/bash
set -e

# Create useful directories
echo "=== Setting up Directory Structure ==="
mkdir -p /opt/tools
mkdir -p /opt/wordlists
mkdir -p /home/"$USER"/Desktop
mkdir -p /home/"$USER"/.config
chown -R "$USER":"$USER" /home/"$USER"

# Download common wordlists
echo "=== Setting up Wordlists ==="
if [ ! -f "/opt/wordlists/rockyou.txt" ]; then
    wget -q "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" -O /opt/wordlists/rockyou.txt
fi

if [ ! -d "/opt/wordlists/SecLists" ]; then
    git clone https://github.com/danielmiessler/SecLists.git /opt/wordlists/SecLists
fi

chown -R "$USER":"$USER" /opt/wordlists

echo "=== System Configuration Complete ==="
