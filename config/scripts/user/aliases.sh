# =============================================================================
# Custom Aliases
# =============================================================================
# Appended to .zshrc and .bashrc during user configuration.

# General aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
grep() { /usr/bin/grep --color=auto "$@"; }

# Security tool aliases
alias nmap-quick='nmap -T4 -F'
alias nmap-full='nmap -T4 -A -v'
# Note: For gobuster, download SecLists or use your own wordlists
alias gobuster-dir='gobuster dir -w /opt/wordlists/rockyou.txt'
alias http-server='python3 -m http.server'

# Network aliases
alias myip='curl -s ifconfig.me'
alias ports='netstat -tulanp'

# Directory shortcuts
alias home='cd ~'
alias tools='cd /opt/tools'
alias wordlists='cd /opt/wordlists'
alias projects='cd ~/projects'
alias shared='cd ~/shared'
