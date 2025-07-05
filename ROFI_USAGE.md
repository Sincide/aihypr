# 🖼️ Rofi Wallpaper Picker - Quick Guide

## How to Launch the Rofi Picker

After running `./install.sh`, you have **3 ways** to launch the wallpaper picker:

### 1. **Keyboard Shortcut (Recommended)**
```
SUPER + W
```
- **Instant access** - just press the keys
- **Automatically configured** by the install script
- **Works from anywhere** in Hyprland

### 2. **Terminal Command**
```bash
ai-themer-pick
```
- Type this in any terminal
- **Available system-wide** (added to PATH)

### 3. **Direct CLI (Advanced)**
```bash
cd aihypr/ai-themer
python -m src.ai_themer.cli pick
```

## What Happens When You Launch It

1. **🔍 Scans wallpapers** in all category folders
2. **📸 Generates thumbnails** automatically (cached for speed)
3. **🖼️ Shows Rofi menu** with 3-column grid of thumbnails
4. **✨ Select wallpaper** → AI extracts colors → Applies theme instantly
5. **📱 Shows notification** when complete

## Rofi Interface

```
┌─────────────────────────────────────────────────┐
│ Select Wallpaper                               │
├─────────────────────────────────────────────────┤
│ [🖼️] nature/forest-sunrise                     │
│ [🖼️] cyberpunk/neon-city                       │
│ [🖼️] abstract/geometric-blue                   │
│                                                │
│ [🖼️] minimal/clean-gradient                    │
│ [🖼️] space/galaxy-spiral                       │
│ [🖼️] cityscape/tokyo-skyline                   │
└─────────────────────────────────────────────────┘
```

## What Gets Themed Instantly

When you select a wallpaper:

- ✅ **Hyprland** - Window borders update (1 second)
- ✅ **Alacritty** - All terminals change colors immediately
- ✅ **Rofi** - Next launch uses new theme
- ✅ **Waybar** - Status bar restarts with new colors (2 seconds)
- ✅ **Fish Shell** - Prompt colors update in all terminals

## Tips

### **Organize Your Wallpapers**
```bash
# Add wallpapers to categories
cp ~/Pictures/sunset.jpg wallpapers/nature/
cp ~/Downloads/cyberpunk-city.png wallpapers/cyberpunk/
cp ~/Desktop/abstract-art.jpg wallpapers/abstract/
```

### **Keyboard Navigation**
- **Arrow keys** - Navigate
- **Enter** - Select wallpaper
- **Escape** - Cancel
- **Type** - Filter by name

### **Thumbnails**
- Generated automatically with ImageMagick
- Cached in `~/.config/ai-themer/thumbnails/`
- 200x200 pixels for fast display
- Falls back to original image if ImageMagick unavailable

## Troubleshooting

### **Rofi doesn't launch**
```bash
# Check if rofi is installed
which rofi

# Install if missing
sudo pacman -S rofi-wayland
```

### **No thumbnails showing**
```bash
# Check if ImageMagick is installed
which convert

# Install if missing
sudo pacman -S imagemagick
```

### **Keybind doesn't work**
```bash
# Check if keybind was added
grep "ai-themer-pick" ~/.config/hypr/conf/keybindings.conf

# Add manually if missing
echo "bind = SUPER, W, exec, ai-themer-pick" >> ~/.config/hypr/conf/keybindings.conf

# Reload Hyprland
hyprctl reload
```

### **Command not found**
```bash
# Check if launcher script exists
ls -la ~/.local/bin/ai-themer-pick

# Ensure ~/.local/bin is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.config/fish/config.fish
```

## Examples

### **Daily Workflow**
1. **Morning**: Press `SUPER+W` → Select sunny/minimal wallpaper
2. **Evening**: Press `SUPER+W` → Select dark/cyberpunk wallpaper
3. **Working**: Press `SUPER+W` → Select clean/minimal wallpaper

### **Mood-Based Theming**
- **Energetic**: `space/` or `cyberpunk/` categories
- **Calm**: `nature/` or `minimal/` categories
- **Creative**: `abstract/` category
- **Professional**: `minimal/` or `cityscape/` categories

## Advanced Usage

### **Change Extraction Method**
```bash
# Use specific AI algorithm
cd aihypr/ai-themer
python -m src.ai_themer.cli pick --method kmeans_lab
```

### **Different Wallpaper Directory**
```bash
python -m src.ai_themer.cli pick --wallpaper-dir ~/Pictures/MyWallpapers/
```

---

**Press `SUPER+W` and start theming!** 🎨✨ 