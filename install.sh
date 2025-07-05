#!/bin/bash

set -e

echo "🚀 Post-installation script for Arch Linux + Hyprland"

# Update mirrors with reflector for Sweden
echo "📡 Setting up mirrors for Sweden..."
sudo pacman -S reflector --noconfirm
sudo reflector --country Sweden --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syyu --noconfirm

# Install yay-bin
echo "📦 Installing yay-bin..."
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ~

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
    "ttf-jetbrains-mono-nerd"
    "ttf-font-awesome"
    
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
)

AUR_PACKAGES=(
    "hyprpicker"
    "wlogout"
)

# Install packages
echo "📦 Installing packages..."
yay -S --noconfirm "${PACKAGES[@]}"

echo "📦 Installing AUR packages..."
yay -S --noconfirm "${AUR_PACKAGES[@]}"

# Setup configs
echo "🔗 Setting up configuration symlinks..."
mkdir -p ~/.config

for dir in config/*/; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        echo "Linking $dirname..."
        rm -rf ~/.config/"$dirname"
        ln -sf "$(pwd)/$dir" ~/.config/"$dirname"
    fi
done

# Set fish as default shell
echo "🐟 Setting fish as default shell..."
if ! grep -q "$(which fish)" /etc/shells; then
    echo "$(which fish)" | sudo tee -a /etc/shells
fi
chsh -s "$(which fish)"

echo "✅ Installation complete!"
echo "📝 Please reboot or log out and back in to use fish shell" 