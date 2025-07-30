# Kali Linux Security VM with Vagrant

A fully automated, reproducible Kali Linux VM setup for security research, penetration testing, and training (TryHackMe,
HackTheBox, etc.).

## Features

- **Automated Certificate Management**: Handles Zscaler/corporate proxy certificates
- **Pre-configured Security Tools**: Nmap, Metasploit, Burp Suite, Gobuster, and more
- **Customizable Environment**: Timezone, keyboard, locale configuration
- **Development Ready**: Python, Node.js, Go, Docker pre-installed
- **User-friendly Setup**: Oh My Zsh, custom aliases, useful scripts
- **Persistent Storage**: Shared folders for projects and data

## Quick Start

1. **Install Prerequisites**:

   ```bash
   # Install VirtualBox and Vagrant
   # On Ubuntu/Debian:
   sudo apt update
   sudo apt install virtualbox vagrant

   # On macOS with Homebrew:
   brew install virtualbox vagrant
   ```

2. **Clone and Configure**:

   ```bash
   git clone <your-repo>
   cd kali-vagrant-vm

   # Copy your Zscaler certificate (optional)
   mkdir -p config
   cp /path/to/your/zscaler-cert.crt config/
   ```

3. **Start the VM**:

   ```bash
   vagrant up
   ```

4. **Connect**:

   ```bash
   # SSH access
   vagrant ssh

   # Or use the GUI (if enabled)
   # VirtualBox GUI will open automatically
   ```

## Configuration

### Environment Variables

Customize your VM by setting environment variables before running `vagrant up`:

```bash
export VM_NAME=my-kali-vm
export VM_MEMORY=8192        # RAM in MB
export VM_CPUS=4            # CPU cores
export VM_GUI=true          # Enable/disable GUI
export USER_TIMEZONE=Europe/London
export USER_KEYBOARD=gb     # Keyboard layout
export USER_LOCALE=en_GB.UTF-8
```

### Directory Structure

```text
kali-vagrant-vm/
├── Vagrantfile              # Main Vagrant configuration
├── provision/               # Provisioning scripts
│   ├── main-provision.sh    # System configuration
│   ├── user-provision.sh    # User-specific setup
│   └── final-provision.sh   # Final configuration
├── config/                  # Configuration files
│   ├── ZscalerRootCertificate-2048-SHA256.crt
```
