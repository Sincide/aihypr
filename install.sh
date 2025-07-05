#!/bin/bash

set -e

echo "🚀 Post-installation script for Arch Linux + Hyprland"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Update mirrors with reflector for Sweden
echo "📡 Setting up mirrors for Sweden..."
sudo pacman -S --needed rsync reflector --noconfirm
sudo reflector --country Sweden --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syyu --noconfirm

# Install yay-bin if not already installed
if ! command -v yay &> /dev/null; then
    echo "📦 Installing yay-bin..."
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ~
else
    echo "📦 yay-bin already installed, skipping..."
fi

# Package lists - easy to modify
PACKAGES=(
    # Core system
    "hyprland"
    "waybar"
    "rofi-wayland"
    "alacritty"
    "fish"
    "btop"
    "swaync"
    
    # Fonts
    "ttf-jetbrains-mono-nerd"    # Main terminal/coding font (Alacritty, SwayNC)
    "ttf-font-awesome"           # Icons for Waybar
    "ttf-roboto"                 # UI font for Waybar
    "ttf-roboto-mono"            # Monospace fallback
    "noto-fonts"                 # Wide character support
    "noto-fonts-emoji"           # Emoji support
    "noto-fonts-extra"           # Additional language support
    "ttf-liberation"             # Microsoft font alternatives
    "ttf-dejavu"                 # Good fallback fonts
    
    # Tools
    "zoxide"
    "fzf"
    "neovim"
    "git"
    "curl"
    "wget"
    "unzip"
    "playerctl"                      # Media player control
    "brightnessctl"                  # Screen brightness control
    
    # SSH and security
    "openssh"                        # SSH client and server
    "keychain"                       # SSH key manager
    "gnupg"                          # GPG for signing commits
    
    # Optional apps
    "brave-bin"
    "thunar"
    "qbittorrent-nox"
    "grim"
    "slurp"
    "wl-clipboard"
    "polkit-gnome"
    "network-manager-applet"
    "swww"                           # Wallpaper daemon for Wayland
    
    # Image tools for AI Themer
    "imagemagick"
    "libnotify"
    
    # Python packages for AI Themer
    "python"
    "python-pillow"
    "python-scikit-learn"
    "python-numpy"
    "python-jinja"
    "python-click"
    "python-rich"
    "python-yaml"
    "python-watchdog"
    "python-colorthief"
)

AUR_PACKAGES=(
    "hyprpicker"
    "wlogout"
    "python-colorspacious"
    "ttf-material-design-icons"      # Additional icon fonts
    "cliphist"                       # Clipboard history manager
    "cursor-bin"                     # Cursor AI code editor
)

# Install packages
echo "📦 Installing packages..."
yay -S --needed --noconfirm "${PACKAGES[@]}"

echo "📦 Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"

# Setup configs
echo "🔗 Setting up configuration symlinks..."
mkdir -p ~/.config

for dir in "$SCRIPT_DIR"/config/*/; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        echo "Linking $dirname..."
        rm -rf ~/.config/"$dirname"
        ln -sf "$dir" ~/.config/"$dirname"
    fi
done

# Setup wallpapers directory
echo "🖼️  Setting up wallpapers directory..."
mkdir -p "$SCRIPT_DIR"/wallpapers/{nature,cyberpunk,abstract,minimal,space,cityscape}
chmod 755 "$SCRIPT_DIR"/wallpapers/{nature,cyberpunk,abstract,minimal,space,cityscape}
echo "   ✅ Wallpapers categories created"

# Setup AI Themer
echo "🎨 Setting up AI Themer..."
cd "$SCRIPT_DIR/ai-themer"
echo "   Testing AI Themer installation..."
if python demo_simulation.py > /dev/null 2>&1; then
    echo "   ✅ AI Themer demo works perfectly"
else
    echo "   ⚠️  AI Themer demo failed - check dependencies"
fi

# Test full CLI functionality
echo "   Testing full CLI functionality..."
if python -m src.ai_themer.cli --help > /dev/null 2>&1; then
    echo "   ✅ AI Themer CLI is ready"
    echo "   📖 Run 'python demo_simulation.py' to see it in action"
    echo "   🎯 Add wallpapers to ../wallpapers/nature/ (or other categories) to use it"
else
    echo "   ⚠️  AI Themer CLI failed - some dependencies might be missing"
fi

# Test color extraction and JSON serialization
echo "   Testing color extraction..."
if [ -f "../wallpapers/nature/graveyard.png" ]; then
    if python test_color_extraction.py > /dev/null 2>&1; then
        echo "   ✅ Color extraction and JSON serialization working"
    else
        echo "   ⚠️  Color extraction test failed - check dependencies"
    fi
else
    echo "   ⚠️  No test image found - color extraction test skipped"
fi

# Create Rofi launcher script
echo "   Creating Rofi launcher script..."
mkdir -p ~/.local/bin
mkdir -p ~/.cache/rofi
cat > ~/.local/bin/ai-themer-pick << EOF
#!/bin/bash
# AI Themer Rofi Wallpaper Picker
# Suppress Python warnings and ensure config directory exists
export PYTHONWARNINGS="ignore::SyntaxWarning"
mkdir -p ~/.config/ai-themer
mkdir -p ~/.cache/rofi
cd "$SCRIPT_DIR/ai-themer"
python src/ai_themer/rofi_picker.py "$SCRIPT_DIR/wallpapers" --template-dir "$SCRIPT_DIR/ai-themer/templates"
EOF
chmod +x ~/.local/bin/ai-themer-pick
echo "   ✅ Rofi launcher created at ~/.local/bin/ai-themer-pick"

# Add Hyprland keybind
echo "   Adding Hyprland keybind..."
if [ -f ~/.config/hypr/conf/keybindings.conf ]; then
    if ! grep -q "ai-themer-pick" ~/.config/hypr/conf/keybindings.conf; then
        echo "" >> ~/.config/hypr/conf/keybindings.conf
        echo "# AI Themer wallpaper picker" >> ~/.config/hypr/conf/keybindings.conf
        echo "bind = SUPER, W, exec, ai-themer-pick" >> ~/.config/hypr/conf/keybindings.conf
        echo "   ✅ Added SUPER+W keybind for wallpaper picker"
    else
        echo "   ✅ Keybind already exists"
    fi
else
    echo "   ⚠️  Hyprland keybindings.conf not found - add manually: bind = SUPER, W, exec, ai-themer-pick"
fi

cd "$SCRIPT_DIR"

# Setup Git
echo "🔧 Setting up Git configuration..."
if ! git config --global user.name > /dev/null 2>&1; then
    echo "   Git user.name not configured"
    read -p "   Enter your Git username: " git_username
    git config --global user.name "$git_username"
    echo "   ✅ Git username set to: $git_username"
else
    existing_name=$(git config --global user.name)
    echo "   ✅ Git username already set to: $existing_name"
fi

if ! git config --global user.email > /dev/null 2>&1; then
    echo "   Git user.email not configured"
    read -p "   Enter your Git email: " git_email
    git config --global user.email "$git_email"
    echo "   ✅ Git email set to: $git_email"
else
    existing_email=$(git config --global user.email)
    echo "   ✅ Git email already set to: $existing_email"
fi

# Set some useful Git defaults
echo "   Setting up Git defaults..."
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor nvim
echo "   ✅ Git defaults configured (main branch, merge pulls, nvim editor)"

# Setup SSH
echo "🔐 Setting up SSH..."
# Enable SSH service
sudo systemctl enable sshd.service
echo "   ✅ SSH service enabled"

# Create SSH directory with proper permissions if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "   ✅ SSH directory created with proper permissions"

# Create SSH manager launcher
echo "   Creating SSH manager launcher..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/ssh-manager << EOF
#!/bin/bash
# SSH Key Manager Launcher
cd "$SCRIPT_DIR"
./scripts/ssh-manager.sh
EOF
chmod +x ~/.local/bin/ssh-manager
echo "   ✅ SSH manager available as 'ssh-manager' command"

# Note: SSH backup directory (/mnt/Stuff/backups) will be available after running post-install scripts
echo "   ✅ SSH backup directory will be available at /mnt/Stuff/backups after mounting drives"

# Add SSH agent setup to fish config
echo "   Setting up SSH agent for fish shell..."
if [ -f ~/.config/fish/config.fish ]; then
    if ! grep -q "keychain" ~/.config/fish/config.fish; then
        echo "" >> ~/.config/fish/config.fish
        echo "# SSH agent setup with keychain" >> ~/.config/fish/config.fish
        echo "if status is-interactive" >> ~/.config/fish/config.fish
        echo "    # Start keychain for SSH key management" >> ~/.config/fish/config.fish
        echo "    if type -q keychain" >> ~/.config/fish/config.fish
        echo "        if test -f ~/.ssh/id_rsa -o -f ~/.ssh/id_ed25519" >> ~/.config/fish/config.fish
        echo "            keychain --quiet --agents ssh" >> ~/.config/fish/config.fish
        echo "            source ~/.keychain/(hostname)-sh" >> ~/.config/fish/config.fish
        echo "        end" >> ~/.config/fish/config.fish
        echo "    end" >> ~/.config/fish/config.fish
        echo "end" >> ~/.config/fish/config.fish
        echo "" >> ~/.config/fish/config.fish
        echo "# SSH Manager aliases" >> ~/.config/fish/config.fish
        echo "alias sshm 'ssh-manager'" >> ~/.config/fish/config.fish
        echo "abbr -a sshm 'ssh-manager'" >> ~/.config/fish/config.fish
        echo "   ✅ SSH agent auto-start configured for fish"
        echo "   ✅ SSH manager aliases added (sshm)"
    else
        echo "   ✅ SSH agent configuration already exists"
    fi
else
    echo "   ⚠️  Fish config not found - SSH agent setup skipped"
fi

# Set fish as default shell
echo "🐟 Setting fish as default shell..."
if ! grep -q "$(which fish)" /etc/shells; then
    echo "$(which fish)" | sudo tee -a /etc/shells
fi
chsh -s "$(which fish)"

echo "✅ Installation complete!"
echo "📝 Please reboot or log out and back in to use fish shell"
echo ""
echo "🎨 AI Themer is now available:"
echo "   • Run 'cd ai-themer && python demo_simulation.py' to see a demo"
echo "   • Add your wallpapers to the appropriate category folders"
echo "   • Launch Rofi picker: 'ai-themer-pick' (or use keyboard shortcut)"
echo "   • All Python dependencies are installed - no pip needed!"
echo ""
echo "🖼️  Wallpaper System:"
echo "   • Uses swww for smooth wallpaper transitions"
echo "   • swww-daemon will start automatically on login"
echo "   • Run 'swww-daemon' manually if wallpaper setting fails"
echo ""
echo "🖼️  Rofi Wallpaper Picker:"
echo "   • Command: ai-themer-pick"
echo "   • Features: Thumbnails, categories, instant theme application"
echo "   • Add to Hyprland keybind: bind = SUPER, W, exec, ai-themer-pick"
echo ""
echo "📂 Wallpapers categories:"
echo "   wallpapers/nature/     - 🌲 Forests, mountains, landscapes"
echo "   wallpapers/cyberpunk/  - 🌃 Neon cities, futuristic themes"
echo "   wallpapers/abstract/   - 🎨 Geometric shapes, patterns"
echo "   wallpapers/minimal/    - ⚪ Clean, simple designs"
echo "   wallpapers/space/      - 🌌 Cosmic, stars, galaxies"
echo "   wallpapers/cityscape/  - 🏙️ Urban landscapes, skylines"
echo ""
echo "🔤 Fonts installed:"
echo "   • JetBrains Mono Nerd Font (terminal, coding)"
echo "   • Font Awesome (icons)"
echo "   • Roboto (UI elements)"
echo "   • Noto Fonts (wide character support + emoji)"
echo "   • Liberation & DejaVu (fallback fonts)"
echo "   • Material Design Icons (additional icons)"
echo ""
echo "🔐 SSH Setup:"
echo "   • SSH service enabled and ready"
echo "   • SSH directory created with proper permissions"
echo "   • SSH agent auto-start configured with keychain"
echo "   • SSH Key Manager: run 'ssh-manager' or 'sshm' command"
echo "   • Interactive backup/restore system ready"
echo ""
echo "🛡️  Security Notes:"
echo "   • Generate SSH keys: ssh-keygen -t ed25519 -C 'your_email@example.com'"
echo "   • Add to GitHub/GitLab: copy ~/.ssh/id_ed25519.pub"
echo "   • Test connections: sshm → option 6"
echo "   • Backup keys before system changes: sshm → option 1"
echo ""
echo "💡 Quick SSH Setup Guide:"
echo "   1. Generate new SSH key: ssh-keygen -t ed25519"
echo "   2. Add to GitHub: cat ~/.ssh/id_ed25519.pub (copy to GitHub settings)"
echo "   3. Test connection: ssh -T git@github.com"
echo "   4. Create first backup: sshm → option 1"
echo "   5. Set up automatic key loading: keychain ~/.ssh/id_ed25519" 