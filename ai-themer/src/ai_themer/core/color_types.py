"""
Color data structures and types for AI Themer.
Provides semantic color representations and palette management.
"""

from typing import Dict, List, Optional, Tuple, Union
from dataclasses import dataclass
from enum import Enum
import colorsys
import re


class ColorRole(Enum):
    """Semantic roles that colors can play in a theme."""
    PRIMARY = "primary"
    SECONDARY = "secondary" 
    ACCENT = "accent"
    BACKGROUND = "background"
    SURFACE = "surface"
    TEXT = "text"
    TEXT_SECONDARY = "text_secondary"
    BORDER = "border"
    WARNING = "warning"
    ERROR = "error"


@dataclass
class SemanticColor:
    """
    Represents a color with semantic meaning and multiple format representations.
    """
    # Core RGB values (0-255)
    r: int
    g: int
    b: int
    
    # Semantic role
    role: ColorRole
    
    # Confidence score for role assignment (0.0-1.0)
    confidence: float = 1.0
    
    # Optional alpha channel
    alpha: int = 255
    
    def __post_init__(self):
        """Validate color values after initialization."""
        self.r = max(0, min(255, self.r))
        self.g = max(0, min(255, self.g)) 
        self.b = max(0, min(255, self.b))
        self.alpha = max(0, min(255, self.alpha))
        self.confidence = max(0.0, min(1.0, self.confidence))
    
    @property
    def hex(self) -> str:
        """Get hex representation (#RRGGBB)."""
        return f"#{self.r:02x}{self.g:02x}{self.b:02x}"
    
    @property
    def hex_with_alpha(self) -> str:
        """Get hex representation with alpha (#RRGGBBAA)."""
        return f"#{self.r:02x}{self.g:02x}{self.b:02x}{self.alpha:02x}"
    
    @property
    def rgb(self) -> Tuple[int, int, int]:
        """Get RGB tuple (r, g, b)."""
        return (self.r, self.g, self.b)
    
    @property
    def rgba(self) -> Tuple[int, int, int, int]:
        """Get RGBA tuple (r, g, b, a)."""
        return (self.r, self.g, self.b, self.alpha)
    
    @property
    def rgb_float(self) -> Tuple[float, float, float]:
        """Get RGB as float tuple (0.0-1.0)."""
        return (self.r / 255.0, self.g / 255.0, self.b / 255.0)
    
    @property
    def hsl(self) -> Tuple[float, float, float]:
        """Get HSL representation (h: 0-360, s: 0-100, l: 0-100)."""
        h, l, s = colorsys.rgb_to_hls(self.r / 255.0, self.g / 255.0, self.b / 255.0)
        return (h * 360, s * 100, l * 100)
    
    @property
    def luminance(self) -> float:
        """
        Calculate relative luminance using WCAG formula.
        Returns value between 0.0 (black) and 1.0 (white).
        """
        def gamma_correct(c: float) -> float:
            return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
        
        r, g, b = self.rgb_float
        r = gamma_correct(r)
        g = gamma_correct(g)
        b = gamma_correct(b)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    
    @property
    def is_dark(self) -> bool:
        """Check if color is dark (luminance < 0.5)."""
        return self.luminance < 0.5
    
    @property
    def is_light(self) -> bool:
        """Check if color is light (luminance >= 0.5)."""
        return self.luminance >= 0.5
    
    def contrast_ratio(self, other: 'SemanticColor') -> float:
        """
        Calculate WCAG contrast ratio with another color.
        Returns value between 1.0 (no contrast) and 21.0 (maximum contrast).
        """
        l1 = self.luminance
        l2 = other.luminance
        lighter = max(l1, l2)
        darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    
    def darken(self, amount: float = 0.1) -> 'SemanticColor':
        """Create a darker version of this color."""
        h, s, l = self.hsl
        new_l = max(0, l - amount * 100)
        
        r, g, b = colorsys.hls_to_rgb(h / 360, new_l / 100, s / 100)
        return SemanticColor(
            r=int(r * 255),
            g=int(g * 255),
            b=int(b * 255),
            role=self.role,
            confidence=self.confidence
        )
    
    def lighten(self, amount: float = 0.1) -> 'SemanticColor':
        """Create a lighter version of this color.""" 
        h, s, l = self.hsl
        new_l = min(100, l + amount * 100)
        
        r, g, b = colorsys.hls_to_rgb(h / 360, new_l / 100, s / 100)
        return SemanticColor(
            r=int(r * 255),
            g=int(g * 255), 
            b=int(b * 255),
            role=self.role,
            confidence=self.confidence
        )
    
    def with_alpha(self, alpha: int) -> 'SemanticColor':
        """Create a copy with different alpha value."""
        return SemanticColor(
            r=self.r,
            g=self.g,
            b=self.b,
            role=self.role,
            confidence=self.confidence,
            alpha=alpha
        )
    
    @classmethod
    def from_hex(cls, hex_color: str, role: ColorRole = ColorRole.PRIMARY) -> 'SemanticColor':
        """Create SemanticColor from hex string."""
        # Remove # prefix if present
        hex_color = hex_color.lstrip('#')
        
        # Handle different hex formats
        if len(hex_color) == 3:
            hex_color = ''.join([c*2 for c in hex_color])
        elif len(hex_color) == 6:
            pass  # Standard format
        elif len(hex_color) == 8:
            # RRGGBBAA format - extract alpha
            alpha = int(hex_color[6:8], 16)
            hex_color = hex_color[:6]
        else:
            raise ValueError(f"Invalid hex color format: {hex_color}")
        
        # Parse RGB components
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        
        return cls(r=r, g=g, b=b, role=role)
    
    @classmethod
    def from_rgb(cls, r: int, g: int, b: int, role: ColorRole = ColorRole.PRIMARY) -> 'SemanticColor':
        """Create SemanticColor from RGB values."""
        return cls(r=r, g=g, b=b, role=role)
    
    def __str__(self) -> str:
        return f"{self.role.value}: {self.hex}"


@dataclass 
class ColorPalette:
    """
    Represents a complete color palette with semantic color assignments.
    """
    colors: Dict[ColorRole, SemanticColor]
    
    # Metadata
    source_image: Optional[str] = None
    extraction_method: Optional[str] = None
    quality_score: Optional[float] = None
    
    def __post_init__(self):
        """Ensure we have all required colors."""
        required_roles = {
            ColorRole.PRIMARY,
            ColorRole.BACKGROUND, 
            ColorRole.TEXT
        }
        
        missing_roles = required_roles - set(self.colors.keys())
        if missing_roles:
            raise ValueError(f"Missing required color roles: {missing_roles}")
    
    def get_color(self, role: ColorRole) -> Optional[SemanticColor]:
        """Get color by semantic role."""
        return self.colors.get(role)
    
    def get_primary(self) -> SemanticColor:
        """Get primary color."""
        return self.colors[ColorRole.PRIMARY]
    
    def get_background(self) -> SemanticColor:
        """Get background color."""
        return self.colors[ColorRole.BACKGROUND]
    
    def get_text(self) -> SemanticColor:
        """Get text color."""
        return self.colors[ColorRole.TEXT]
    
    def get_accent(self) -> Optional[SemanticColor]:
        """Get accent color if available."""
        return self.colors.get(ColorRole.ACCENT)
    
    def validate_contrast(self) -> Dict[str, float]:
        """
        Validate contrast ratios between key color pairs.
        Returns dict of contrast ratios.
        """
        contrasts = {}
        
        bg = self.get_background()
        text = self.get_text()
        
        if bg and text:
            contrasts['text_on_background'] = text.contrast_ratio(bg)
        
        primary = self.get_primary()
        if primary and bg:
            contrasts['primary_on_background'] = primary.contrast_ratio(bg)
        
        accent = self.get_accent()
        if accent and bg:
            contrasts['accent_on_background'] = accent.contrast_ratio(bg)
            
        return contrasts
    
    def meets_accessibility_standards(self) -> bool:
        """Check if palette meets WCAG AA contrast standards."""
        contrasts = self.validate_contrast()
        
        # WCAG AA requires 4.5:1 for normal text, 3:1 for large text
        # We'll use the more strict 4.5:1 requirement
        required_contrast = 4.5
        
        text_contrast = contrasts.get('text_on_background', 0)
        return text_contrast >= required_contrast
    
    def to_dict(self) -> Dict[str, any]:
        """Convert palette to dictionary representation."""
        return {
            'colors': {
                role.value: {
                    'hex': color.hex,
                    'rgb': color.rgb,
                    'hsl': color.hsl,
                    'confidence': color.confidence
                }
                for role, color in self.colors.items()
            },
            'metadata': {
                'source_image': self.source_image,
                'extraction_method': self.extraction_method,
                'quality_score': self.quality_score,
                'contrast_ratios': self.validate_contrast(),
                'accessibility_compliant': self.meets_accessibility_standards()
            }
        }
    
    @classmethod
    def from_colors(cls, colors: List[Tuple[int, int, int]], 
                   source_image: Optional[str] = None) -> 'ColorPalette':
        """Create palette from list of RGB tuples with automatic role assignment."""
        if len(colors) < 3:
            raise ValueError("Need at least 3 colors to create a palette")
        
        # Convert to SemanticColor objects
        semantic_colors = [
            SemanticColor.from_rgb(r, g, b) for r, g, b in colors
        ]
        
        # Sort by luminance to help with role assignment
        semantic_colors.sort(key=lambda c: c.luminance)
        
        # Assign roles based on luminance and position
        color_map = {}
        
        # Background: darkest color
        color_map[ColorRole.BACKGROUND] = semantic_colors[0]
        color_map[ColorRole.BACKGROUND].role = ColorRole.BACKGROUND
        
        # Text: lightest color that has good contrast with background
        bg = color_map[ColorRole.BACKGROUND]
        for color in reversed(semantic_colors):
            if color.contrast_ratio(bg) >= 3.0:  # Minimum readability
                color_map[ColorRole.TEXT] = color
                color_map[ColorRole.TEXT].role = ColorRole.TEXT
                break
        
        # If no good text color found, use the lightest
        if ColorRole.TEXT not in color_map:
            color_map[ColorRole.TEXT] = semantic_colors[-1] 
            color_map[ColorRole.TEXT].role = ColorRole.TEXT
        
        # Primary: most saturated color (if available)
        # Calculate saturation for middle colors
        middle_colors = semantic_colors[1:-1] if len(semantic_colors) > 2 else semantic_colors[1:2]
        if middle_colors:
            most_saturated = max(middle_colors, key=lambda c: c.hsl[1])  # HSL saturation
            color_map[ColorRole.PRIMARY] = most_saturated
            color_map[ColorRole.PRIMARY].role = ColorRole.PRIMARY
        else:
            # Fallback to a middle luminance color
            color_map[ColorRole.PRIMARY] = semantic_colors[len(semantic_colors) // 2]
            color_map[ColorRole.PRIMARY].role = ColorRole.PRIMARY
        
        # Secondary and accent colors if we have enough colors
        remaining_colors = [c for c in semantic_colors if c not in color_map.values()]
        
        if remaining_colors:
            color_map[ColorRole.SECONDARY] = remaining_colors[0]
            color_map[ColorRole.SECONDARY].role = ColorRole.SECONDARY
        
        if len(remaining_colors) > 1:
            color_map[ColorRole.ACCENT] = remaining_colors[1]
            color_map[ColorRole.ACCENT].role = ColorRole.ACCENT
        
        # Surface color: slightly lighter than background
        if ColorRole.SURFACE not in color_map:
            surface = color_map[ColorRole.BACKGROUND].lighten(0.05)
            surface.role = ColorRole.SURFACE
            color_map[ColorRole.SURFACE] = surface
        
        return cls(
            colors=color_map,
            source_image=source_image,
            extraction_method="automatic_assignment"
        ) 