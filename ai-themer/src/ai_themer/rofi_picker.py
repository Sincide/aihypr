"""
Rofi-based wallpaper picker for AI Themer.
Provides a visual interface for selecting wallpapers and applying themes.
"""

import os
import subprocess
import tempfile
import shutil
import warnings
import sys
from typing import List, Optional, Tuple
from pathlib import Path

# Suppress warnings from colorspacious library
warnings.filterwarnings("ignore", message="invalid escape sequence")
warnings.filterwarnings("ignore", category=SyntaxWarning)

# Add the parent directory to Python path to handle imports when run directly
if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(os.path.dirname(script_dir))
    sys.path.insert(0, parent_dir)

try:
    from .core.color_extractor import ColorExtractor, ColorExtractionMethod
    from .core.template_engine import TemplateEngine
    from .core.theme_applier import ThemeApplier
except ImportError:
    # Handle case when running as script directly
    from src.ai_themer.core.color_extractor import ColorExtractor, ColorExtractionMethod
    from src.ai_themer.core.template_engine import TemplateEngine
    from src.ai_themer.core.theme_applier import ThemeApplier


class RofiWallpaperPicker:
    """Rofi-based wallpaper picker with thumbnail support."""
    
    def __init__(self, wallpaper_dir: str, template_dir: str, config_dir: str):
        self.wallpaper_dir = wallpaper_dir
        self.template_dir = template_dir
        self.config_dir = config_dir
        self.thumbnail_dir = os.path.join(config_dir, "thumbnails")
        
        # Create thumbnail directory
        os.makedirs(self.thumbnail_dir, exist_ok=True)
        
        # Image extensions to scan for
        self.image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}
    
    def find_wallpapers(self) -> List[Tuple[str, str, str]]:
        """
        Find all wallpapers in the directory structure.
        
        Returns:
            List of (category, filename, full_path) tuples
        """
        wallpapers = []
        
        # Scan wallpaper directory
        for root, dirs, files in os.walk(self.wallpaper_dir):
            for file in files:
                if any(file.lower().endswith(ext) for ext in self.image_extensions):
                    full_path = os.path.join(root, file)
                    
                    # Determine category from directory structure
                    rel_path = os.path.relpath(root, self.wallpaper_dir)
                    if rel_path == ".":
                        category = "uncategorized"
                    else:
                        category = rel_path.split(os.sep)[0]
                    
                    wallpapers.append((category, file, full_path))
        
        return sorted(wallpapers)
    
    def generate_thumbnail(self, image_path: str, size: int = 200) -> str:
        """
        Generate thumbnail for an image.
        
        Args:
            image_path: Path to the original image
            size: Thumbnail size in pixels
            
        Returns:
            Path to the generated thumbnail
        """
        # Create thumbnail filename
        image_name = os.path.basename(image_path)
        name_without_ext = os.path.splitext(image_name)[0]
        thumbnail_path = os.path.join(self.thumbnail_dir, f"{name_without_ext}_thumb.jpg")
        
        # Check if thumbnail already exists and is newer than original
        if (os.path.exists(thumbnail_path) and 
            os.path.getmtime(thumbnail_path) > os.path.getmtime(image_path)):
            return thumbnail_path
        
        # Generate thumbnail using ImageMagick
        try:
            subprocess.run([
                'convert', 
                image_path,
                '-thumbnail', f'{size}x{size}^',
                '-gravity', 'center',
                '-extent', f'{size}x{size}',
                '-quality', '80',
                thumbnail_path
            ], check=True, capture_output=True)
            
            return thumbnail_path
            
        except subprocess.CalledProcessError:
            # Fallback: copy original if ImageMagick fails
            shutil.copy2(image_path, thumbnail_path)
            return thumbnail_path
        except FileNotFoundError:
            # ImageMagick not installed, copy original
            shutil.copy2(image_path, thumbnail_path)
            return thumbnail_path
    
    def create_rofi_entries(self, wallpapers: List[Tuple[str, str, str]]) -> Tuple[List[str], dict]:
        """
        Create Rofi menu entries with thumbnails.
        
        Args:
            wallpapers: List of (category, filename, full_path) tuples
            
        Returns:
            Tuple of (rofi_entries, path_mapping)
        """
        entries = []
        path_mapping = {}
        
        for category, filename, full_path in wallpapers:
            # Generate thumbnail
            thumbnail_path = self.generate_thumbnail(full_path)
            
            # Create display name
            name_without_ext = os.path.splitext(filename)[0]
            display_name = f"{category}/{name_without_ext}"
            
            # Create Rofi entry with icon
            entry = f"{display_name}\x00icon\x1f{thumbnail_path}"
            entries.append(entry)
            path_mapping[display_name] = full_path
        
        return entries, path_mapping
    
    def launch_rofi(self, entries: List[str]) -> Optional[str]:
        """
        Launch Rofi with wallpaper entries.
        
        Args:
            entries: List of Rofi entries
            
        Returns:
            Selected entry or None if cancelled
        """
        try:
            # Create temporary file with entries
            with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
                for entry in entries:
                    f.write(entry + '\n')
                temp_file = f.name
            
            # Launch Rofi
            result = subprocess.run([
                'rofi',
                '-dmenu',
                '-i',  # Case insensitive
                '-p', 'Select Wallpaper',
                '-theme-str', 'listview { columns: 3; }',  # 3 columns for thumbnails
                '-show-icons',
                '-markup-rows',
                '-input', temp_file
            ], capture_output=True, text=True)
            
            # Clean up temp file
            os.unlink(temp_file)
            
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                return None
                
        except FileNotFoundError:
            raise Exception("Rofi not found. Please install rofi-wayland.")
        except Exception as e:
            raise Exception(f"Failed to launch Rofi: {e}")
    
    def apply_theme_from_wallpaper(self, wallpaper_path: str, method: str = "adaptive") -> bool:
        """
        Apply theme from selected wallpaper.
        
        Args:
            wallpaper_path: Path to the selected wallpaper
            method: Color extraction method
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Extract colors
            extractor = ColorExtractor(default_method=method)
            palette = extractor.extract_colors(wallpaper_path, method=method)
            
            # Apply theme
            applier = ThemeApplier(self.template_dir, self.config_dir)
            results = applier.apply_theme(
                palette,
                applications=None,  # Apply to all apps
                create_backup=True,
                reload_applications=True
            )
            
            # Check if all applications succeeded
            success_count = sum(1 for result in results.values() if result.success)
            total_count = len(results)
            
            return success_count == total_count
            
        except Exception as e:
            print(f"Failed to apply theme: {e}")
            return False
    
    def run(self, method: str = "adaptive") -> bool:
        """
        Run the complete wallpaper picker workflow.
        
        Args:
            method: Color extraction method
            
        Returns:
            True if a theme was applied, False otherwise
        """
        # Find wallpapers
        wallpapers = self.find_wallpapers()
        
        if not wallpapers:
            print(f"No wallpapers found in {self.wallpaper_dir}")
            return False
        
        print(f"Found {len(wallpapers)} wallpapers")
        
        # Create Rofi entries
        entries, path_mapping = self.create_rofi_entries(wallpapers)
        
        # Launch Rofi picker
        selected = self.launch_rofi(entries)
        
        if not selected:
            print("No wallpaper selected")
            return False
        
        # Get wallpaper path
        wallpaper_path = path_mapping.get(selected)
        if not wallpaper_path:
            print(f"Invalid selection: {selected}")
            return False
        
        print(f"Selected: {wallpaper_path}")
        print("Applying theme...")
        
        # Apply theme
        success = self.apply_theme_from_wallpaper(wallpaper_path, method)
        
        if success:
            print("✓ Theme applied successfully!")
            
            # Send notification
            try:
                subprocess.run([
                    'notify-send', 
                    'AI Themer', 
                    f'Theme applied from {os.path.basename(wallpaper_path)}',
                    '--icon=preferences-desktop-wallpaper'
                ], check=False)
            except:
                pass  # Notification not critical
            
        else:
            print("✗ Failed to apply theme")
            
            # Send error notification
            try:
                subprocess.run([
                    'notify-send', 
                    'AI Themer', 
                    'Failed to apply theme',
                    '--icon=dialog-error'
                ], check=False)
            except:
                pass
        
        return success


def create_rofi_launcher_script(wallpaper_dir: str, ai_themer_dir: str) -> str:
    """
    Create a standalone launcher script for the Rofi picker.
    
    Args:
        wallpaper_dir: Path to wallpapers directory
        ai_themer_dir: Path to AI Themer directory
        
    Returns:
        Path to the created launcher script
    """
    launcher_content = f'''#!/bin/bash
# AI Themer Rofi Wallpaper Picker
# Auto-generated launcher script

cd "{ai_themer_dir}"
python -m src.ai_themer.rofi_picker "{wallpaper_dir}"
'''
    
    script_path = os.path.expanduser("~/.local/bin/ai-themer-pick")
    os.makedirs(os.path.dirname(script_path), exist_ok=True)
    
    with open(script_path, 'w') as f:
        f.write(launcher_content)
    
    # Make executable
    os.chmod(script_path, 0o755)
    
    return script_path


def main():
    """Main entry point for the rofi picker."""
    import argparse
    
    parser = argparse.ArgumentParser(description='AI Themer Rofi Wallpaper Picker')
    parser.add_argument('wallpaper_dir', help='Directory containing wallpapers')
    parser.add_argument('--template-dir', help='Template directory', 
                       default=os.path.join(os.path.dirname(__file__), '..', '..', 'templates'))
    parser.add_argument('--config-dir', help='Configuration directory',
                       default=os.path.expanduser('~/.config/ai-themer'))
    parser.add_argument('--method', help='Color extraction method',
                       default='adaptive', choices=['adaptive', 'dominant', 'kmeans'])
    
    args = parser.parse_args()
    
    # Ensure directories exist
    os.makedirs(args.config_dir, exist_ok=True)
    
    # Create and run picker
    picker = RofiWallpaperPicker(
        wallpaper_dir=os.path.expanduser(args.wallpaper_dir),
        template_dir=os.path.expanduser(args.template_dir),
        config_dir=args.config_dir
    )
    
    try:
        success = picker.run(method=args.method)
        if success:
            print("✅ Theme applied successfully!")
            sys.exit(0)
        else:
            print("❌ Theme application failed or cancelled")
            sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main() 