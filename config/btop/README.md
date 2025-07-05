# btop Configuration

This directory contains the modular configuration for btop system monitor.

## Structure

- `btop.conf` - Main configuration file with all settings
- `themes/` - Directory containing custom color themes
  - `catppuccin-mocha.theme` - Custom Catppuccin Mocha color theme

## Theme System

btop uses a different approach for color modularization compared to other applications:

1. **Main Config**: `btop.conf` contains all functionality settings
2. **Theme Files**: Colors are stored in separate `.theme` files in the `themes/` directory
3. **Theme Reference**: The main config references the theme with `color_theme = "catppuccin-mocha"`

## Color Consistency

The `catppuccin-mocha.theme` uses the same Catppuccin Mocha color palette as:
- Hyprland (`colors.conf`)
- Waybar (`colors.css`)
- Alacritty (`colors.toml`)
- Rofi (`colors.rasi`)
- SwayNotificationCenter (`colors.css`)

## Usage

btop will automatically load the theme specified in `color_theme` from the `themes/` directory. To change colors system-wide, you can:

1. **Edit the theme file** directly: `themes/catppuccin-mocha.theme`
2. **Create a new theme** and update `color_theme` in `btop.conf`
3. **Switch to built-in themes** like "Default" or "TTY"

## Key Features

- **Comprehensive monitoring**: CPU, memory, network, processes
- **Modern UI**: Braille characters for high-resolution graphs
- **Transparent background**: Compatible with terminal transparency
- **Optimized performance**: 2-second update intervals for smooth graphs
- **Vim-like navigation**: Optional vim keys for list navigation (currently disabled) 