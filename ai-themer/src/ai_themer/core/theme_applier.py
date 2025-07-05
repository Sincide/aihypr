"""
Theme applier for coordinating theme application across multiple applications.
Handles backup, restore, and application-specific reload logic.
"""

from typing import Dict, List, Optional, Tuple, Any
import os
import shutil
import subprocess
import json
import time
from pathlib import Path
from dataclasses import dataclass, field
from datetime import datetime
import logging
import numpy as np

from .color_types import ColorPalette
from .template_engine import TemplateEngine
from ..utils.file_utils import ensure_dir, backup_file, restore_file


def convert_numpy_types(obj):
    """
    Convert numpy types to native Python types for JSON serialization.
    
    Args:
        obj: Object that might contain numpy types
        
    Returns:
        Object with numpy types converted to native Python types
    """
    if isinstance(obj, np.integer):
        return int(obj)
    elif isinstance(obj, np.floating):
        return float(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    elif isinstance(obj, dict):
        return {k: convert_numpy_types(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_numpy_types(item) for item in obj]
    elif isinstance(obj, tuple):
        return tuple(convert_numpy_types(item) for item in obj)
    else:
        return obj


@dataclass
class ApplicationConfig:
    """Configuration for a specific application."""
    name: str
    template_path: str
    output_path: str
    backup_path: Optional[str] = None
    reload_command: Optional[str] = None
    reload_delay: float = 0.5
    enabled: bool = True
    requires_restart: bool = False
    
    def __post_init__(self):
        if self.backup_path is None:
            self.backup_path = f"{self.output_path}.backup"


@dataclass
class ThemeApplication:
    """Results of applying a theme to an application."""
    app_name: str
    success: bool
    output_path: str
    backup_created: bool = False
    reloaded: bool = False
    error: Optional[str] = None
    reload_output: Optional[str] = None


class ThemeApplier:
    """
    Coordinates theme application across multiple applications.
    Handles backup/restore and application reload logic.
    """
    
    def __init__(self, 
                 template_dir: str,
                 config_dir: Optional[str] = None,
                 backup_dir: Optional[str] = None):
        """
        Initialize theme applier.
        
        Args:
            template_dir: Directory containing template files
            config_dir: Directory for storing applier configuration
            backup_dir: Directory for storing backups
        """
        self.template_dir = template_dir
        self.config_dir = config_dir or os.path.expanduser("~/.config/ai-themer")
        self.backup_dir = backup_dir or os.path.join(self.config_dir, "backups")
        
        self.template_engine = TemplateEngine(template_dir)
        self.applications: Dict[str, ApplicationConfig] = {}
        self.logger = logging.getLogger(__name__)
        
        # Ensure directories exist
        ensure_dir(self.config_dir)
        ensure_dir(self.backup_dir)
        
        # Load default application configurations
        self._load_default_applications()
    
    def _load_default_applications(self):
        """Load default application configurations."""
        home = os.path.expanduser("~")
        
        # Hyprland
        self.applications["hyprland"] = ApplicationConfig(
            name="hyprland",
            template_path="hyprland/colors.conf.j2",
            output_path=os.path.join(home, ".config/hypr/conf/colors.conf"),
            reload_command="hyprctl reload",
            reload_delay=1.0
        )
        
        # Alacritty
        self.applications["alacritty"] = ApplicationConfig(
            name="alacritty",
            template_path="alacritty/colors.toml.j2",
            output_path=os.path.join(home, ".config/alacritty/colors.toml"),
            reload_command=None,  # Alacritty has live_config_reload enabled by default
            reload_delay=0.1
        )
        
        # Rofi
        self.applications["rofi"] = ApplicationConfig(
            name="rofi",
            template_path="rofi/colors.rasi.j2",
            output_path=os.path.join(home, ".config/rofi/colors.rasi"),
            reload_command=None,  # Rofi reads config on each launch
            reload_delay=0.0
        )
        
        # Waybar
        self.applications["waybar"] = ApplicationConfig(
            name="waybar",
            template_path="waybar/colors.css.j2",
            output_path=os.path.join(home, ".config/waybar/colors.css"),
            reload_command="pkill -SIGUSR2 waybar || (pkill waybar && sleep 1 && waybar &)",  # Reload or restart waybar
            reload_delay=2.0
        )
        
        # SwayNC
        self.applications["swaync"] = ApplicationConfig(
            name="swaync",
            template_path="",  # SwayNC uses direct CSS generation, not templates
            output_path=os.path.join(home, ".config/swaync/style.css"),  # Generate complete GTK CSS replacement
            reload_command="swaync-client -rs",  # Reload swaync
            reload_delay=1.0
        )
    
    def apply_theme(self, 
                   palette: ColorPalette,
                   applications: Optional[List[str]] = None,
                   create_backup: bool = True,
                   reload_applications: bool = True) -> Dict[str, ThemeApplication]:
        """
        Apply theme to specified applications.
        
        Args:
            palette: Color palette to apply
            applications: List of application names to apply to (None = all)
            create_backup: Whether to create backups before applying
            reload_applications: Whether to reload applications after applying
            
        Returns:
            Dictionary mapping application names to ThemeApplication results
        """
        if applications is None:
            applications = [name for name, config in self.applications.items() if config.enabled]
        
        results = {}
        
        for app_name in applications:
            if app_name not in self.applications:
                results[app_name] = ThemeApplication(
                    app_name=app_name,
                    success=False,
                    output_path="",
                    error=f"Unknown application: {app_name}"
                )
                continue
            
            try:
                result = self._apply_to_application(
                    app_name, 
                    palette, 
                    create_backup, 
                    reload_applications
                )
                results[app_name] = result
                
            except Exception as e:
                self.logger.error(f"Failed to apply theme to {app_name}: {e}")
                results[app_name] = ThemeApplication(
                    app_name=app_name,
                    success=False,
                    output_path="",
                    error=str(e)
                )
        
        # Save application record
        self._save_application_record(palette, results)
        
        return results
    
    def _generate_swaync_css(self, palette: ColorPalette) -> str:
        """Generate SwayNC CSS using proper GTK @define-color syntax."""
        from .color_types import ColorRole
        
        # Helper function to get color safely
        def get_color_hex(role: ColorRole, fallback_hex: str = "#1e1e2e") -> str:
            color = palette.get_color(role)
            return color.hex if color else fallback_hex
        
        # Get colors using ColorRole enum
        bg_color = get_color_hex(ColorRole.BACKGROUND, "#1e1e2e")
        surface_color = get_color_hex(ColorRole.SURFACE, "#313244")
        text_color = get_color_hex(ColorRole.TEXT, "#cdd6f4")
        primary_color = get_color_hex(ColorRole.PRIMARY, "#89b4fa")
        accent_color = get_color_hex(ColorRole.ACCENT, primary_color)  # Fallback to primary
        
        # Use warning/error colors if available, otherwise use primary colors
        warning_color = get_color_hex(ColorRole.WARNING, "#f9e2af")
        error_color = get_color_hex(ColorRole.ERROR, "#f38ba8")
        
        # Generate additional color variations
        hover_color = surface_color  # Use surface color for hover
        selected_color = accent_color  # Use accent color for selected
        
        # Generate GTK CSS with @define-color syntax
        css_content = []
        css_content.append("/* SwayNotificationCenter Theme */")
        css_content.append("/* Generated by AI Themer - GTK CSS with @define-color */")
        css_content.append("")
        css_content.append("/* Color definitions */")
        css_content.append(f"@define-color background_color {bg_color};")
        css_content.append(f"@define-color text_color {text_color};")
        css_content.append(f"@define-color border_color {surface_color};")
        css_content.append(f"@define-color button_color {surface_color};")
        css_content.append(f"@define-color hover_color {hover_color};")
        css_content.append(f"@define-color selected_color {selected_color};")
        css_content.append(f"@define-color urgent_color {error_color};")
        css_content.append("")
        css_content.append("/* Base styling */")
        css_content.append("* {")
        css_content.append("  font-family: \"JetBrainsMono Nerd Font\";")
        css_content.append("  font-size: 12px;")
        css_content.append("  color: @text_color;")
        css_content.append("  background-color: @background_color;")
        css_content.append("  border: 1px solid @border_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#main {")
        css_content.append("  background-color: @background_color;")
        css_content.append("  border-radius: 10px;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#notifications {")
        css_content.append("  background-color: @background_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification {")
        css_content.append("  background-color: @background_color;")
        css_content.append("  border-bottom: 1px solid @border_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification:hover {")
        css_content.append("  background-color: @hover_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification-action-button {")
        css_content.append("  background-color: @button_color;")
        css_content.append("  color: @text_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification-action-button:hover {")
        css_content.append("  background-color: @hover_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification-close-button {")
        css_content.append("  background-color: @button_color;")
        css_content.append("  color: @text_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification-close-button:hover {")
        css_content.append("  background-color: @hover_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification-title {")
        css_content.append("  font-weight: bold;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification-body {")
        css_content.append("  color: @text_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#buttons button {")
        css_content.append("  background-color: @button_color;")
        css_content.append("  color: @text_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#buttons button:hover {")
        css_content.append("  background-color: @hover_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#buttons button:active {")
        css_content.append("  background-color: @selected_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#buttons button:disabled {")
        css_content.append("  background-color: @button_color;")
        css_content.append("  color: @text_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#buttons button.active {")
        css_content.append("  background-color: @selected_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("#controls {")
        css_content.append("  background-color: @background_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("/* Additional SwayNC specific styles */")
        css_content.append(".control-center {")
        css_content.append("  background-color: @background_color;")
        css_content.append("  border: 1px solid @border_color;")
        css_content.append("  border-radius: 10px;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".widget-title {")
        css_content.append("  background-color: @button_color;")
        css_content.append("  color: @text_color;")
        css_content.append("  font-weight: bold;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".widget-dnd {")
        css_content.append("  background-color: @button_color;")
        css_content.append("  color: @text_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".widget-dnd > switch:checked {")
        css_content.append("  background-color: @selected_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append("/* Urgency levels */")
        css_content.append(".notification.critical {")
        css_content.append("  border-color: @urgent_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification.critical .notification-title {")
        css_content.append("  color: @urgent_color;")
        css_content.append("}")
        css_content.append("")
        css_content.append(".notification.critical .notification-body {")
        css_content.append("  color: @urgent_color;")
        css_content.append("}")
        css_content.append("")
        
        return "\n".join(css_content)

    def _apply_to_application(self,
                            app_name: str,
                            palette: ColorPalette,
                            create_backup: bool,
                            reload_application: bool) -> ThemeApplication:
        """Apply theme to a specific application."""
        config = self.applications[app_name]
        
        # Create backup if requested
        backup_created = False
        if create_backup and os.path.exists(config.output_path):
            backup_path = self._create_backup(config.output_path, app_name)
            backup_created = True
            self.logger.info(f"Created backup for {app_name}: {backup_path}")
        
        # Generate content for application
        try:
            if app_name == "swaync":
                # Special handling for SwayNC - generate CSS directly
                rendered = self._generate_swaync_css(palette)
            else:
                # Use template rendering for other applications
                rendered = self.template_engine.render_template(
                    config.template_path,
                    palette,
                    app_name=app_name,
                    timestamp=datetime.now().isoformat(),
                    user_home=os.path.expanduser("~")
                )
        except Exception as e:
            return ThemeApplication(
                app_name=app_name,
                success=False,
                output_path=config.output_path,
                backup_created=backup_created,
                error=f"Content generation failed: {e}"
            )
        
        # Ensure output directory exists
        ensure_dir(os.path.dirname(config.output_path))
        
        # Write rendered template
        try:
            with open(config.output_path, 'w') as f:
                f.write(rendered)
                f.flush()  # Ensure data is written to disk
                os.fsync(f.fileno())  # Force write to disk for live reload
            
            self.logger.info(f"Applied theme to {app_name}: {config.output_path}")
            
        except Exception as e:
            return ThemeApplication(
                app_name=app_name,
                success=False,
                output_path=config.output_path,
                backup_created=backup_created,
                error=f"Failed to write config file: {e}"
            )
        
        # Handle application reload
        reloaded = False
        reload_output = None
        if reload_application:
            if config.reload_command:
                try:
                    # Wait for file to be written
                    time.sleep(config.reload_delay)
                    
                    # Execute reload command
                    result = subprocess.run(
                        config.reload_command,
                        shell=True,
                        capture_output=True,
                        text=True,
                        timeout=30
                    )
                    
                    reloaded = True
                    reload_output = result.stdout if result.stdout else result.stderr
                    
                    self.logger.info(f"Reloaded {app_name} (exit code: {result.returncode})")
                    
                except subprocess.TimeoutExpired:
                    reload_output = "Reload command timed out"
                    self.logger.warning(f"Reload command for {app_name} timed out")
                except Exception as e:
                    reload_output = str(e)
                    self.logger.error(f"Failed to reload {app_name}: {e}")
            else:
                # For applications with live reload (like Alacritty), just wait for the change to be detected
                time.sleep(config.reload_delay)
                reloaded = True
                reload_output = "Live reload (automatic)"
                self.logger.info(f"Applied theme to {app_name} with live reload")
        
        return ThemeApplication(
            app_name=app_name,
            success=True,
            output_path=config.output_path,
            backup_created=backup_created,
            reloaded=reloaded,
            reload_output=reload_output
        )
    
    def _create_backup(self, file_path: str, app_name: str) -> str:
        """Create a backup of the given file."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_filename = f"{app_name}_{timestamp}.backup"
        backup_path = os.path.join(self.backup_dir, backup_filename)
        
        shutil.copy2(file_path, backup_path)
        return backup_path
    
    def _save_application_record(self, palette: ColorPalette, results: Dict[str, ThemeApplication]):
        """Save a record of the theme application."""
        record = {
            "timestamp": datetime.now().isoformat(),
            "palette": convert_numpy_types(palette.to_dict()),
            "applications": {
                name: {
                    "success": result.success,
                    "output_path": result.output_path,
                    "backup_created": result.backup_created,
                    "reloaded": result.reloaded,
                    "error": result.error
                }
                for name, result in results.items()
            }
        }
        
        # Ensure the entire record is JSON-serializable
        record = convert_numpy_types(record)
        
        record_path = os.path.join(self.config_dir, "last_application.json")
        try:
            with open(record_path, 'w') as f:
                json.dump(record, f, indent=2)
        except Exception as e:
            self.logger.error(f"Failed to save application record: {e}")
            # Continue execution even if record saving fails
    
    def restore_backups(self, applications: Optional[List[str]] = None) -> Dict[str, bool]:
        """
        Restore applications from their most recent backups.
        
        Args:
            applications: List of application names to restore (None = all)
            
        Returns:
            Dictionary mapping application names to success status
        """
        if applications is None:
            applications = list(self.applications.keys())
        
        results = {}
        
        for app_name in applications:
            if app_name not in self.applications:
                results[app_name] = False
                continue
            
            try:
                backup_path = self._find_latest_backup(app_name)
                if not backup_path:
                    self.logger.warning(f"No backup found for {app_name}")
                    results[app_name] = False
                    continue
                
                config = self.applications[app_name]
                shutil.copy2(backup_path, config.output_path)
                
                self.logger.info(f"Restored {app_name} from {backup_path}")
                results[app_name] = True
                
            except Exception as e:
                self.logger.error(f"Failed to restore {app_name}: {e}")
                results[app_name] = False
        
        return results
    
    def _find_latest_backup(self, app_name: str) -> Optional[str]:
        """Find the most recent backup for an application."""
        if not os.path.exists(self.backup_dir):
            return None
        
        backups = []
        for filename in os.listdir(self.backup_dir):
            if filename.startswith(f"{app_name}_") and filename.endswith(".backup"):
                backup_path = os.path.join(self.backup_dir, filename)
                backups.append((backup_path, os.path.getmtime(backup_path)))
        
        if not backups:
            return None
        
        # Return the most recent backup
        backups.sort(key=lambda x: x[1], reverse=True)
        return backups[0][0]
    
    def list_backups(self) -> Dict[str, List[Tuple[str, float]]]:
        """List all available backups by application."""
        backups = {}
        
        if not os.path.exists(self.backup_dir):
            return backups
        
        for filename in os.listdir(self.backup_dir):
            if not filename.endswith(".backup"):
                continue
            
            # Parse application name from filename
            parts = filename.split("_")
            if len(parts) < 2:
                continue
            
            app_name = parts[0]
            backup_path = os.path.join(self.backup_dir, filename)
            timestamp = os.path.getmtime(backup_path)
            
            if app_name not in backups:
                backups[app_name] = []
            
            backups[app_name].append((backup_path, timestamp))
        
        # Sort backups by timestamp (most recent first)
        for app_name in backups:
            backups[app_name].sort(key=lambda x: x[1], reverse=True)
        
        return backups
    
    def configure_application(self, app_name: str, config: ApplicationConfig):
        """Configure or update an application."""
        self.applications[app_name] = config
        self.logger.info(f"Configured application: {app_name}")
    
    def get_application_status(self) -> Dict[str, Dict[str, Any]]:
        """Get status information for all applications."""
        status = {}
        
        for app_name, config in self.applications.items():
            config_exists = os.path.exists(config.output_path)
            has_backup = self._find_latest_backup(app_name) is not None
            
            status[app_name] = {
                "enabled": config.enabled,
                "config_exists": config_exists,
                "config_path": config.output_path,
                "template_path": config.template_path,
                "has_backup": has_backup,
                "reload_command": config.reload_command,
                "requires_restart": config.requires_restart
            }
        
        return status
    
    def preview_theme(self, palette: ColorPalette, app_name: str) -> str:
        """Preview how a theme would look for a specific application."""
        if app_name not in self.applications:
            raise ValueError(f"Unknown application: {app_name}")
        
        config = self.applications[app_name]
        
        return self.template_engine.render_template(
            config.template_path,
            palette,
            app_name=app_name,
            timestamp=datetime.now().isoformat(),
            user_home=os.path.expanduser("~")
        ) 