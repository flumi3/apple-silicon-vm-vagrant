# -*- mode: ruby -*-
# vi: set ft=ruby :

# Load environment variables from .env file if it exists
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # dotenv gem not available, continue without it
end

# Configuration variables - can be overridden by environment variables
VM_NAME = ENV['VM_NAME'] || 'security-vm'
VM_MEMORY = ENV['VM_MEMORY'] || '4096' # 4GB RAM
VM_CPUS = ENV['VM_CPUS'] || '4'
VM_GUI = ENV['VM_GUI'] || 'false'

# User configuration
USER_TIMEZONE = ENV['USER_TIMEZONE'] || 'Europe/Berlin'
USER_KEYBOARD = ENV['USER_KEYBOARD'] || 'de'
USER_LOCALE = ENV['USER_LOCALE'] || 'en_US.UTF-8'

# Proxy configuration
HTTP_PROXY = ENV['HTTP_PROXY'] || ''
HTTPS_PROXY = ENV['HTTPS_PROXY'] || ''

Vagrant.configure("2") do |config|
  config.vm.box = "utm/bookworm"
  config.vm.box_check_update = true
  
  # VM configuration
  config.vm.hostname = VM_NAME
  
  # Network configuration
  config.vm.network "private_network", type: "dhcp"
  # Port forwarding for common services
  config.vm.network "forwarded_port", guest: 8080, host: 8080  # Burp/ZAP
  config.vm.network "forwarded_port", guest: 4444, host: 4444  # Metasploit
  config.vm.network "forwarded_port", guest: 8000, host: 8000  # HTTP server
  
  # Shared folders
  config.vm.synced_folder ".", "/vagrant"
  config.vm.synced_folder "./shared", "/home/vagrant/shared", create: true
  config.vm.synced_folder "./projects", "/home/vagrant/projects", create: true

  # VirtualBox specific settings
  config.vm.provider "utm" do |vb|
    vb.name = VM_NAME
    vb.memory = VM_MEMORY
    vb.cpus = VM_CPUS
    # vb.gui = VM_GUI == 'true'  # doesn't work with UTM as a provider
    
    # Performance optimizations (doesn't work with UTM as a provider)
    # vb.customize ["modifyvm", :id, "--vram", "128"]
    # vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
    # vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    # vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
  end
  
  # Copy configuration files
  # Remove existing certificate file to avoid permissions issues on re-provisioning
  config.vm.provision "shell",
    inline: "rm -f /tmp/ZscalerRootCertificate-2048-SHA256.crt",
    run: "always"

  config.vm.provision "file",
    source: "./config/ZscalerRootCertificate-2048-SHA256.crt", 
    destination: "/tmp/ZscalerRootCertificate-2048-SHA256.crt", 
    run: "always" if File.exist?("./config/ZscalerRootCertificate-2048-SHA256.crt")

  # Zscaler configuration
  config.vm.provision "shell",
    name: "configure-zscaler",
    path: "./provision/configure-zscaler.sh",
    args: [HTTP_PROXY, HTTPS_PROXY],
    privileged: true

  # Install packages
  config.vm.provision "shell",
    name: "install-packages",
    path: "./provision/install-packages.sh",
    privileged: true

  # System configuration
  config.vm.provision "shell",
    name: "system-config",
    path: "./provision/system-config.sh",
    args: [USER_TIMEZONE, USER_KEYBOARD, USER_LOCALE],
    privileged: true
  
  # User-specific provisioning (runs as vagrant user)
  config.vm.provision "shell",
    name: "user-config",
    path: "./provision/user-config.sh",
    privileged: true

  # Final system configuration
  config.vm.provision "shell",
    name: "final-provision",
    path: "./provision/final-provision.sh",
    privileged: true
end
