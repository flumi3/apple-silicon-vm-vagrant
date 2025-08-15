# Security VM with Vagrant

A fully automated, reproducible Debian VM setup for security research, penetration testing, and training (TryHackMe,
HackTheBox, etc.).

## Features

- **Automated Certificate Management**: Handles Zscaler/corporate proxy certificates
- **Pre-configured Security Tools**: Nmap, Metasploit, Burp Suite, Gobuster, and more
- **Customizable Environment**: Timezone, keyboard, locale configuration
- **Development Ready**: Python, Node.js, Go, Docker pre-installed
- **User-friendly Setup**: Oh My Zsh, custom aliases, useful scripts
- **Persistent Storage**: Shared folders for projects and data

## Getting Started

1. **Install Prerequisites**:

   ```bash
   # Install VirtualBox and Vagrant
   # On Ubuntu/Debian:
   sudo apt update
   sudo apt install virtualbox vagrant

   # On macOS with Homebrew:
   brew install vagrant
   vagrant plugin install vagrant_utm
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

   # or this, if you want a log file
   vagrant up 2>&1 | tee vagrant-up-$(date +%Y%m%d-%H%M%S).log
   ```

4. **Connect**:

   ```bash
   # SSH access
   vagrant ssh

   # Or use the GUI (if enabled)
   # VirtualBox GUI will open automatically
   ```

## Vagrant Usage

### Provisioning

You can run specific provisioners:

```bash
# Run only the packages provisioner
vagrant provision --provision-with install-packages

# Run multiple specific provisioners
vagrant provision --provision-with configure-zscaler,install-packages

# Run only user configuration
vagrant provision --provision-with user-config
```

You can also use provisioner types to run all provisioners of a certain type:

```bash
# Run all shell provisioners
vagrant provision --provision-with shell

# Run all file provisioners
vagrant provision --provision-with file
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

## Troubleshooting

### SSL Error: Unable to Get Local Issuer Certificate (Zscaler)

This issue is likely caused by your company providing custom SSL certificates, i.e. the company performing an inspection
of all SSL traffic (e.g. using Zscaler). For doing so, they likely have deployed a custom root certificate. You can
validate that by going to Chrome or Firefox for an HTTPS site. Go into the information for that and look at who issued
it.

To resolve the issue, you will have to get that root cert and make it trusted by Vagrant.

1. Locate the `cacert.pem` file used by Vagrant:

   ```bash
   # Mac
   /opt/vagrant/embedded/

   # Windows
   /vagrant/embedded/
   ```

2. Download your company's root certificate (e.g., through Chrome or Firefox)

3. Append the content (including the `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----` lines) into the
   `cacert.pem` file.
