# Fish Shell Configuration

This directory contains the modular configuration for the Fish shell.

## Structure

- `config.fish` - Main configuration file with all settings and functionality
- `colors.fish` - Extracted color definitions using Catppuccin Mocha theme

## Modular Design

Fish shell supports modular configuration through the `source` command:

1. **Main Config**: `config.fish` contains all functionality settings and sources the color file
2. **Color Module**: `colors.fish` contains all color definitions for the shell
3. **Sourcing**: The main config loads colors with `source ~/.config/fish/colors.fish`

## Color Consistency

The `colors.fish` uses the same Catppuccin Mocha color palette as:
- Hyprland (`colors.conf`)
- Waybar (`colors.css`)
- Alacritty (`colors.toml`)
- Rofi (`colors.rasi`)
- SwayNotificationCenter (`colors.css`)
- btop (`themes/catppuccin-mocha.theme`)

## Key Features

### Shell Features
- **Vi mode**: Vi-style key bindings enabled by default
- **Smart completion**: Enhanced tab completion with colors
- **History management**: 10,000 command history with duplicate removal
- **Syntax highlighting**: Colored syntax highlighting for commands

### Color Features
- **Comprehensive theming**: All fish color variables defined
- **Git integration**: Colored git prompt with status indicators
- **Pager colors**: Enhanced completion and search interface
- **Terminal integration**: Colors for ls, grep, less, and man pages

### Aliases & Abbreviations
- **Git shortcuts**: Comprehensive git aliases and abbreviations
- **System commands**: Enhanced ls, df, du with better defaults
- **Package management**: Arch Linux pacman and AUR helper shortcuts
- **Docker shortcuts**: Common docker and docker-compose commands
- **Navigation**: Quick directory navigation shortcuts

### Utility Functions
- **mkcd**: Create directory and cd into it
- **extract**: Universal archive extraction function
- **weather**: Get weather information via curl
- **cheat**: Access cheat.sh from command line
- **qr**: Generate QR codes via curl

### Integration
- **Starship**: Modern prompt (if installed)
- **Zoxide**: Smart directory jumping (if installed)
- **Direnv**: Per-directory environment variables (if installed)
- **FZF**: Fuzzy finder with Catppuccin colors

## Usage

### Changing Colors
To change the entire shell's color scheme:
1. **Edit color file**: Modify `colors.fish` directly
2. **Reload configuration**: Run `source ~/.config/fish/config.fish` or use `rf` abbreviation
3. **System-wide consistency**: Update other application color files to match

### Adding Custom Configuration
- **Functions**: Add new functions directly to `config.fish` or create separate files
- **Aliases**: Add to the aliases section in `config.fish`
- **Environment variables**: Add to the environment section in `config.fish`

### Fish-Specific Features
- **Abbreviations**: Fish's smart shortcuts that expand as you type
- **Functions**: More powerful than aliases, support parameters and logic
- **Universal variables**: Variables that persist across sessions
- **Command substitution**: Clean syntax with parentheses instead of backticks

## Installation

1. Copy files to `~/.config/fish/`
2. Restart fish shell or run `source ~/.config/fish/config.fish`
3. Optional: Install recommended tools (starship, zoxide, direnv, fzf)

## Benefits

- **Easy theme switching**: Change colors in one file affects entire shell
- **Maintainable code**: Separated concerns make configuration easier to manage
- **Consistent experience**: Same color theme across all applications
- **Fish advantages**: Modern shell with better defaults and syntax
- **Rich features**: Comprehensive set of aliases, functions, and integrations 