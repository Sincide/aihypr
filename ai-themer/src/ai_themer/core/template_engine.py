"""
Template engine for generating application configuration files.
Uses Jinja2 with custom filters for color manipulation and formatting.
"""

from typing import Dict, Any, Optional, List, Callable
import os
import json
import yaml
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, BaseLoader, DictLoader, Template
from jinja2.exceptions import TemplateError
import colorsys

from .color_types import ColorPalette, SemanticColor, ColorRole


class TemplateEngine:
    """
    Advanced template engine for generating application configuration files.
    Provides extensive color manipulation and formatting capabilities.
    """
    
    def __init__(self, template_dir: Optional[str] = None):
        """
        Initialize template engine.
        
        Args:
            template_dir: Directory containing template files
        """
        self.template_dir = template_dir
        self.environment = self._create_environment()
        self._register_filters()
        
    def _create_environment(self) -> Environment:
        """Create Jinja2 environment with appropriate loader."""
        if self.template_dir and os.path.exists(self.template_dir):
            loader = FileSystemLoader(self.template_dir)
        else:
            # Use empty dict loader if no template directory
            loader = DictLoader({})
        
        return Environment(
            loader=loader,
            trim_blocks=True,
            lstrip_blocks=True,
            keep_trailing_newline=True
        )
    
    def _register_filters(self):
        """Register custom Jinja2 filters for color manipulation."""
        
        # Color format filters
        self.environment.filters['hex'] = self._filter_hex
        self.environment.filters['rgb'] = self._filter_rgb
        self.environment.filters['rgba'] = self._filter_rgba
        self.environment.filters['hsl'] = self._filter_hsl
        self.environment.filters['hsla'] = self._filter_hsla
        
        # Color manipulation filters
        self.environment.filters['darken'] = self._filter_darken
        self.environment.filters['lighten'] = self._filter_lighten
        self.environment.filters['saturate'] = self._filter_saturate
        self.environment.filters['desaturate'] = self._filter_desaturate
        self.environment.filters['alpha'] = self._filter_alpha
        self.environment.filters['mix'] = self._filter_mix
        
        # Color analysis filters
        self.environment.filters['luminance'] = self._filter_luminance
        self.environment.filters['contrast'] = self._filter_contrast
        self.environment.filters['is_dark'] = self._filter_is_dark
        self.environment.filters['is_light'] = self._filter_is_light
        
        # Color harmony filters
        self.environment.filters['complement'] = self._filter_complement
        self.environment.filters['triad'] = self._filter_triad
        self.environment.filters['analogous'] = self._filter_analogous
        
        # Format-specific filters
        self.environment.filters['css_var'] = self._filter_css_var
        self.environment.filters['rasi_var'] = self._filter_rasi_var
        self.environment.filters['shell_var'] = self._filter_shell_var
        
    def render_template(self, template_name: str, palette: ColorPalette, 
                       **context) -> str:
        """
        Render a template with the given color palette and context.
        
        Args:
            template_name: Name of the template file
            palette: ColorPalette to use for rendering
            **context: Additional context variables
            
        Returns:
            Rendered template content
        """
        try:
            template = self.environment.get_template(template_name)
            
            # Prepare context with palette colors
            render_context = {
                'palette': palette,
                'colors': self._prepare_color_context(palette),
                **context
            }
            
            return template.render(**render_context)
            
        except TemplateError as e:
            raise ValueError(f"Template rendering failed: {e}")
    
    def render_string(self, template_string: str, palette: ColorPalette, 
                     **context) -> str:
        """
        Render a template string with the given color palette and context.
        
        Args:
            template_string: Template content as string
            palette: ColorPalette to use for rendering
            **context: Additional context variables
            
        Returns:
            Rendered template content
        """
        try:
            template = Template(template_string, environment=self.environment)
            
            # Prepare context with palette colors
            render_context = {
                'palette': palette,
                'colors': self._prepare_color_context(palette),
                **context
            }
            
            return template.render(**render_context)
            
        except TemplateError as e:
            raise ValueError(f"Template rendering failed: {e}")
    
    def _prepare_color_context(self, palette: ColorPalette) -> Dict[str, Any]:
        """Prepare color context for template rendering."""
        context = {}
        
        # Add individual colors by role
        for role, color in palette.colors.items():
            context[role.value] = color
        
        # Add convenience shortcuts
        context['bg'] = palette.get_background()
        context['fg'] = palette.get_text()
        context['accent'] = palette.get_accent()
        context['primary'] = palette.get_primary()
        
        # Add color lists
        context['all_colors'] = list(palette.colors.values())
        context['color_roles'] = list(palette.colors.keys())
        
        return context
    
    # Color format filters
    def _filter_hex(self, color: SemanticColor) -> str:
        """Convert color to hex format."""
        return color.hex
    
    def _filter_rgb(self, color: SemanticColor) -> str:
        """Convert color to rgb() format."""
        return f"rgb({color.r}, {color.g}, {color.b})"
    
    def _filter_rgba(self, color: SemanticColor, alpha: Optional[float] = None) -> str:
        """Convert color to rgba() format."""
        a = alpha if alpha is not None else color.alpha / 255.0
        return f"rgba({color.r}, {color.g}, {color.b}, {a:.2f})"
    
    def _filter_hsl(self, color: SemanticColor) -> str:
        """Convert color to hsl() format."""
        h, s, l = color.hsl
        return f"hsl({h:.0f}, {s:.0f}%, {l:.0f}%)"
    
    def _filter_hsla(self, color: SemanticColor, alpha: Optional[float] = None) -> str:
        """Convert color to hsla() format."""
        h, s, l = color.hsl
        a = alpha if alpha is not None else color.alpha / 255.0
        return f"hsla({h:.0f}, {s:.0f}%, {l:.0f}%, {a:.2f})"
    
    # Color manipulation filters
    def _filter_darken(self, color: SemanticColor, amount: float = 0.1) -> SemanticColor:
        """Darken a color by the specified amount."""
        return color.darken(amount)
    
    def _filter_lighten(self, color: SemanticColor, amount: float = 0.1) -> SemanticColor:
        """Lighten a color by the specified amount."""
        return color.lighten(amount)
    
    def _filter_saturate(self, color: SemanticColor, amount: float = 0.1) -> SemanticColor:
        """Increase saturation of a color."""
        h, s, l = color.hsl
        new_s = min(100, s + amount * 100)
        
        r, g, b = colorsys.hls_to_rgb(h / 360, l / 100, new_s / 100)
        return SemanticColor(
            r=int(r * 255),
            g=int(g * 255),
            b=int(b * 255),
            role=color.role,
            confidence=color.confidence
        )
    
    def _filter_desaturate(self, color: SemanticColor, amount: float = 0.1) -> SemanticColor:
        """Decrease saturation of a color."""
        h, s, l = color.hsl
        new_s = max(0, s - amount * 100)
        
        r, g, b = colorsys.hls_to_rgb(h / 360, l / 100, new_s / 100)
        return SemanticColor(
            r=int(r * 255),
            g=int(g * 255),
            b=int(b * 255),
            role=color.role,
            confidence=color.confidence
        )
    
    def _filter_alpha(self, color: SemanticColor, alpha: float) -> SemanticColor:
        """Set alpha channel of a color."""
        alpha_int = int(alpha * 255) if alpha <= 1.0 else int(alpha)
        return color.with_alpha(alpha_int)
    
    def _filter_mix(self, color1: SemanticColor, color2: SemanticColor, 
                   ratio: float = 0.5) -> SemanticColor:
        """Mix two colors with the given ratio."""
        r = int(color1.r * (1 - ratio) + color2.r * ratio)
        g = int(color1.g * (1 - ratio) + color2.g * ratio)
        b = int(color1.b * (1 - ratio) + color2.b * ratio)
        
        return SemanticColor(
            r=r, g=g, b=b,
            role=color1.role,
            confidence=min(color1.confidence, color2.confidence)
        )
    
    # Color analysis filters
    def _filter_luminance(self, color: SemanticColor) -> float:
        """Get luminance value of a color."""
        return color.luminance
    
    def _filter_contrast(self, color1: SemanticColor, color2: SemanticColor) -> float:
        """Calculate contrast ratio between two colors."""
        return color1.contrast_ratio(color2)
    
    def _filter_is_dark(self, color: SemanticColor) -> bool:
        """Check if color is dark."""
        return color.is_dark
    
    def _filter_is_light(self, color: SemanticColor) -> bool:
        """Check if color is light."""
        return color.is_light
    
    # Color harmony filters
    def _filter_complement(self, color: SemanticColor) -> SemanticColor:
        """Get complementary color."""
        h, s, l = color.hsl
        comp_h = (h + 180) % 360
        
        r, g, b = colorsys.hls_to_rgb(comp_h / 360, l / 100, s / 100)
        return SemanticColor(
            r=int(r * 255),
            g=int(g * 255),
            b=int(b * 255),
            role=ColorRole.ACCENT,
            confidence=color.confidence
        )
    
    def _filter_triad(self, color: SemanticColor) -> List[SemanticColor]:
        """Get triadic color harmony."""
        h, s, l = color.hsl
        colors = []
        
        for offset in [0, 120, 240]:
            new_h = (h + offset) % 360
            r, g, b = colorsys.hls_to_rgb(new_h / 360, l / 100, s / 100)
            colors.append(SemanticColor(
                r=int(r * 255),
                g=int(g * 255),
                b=int(b * 255),
                role=ColorRole.ACCENT,
                confidence=color.confidence
            ))
        
        return colors
    
    def _filter_analogous(self, color: SemanticColor) -> List[SemanticColor]:
        """Get analogous color harmony."""
        h, s, l = color.hsl
        colors = []
        
        for offset in [-30, 0, 30]:
            new_h = (h + offset) % 360
            r, g, b = colorsys.hls_to_rgb(new_h / 360, l / 100, s / 100)
            colors.append(SemanticColor(
                r=int(r * 255),
                g=int(g * 255),
                b=int(b * 255),
                role=ColorRole.ACCENT,
                confidence=color.confidence
            ))
        
        return colors
    
    # Format-specific filters
    def _filter_css_var(self, color: SemanticColor, var_name: str) -> str:
        """Format color as CSS variable."""
        return f"--{var_name}: {color.hex};"
    
    def _filter_rasi_var(self, color: SemanticColor, var_name: str) -> str:
        """Format color as Rofi RASI variable."""
        return f"@define-color {var_name} {color.hex};"
    
    def _filter_shell_var(self, color: SemanticColor, var_name: str) -> str:
        """Format color as shell variable."""
        return f"{var_name}='{color.hex}'"
    
    def save_rendered_template(self, template_name: str, output_path: str,
                              palette: ColorPalette, **context) -> None:
        """
        Render template and save to file.
        
        Args:
            template_name: Name of the template file
            output_path: Path to save the rendered file
            palette: ColorPalette to use for rendering
            **context: Additional context variables
        """
        rendered = self.render_template(template_name, palette, **context)
        
        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Write rendered content
        with open(output_path, 'w') as f:
            f.write(rendered)
    
    def get_available_templates(self) -> List[str]:
        """Get list of available template files."""
        if not self.template_dir or not os.path.exists(self.template_dir):
            return []
        
        templates = []
        for root, dirs, files in os.walk(self.template_dir):
            for file in files:
                if file.endswith(('.j2', '.jinja', '.template')):
                    rel_path = os.path.relpath(os.path.join(root, file), self.template_dir)
                    templates.append(rel_path)
        
        return templates
    
    def validate_template(self, template_name: str) -> Dict[str, Any]:
        """
        Validate a template and return information about it.
        
        Args:
            template_name: Name of the template to validate
            
        Returns:
            Dictionary with validation results
        """
        try:
            template = self.environment.get_template(template_name)
            
            # Create a dummy palette for validation
            dummy_palette = ColorPalette.from_colors([
                (30, 30, 30),    # Dark background
                (200, 200, 200), # Light text
                (100, 150, 200), # Primary color
                (150, 100, 200), # Secondary color
                (200, 100, 100), # Accent color
            ])
            
            # Try to render with dummy data
            rendered = template.render(
                palette=dummy_palette,
                colors=self._prepare_color_context(dummy_palette)
            )
            
            return {
                'valid': True,
                'template_name': template_name,
                'rendered_length': len(rendered),
                'variables_used': self._extract_template_variables(template)
            }
            
        except Exception as e:
            return {
                'valid': False,
                'template_name': template_name,
                'error': str(e)
            }
    
    def _extract_template_variables(self, template: Template) -> List[str]:
        """Extract variable names used in a template."""
        # This is a simplified implementation
        # In a real implementation, you might want to use Jinja2's AST
        variables = []
        
        # Get undeclared variables (this is what the template expects)
        try:
            # Create a mock context to find undeclared variables
            from jinja2.meta import find_undeclared_variables
            variables = list(find_undeclared_variables(template.environment.parse(template.source)))
        except:
            pass
        
        return variables 