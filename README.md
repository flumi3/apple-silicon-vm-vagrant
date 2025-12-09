# Security focused Debian VM for Apple Silicon using Vagrant & UTM

Want to spin up reproducible VMs on your Mac running Apple Silicon (M1/M2/etc.)? Tough...  
Want to have Kali-Linux? Sitting behind a corporate proxy with SSL inspection? This will make you cry - I promise.  
But wait, there's hope!

This project creates **reproducible Debian-based security/dev VMs** on Apple Silicon Macs using
[Vagrant](https://developer.hashicorp.com/vagrant) and [UTM](https://mac.getutm.app/).  
It installs **tools**, configures **shared folders**, sets up **keyboard layouts**, **timezones**, **locales**, and even
makes the VM work seamlessly behind corporate proxies.

Jump to the [Quick Start](#quick-start) guide below, or check out the `docs/` folder for more information.

## Features

- 🚀 **Quick Setup**: Interactive CLI wizard (`./setup.sh`) configures everything
- ⚡ **Flexible Provisioning**: Choose minimal VM (~10 min) or full security/dev toolkit (~15-20 min)
- 🔒 **Corporate Proxy Support**: Auto-detects and installs any CA certificates in `config/`
- 🛠️ **Security Tools**: Installs the most important security tools from Kali repositories
- 🐳 **Development Ready**: Docker, Python, Node.js
- 💻 **Customizable**: Timezone, keyboard, locale configuration
- 📁 **Persistent Storage**: Shared folders for projects and data

## Quick Start

### Prerequisites

```bash
# Install UTM
brew install --cask utm

# Install Vagrant
brew install --cask vagrant

# Install the UTM plugin for Vagrant
vagrant plugin install vagrant_utm
```

### Setup

```bash
# Clone the repository
git clone git@github.com:flumi3/apple-silicon-vm-vagrant.git
cd apple-silicon-vm-vagrant

# Run the setup wizard
./setup.sh

# Start the VM
vagrant up
```

### Connect

```bash
vagrant ssh
```

> 💡 **Tip:** Run `helpme` inside the VM to see available commands, directory structure, and useful information.

## Next Steps

- [Configuration](docs/configuration.md) — Environment variables and Vagrant commands
- [Technical Details](docs/technical_details.md) — How provisioning works and architecture decisions
- [SSL Inspection & Proxies](docs/ssl_inspection_and_proxies.md) — Corporate proxy and certificate setup
- [Troubleshooting](docs/troubleshooting.md) — Common issues and solutions
