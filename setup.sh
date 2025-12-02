#!/bin/bash

# =============================================================================
# Kali Security VM Setup Wizard
# =============================================================================
# Interactive configuration tool.
# Generates a .env file with your preferences before running 'vagrant up'.
#
# Usage: ./setup.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
DEFAULT_VM_NAME="debian-vm"
DEFAULT_VM_MEMORY="4096"
DEFAULT_VM_CPUS="4"
DEFAULT_TIMEZONE="Europe/Berlin"
DEFAULT_KEYBOARD="de"
DEFAULT_LOCALE="en_US.UTF-8"
DEFAULT_PROVISIONING_MODE="minimal"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║       Debian VM Setup Wizard                                      ║"
    echo "║        For Apple Silicon Macs (UTM/QEMU)                          ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result
    
    # Print prompt to stderr so it's visible even when output is captured
    echo -ne "${prompt} [${CYAN}${default}${NC}]: " >&2
    read -r result
    echo "${result:-$default}"
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ "$default" = "y" ]; then
        # Print prompt to stderr so it's visible
        echo -ne "${prompt} [${CYAN}Y/n${NC}]: " >&2
    else
        echo -ne "${prompt} [${CYAN}y/N${NC}]: " >&2
    fi
    read -r result
    result="${result:-$default}"
    [[ "$result" =~ ^[Yy] ]]
}

# =============================================================================
# Prerequisite Checks
# =============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local all_ok=true
    
    # Check for Apple Silicon
    if [[ "$(uname -m)" == "arm64" ]]; then
        print_success "Apple Silicon detected"
    else
        print_warning "Not running on Apple Silicon ($(uname -m))"
        print_info "This setup is optimized for Apple Silicon Macs"
    fi
    
    # Check for Vagrant
    if command -v vagrant &> /dev/null; then
        local vagrant_version=$(vagrant --version 2>/dev/null | head -1)
        print_success "Vagrant installed: $vagrant_version"
    else
        print_error "Vagrant not installed"
        print_info "Install with: brew install --cask vagrant"
        all_ok=false
    fi
    
    # Check for UTM
    if [ -d "/Applications/UTM.app" ]; then
        print_success "UTM installed"
    else
        print_error "UTM not installed"
        print_info "Install with: brew install --cask utm"
        all_ok=false
    fi
    
    # Check for vagrant-utm plugin
    if vagrant plugin list 2>/dev/null | grep -q "vagrant_utm"; then
        print_success "vagrant_utm plugin installed"
    else
        print_warning "vagrant_utm plugin not installed"
        print_info "Install with: vagrant plugin install vagrant_utm"
        all_ok=false
    fi
    
    echo ""
    
    if [ "$all_ok" = false ]; then
        echo -e "${YELLOW}Some prerequisites are missing. Install them before running 'vagrant up'.${NC}"
        echo ""
        if ! prompt_yes_no "Continue with setup anyway?" "y"; then
            echo "Exiting. Please install prerequisites and run setup again."
            exit 1
        fi
    fi
}

# =============================================================================
# Configuration Prompts
# =============================================================================

configure_vm_resources() {
    print_section "VM Resources"
    
    echo "Configure the virtual machine resources."
    echo ""
    
    VM_NAME=$(prompt_with_default "VM name" "$DEFAULT_VM_NAME")
    VM_MEMORY=$(prompt_with_default "Memory (MB)" "$DEFAULT_VM_MEMORY")
    VM_CPUS=$(prompt_with_default "CPU cores" "$DEFAULT_VM_CPUS")
}

configure_locale() {
    print_section "Locale Settings"
    
    echo "Configure timezone, keyboard layout, and locale."
    echo ""
    
    USER_TIMEZONE=$(prompt_with_default "Timezone" "$DEFAULT_TIMEZONE")
    USER_KEYBOARD=$(prompt_with_default "Keyboard layout (e.g., us, de, gb)" "$DEFAULT_KEYBOARD")
    USER_LOCALE=$(prompt_with_default "Locale" "$DEFAULT_LOCALE")
}

configure_provisioning() {
    print_section "Provisioning Mode"
    
    echo "Choose how much to install during initial setup:"
    echo ""
    echo -e "  ${BOLD}minimal${NC} - Essential tools only (~5-10 minutes)"
    echo "            curl, wget, git, vim, zsh, openvpn, tmux"
    echo ""
    echo -e "  ${BOLD}full${NC}    - Complete security toolkit (~20-30 minutes)"
    echo "            Everything in minimal, plus:"
    echo "            - Kali Linux security tools (nmap, burpsuite, metasploit, etc.)"
    echo "            - Python security packages (impacket, bloodhound, etc.)"
    echo "            - Wordlists (rockyou.txt, SecLists)"
    echo ""
    
    PROVISIONING_MODE=$(prompt_with_default "Provisioning mode (minimal/full)" "$DEFAULT_PROVISIONING_MODE")
    
    # Validate input
    if [[ "$PROVISIONING_MODE" != "minimal" && "$PROVISIONING_MODE" != "full" ]]; then
        print_warning "Invalid option. Defaulting to 'minimal'."
        PROVISIONING_MODE="minimal"
    fi
}

configure_proxy() {
    print_section "Corporate Proxy (Optional)"
    
    echo "Configure if you're behind a corporate proxy (e.g., ZScaler, Netskope)."
    echo ""
    
    if prompt_yes_no "Are you behind a corporate proxy?" "n"; then
        echo ""
        HTTP_PROXY=$(prompt_with_default "HTTP Proxy URL (e.g., http://proxy:8080)" "")
        HTTPS_PROXY=$(prompt_with_default "HTTPS Proxy URL (leave empty to use HTTP)" "${HTTP_PROXY}")
        
        echo ""
        echo "If your proxy uses SSL inspection, you'll need a root CA certificate."
        echo ""
        
        # Check if certificates already exist in config/
        local existing_certs=$(ls "$SCRIPT_DIR/config/"*.crt 2>/dev/null | wc -l | tr -d ' ')
        if [ "$existing_certs" -gt 0 ]; then
            print_info "Found $existing_certs certificate(s) in config/ directory"
            if ! prompt_yes_no "Add another certificate?" "n"; then
                return
            fi
        fi
        
        echo ""
        echo "You can either:"
        echo "  1) Specify a path to your certificate file"
        echo "  2) Manually place it in the config/ directory later"
        echo ""
        
        CERT_PATH=$(prompt_with_default "Certificate path (leave empty to skip)" "")
        
        if [ -n "$CERT_PATH" ] && [ -f "$CERT_PATH" ]; then
                # Copy certificate to config directory
                local cert_name=$(basename "$CERT_PATH")
                # Ensure .crt extension
                if [[ "$cert_name" != *.crt ]]; then
                    cert_name="${cert_name%.*}.crt"
                fi
                
                mkdir -p "$SCRIPT_DIR/config"
                cp "$CERT_PATH" "$SCRIPT_DIR/config/$cert_name"
                print_success "Certificate copied to config/$cert_name"
            elif [ -n "$CERT_PATH" ]; then
                print_warning "Certificate file not found: $CERT_PATH"
                print_info "You can manually place it in the config/ directory later"
            else
                print_info "No certificate specified. You can add one to config/ later."
            fi
    else
        HTTP_PROXY=""
        HTTPS_PROXY=""
    fi
}

# =============================================================================
# Generate Configuration
# =============================================================================

generate_env_file() {
    print_section "Generating Configuration"
    
    local env_file="$SCRIPT_DIR/.env"
    
    cat > "$env_file" << EOF
# =============================================================================
# VM Configuration
# Generated by setup.sh on $(date)
# =============================================================================

# VM Resources
VM_NAME=${VM_NAME}
VM_MEMORY=${VM_MEMORY}
VM_CPUS=${VM_CPUS}

# Locale Settings
USER_TIMEZONE=${USER_TIMEZONE}
USER_KEYBOARD=${USER_KEYBOARD}
USER_LOCALE=${USER_LOCALE}

# Provisioning Mode: minimal (fast) or full (complete security toolkit)
PROVISIONING_MODE=${PROVISIONING_MODE}

# Corporate Proxy (optional)
HTTP_PROXY=${HTTP_PROXY}
HTTPS_PROXY=${HTTPS_PROXY}
EOF
    
    print_success "Configuration saved to .env"
}

show_summary() {
    print_section "Configuration Summary"
    
    echo -e "  ${BOLD}VM Name:${NC}           $VM_NAME"
    echo -e "  ${BOLD}Memory:${NC}            $VM_MEMORY MB"
    echo -e "  ${BOLD}CPUs:${NC}              $VM_CPUS"
    echo -e "  ${BOLD}Timezone:${NC}          $USER_TIMEZONE"
    echo -e "  ${BOLD}Keyboard:${NC}          $USER_KEYBOARD"
    echo -e "  ${BOLD}Locale:${NC}            $USER_LOCALE"
    echo -e "  ${BOLD}Provisioning:${NC}      $PROVISIONING_MODE"
    
    if [ -n "$HTTP_PROXY" ]; then
        echo -e "  ${BOLD}HTTP Proxy:${NC}        $HTTP_PROXY"
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        echo -e "  ${BOLD}HTTPS Proxy:${NC}       $HTTPS_PROXY"
    fi
    
    # Check for certificates
    local certs=$(ls "$SCRIPT_DIR/config/"*.crt 2>/dev/null | wc -l | tr -d ' ')
    if [ "$certs" -gt 0 ]; then
        echo -e "  ${BOLD}Certificates:${NC}      $certs found in config/"
    fi
    
    echo ""
}

show_next_steps() {
    print_section "Next Steps"
    
    echo "Your configuration is ready! To create the VM:"
    echo ""
    echo -e "  ${CYAN}vagrant up${NC}"
    echo ""
    echo "Other useful commands:"
    echo ""
    echo -e "  ${CYAN}vagrant ssh${NC}          - Connect to the VM"
    echo -e "  ${CYAN}vagrant halt${NC}         - Stop the VM"
    echo -e "  ${CYAN}vagrant destroy${NC}      - Delete the VM"
    echo -e "  ${CYAN}vagrant provision${NC}    - Re-run provisioning scripts"
    echo ""
    
    if [ "$PROVISIONING_MODE" = "minimal" ]; then
        echo -e "${YELLOW}Note:${NC} You selected minimal provisioning."
        echo "      To add security tools later, run:"
        echo -e "      ${CYAN}PROVISIONING_MODE=full vagrant provision${NC}"
        echo ""
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header
    check_prerequisites
    configure_vm_resources
    configure_locale
    configure_provisioning
    configure_proxy
    generate_env_file
    show_summary
    show_next_steps
}

main "$@"
