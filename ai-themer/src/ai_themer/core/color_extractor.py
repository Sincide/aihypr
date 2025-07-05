"""
Advanced color extraction engine for AI Themer.
Implements multiple algorithms for extracting dominant colors from images.
"""

from typing import List, Tuple, Optional, Dict, Any
import numpy as np
from PIL import Image
import colorsys
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
import colorspacious
from colorthief import ColorThief
import io

from .color_types import ColorPalette, SemanticColor, ColorRole


class ColorExtractionMethod:
    """Enumeration of available color extraction methods."""
    KMEANS_LAB = "kmeans_lab"
    KMEANS_RGB = "kmeans_rgb"
    MEDIAN_CUT = "median_cut"
    COLORTHIEF = "colorthief"
    ADAPTIVE = "adaptive"


class ColorExtractor:
    """
    Advanced color extraction engine with multiple algorithms and quality assessment.
    """
    
    def __init__(self, 
                 default_method: str = ColorExtractionMethod.KMEANS_LAB,
                 max_colors: int = 8,
                 min_colors: int = 3,
                 resize_image: Tuple[int, int] = (200, 200)):
        """
        Initialize color extractor.
        
        Args:
            default_method: Default extraction method to use
            max_colors: Maximum number of colors to extract
            min_colors: Minimum number of colors to extract  
            resize_image: Target size for image resizing (performance optimization)
        """
        self.default_method = default_method
        self.max_colors = max_colors
        self.min_colors = min_colors
        self.resize_image = resize_image
        
    def extract_colors(self, 
                      image_path: str, 
                      method: Optional[str] = None,
                      num_colors: Optional[int] = None) -> ColorPalette:
        """
        Extract colors from an image using specified method.
        
        Args:
            image_path: Path to the image file
            method: Extraction method to use (defaults to self.default_method)
            num_colors: Number of colors to extract (defaults based on method)
            
        Returns:
            ColorPalette with extracted colors and metadata
        """
        method = method or self.default_method
        num_colors = num_colors or self._get_default_color_count(method)
        
        # Load and preprocess image
        image = self._load_and_preprocess_image(image_path)
        
        # Extract colors using specified method
        if method == ColorExtractionMethod.KMEANS_LAB:
            colors = self._extract_kmeans_lab(image, num_colors)
        elif method == ColorExtractionMethod.KMEANS_RGB:
            colors = self._extract_kmeans_rgb(image, num_colors)
        elif method == ColorExtractionMethod.MEDIAN_CUT:
            colors = self._extract_median_cut(image, num_colors)
        elif method == ColorExtractionMethod.COLORTHIEF:
            colors = self._extract_colorthief(image_path, num_colors)
        elif method == ColorExtractionMethod.ADAPTIVE:
            colors = self._extract_adaptive(image, image_path)
        else:
            raise ValueError(f"Unknown extraction method: {method}")
        
        # Create palette with automatic role assignment
        palette = ColorPalette.from_colors(colors, source_image=image_path)
        palette.extraction_method = method
        
        # Calculate quality score
        palette.quality_score = self._calculate_quality_score(palette, image)
        
        return palette
    
    def _load_and_preprocess_image(self, image_path: str) -> Image.Image:
        """Load and preprocess image for color extraction."""
        try:
            image = Image.open(image_path)
            
            # Convert to RGB if necessary
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Resize for performance (but keep aspect ratio)
            image.thumbnail(self.resize_image, Image.Resampling.LANCZOS)
            
            return image
            
        except Exception as e:
            raise ValueError(f"Failed to load image {image_path}: {e}")
    
    def _extract_kmeans_lab(self, image: Image.Image, num_colors: int) -> List[Tuple[int, int, int]]:
        """
        Extract colors using K-means clustering in LAB color space.
        This provides perceptually uniform color clustering.
        """
        # Convert image to numpy array
        img_array = np.array(image)
        pixels = img_array.reshape(-1, 3)
        
        # Convert RGB to LAB color space
        lab_pixels = []
        for pixel in pixels:
            # Convert to 0-1 range for colorspacious
            rgb_normalized = pixel / 255.0
            lab = colorspacious.cspace_convert(rgb_normalized, "sRGB1", "CIELab")
            lab_pixels.append(lab)
        
        lab_pixels = np.array(lab_pixels)
        
        # Apply K-means clustering in LAB space
        kmeans = KMeans(n_clusters=num_colors, random_state=42, n_init=10)
        kmeans.fit(lab_pixels)
        
        # Convert cluster centers back to RGB
        lab_centers = kmeans.cluster_centers_
        rgb_colors = []
        
        for lab_center in lab_centers:
            # Convert LAB back to RGB
            rgb_normalized = colorspacious.cspace_convert(lab_center, "CIELab", "sRGB1")
            # Clip values to valid range and convert to 0-255
            rgb_normalized = np.clip(rgb_normalized, 0, 1)
            rgb = (rgb_normalized * 255).astype(int)
            # Convert numpy types to native Python types
            rgb_colors.append((int(rgb[0]), int(rgb[1]), int(rgb[2])))
        
        return rgb_colors
    
    def _extract_kmeans_rgb(self, image: Image.Image, num_colors: int) -> List[Tuple[int, int, int]]:
        """Extract colors using K-means clustering in RGB color space."""
        img_array = np.array(image)
        pixels = img_array.reshape(-1, 3)
        
        # Apply K-means clustering
        kmeans = KMeans(n_clusters=num_colors, random_state=42, n_init=10)
        kmeans.fit(pixels)
        
        # Get cluster centers (dominant colors)
        colors = kmeans.cluster_centers_.astype(int)
        # Convert numpy types to native Python types
        return [(int(color[0]), int(color[1]), int(color[2])) for color in colors]
    
    def _extract_median_cut(self, image: Image.Image, num_colors: int) -> List[Tuple[int, int, int]]:
        """
        Extract colors using median cut algorithm.
        Fast and deterministic color quantization.
        """
        # Convert image to P mode (palette mode) with specified number of colors
        quantized = image.quantize(colors=num_colors, method=Image.Quantize.MEDIANCUT)
        
        # Get the palette
        palette = quantized.getpalette()
        
        # Extract RGB tuples
        colors = []
        for i in range(num_colors):
            r = palette[i * 3]
            g = palette[i * 3 + 1] 
            b = palette[i * 3 + 2]
            colors.append((r, g, b))
        
        return colors
    
    def _extract_colorthief(self, image_path: str, num_colors: int) -> List[Tuple[int, int, int]]:
        """Extract colors using the ColorThief library."""
        try:
            color_thief = ColorThief(image_path)
            
            if num_colors == 1:
                dominant = color_thief.get_color(quality=1)
                return [dominant]
            else:
                palette = color_thief.get_palette(color_count=num_colors, quality=1)
                return palette
                
        except Exception as e:
            # Fallback to median cut if ColorThief fails
            image = Image.open(image_path).convert('RGB')
            return self._extract_median_cut(image, num_colors)
    
    def _extract_adaptive(self, image: Image.Image, image_path: str) -> List[Tuple[int, int, int]]:
        """
        Adaptive extraction that tries multiple methods and picks the best result.
        """
        results = []
        
        # Try different methods
        methods_to_try = [
            (ColorExtractionMethod.KMEANS_LAB, 6),
            (ColorExtractionMethod.COLORTHIEF, 5), 
            (ColorExtractionMethod.MEDIAN_CUT, 7)
        ]
        
        for method, num_colors in methods_to_try:
            try:
                if method == ColorExtractionMethod.KMEANS_LAB:
                    colors = self._extract_kmeans_lab(image, num_colors)
                elif method == ColorExtractionMethod.COLORTHIEF:
                    colors = self._extract_colorthief(image_path, num_colors)
                elif method == ColorExtractionMethod.MEDIAN_CUT:
                    colors = self._extract_median_cut(image, num_colors)
                
                # Create a temporary palette to evaluate quality
                temp_palette = ColorPalette.from_colors(colors, source_image=image_path)
                quality = self._calculate_quality_score(temp_palette, image)
                
                results.append((colors, quality, method))
                
            except Exception:
                continue  # Skip failed methods
        
        if not results:
            # Fallback to simple median cut
            return self._extract_median_cut(image, 5)
        
        # Return colors from the highest quality result
        best_result = max(results, key=lambda x: x[1])
        return best_result[0]
    
    def _calculate_quality_score(self, palette: ColorPalette, image: Image.Image) -> float:
        """
        Calculate a quality score for the extracted palette.
        Higher scores indicate better color extraction.
        """
        scores = []
        
        # 1. Contrast score (30% weight)
        contrast_ratios = palette.validate_contrast()
        text_contrast = contrast_ratios.get('text_on_background', 1.0)
        contrast_score = min(1.0, text_contrast / 4.5)  # Normalize to WCAG AA standard
        scores.append(('contrast', contrast_score, 0.3))
        
        # 2. Color diversity score (25% weight)
        colors = [color for color in palette.colors.values()]
        diversity_score = self._calculate_color_diversity(colors)
        scores.append(('diversity', diversity_score, 0.25))
        
        # 3. Saturation balance score (20% weight)
        saturation_score = self._calculate_saturation_balance(colors)
        scores.append(('saturation', saturation_score, 0.2))
        
        # 4. Luminance distribution score (15% weight)
        luminance_score = self._calculate_luminance_distribution(colors)
        scores.append(('luminance', luminance_score, 0.15))
        
        # 5. Role assignment confidence (10% weight)
        confidence_score = np.mean([color.confidence for color in colors])
        scores.append(('confidence', confidence_score, 0.1))
        
        # Calculate weighted average
        total_score = sum(score * weight for _, score, weight in scores)
        
        return min(1.0, max(0.0, total_score))
    
    def _calculate_color_diversity(self, colors: List[SemanticColor]) -> float:
        """Calculate how diverse the colors are in the palette."""
        if len(colors) < 2:
            return 0.0
        
        # Calculate average distance between all color pairs in LAB space
        total_distance = 0
        comparisons = 0
        
        for i, color1 in enumerate(colors):
            for color2 in colors[i+1:]:
                # Convert to LAB for perceptual distance
                lab1 = colorspacious.cspace_convert(color1.rgb_float, "sRGB1", "CIELab")
                lab2 = colorspacious.cspace_convert(color2.rgb_float, "sRGB1", "CIELab")
                
                # Calculate Euclidean distance in LAB space
                distance = np.sqrt(np.sum((lab1 - lab2) ** 2))
                total_distance += distance
                comparisons += 1
        
        avg_distance = total_distance / comparisons if comparisons > 0 else 0
        
        # Normalize to 0-1 range (100 is a reasonable max distance in LAB)
        return min(1.0, avg_distance / 100.0)
    
    def _calculate_saturation_balance(self, colors: List[SemanticColor]) -> float:
        """Calculate how well-balanced the saturations are."""
        saturations = [color.hsl[1] for color in colors]  # HSL saturation values
        
        if not saturations:
            return 0.0
        
        # We want a mix of saturations, not all high or all low
        saturation_std = np.std(saturations)
        
        # Normalize standard deviation (50 is a reasonable max for HSL saturation std)
        return min(1.0, saturation_std / 50.0)
    
    def _calculate_luminance_distribution(self, colors: List[SemanticColor]) -> float:
        """Calculate how well the luminance values are distributed."""
        luminances = [color.luminance for color in colors]
        
        if not luminances:
            return 0.0
        
        # We want good spread across the luminance range
        luminance_range = max(luminances) - min(luminances)
        
        # Also check for reasonable distribution
        luminance_std = np.std(luminances)
        
        # Combine range and standard deviation
        range_score = luminance_range  # Already 0-1
        std_score = min(1.0, luminance_std * 2)  # Reasonable std is around 0.5
        
        return (range_score + std_score) / 2
    
    def _get_default_color_count(self, method: str) -> int:
        """Get default number of colors for each extraction method."""
        defaults = {
            ColorExtractionMethod.KMEANS_LAB: 6,
            ColorExtractionMethod.KMEANS_RGB: 6,
            ColorExtractionMethod.MEDIAN_CUT: 8,
            ColorExtractionMethod.COLORTHIEF: 5,
            ColorExtractionMethod.ADAPTIVE: 6
        }
        return defaults.get(method, 6)
    
    def compare_methods(self, image_path: str) -> Dict[str, Any]:
        """
        Compare all extraction methods on the same image.
        Useful for testing and method selection.
        """
        methods = [
            ColorExtractionMethod.KMEANS_LAB,
            ColorExtractionMethod.KMEANS_RGB,
            ColorExtractionMethod.MEDIAN_CUT,
            ColorExtractionMethod.COLORTHIEF
        ]
        
        results = {}
        
        for method in methods:
            try:
                palette = self.extract_colors(image_path, method=method)
                results[method] = {
                    'palette': palette,
                    'quality_score': palette.quality_score,
                    'colors': [color.hex for color in palette.colors.values()],
                    'accessibility_compliant': palette.meets_accessibility_standards(),
                    'contrast_ratios': palette.validate_contrast()
                }
            except Exception as e:
                results[method] = {'error': str(e)}
        
        # Rank methods by quality score
        successful_methods = {k: v for k, v in results.items() if 'error' not in v}
        if successful_methods:
            ranked = sorted(successful_methods.items(), 
                          key=lambda x: x[1]['quality_score'], 
                          reverse=True)
            results['ranking'] = [method for method, _ in ranked]
            results['best_method'] = ranked[0][0]
        
        return results 