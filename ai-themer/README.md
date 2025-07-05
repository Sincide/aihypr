# AI Themer 🎨

**Intelligent AI-powered theming system for Linux that extracts colors from wallpapers and applies them across your entire desktop environment.**

## Features

### 🔬 Advanced Color Science
- **Multiple extraction algorithms**: K-means clustering (LAB/RGB), median cut, ColorThief, adaptive selection
- **Perceptually uniform color spaces**: LAB color space for more natural color clustering
- **Quality assessment**: Automatic scoring based on contrast ratios, color diversity, and accessibility standards
- **WCAG compliance**: Ensures themes meet accessibility guidelines for text readability

### 🎯 Intelligent Color Assignment
- **Semantic role mapping**: Automatically assigns colors to background, text, primary, secondary, accent roles
- **Luminance-based sorting**: Smart assignment based on color brightness and saturation
- **Accessibility validation**: Ensures sufficient contrast ratios between text and background
- **Fallback generation**: Creates missing colors using complementary and harmonic relationships

### 📝 Powerful Template System
- **Jinja2-based templates** with 20+ custom color manipulation filters
- **Format conversion**: hex, rgb, rgba, hsl, hsla outputs
- **Color manipulation**: darken, lighten, saturate, desaturate, alpha, mix
- **Color analysis**: luminance, contrast ratio, brightness detection
- **Color harmony**: complement, triad, analogous color generation
- **Format-specific helpers**: CSS variables, Rofi RASI, shell variables

### 🔧 Multi-Application Support
- **Hyprland**: Window manager colors, borders, decorations
- **Alacritty**: Terminal color schemes with full 16-color palette
- **Rofi**: Launcher themes with comprehensive state styling
- **Extensible**: Easy to add new applications via templates

### 🛡️ Robust System Management
- **Automatic backups**: Creates timestamped backups before applying themes
- **Restore functionality**: One-command restoration from backups
- **Application reload**: Automatic or manual application reloading
- **Error handling**: Comprehensive error reporting and graceful failure
- **Dry-run mode**: Preview themes without applying changes

### 🖥️ Beautiful CLI Interface
- **Rich terminal output** with colors, tables, and progress indicators
- **Multiple commands**: apply, pick, extract, status, restore
- **Method comparison**: Test different extraction algorithms
- **Status monitoring**: Check application and backup status
- **Verbose logging**: Detailed operation logging

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Wallpaper     │───▶│  Color Extractor │───▶│  Color Palette  │
│   Images        │    │  (5 algorithms)  │    │  (Semantic)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Generated      │◀───│ Template Engine  │◀───│  Theme Applier  │
│  Configs        │    │  (Jinja2 + 20+   │    │  (Orchestrator) │
│                 │    │   color filters)  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Core Components

1. **Color Extractor**: Extracts dominant colors using multiple algorithms
2. **Template Engine**: Renders application configs using intelligent templates
3. **Theme Applier**: Orchestrates theme application across multiple apps
4. **CLI Interface**: Beautiful command-line interface for user interaction

## Installation

### Prerequisites
- Python 3.8+
- Linux system with standard tools
- Target applications (Hyprland, Alacritty, Rofi, etc.)

### From Source
```bash
git clone <repository-url>
cd ai-themer

# Install using system package manager (recommended)
# Install required Python packages via your distribution's package manager

# For Arch Linux:
sudo pacman -S python-pillow python-scikit-learn python-numpy \
               python-jinja python-click python-rich python-yaml

# Run the demo to verify installation
python demo_simulation.py
```

## Usage

### Basic Theme Application
```bash
# Apply theme from wallpaper to all applications
ai-themer apply /path/to/wallpaper.jpg

# Apply to specific applications only
ai-themer apply /path/to/wallpaper.jpg --apps hyprland alacritty

# Preview theme without applying
ai-themer apply /path/to/wallpaper.jpg --preview

# Use specific extraction method
ai-themer apply /path/to/wallpaper.jpg --method kmeans_lab
```

### Color Extraction and Analysis
```bash
# Extract colors from image
ai-themer extract /path/to/image.jpg

# Compare all extraction methods
ai-themer extract /path/to/image.jpg --compare-methods
```

### System Management
```bash
# Check system status
ai-themer status

# Restore from backups
ai-themer restore

# Restore specific applications
ai-themer restore --apps hyprland alacritty
```

### Wallpaper Picker (Future Feature)
```bash
# Launch wallpaper picker (will integrate with Rofi)
ai-themer pick --wallpaper-dir ~/Pictures/wallpapers
```

## Configuration

### Template Customization
Templates are located in `templates/` directory. Each application has its own subdirectory:

```
templates/
├── hyprland/
│   └── colors.conf.j2
├── alacritty/
│   └── colors.toml.j2
└── rofi/
    └── colors.rasi.j2
```

### Template Variables
Templates have access to rich color context:

```jinja2
# Basic colors
{{ colors.background | hex }}     # Background color in hex
{{ colors.text | hex }}           # Text color in hex
{{ colors.primary | hex }}        # Primary accent color

# Color manipulation
{{ colors.primary | darken(0.2) | hex }}    # Darker primary
{{ colors.primary | lighten(0.3) | hex }}   # Lighter primary
{{ colors.primary | alpha(0.5) | hex }}     # Semi-transparent

# Color analysis
{% if colors.background | is_dark %}
  # Dark theme specific settings
{% endif %}

# Format conversion
{{ colors.primary | rgb }}        # rgb(100, 150, 200)
{{ colors.primary | hsl }}        # hsl(210, 50%, 60%)
```

### Application Configuration
Applications are configured in the `ThemeApplier` class:

```python
ApplicationConfig(
    name="myapp",
    template_path="myapp/config.j2",
    output_path="~/.config/myapp/colors.conf",
    reload_command="myapp --reload",
    reload_delay=1.0
)
```

## Color Extraction Methods

### K-means LAB (Recommended)
- **Best for**: Most wallpapers
- **Pros**: Perceptually uniform clustering, high quality results
- **Cons**: Slightly slower

### K-means RGB
- **Best for**: Fast processing
- **Pros**: Very fast, good results
- **Cons**: Less perceptually accurate than LAB

### Median Cut
- **Best for**: Deterministic results
- **Pros**: Fast, deterministic, good for simple images
- **Cons**: May miss subtle color variations

### ColorThief
- **Best for**: Artistic images
- **Pros**: Handles complex images well
- **Cons**: External dependency

### Adaptive (Default)
- **Best for**: Unknown wallpaper types
- **Pros**: Tries multiple methods, picks best result
- **Cons**: Slower due to multiple attempts

## Quality Scoring

AI Themer uses a sophisticated quality scoring system (0.0-1.0):

- **Contrast Score (30%)**: WCAG-compliant text readability
- **Color Diversity (25%)**: Variety in extracted colors
- **Saturation Balance (20%)**: Mix of saturated and muted colors
- **Luminance Distribution (15%)**: Good spread of light/dark values
- **Role Assignment Confidence (10%)**: Certainty in color role assignment

## File Structure

```
ai-themer/
├── src/ai_themer/
│   ├── core/
│   │   ├── color_extractor.py    # Color extraction algorithms
│   │   ├── color_types.py        # Color data structures
│   │   ├── template_engine.py    # Jinja2 template engine
│   │   └── theme_applier.py      # Theme application coordinator
│   ├── utils/
│   │   └── file_utils.py         # File operations and utilities
│   ├── applications/             # Application-specific integrations
│   └── cli.py                    # Command-line interface
├── templates/                    # Application config templates
│   ├── hyprland/
│   ├── alacritty/
│   └── rofi/
├── demo_simulation.py            # Working demonstration
└── pyproject.toml               # Project configuration
```

## Development

### Running Tests
```bash
# Run comprehensive simulation
python demo_simulation.py

# Run specific component tests
python tests/test_simulation.py
```

### Adding New Applications

1. **Create template**: Add template in `templates/myapp/config.j2`
2. **Configure application**: Add to `ThemeApplier._load_default_applications()`
3. **Test**: Use preview mode to validate template

Example template:
```jinja2
# MyApp Configuration
# Generated by AI Themer

background_color={{ colors.background | hex }}
text_color={{ colors.text | hex }}
accent_color={{ colors.primary | hex }}

# Conditional theming
{% if colors.background | is_dark %}
theme=dark
{% else %}
theme=light
{% endif %}
```

### Custom Color Filters

Add custom Jinja2 filters in `TemplateEngine._register_filters()`:

```python
def _filter_my_custom_filter(self, color: SemanticColor) -> str:
    # Custom color manipulation
    return f"custom({color.hex})"

# Register in _register_filters()
self.environment.filters['my_filter'] = self._filter_my_custom_filter
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Run the test suite
5. Submit a pull request

### Contribution Guidelines
- Follow Python PEP 8 style guidelines
- Add type hints for all functions
- Include comprehensive docstrings
- Test all new features thoroughly
- Update documentation for user-facing changes

## Troubleshooting

### Common Issues

**Template rendering fails**
- Check template syntax in `templates/` directory
- Verify all required color roles are available
- Use `--preview` mode to debug template issues

**Application not reloading**
- Check if reload command is correct in application configuration
- Some applications auto-reload, others require manual restart
- Verify application is running when reload command executes

**Colors don't look good**
- Try different extraction methods with `--method`
- Use `--compare-methods` to find best algorithm for your wallpaper
- Check quality score - low scores indicate problematic source images

**Permission errors**
- Ensure write access to config directories
- Check that backup directory is writable
- Verify target application config paths exist

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Color science based on CIE standards and WCAG guidelines
- Template system powered by Jinja2
- CLI interface built with Click and Rich
- Color extraction using scikit-learn and ColorThief

---

**AI Themer - Making Linux beautiful, one wallpaper at a time.** 🎨 