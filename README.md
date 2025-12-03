# Debian (Security) VM for Apple Silicon

Want to quickly spin up VMs on your Mac running Apple Silicon (M1/M2/etc.)? Not optimal...  
Want to do this behind a corporate proxy with SSL inspection and limited internet access? _Might as well bring the ring
to Mordor and throw it into the volcano yourself..._  
But wait, there's hope!

With just a few commands, you can create VMs that are ready for **security testing**, **development**, or other tasks.
Using UTM and Vagrant, this project handles everything for you: installing **tools**, configuring **shared folders**,
setting up **keyboard layouts**, **timezones**, **locales**, and even making the VM work seamlessly behind corporate
proxies.

Jump to the [Quick Start](#quick-start) guide below, or check out the `docs/` folder for more information.

## Features

- 🚀 **Quick Setup**: Interactive CLI wizard (`./setup.sh`) configures everything
- ⚡ **Flexible Provisioning**: Choose minimal VM (~10 min) or full security/dev toolkit (~20-30 min)
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

## Next Steps

- [Configuration](docs/configuration.md) — Environment variables and Vagrant commands
- [Technical Details](docs/technical_details.md) — How provisioning works and architecture decisions
- [SSL Inspection & Proxies](docs/ssl_inspection_and_proxies.md) — Corporate proxy and certificate setup
- [Troubleshooting](docs/troubleshooting.md) — Common issues and solutions
