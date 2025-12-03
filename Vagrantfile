# -*- mode: ruby -*-
# vi: set ft=ruby :

# =============================================================================
# Kali Security VM for Apple Silicon Macs (UTM/QEMU)
# =============================================================================
# This Vagrantfile is designed specifically for Macs with Apple Silicon (M1/M2/M3/...).
#
# Quick start:
#   1. Run ./setup.sh to configure your environment
#   2. Run vagrant up
#
# For manual configuration, set environment variables or create a .env file.
# =============================================================================

# Load environment variables from .env file if it exists
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # dotenv gem not available, continue without it
end

# =============================================================================
# Configuration Variables
# =============================================================================

# VM Resources
VM_NAME = ENV['VM_NAME'] || 'debian-vm'
VM_MEMORY = ENV['VM_MEMORY'] || '4096'
VM_CPUS = ENV['VM_CPUS'] || '4'

# User Preferences
USER_TIMEZONE = ENV['USER_TIMEZONE'] || 'Europe/Berlin'
USER_KEYBOARD = ENV['USER_KEYBOARD'] || 'de'
USER_LOCALE = ENV['USER_LOCALE'] || 'en_US.UTF-8'

# Provisioning Mode: 'minimal' (fast, ~10 min) or 'full' (all security tools, ~20 min)
PROVISIONING_MODE = ENV['PROVISIONING_MODE'] || 'minimal'

# Desktop Environment: 'none', 'xfce', 'gnome', or 'kde'
DESKTOP_ENVIRONMENT = ENV['DESKTOP_ENVIRONMENT'] || 'none'

# Corporate Proxy Configuration (optional)
HTTP_PROXY = ENV['HTTP_PROXY'] || ''
HTTPS_PROXY = ENV['HTTPS_PROXY'] || ''

# =============================================================================
# Vagrant Configuration
# =============================================================================

Vagrant.configure("2") do |config|
  # Base box: Debian Bookworm for UTM (ARM64)
  config.vm.box = "utm/bookworm"
  config.vm.box_check_update = true
  config.vm.hostname = VM_NAME

  # ---------------------------------------------------------------------------
  # Network Configuration
  # ---------------------------------------------------------------------------
  config.vm.network "private_network", type: "dhcp"
  
  # Port forwarding for common security tools
  config.vm.network "forwarded_port", guest: 8080, host: 8080  # Burp Suite / ZAP
  config.vm.network "forwarded_port", guest: 4444, host: 4444  # Metasploit / Reverse shells
  config.vm.network "forwarded_port", guest: 8000, host: 8000  # HTTP server

  # ---------------------------------------------------------------------------
  # Shared Folders
  # ---------------------------------------------------------------------------
  config.vm.synced_folder ".", "/vagrant"
  config.vm.synced_folder "./shared", "/home/vagrant/shared", create: true
  config.vm.synced_folder "./projects", "/home/vagrant/projects", create: true

  # ---------------------------------------------------------------------------
  # UTM Provider Configuration (Apple Silicon)
  # ---------------------------------------------------------------------------
  config.vm.provider "utm" do |utm|
    utm.name = VM_NAME
    utm.memory = VM_MEMORY
    utm.cpus = VM_CPUS
  end

  # ---------------------------------------------------------------------------
  # Certificate Provisioning (Auto-detect all .crt files in config/)
  # ---------------------------------------------------------------------------
  # Clean up any previously uploaded certificates
  config.vm.provision "shell",
    inline: "rm -f /tmp/*.crt",
    run: "always"

  # Auto-detect and upload all .crt files from config/ directory
  Dir.glob("./config/*.crt").each do |cert_file|
    cert_name = File.basename(cert_file)
    config.vm.provision "file",
      source: cert_file,
      destination: "/tmp/#{cert_name}",
      run: "always"
  end

  # Upload Kali GPG keyring (fallback for corporate proxies blocking kali.org)
  if File.exist?("./config/kali-archive-keyring.gpg")
    config.vm.provision "file",
      source: "./config/kali-archive-keyring.gpg",
      destination: "/tmp/kali-archive-keyring.gpg",
      run: "always"
  end

  # ---------------------------------------------------------------------------
  # File provisioning
  # ---------------------------------------------------------------------------
  
  # Upload package lists needed for installation (upload all files in folder)
  Dir.glob("./provision/packages/*").each do |pkg_file|
    pkg_name = File.basename(pkg_file)
    config.vm.provision "file",
      source: pkg_file,
      destination: "/tmp/packages/#{pkg_name}",
      run: "always"
  end

  # Upload user-config files needed for provisioning
  Dir.glob("./provision/user-config/*").each do |pkg_file|
    pkg_name = File.basename(pkg_file)
    config.vm.provision "file",
      source: pkg_file,
      destination: "/tmp/user-config/#{pkg_name}",
      run: "always"
  end

  # Upload final-provision files needed for provisioning
  Dir.glob("./provision/final-provision/*").each do |pkg_file|
    pkg_name = File.basename(pkg_file)
    config.vm.provision "file",
      source: pkg_file,
      destination: "/tmp/final-provision/#{pkg_name}",
      run: "always"
  end

  # ---------------------------------------------------------------------------
  # Provisioning Scripts
  # ---------------------------------------------------------------------------
  
  # 1. Corporate proxy and certificate configuration
  config.vm.provision "shell",
    name: "configure-proxy",
    path: "./provision/configure-proxy.sh",
    args: [HTTP_PROXY, HTTPS_PROXY],
    privileged: true

  # 2. Package installation (minimal or full based on PROVISIONING_MODE)
  if PROVISIONING_MODE == 'full'
    config.vm.provision "shell",
      name: "install-packages-full",
      path: "./provision/install-packages-full.sh",
      privileged: true
  else
    config.vm.provision "shell",
      name: "install-packages-minimal",
      path: "./provision/install-packages-minimal.sh",
      privileged: true
  end

  # 3. System configuration (timezone, keyboard, locale)
  config.vm.provision "shell",
    name: "system-config",
    path: "./provision/system-config.sh",
    args: [USER_TIMEZONE, USER_KEYBOARD, USER_LOCALE],
    privileged: true

  # 4. User environment setup
  config.vm.provision "shell",
    name: "user-config",
    path: "./provision/user-config.sh",
    privileged: true

  # 5. Desktop environment installation (if selected)
  config.vm.provision "shell",
    name: "install-desktop",
    path: "./provision/install-desktop.sh",
    args: [DESKTOP_ENVIRONMENT],
    privileged: true

  # 6. Final configuration and verification
  config.vm.provision "shell",
    name: "final-provision",
    path: "./provision/final-provision.sh",
    privileged: true
end
