# 🖼️ Wallpapers Quick Start Guide

## Where to Put Your Wallpapers

```bash
# Your wallpapers go in category folders:
wallpapers/nature/       # 🌲 Natural landscapes
wallpapers/cyberpunk/    # 🌃 Futuristic themes
wallpapers/abstract/     # 🎨 Artistic patterns
wallpapers/minimal/      # ⚪ Clean designs
wallpapers/space/        # 🌌 Cosmic themes
wallpapers/cityscape/    # 🏙️ Urban landscapes
```

## Directory Structure
```
aihypr/
├── wallpapers/
│   ├── nature/          # 👈 PUT NATURE WALLPAPERS HERE
│   ├── cyberpunk/       # 👈 PUT CYBERPUNK WALLPAPERS HERE
│   ├── abstract/        # 👈 PUT ABSTRACT WALLPAPERS HERE
│   ├── minimal/         # 👈 PUT MINIMAL WALLPAPERS HERE
│   ├── space/           # 👈 PUT SPACE WALLPAPERS HERE
│   ├── cityscape/       # 👈 PUT CITYSCAPE WALLPAPERS HERE
│   └── README.md        # Detailed instructions
├── ai-themer/           # AI Themer application
└── config/              # Your system configs
```

## Quick Usage

### 1. Add Wallpapers
```bash
# Copy wallpapers to appropriate categories
cp ~/Pictures/forest-sunrise.jpg wallpapers/nature/
cp ~/Downloads/neon-city.png wallpapers/cyberpunk/
cp ~/Desktop/geometric-pattern.jpg wallpapers/abstract/

# Or move them
mv ~/Desktop/minimal-gradient.jpg wallpapers/minimal/
```

### 2. Apply Theme
```bash
# Go to AI Themer directory
cd ai-themer

# Apply theme from any category
python -m src.ai_themer.cli apply ../wallpapers/nature/forest-sunrise.jpg
python -m src.ai_themer.cli apply ../wallpapers/cyberpunk/neon-city.png

# Or run the demo first
python demo_simulation.py
```

### 3. Supported Formats
- ✅ JPEG (.jpg, .jpeg)
- ✅ PNG (.png)
- ✅ WebP (.webp)
- ✅ BMP (.bmp)

### 4. Example Commands
```bash
# Apply theme from specific wallpaper
cd ai-themer
python -m src.ai_themer.cli apply ../wallpapers/nature/sunset.jpg

# Preview theme without applying
python -m src.ai_themer.cli apply ../wallpapers/abstract/geometric.png --preview

# Use different extraction method
python -m src.ai_themer.cli apply ../wallpapers/cityscape/tokyo-skyline.jpg --method kmeans_lab
```

## Tips for Best Results

### Good Wallpapers for Theming:
- 🌅 **Landscapes** - Clear color themes (sunset, forest, ocean)
- 🏙️ **Cityscapes** - Good contrast and defined colors
- 🎨 **Abstract art** - Strong color schemes
- 🌌 **Space/cosmic** - Rich, contrasting colors

### Avoid:
- ❌ Very noisy/busy images
- ❌ Low contrast images
- ❌ Images with too many similar colors
- ❌ Very dark or very bright images

## After Installation

Once you run `./install.sh`, you can immediately:

1. **Add wallpapers** to `wallpapers/nature/` (or any category)
2. **Test the demo**: `cd ai-themer && python demo_simulation.py`
3. **Apply themes**: `python -m src.ai_themer.cli apply ../wallpapers/nature/your-wallpaper.jpg`

No pip, no venv, no extra setup needed! 🎉 