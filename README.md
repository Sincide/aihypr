# 🏠 Arch Linux + Hyprland Dotfiles

A comprehensive, modular dotfiles configuration for Arch Linux featuring Hyprland compositor with beautiful theming and productivity tools.

## 📋 Table of Contents

- [🌟 Features](#-features)
- [📦 What's Included](#-whats-included)
- [⚡ Quick Start](#-quick-start)
- [🎨 Theming System](#-theming-system)
- [🔧 Component Guide](#-component-guide)
- [⌨️ Keybindings](#️-keybindings)
- [🎯 Customization](#-customization)
- [🔍 Troubleshooting](#-troubleshooting)
- [📚 Resources](#-resources)

## 🌟 Features

- **🎨 Unified Theming**: Catppuccin Mocha color scheme across all applications
- **🖼️ Smart Wallpaper System**: AI-powered color extraction and automatic theming
- **🔥 Modern Window Manager**: Hyprland with smooth animations and effects
- **⚡ Lightning Fast**: Optimized for performance with minimal resource usage
- **🐟 Fish Shell**: Modern shell with intelligent autocompletions and syntax highlighting
- **🌈 Consistent Colors**: Modular color system that changes everything at once
- **📱 Touch-Friendly**: Rofi menus with thumbnails and categories
- **🔧 Highly Modular**: Easy to customize and extend individual components

## 📦 What's Included

### Core Components
- **Hyprland**: Wayland compositor with smooth animations
- **Waybar**: Status bar with system information and workspace indicators
- **Alacritty**: GPU-accelerated terminal emulator
- **Fish**: Modern shell with intelligent features
- **Rofi**: Application launcher and menu system
- **SwayNC**: Notification daemon with modern UI
- **btop**: System monitor with beautiful graphs

### Theming & Utilities
- **AI Themer**: Automatic wallpaper-based color extraction and theming
- **Wallpaper Manager**: Organized wallpaper collection with rofi picker
- **Color System**: Modular color configuration across all applications
- **Font System**: Comprehensive font stack with Nerd Fonts

### Development Tools
- **Git Integration**: Git status in prompt and comprehensive aliases
- **Modern CLI Tools**: zoxide, fzf, and other productivity enhancers
- **Python Environment**: Ready for development with package management

## ⚡ Quick Start

### Prerequisites
- Fresh Arch Linux installation
- Internet connection
- User with sudo privileges

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/aihypr.git ~/aihypr
   cd ~/aihypr
   ```

2. **Run the installation script**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Reboot to apply all changes**:
   ```bash
   sudo reboot
   ```

### First Steps After Installation

1. **Add wallpapers** to get started:
   ```bash
   # Add your wallpapers to appropriate categories
   cp your-wallpaper.jpg ~/aihypr/wallpapers/nature/
   ```

2. **Launch the wallpaper picker**:
   ```bash
   ai-themer-pick
   # Or use the keyboard shortcut: Super+W
   ```

3. **Test the setup**:
   ```bash
   # Open terminal: Super+Q
   # Open file manager: Super+E
   # Open app launcher: Super+R
   ```

## 🎨 Theming System

### Color Philosophy
This setup uses a **modular color system** where:
- All colors are defined in separate files
- One color change affects the entire system
- Colors are consistent across all applications
- Easy to switch between different themes

### Catppuccin Mocha Palette
The default theme uses Catppuccin Mocha with these key colors:
- **Base**: `#1e1e2e` - Main background
- **Text**: `#cdd6f4` - Primary text
- **Blue**: `#89b4fa` - Accent color
- **Green**: `#a6e3a1` - Success states
- **Red**: `#f38ba8` - Error states
- **Yellow**: `#f9e2af` - Warning states

### AI Themer Integration
The AI Themer automatically:
1. Extracts dominant colors from wallpapers
2. Generates harmonious color palettes
3. Updates all application themes
4. Applies changes without restart

## 🔧 Component Guide

### Hyprland Window Manager

**Configuration Files**:
- `config/hypr/hyprland.conf` - Main config that sources all modules
- `config/hypr/conf/` - Modular configuration directory

**Key Features**:
- Smooth animations and transitions
- Intelligent window management
- Multi-monitor support
- Workspace management
- Custom keybindings

**Common Commands**:
```bash
# Reload Hyprland config
Super+Shift+R

# Kill active window
Super+C

# Toggle floating mode
Super+V

# Open terminal
Super+Q
```

### Waybar Status Bar

**Configuration Files**:
- `config/waybar/config.jsonc` - Main configuration
- `config/waybar/style.css` - Styling
- `config/waybar/colors.css` - Color definitions

**Modules Included**:
- Workspace indicators
- System information (CPU, memory, network)
- Audio controls
- Battery status
- Date and time
- Notification indicators

**Customization**:
- Edit `config.jsonc` to add/remove modules
- Modify `style.css` for visual changes
- Update `colors.css` for color scheme changes

### Alacritty Terminal

**Configuration Files**:
- `config/alacritty/alacritty.toml` - Main configuration
- `config/alacritty/colors.toml` - Color scheme

**Features**:
- GPU acceleration
- Transparent background
- Font ligatures support
- Extensive keybindings
- Vi mode support

**Customization**:
```toml
# Font settings
[font]
size = 12.0  # Change font size
normal = { family = "JetBrains Mono", style = "Regular" }

# Transparency
[window]
opacity = 0.95  # Adjust transparency
```

### Fish Shell

**Configuration Files**:
- `config/fish/config.fish` - Main configuration
- `config/fish/colors.fish` - Color definitions
- `config/fish/functions/` - Custom functions

**Features**:
- Intelligent autocompletions
- Syntax highlighting
- Git integration
- Vi mode keybindings
- Extensive aliases and abbreviations

**Key Aliases**:
```fish
# Git shortcuts
gs -> git status
ga -> git add
gc -> git commit
gp -> git push

# System shortcuts
ll -> ls -la
.. -> cd ..
rf -> reload fish config
```

### Rofi Application Launcher

**Configuration Files**:
- `config/rofi/config.rasi` - Main configuration
- `config/rofi/themes/default.rasi` - Theme definitions
- `config/rofi/colors.rasi` - Color scheme

**Features**:
- Application launcher
- Window switcher
- SSH launcher
- Custom themes
- Icon support

**Usage**:
```bash
# Launch applications
Super+R

# Switch windows
Super+Tab

# Custom wallpaper picker
Super+W
```

### SwayNC Notifications

**Configuration Files**:
- `config/swaync/config.json` - Main configuration
- `config/swaync/style.css` - Styling
- `config/swaync/colors.css` - Color definitions

**Features**:
- Modern notification UI
- Notification history
- Do Not Disturb mode
- Action buttons
- Image support

### btop System Monitor

**Configuration Files**:
- `config/btop/btop.conf` - Main configuration
- `config/btop/themes/catppuccin-mocha.theme` - Custom theme

**Features**:
- Real-time system monitoring
- Process management
- Network monitoring
- Beautiful graphs
- Vim-like navigation

**Usage**:
```bash
# Launch btop
btop

# Navigation
Arrow keys - Move around
Space - Select process
k - Kill process
q - Quit
```

## ⌨️ Keybindings

### Hyprland Window Management
| Key Combination | Action |
|-----------------|--------|
| `Super+Q` | Open terminal |
| `Super+E` | Open file manager |
| `Super+R` | Open app launcher |
| `Super+C` | Close active window |
| `Super+M` | Exit Hyprland |
| `Super+V` | Toggle floating mode |
| `Super+J` | Toggle split direction |
| `Super+P` | Toggle pseudo mode |
| `Super+Arrow Keys` | Move focus |
| `Super+1-9` | Switch to workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `Super+S` | Toggle scratchpad |
| `Super+Mouse` | Move/resize windows |

### Custom Shortcuts
| Key Combination | Action |
|-----------------|--------|
| `Super+W` | Launch AI Themer wallpaper picker |
| `Super+Shift+R` | Reload Hyprland config |
| `Super+Print` | Screenshot area |
| `Super+Shift+Print` | Screenshot full screen |

### Terminal (Alacritty)
| Key Combination | Action |
|-----------------|--------|
| `Ctrl+Shift+C` | Copy |
| `Ctrl+Shift+V` | Paste |
| `Ctrl+Shift+F` | Search |
| `Ctrl+Plus` | Increase font size |
| `Ctrl+Minus` | Decrease font size |
| `Ctrl+0` | Reset font size |
| `F11` | Toggle fullscreen |

### Fish Shell
| Key Combination | Action |
|-----------------|--------|
| `Ctrl+R` | Search history |
| `Ctrl+F` | Accept suggestion |
| `Alt+F` | Forward word |
| `Alt+B` | Backward word |
| `Ctrl+A` | Beginning of line |
| `Ctrl+E` | End of line |
| `Ctrl+K` | Kill to end of line |
| `Ctrl+U` | Kill to beginning of line |

## 🎯 Customization

### Changing Colors System-Wide

1. **Edit base colors** in any color file:
   ```bash
   # Edit Hyprland colors
   nvim ~/.config/hypr/conf/colors.conf
   
   # Edit Waybar colors
   nvim ~/.config/waybar/colors.css
   
   # Edit Alacritty colors
   nvim ~/.config/alacritty/colors.toml
   ```

2. **Reload configurations**:
   ```bash
   # Reload Hyprland
   hyprctl reload
   
   # Reload Waybar
   killall waybar && waybar &
   
   # Reload terminal (reopen)
   ```

### Adding New Wallpapers

1. **Organize by category**:
   ```bash
   # Nature wallpapers
   cp nature-wallpaper.jpg ~/aihypr/wallpapers/nature/
   
   # Cyberpunk wallpapers
   cp cyberpunk-wallpaper.jpg ~/aihypr/wallpapers/cyberpunk/
   ```

2. **Supported formats**: JPG, PNG, WebP
3. **Recommended resolution**: 1920x1080 or higher
4. **Use AI Themer** to automatically generate themes

### Customizing Keybindings

Edit `~/.config/hypr/conf/keybindings.conf`:
```bash
# Add custom keybinding
bind = $mainMod, T, exec, thunar  # Super+T opens file manager

# Modify existing keybinding
bind = $mainMod, Q, exec, alacritty  # Change terminal
```

### Adding Applications to Autostart

Edit `~/.config/hypr/conf/autostart.conf`:
```bash
# Add application to autostart
exec-once = firefox
exec-once = discord
exec-once = spotify
```

### Customizing Waybar

1. **Add/Remove modules** in `config.jsonc`:
   ```json
   "modules-left": ["hyprland/workspaces", "custom/media"],
   "modules-center": ["clock"],
   "modules-right": ["cpu", "memory", "network", "battery"]
   ```

2. **Style modules** in `style.css`:
   ```css
   #cpu {
       background-color: @cpu_bg;
       color: @fg_primary;
       padding: 0 10px;
   }
   ```

### Font Configuration

All fonts are defined in individual config files:
- **Alacritty**: `config/alacritty/alacritty.toml`
- **Waybar**: `config/waybar/style.css`
- **Rofi**: `config/rofi/config.rasi`

To change fonts globally:
1. Install the font
2. Update each config file
3. Reload applications

## 🔍 Troubleshooting

### Common Issues

#### Hyprland Won't Start
```bash
# Check Hyprland logs
journalctl -u hyprland

# Test configuration
hyprland -c ~/.config/hypr/hyprland.conf
```

#### Waybar Not Showing
```bash
# Kill and restart Waybar
killall waybar
waybar &

# Check for configuration errors
waybar --log-level=debug
```

#### Terminal Colors Wrong
```bash
# Check terminal environment
echo $TERM
echo $COLORTERM

# Reload Alacritty config
# Just close and reopen the terminal
```

#### Fish Shell Not Default
```bash
# Check current shell
echo $SHELL

# Set Fish as default
chsh -s /usr/bin/fish
```

#### Rofi Not Finding Applications
```bash
# Update desktop database
sudo update-desktop-database

# Clear rofi cache
rm -rf ~/.cache/rofi
```

#### AI Themer Not Working
```bash
# Check Python dependencies
cd ~/aihypr/ai-themer
python -m src.ai_themer.cli --help

# Test with demo
python demo_simulation.py
```

### Performance Issues

#### High CPU Usage
1. **Check running processes**: `btop`
2. **Disable animations**: Edit `config/hypr/conf/appearance.conf`
3. **Reduce blur effects**: Lower blur values in Hyprland config

#### Memory Usage
1. **Check memory usage**: `btop` or `free -h`
2. **Reduce background processes**: Edit autostart config
3. **Optimize Waybar**: Reduce update intervals

#### Slow Terminal
1. **Check terminal settings**: Disable unnecessary features
2. **Reduce history size**: Edit Fish config
3. **Optimize prompt**: Simplify Fish prompt

### Configuration Validation

```bash
# Test Hyprland config
hyprland --config ~/.config/hypr/hyprland.conf --test

# Validate JSON configs
python -m json.tool ~/.config/waybar/config.jsonc

# Check Fish config
fish --no-config -c 'source ~/.config/fish/config.fish'
```

## 📚 Resources

### Documentation
- [Hyprland Wiki](https://wiki.hypr.land/)
- [Waybar Documentation](https://github.com/Alexays/Waybar/wiki)
- [Alacritty Documentation](https://alacritty.org/config-alacritty.html)
- [Fish Shell Documentation](https://fishshell.com/docs/current/)
- [Rofi Documentation](https://github.com/davatorium/rofi)

### Color Schemes
- [Catppuccin](https://github.com/catppuccin/catppuccin)
- [Base16](https://github.com/chriskempson/base16)
- [Dracula](https://draculatheme.com/)

### Fonts
- [Nerd Fonts](https://www.nerdfonts.com/)
- [JetBrains Mono](https://www.jetbrains.com/mono/)
- [Font Awesome](https://fontawesome.com/)

### Wallpapers
- [Unsplash](https://unsplash.com/)
- [Wallhaven](https://wallhaven.cc/)
- [r/wallpapers](https://reddit.com/r/wallpapers)

### Community
- [r/hyprland](https://reddit.com/r/hyprland)
- [r/unixporn](https://reddit.com/r/unixporn)
- [Hyprland Discord](https://discord.gg/hyprland)

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💝 Acknowledgments

- [Catppuccin](https://github.com/catppuccin) for the beautiful color scheme
- [Hyprland](https://github.com/hyprwm/Hyprland) for the amazing compositor
- The entire Arch Linux and open-source community

---

**Enjoy your beautiful new desktop setup! 🎉** 