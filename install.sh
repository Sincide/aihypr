#!/bin/bash

set -e

echo "🚀 Post-installation script for Arch Linux + Hyprland"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Update mirrors with reflector for Sweden
echo "📡 Setting up mirrors for Sweden..."
sudo pacman -S --needed reflector --noconfirm
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
    
    # Optional apps
    "brave-bin"
    "thunar"
    "qbittorrent-nox"
    "grim"
    "slurp"
    "wl-clipboard"
    
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

# Create Rofi launcher script
echo "   Creating Rofi launcher script..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/ai-themer-pick << EOF
#!/bin/bash
# AI Themer Rofi Wallpaper Picker
cd "$SCRIPT_DIR/ai-themer"
python -m src.ai_themer.cli pick --wallpaper-dir ../wallpapers/
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