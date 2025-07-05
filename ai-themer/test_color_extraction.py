#!/usr/bin/env python3
"""
Simple test script to verify color extraction and JSON serialization.
This helps debug the "Object of type int64 is not JSON serializable" error.
"""

import json
import sys
import os

# Add the src directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from ai_themer.core.color_extractor import ColorExtractor
from ai_themer.core.color_types import ColorPalette

def test_color_extraction(image_path):
    """Test color extraction and JSON serialization."""
    print(f"Testing color extraction from: {image_path}")
    
    try:
        # Initialize color extractor
        extractor = ColorExtractor()
        
        # Extract colors
        print("Extracting colors...")
        palette = extractor.extract_colors(image_path, method="adaptive")
        
        print(f"✅ Colors extracted successfully!")
        print(f"   - Number of colors: {len(palette.colors)}")
        print(f"   - Method: {palette.extraction_method}")
        
        # Test JSON serialization
        print("Testing JSON serialization...")
        palette_dict = palette.to_dict()
        json_str = json.dumps(palette_dict, indent=2)
        
        print("✅ JSON serialization successful!")
        print(f"   - JSON length: {len(json_str)} characters")
        
        # Print color summary
        print("\n🎨 Color Summary:")
        for role, color in palette.colors.items():
            print(f"   {role.value}: {color.hex} (RGB: {color.rgb})")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    # Test with the graveyard image if it exists
    test_image = "../wallpapers/nature/graveyard.png"
    
    if os.path.exists(test_image):
        print("🧪 Testing AI Themer color extraction...")
        success = test_color_extraction(test_image)
        
        if success:
            print("\n✅ All tests passed! AI Themer should work correctly now.")
        else:
            print("\n❌ Tests failed. Check the error messages above.")
    else:
        print(f"❌ Test image not found: {test_image}")
        print("Please add a wallpaper to ../wallpapers/nature/ and try again.") 