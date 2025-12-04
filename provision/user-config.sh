#!/bin/bash
set -e

DEFAULT_USER=${1:-"vagrant"}
USER_HOME="/home/$DEFAULT_USER"
CONFIG_DIR="/tmp/scripts/user"

echo "[+] Starting User Configuration for user $DEFAULT_USER (running as $(whoami))..."

# Create useful directories
echo "[+] Setting up Directory Structure..."
mkdir -p /opt/tools
mkdir -p /home/"$DEFAULT_USER"
chown -R "$DEFAULT_USER":"$DEFAULT_USER" /home/"$DEFAULT_USER"

# Install Oh My Zsh for user
echo "[+] Installing Oh My Zsh..."
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    # Run as the target user
    sudo -u "$DEFAULT_USER" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Install popular plugins
    sudo -u "$DEFAULT_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    sudo -u "$DEFAULT_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    
    # Configure .zshrc
    sudo -u "$DEFAULT_USER" sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker docker-compose golang npm python pip)/' "$USER_HOME/.zshrc"
fi

# Add custom aliases from external file
if [ -f "${CONFIG_DIR}/aliases.sh" ]; then
    cp "${CONFIG_DIR}/aliases.sh" "$USER_HOME/.shell_aliases"
    chown "$DEFAULT_USER":"$DEFAULT_USER" "$USER_HOME/.shell_aliases"

    # Ensure shells source the aliases file
    if ! grep -q "source ~/.shell_aliases" "$USER_HOME/.zshrc" 2>/dev/null; then
        echo "source ~/.shell_aliases" >> "$USER_HOME/.zshrc"
        chown "$DEFAULT_USER":"$DEFAULT_USER" "$USER_HOME/.zshrc"
    fi

    if ! grep -q "source ~/.shell_aliases" "$USER_HOME/.bashrc" 2>/dev/null; then
        echo "source ~/.shell_aliases" >> "$USER_HOME/.bashrc"
        chown "$DEFAULT_USER":"$DEFAULT_USER" "$USER_HOME/.bashrc"
    fi
else
    echo "[!] WARN: ${CONFIG_DIR}/aliases.sh not found"
fi

# Configure Git for user
echo "[+] Configuring Git for User..."
sudo -u "$DEFAULT_USER" git config --global init.defaultBranch main
sudo -u "$DEFAULT_USER" git config --global pull.rebase false

# Configure Vim
echo "[+] Configuring Vim..."
if [ -f "${CONFIG_DIR}/vimrc" ]; then
    cp "${CONFIG_DIR}/vimrc" "$USER_HOME/.vimrc"
else
    echo "[!] WARN: ${CONFIG_DIR}/vimrc not found"
fi

# Configure tmux
echo "[+] Configuring tmux..."
if [ -f "${CONFIG_DIR}/tmux.conf" ]; then
    cp "${CONFIG_DIR}/tmux.conf" "$USER_HOME/.tmux.conf"
else
    echo "[!] WARN: ${CONFIG_DIR}/tmux.conf not found"
fi

# Set up desktop shortcuts if GUI is available
if [ -n "$DISPLAY" ] || pgrep -x "Xvfb" > /dev/null 2>&1; then
    echo "[+] Setting up Desktop Environment..."
    
    # Create desktop shortcuts
    sudo -u "$DEFAULT_USER" mkdir -p "$USER_HOME/Desktop"
    
    # Burp Suite shortcut
    cat > "$USER_HOME/Desktop/burpsuite.desktop" << 'EOF'
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
    cat > "$USER_HOME/Desktop/terminal.desktop" << 'EOF'
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
    chmod +x "$USER_HOME/Desktop"/*.desktop
fi

# Create useful scripts
echo "[+] Creating Utility Scripts..."
sudo -u "$DEFAULT_USER" mkdir -p "$USER_HOME/bin"

# Copy utility scripts from config directory
for script in serve revshell; do
    if [ -f "${CONFIG_DIR}/${script}" ]; then
        cp "${CONFIG_DIR}/${script}" "$USER_HOME/bin/${script}"
        chmod +x "$USER_HOME/bin/${script}"
    else
        echo "[!] WARN: ${CONFIG_DIR}/${script} not found"
    fi
done

# Add ~/bin to PATH (idempotent - check before adding)
if ! grep -q 'export PATH.*~/bin' "$USER_HOME/.zshrc" 2>/dev/null; then
    echo "export PATH=\$PATH:~/bin" >> "$USER_HOME/.zshrc"
fi
if ! grep -q 'export PATH.*~/bin' "$USER_HOME/.bashrc" 2>/dev/null; then
    echo "export PATH=\$PATH:~/bin" >> "$USER_HOME/.bashrc"
fi

# Ensure user's local Python bin directory is in PATH (for pipx and --user installs) (idempotent)
if ! grep -q '.local/bin' "$USER_HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.zshrc"
fi
if ! grep -q '.local/bin' "$USER_HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
fi

# Create .hushlogin to suppress default Kali/Debian login message
# Our custom MOTD in /etc/motd will still be shown
touch "$USER_HOME/.hushlogin"

# Fix ownership of all user files
chown -R "$DEFAULT_USER":"$DEFAULT_USER" "$USER_HOME"

echo "[+] User Configuration Complete"
