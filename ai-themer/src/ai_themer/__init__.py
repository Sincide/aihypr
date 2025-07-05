"""
AI Themer - Intelligent theming system for Linux
Extracts colors from wallpapers and applies them across your system
"""

__version__ = "1.0.0"
__author__ = "AI Themer Project"

from .core.color_extractor import ColorExtractor
from .core.template_engine import TemplateEngine
from .core.theme_applier import ThemeApplier

__all__ = [
    "ColorExtractor",
    "TemplateEngine", 
    "ThemeApplier",
] 