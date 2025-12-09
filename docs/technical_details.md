# Technical Details

This guide explains the technical architecture behind the project: how the provisioning pipeline works, why we chose
Vagrant with UTM as the virtualization backend, and the rationale for using Debian with Kali repositories instead of a
pure Kali image.

### Content

- [Provisioning Pipeline](#provisioning-pipeline)
- [File Organization & Customization Points](#file-organization--customization-points)
- [Why Vagrant + UTM?](#why-vagrant--utm)
- [Why not Kali Linux?](#why-not-kali-linux)

## Provisioning Pipeline

When you run `vagrant up`, the VM goes through **6 sequential stages** to set you up with a ready-to-use Debian-based
security/development environment (see `Vagrantfile` line ~140+):

```mermaid
flowchart LR
    S1["1. Certificates & Proxy"] --> S2["2. Packages"] --> S3["3. System Config"] --> S4["4. User Environment"] --> S5["5. Desktop"] --> S6["6. Final Setup"]
```

1. **configure-proxy.sh** — Auto-detects `config/*.crt` files, installs to system CA store, sets environment variables
2. **install-packages-minimal.sh** — Core tools (curl, git, vim, zsh, Python, pipx)
3. **install-packages-full.sh** — (only if `PROVISIONING_MODE=full`) Adds Kali repos with APT pinning, security tools,
   Docker, wordlists
4. **system-config.sh** — Timezone, keyboard layout, locale (X11 + console)
5. **user-config.sh** — Oh My Zsh, shell aliases, utility scripts, directory structure
6. **install-desktop.sh** — Optional GUI (xfce/gnome/kde) with auto-login
7. **final-provision.sh** — UFW firewall, SSH hardening, MOTD, system scripts

> 📝 **Note**: Each script is uploaded via `Vagrantfile` `config.vm.provision "shell"` and runs as root. User config
> scripts use `sudo -u vagrant` to run as the vagrant user.

## File Organization & Customization Points

- **`setup.sh`** — Interactive wizard generating `.env` file (idempotent, can rerun)
- **`Vagrantfile`** — Main orchestration. Loads `.env`, uploads all `config/**` files to `/tmp/`, defines provisioners
- **`config/packages/*.txt`** — Package lists (one per line, `#` for comments). Edit to add/remove tools:
  - `essential.txt` — Both modes
  - `full-extras.txt` — Only full mode (Docker, Node.js)
  - `kali-tools.txt` — Individual packages from Kali repos (not metapackages to avoid conflicts)
  - `python-tools.txt` — Format: `pipx:package` (isolated) or `pip:package` (shared)
- **`config/scripts/`** — User/system shell scripts & configs copied to VM
- **`provision/`** — Shell provisioning scripts (6 stages)

## Why Vagrant + UTM?

Running VMs on Apple Silicon Macs is tricky. VirtualBox doesn't support ARM64, VMware Fusion has limited ARM support,
and Parallels is paid software.

**The solution:** [UTM](https://mac.getutm.app/) is a free, open-source virtualization app built specifically for
macOS - and it works great on Apple Silicon. It uses QEMU under the hood but provides a native and very fast macOS
experience.

[Vagrant](https://www.vagrantup.com/) adds the "Infrastructure as Code" layer on top. Instead of manually clicking
through UTM's UI to create VMs, you define everything in a `Vagrantfile`. This means:

- **Reproducible**: Run `vagrant up` and get the exact same VM every time
- **Shareable**: Commit the config to Git, share with your team
- **Automated**: No manual setup - provisioning scripts handle everything

The [`vagrant_utm`](https://github.com/naveenrajm7/vagrant_utm) plugin bridges Vagrant and UTM, letting you use familiar
Vagrant commands (`vagrant up`, `vagrant ssh`, `vagrant destroy`) with UTM as the backend.

## Why not Kali Linux?

As this project lets you create a security VM very similar to Kali, you might wonder: "Why not just use a Kali Linux
image directly?"

**The short answer:** There's no official Kali Linux Vagrant box for ARM64/UTM.

**The longer answer:** This project takes a hybrid approach that's more stable than pure Kali:

1. **Base image**: We use **Debian 12** (`utm/bookworm`) - a stable, well-tested ARM64 image built for UTM
2. **Kali repositories**: We add the official Kali repos as a secondary package source
3. **APT pinning**: We set Kali packages to Priority 100, meaning:
   - Debian packages are always preferred (better stability)
   - Kali packages are only used for security tools not available on Debian

This gives you the best of both worlds: Debian's solid stability for the base system, plus access to Kali's security
tools when you need them. It's also more resilient in corporate environments where `kali.org` domains might be blocked.
The VM still works, you just won't have the security tools until you get the repos whitelisted (or install them
manually).

## Key Technical Patterns

### Idempotency & Re-provisioning

Scripts check for existing state before modifying (e.g., `[[ ! grep -q "string" file ]]`). Safe to rerun
`vagrant provision` or specific provisioners.

### Kali Repository Setup & Fallbacks

`install-packages-full.sh` tries multiple Kali mirrors (RWTH Aachen, Karneval, Umeå, official) and falls back to bundled
keyring (`config/kali-archive-keyring.gpg`) if downloads fail. No internet = no blocking.

### Corporate Proxy & SSL Inspection

`configure-proxy.sh`:

- Auto-detects all `config/*.crt` files and installs to `/usr/local/share/ca-certificates/`
- Sets environment variables (`REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `CURL_CA_BUNDLE`)
- Configures pip/npm to use system CA bundle
- **Note**: Vagrant itself needs host's cacert.pem updated _before_ `vagrant up` (documented in
  `docs/ssl_inspection_and_proxies.md`)

### Provisioning Modes

- **minimal** (~10 min): Essential CLI tools only
- **full** (~15-20 min): Adds Kali tools, Docker, Python security packages, wordlists
- **Runtime detection**: `install-packages-full.sh` writes mode to `/etc/vm-provision-mode` for scripts to check

### Desktop Environments

You can optionally install a desktop environment for graphical access:

| Option  | Description                                      | Resources       |
| ------- | ------------------------------------------------ | --------------- |
| `none`  | Headless (default) - command-line only           | Minimal         |
| `xfce`  | Kali's default - lightweight, fast               | 4 GB RAM, 2 CPU |
| `gnome` | Modern, polished - macOS-like experience         | 8 GB RAM, 4 CPU |
| `kde`   | Feature-rich - highly customizable, Windows-like | 8 GB RAM, 4 CPU |

Set via `DESKTOP_ENVIRONMENT` environment variable or through `./setup.sh`.

### Shared Folders

Two directories are automatically synced between your Mac and the VM:

| Host (Mac)    | Guest (VM)    | Purpose              |
| ------------- | ------------- | -------------------- |
| `./projects/` | `~/projects/` | Your project files   |
| `./shared/`   | `~/shared/`   | General file sharing |

Changes in either location are instantly reflected in the other.

### Network & Port Forwarding

The following ports are forwarded from the VM to your host:

| Guest Port | Host Port | Purpose                     |
| ---------- | --------- | --------------------------- |
| 8080       | 8080      | Burp Suite / ZAP Proxy      |
| 4444       | 4444      | Metasploit / Reverse shells |
| 8000       | 8000      | HTTP server                 |

### Firewall & SSH Hardening

`final-provision.sh` configures UFW:

- Default deny incoming, allow outgoing
- Allow SSH, 8080, 4444, 8000
- Disables root login, requires public key auth (but password auth still enabled for vagrant user)

## See Also

- [Configuration](configuration.md) — Environment variables and Vagrant commands
- [SSL Inspection & Proxies](ssl_inspection_and_proxies.md) — Certificate setup for corporate networks
- [Troubleshooting](troubleshooting.md) — Common issues and solutions
