# 🖼️ Wallpapers Collection

Simple wallpaper categories for AI Themer. Add your wallpapers to the appropriate category folders.

## Categories

```
wallpapers/
├── nature/           # 🌲 Forests, mountains, beaches, landscapes
├── cyberpunk/        # 🌃 Neon cities, futuristic, tech aesthetics  
├── abstract/         # 🎨 Geometric shapes, patterns, artistic
├── minimal/          # ⚪ Clean, simple, minimal designs
├── space/            # 🌌 Cosmic, stars, planets, galaxies
└── cityscape/        # 🏙️ Urban landscapes, skylines, architecture
```

## Usage

### Add Wallpapers
```bash
# Copy wallpapers to appropriate categories
cp ~/Pictures/forest.jpg wallpapers/nature/
cp ~/Downloads/neon-city.png wallpapers/cyberpunk/
cp ~/Desktop/geometric.jpg wallpapers/abstract/
```

### Apply Themes
```bash
cd ai-themer

# Apply theme from any wallpaper
python -m src.ai_themer.cli apply ../wallpapers/nature/forest.jpg
python -m src.ai_themer.cli apply ../wallpapers/cyberpunk/neon-city.png
```

### Rofi Picker (Future)
```bash
# Rofi will browse through all categories
python -m src.ai_themer.cli pick --wallpaper-dir ../wallpapers/
```

## Tips

- **Organize by theme/mood** rather than source
- **Use descriptive names**: `sunset-mountain.jpg` instead of `IMG_1234.jpg`
- **Multiple categories OK**: Put the same wallpaper in multiple folders if it fits
- **Supported formats**: JPEG, PNG, WebP, BMP

## Examples

**Nature:**
- `forest-sunrise.jpg`
- `ocean-waves.png`
- `mountain-valley.jpg`

**Cyberpunk:**
- `neon-street.jpg`
- `cyber-city.png`
- `matrix-rain.jpg`

**Abstract:**
- `geometric-blue.jpg`
- `fractal-pattern.png`
- `color-explosion.jpg`

**Minimal:**
- `simple-gradient.jpg`
- `clean-lines.png`
- `white-space.jpg`

Much simpler! 🎉 