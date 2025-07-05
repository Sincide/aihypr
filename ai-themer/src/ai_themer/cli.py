"""
Command-line interface for AI Themer.
Provides commands for extracting colors, applying themes, and managing configurations.
"""

import os
import sys
import json
import logging
from typing import List, Optional
from pathlib import Path

import click
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.panel import Panel
from rich.text import Text

from .core.color_extractor import ColorExtractor, ColorExtractionMethod
from .core.template_engine import TemplateEngine
from .core.theme_applier import ThemeApplier
from .core.color_types import ColorPalette, ColorRole


# Global console for rich output
console = Console()


def setup_logging(verbose: bool = False):
    """Setup logging configuration."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(os.path.expanduser("~/.config/ai-themer/ai-themer.log")),
            logging.StreamHandler(sys.stderr) if verbose else logging.NullHandler()
        ]
    )


@click.group()
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose logging')
@click.option('--config-dir', default=None, help='Custom configuration directory')
@click.pass_context
def cli(ctx, verbose, config_dir):
    """AI Themer - Intelligent theming system for Linux."""
    setup_logging(verbose)
    
    # Store global configuration
    ctx.ensure_object(dict)
    ctx.obj['verbose'] = verbose
    ctx.obj['config_dir'] = config_dir or os.path.expanduser("~/.config/ai-themer")
    
    # Ensure config directory exists
    os.makedirs(ctx.obj['config_dir'], exist_ok=True)


@cli.command()
@click.argument('wallpaper_path', type=click.Path(exists=True))
@click.option('--method', '-m', 
              type=click.Choice([
                  ColorExtractionMethod.KMEANS_LAB,
                  ColorExtractionMethod.KMEANS_RGB,
                  ColorExtractionMethod.MEDIAN_CUT,
                  ColorExtractionMethod.COLORTHIEF,
                  ColorExtractionMethod.ADAPTIVE
              ]), 
              default=ColorExtractionMethod.ADAPTIVE,
              help='Color extraction method')
@click.option('--apps', '-a', multiple=True, help='Applications to theme (default: all)')
@click.option('--no-backup', is_flag=True, help='Skip creating backups')
@click.option('--no-reload', is_flag=True, help='Skip reloading applications')
@click.option('--preview', is_flag=True, help='Preview theme without applying')
@click.option('--template-dir', default=None, help='Custom template directory')
@click.pass_context
def apply(ctx, wallpaper_path, method, apps, no_backup, no_reload, preview, template_dir):
    """Apply theme from wallpaper to applications."""
    
    # Determine template directory
    if template_dir is None:
        # Use bundled templates
        template_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'templates')
    
    if not os.path.exists(template_dir):
        console.print(f"[red]Template directory not found: {template_dir}[/red]")
        sys.exit(1)
    
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        
        # Step 1: Extract colors
        task = progress.add_task("Extracting colors from wallpaper...", total=None)
        
        try:
            extractor = ColorExtractor(default_method=method)
            palette = extractor.extract_colors(wallpaper_path, method=method)
            
            progress.update(task, description="✓ Colors extracted successfully")
            
        except Exception as e:
            console.print(f"[red]Failed to extract colors: {e}[/red]")
            sys.exit(1)
        
        # Display extracted colors
        console.print("\n[bold]Extracted Color Palette:[/bold]")
        color_table = Table(show_header=True, header_style="bold magenta")
        color_table.add_column("Role", style="cyan")
        color_table.add_column("Color", style="white")
        color_table.add_column("Hex", style="green")
        color_table.add_column("Luminance", style="yellow")
        
        for role, color in palette.colors.items():
            color_preview = f"[{color.hex}]████[/{color.hex}]"
            color_table.add_row(
                role.value.title(),
                color_preview,
                color.hex,
                f"{color.luminance:.3f}"
            )
        
        console.print(color_table)
        
        # Display quality metrics
        console.print(f"\n[bold]Quality Score:[/bold] {palette.quality_score:.2f}")
        console.print(f"[bold]Extraction Method:[/bold] {palette.extraction_method}")
        console.print(f"[bold]Accessibility Compliant:[/bold] {'✓' if palette.meets_accessibility_standards() else '✗'}")
        
        # Preview mode - show what would be generated
        if preview:
            progress.update(task, description="Generating theme preview...")
            
            applier = ThemeApplier(template_dir, ctx.obj['config_dir'])
            app_list = list(apps) if apps else list(applier.applications.keys())
            
            console.print(f"\n[bold]Theme Preview for {len(app_list)} applications:[/bold]")
            
            for app_name in app_list:
                if app_name not in applier.applications:
                    console.print(f"[red]Unknown application: {app_name}[/red]")
                    continue
                
                try:
                    preview_content = applier.preview_theme(palette, app_name)
                    
                    # Show first few lines of generated config
                    lines = preview_content.split('\n')
                    preview_lines = lines[:10]
                    if len(lines) > 10:
                        preview_lines.append("...")
                    
                    console.print(f"\n[bold cyan]{app_name.title()}:[/bold cyan]")
                    console.print(Panel(
                        "\n".join(preview_lines),
                        title=f"{app_name} configuration",
                        border_style="blue"
                    ))
                    
                except Exception as e:
                    console.print(f"[red]Preview failed for {app_name}: {e}[/red]")
            
            return
        
        # Step 2: Apply theme
        progress.update(task, description="Applying theme to applications...")
        
        try:
            applier = ThemeApplier(template_dir, ctx.obj['config_dir'])
            
            results = applier.apply_theme(
                palette,
                applications=list(apps) if apps else None,
                create_backup=not no_backup,
                reload_applications=not no_reload
            )
            
            progress.update(task, description="✓ Theme applied successfully")
            
        except Exception as e:
            console.print(f"[red]Failed to apply theme: {e}[/red]")
            sys.exit(1)
    
    # Display application results
    console.print("\n[bold]Application Results:[/bold]")
    
    results_table = Table(show_header=True, header_style="bold magenta")
    results_table.add_column("Application", style="cyan")
    results_table.add_column("Status", style="white")
    results_table.add_column("Config Path", style="green")
    results_table.add_column("Backup", style="yellow")
    results_table.add_column("Reloaded", style="blue")
    
    for app_name, result in results.items():
        status = "✓ Success" if result.success else f"✗ Failed"
        status_style = "green" if result.success else "red"
        
        backup_status = "✓" if result.backup_created else "✗"
        reload_status = "✓" if result.reloaded else "✗"
        
        results_table.add_row(
            app_name,
            f"[{status_style}]{status}[/{status_style}]",
            result.output_path,
            backup_status,
            reload_status
        )
    
    console.print(results_table)
    
    # Show any errors
    errors = {name: result for name, result in results.items() if not result.success}
    if errors:
        console.print("\n[bold red]Errors:[/bold red]")
        for app_name, result in errors.items():
            console.print(f"[red]• {app_name}: {result.error}[/red]")
    
    success_count = sum(1 for result in results.values() if result.success)
    console.print(f"\n[bold]Successfully themed {success_count}/{len(results)} applications[/bold]")


@cli.command()
@click.option('--wallpaper-dir', default=None, help='Wallpaper directory to scan')
@click.option('--method', '-m', 
              type=click.Choice([
                  ColorExtractionMethod.KMEANS_LAB,
                  ColorExtractionMethod.KMEANS_RGB,
                  ColorExtractionMethod.MEDIAN_CUT,
                  ColorExtractionMethod.COLORTHIEF,
                  ColorExtractionMethod.ADAPTIVE
              ]), 
              default=ColorExtractionMethod.ADAPTIVE,
              help='Color extraction method')
@click.pass_context
def pick(ctx, wallpaper_dir, method):
    """Launch Rofi wallpaper picker."""
    
    from .rofi_picker import RofiWallpaperPicker
    
    if wallpaper_dir is None:
        # Look for wallpapers directory in current project
        current_dir = os.getcwd()
        project_wallpapers = os.path.join(current_dir, "wallpapers")
        
        if os.path.exists(project_wallpapers):
            wallpaper_dir = project_wallpapers
        else:
            # Common wallpaper directories
            wallpaper_dirs = [
                os.path.expanduser("~/Pictures/wallpapers"),
                os.path.expanduser("~/Pictures"),
                os.path.expanduser("~/Wallpapers"),
                "/usr/share/backgrounds",
                "/usr/share/pixmaps"
            ]
            
            # Find first existing directory
            for dir_path in wallpaper_dirs:
                if os.path.exists(dir_path):
                    wallpaper_dir = dir_path
                    break
        
        if wallpaper_dir is None:
            console.print("[red]No wallpaper directory found. Use --wallpaper-dir to specify one.[/red]")
            sys.exit(1)
    
    console.print(f"[cyan]Launching Rofi wallpaper picker...[/cyan]")
    console.print(f"[dim]Wallpaper directory: {wallpaper_dir}[/dim]")
    
    # Determine template directory
    template_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'templates')
    
    try:
        # Launch Rofi picker
        picker = RofiWallpaperPicker(wallpaper_dir, template_dir, ctx.obj['config_dir'])
        success = picker.run(method=method)
        
        if success:
            console.print("[green]✓ Theme applied successfully![/green]")
        else:
            console.print("[yellow]No theme applied[/yellow]")
            
    except Exception as e:
        console.print(f"[red]Failed to launch Rofi picker: {e}[/red]")
        
        # Fallback: show available wallpapers
        console.print("\n[yellow]Fallback: Listing available wallpapers[/yellow]")
        
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}
        wallpapers = []
        
        for root, dirs, files in os.walk(wallpaper_dir):
            for file in files:
                if any(file.lower().endswith(ext) for ext in image_extensions):
                    wallpapers.append(os.path.join(root, file))
        
        if wallpapers:
            console.print(f"[green]Found {len(wallpapers)} wallpapers[/green]")
            for i, wallpaper in enumerate(wallpapers[:10]):
                console.print(f"{i+1}. {os.path.basename(wallpaper)}")
            if len(wallpapers) > 10:
                console.print(f"... and {len(wallpapers) - 10} more")
        else:
            console.print(f"[red]No wallpapers found in {wallpaper_dir}[/red]")
        
        sys.exit(1)


@cli.command()
@click.argument('image_path', type=click.Path(exists=True))
@click.option('--compare-methods', is_flag=True, help='Compare all extraction methods')
@click.pass_context
def extract(ctx, image_path, compare_methods):
    """Extract colors from an image."""
    
    extractor = ColorExtractor()
    
    if compare_methods:
        console.print("[bold]Comparing extraction methods...[/bold]")
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            task = progress.add_task("Analyzing image...", total=None)
            
            try:
                comparison = extractor.compare_methods(image_path)
                progress.update(task, description="✓ Analysis complete")
                
            except Exception as e:
                console.print(f"[red]Analysis failed: {e}[/red]")
                sys.exit(1)
        
        # Display comparison results
        console.print("\n[bold]Method Comparison:[/bold]")
        
        if 'ranking' in comparison:
            console.print(f"[green]Best method: {comparison['best_method']}[/green]")
            console.print(f"[cyan]Ranking: {' > '.join(comparison['ranking'])}[/cyan]")
        
        # Show results for each method
        for method, result in comparison.items():
            if method in ['ranking', 'best_method']:
                continue
            
            if 'error' in result:
                console.print(f"\n[red]{method}: {result['error']}[/red]")
                continue
            
            console.print(f"\n[bold]{method}:[/bold]")
            console.print(f"Quality Score: {result['quality_score']:.3f}")
            console.print(f"Accessibility: {'✓' if result['accessibility_compliant'] else '✗'}")
            console.print(f"Colors: {', '.join(result['colors'])}")
    
    else:
        # Single extraction
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            task = progress.add_task("Extracting colors...", total=None)
            
            try:
                palette = extractor.extract_colors(image_path)
                progress.update(task, description="✓ Colors extracted")
                
            except Exception as e:
                console.print(f"[red]Extraction failed: {e}[/red]")
                sys.exit(1)
        
        # Display results
        console.print("\n[bold]Extracted Colors:[/bold]")
        for role, color in palette.colors.items():
            console.print(f"{role.value}: {color.hex}")
        
        console.print(f"\nQuality Score: {palette.quality_score:.3f}")
        console.print(f"Method: {palette.extraction_method}")


@cli.command()
@click.option('--template-dir', default=None, help='Custom template directory')
@click.pass_context
def status(ctx, template_dir):
    """Show current system status."""
    
    if template_dir is None:
        template_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'templates')
    
    console.print("[bold]AI Themer System Status[/bold]")
    
    # Check templates
    console.print(f"\n[bold]Templates:[/bold]")
    if os.path.exists(template_dir):
        console.print(f"[green]✓ Template directory: {template_dir}[/green]")
        
        template_engine = TemplateEngine(template_dir)
        templates = template_engine.get_available_templates()
        console.print(f"[cyan]Available templates: {len(templates)}[/cyan]")
        
        for template in templates:
            console.print(f"  • {template}")
    else:
        console.print(f"[red]✗ Template directory not found: {template_dir}[/red]")
    
    # Check applications
    console.print(f"\n[bold]Applications:[/bold]")
    applier = ThemeApplier(template_dir, ctx.obj['config_dir'])
    app_status = applier.get_application_status()
    
    status_table = Table(show_header=True, header_style="bold magenta")
    status_table.add_column("Application", style="cyan")
    status_table.add_column("Enabled", style="white")
    status_table.add_column("Config Exists", style="green")
    status_table.add_column("Has Backup", style="yellow")
    status_table.add_column("Reload Command", style="blue")
    
    for app_name, status in app_status.items():
        enabled = "✓" if status['enabled'] else "✗"
        config_exists = "✓" if status['config_exists'] else "✗"
        has_backup = "✓" if status['has_backup'] else "✗"
        reload_cmd = status['reload_command'] if status['reload_command'] else "auto"
        
        status_table.add_row(
            app_name,
            enabled,
            config_exists,
            has_backup,
            reload_cmd
        )
    
    console.print(status_table)
    
    # Check backups
    console.print(f"\n[bold]Backups:[/bold]")
    backups = applier.list_backups()
    
    if backups:
        for app_name, app_backups in backups.items():
            console.print(f"[cyan]{app_name}:[/cyan] {len(app_backups)} backups")
    else:
        console.print("[yellow]No backups found[/yellow]")


@cli.command()
@click.option('--apps', '-a', multiple=True, help='Applications to restore (default: all)')
@click.option('--template-dir', default=None, help='Custom template directory')
@click.pass_context
def restore(ctx, apps, template_dir):
    """Restore applications from backups."""
    
    if template_dir is None:
        template_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'templates')
    
    applier = ThemeApplier(template_dir, ctx.obj['config_dir'])
    
    console.print("[bold]Restoring from backups...[/bold]")
    
    results = applier.restore_backups(list(apps) if apps else None)
    
    # Display results
    restore_table = Table(show_header=True, header_style="bold magenta")
    restore_table.add_column("Application", style="cyan")
    restore_table.add_column("Status", style="white")
    
    for app_name, success in results.items():
        status = "✓ Restored" if success else "✗ Failed"
        status_style = "green" if success else "red"
        
        restore_table.add_row(
            app_name,
            f"[{status_style}]{status}[/{status_style}]"
        )
    
    console.print(restore_table)
    
    success_count = sum(1 for success in results.values() if success)
    console.print(f"\n[bold]Successfully restored {success_count}/{len(results)} applications[/bold]")


def main():
    """Main entry point for the CLI."""
    try:
        cli()
    except KeyboardInterrupt:
        console.print("\n[yellow]Operation cancelled by user[/yellow]")
        sys.exit(1)
    except Exception as e:
        console.print(f"\n[red]Unexpected error: {e}[/red]")
        sys.exit(1)


if __name__ == '__main__':
    main() 