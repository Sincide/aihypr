"""
File utility functions for AI Themer.
Provides file system operations, backup/restore, and directory management.
"""

import os
import shutil
import tempfile
from typing import Optional, List
from pathlib import Path


def ensure_dir(path: str) -> None:
    """
    Ensure that a directory exists, creating it if necessary.
    
    Args:
        path: Directory path to create
    """
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)


def backup_file(file_path: str, backup_path: Optional[str] = None) -> str:
    """
    Create a backup of a file.
    
    Args:
        file_path: Path to the file to backup
        backup_path: Optional custom backup path
        
    Returns:
        Path to the backup file
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")
    
    if backup_path is None:
        backup_path = f"{file_path}.backup"
    
    # Ensure backup directory exists
    ensure_dir(os.path.dirname(backup_path))
    
    # Copy file with metadata
    shutil.copy2(file_path, backup_path)
    
    return backup_path


def restore_file(backup_path: str, target_path: str) -> None:
    """
    Restore a file from its backup.
    
    Args:
        backup_path: Path to the backup file
        target_path: Path where the file should be restored
    """
    if not os.path.exists(backup_path):
        raise FileNotFoundError(f"Backup not found: {backup_path}")
    
    # Ensure target directory exists
    ensure_dir(os.path.dirname(target_path))
    
    # Copy backup to target location
    shutil.copy2(backup_path, target_path)


def safe_write_file(file_path: str, content: str, backup: bool = True) -> None:
    """
    Safely write content to a file with optional backup.
    
    Args:
        file_path: Path to the file to write
        content: Content to write
        backup: Whether to create a backup before writing
    """
    # Create backup if requested and file exists
    if backup and os.path.exists(file_path):
        backup_file(file_path)
    
    # Ensure directory exists
    ensure_dir(os.path.dirname(file_path))
    
    # Write content atomically using temporary file
    temp_path = f"{file_path}.tmp"
    
    try:
        with open(temp_path, 'w') as f:
            f.write(content)
        
        # Atomic move
        shutil.move(temp_path, file_path)
        
    except Exception:
        # Clean up temp file on error
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise


def find_files(directory: str, pattern: str, recursive: bool = True) -> List[str]:
    """
    Find files matching a pattern in a directory.
    
    Args:
        directory: Directory to search in
        pattern: File pattern to match (supports glob patterns)
        recursive: Whether to search recursively
        
    Returns:
        List of matching file paths
    """
    import glob
    
    if not os.path.exists(directory):
        return []
    
    if recursive:
        search_pattern = os.path.join(directory, "**", pattern)
        return glob.glob(search_pattern, recursive=True)
    else:
        search_pattern = os.path.join(directory, pattern)
        return glob.glob(search_pattern)


def get_file_size(file_path: str) -> int:
    """
    Get the size of a file in bytes.
    
    Args:
        file_path: Path to the file
        
    Returns:
        File size in bytes
    """
    if not os.path.exists(file_path):
        return 0
    
    return os.path.getsize(file_path)


def is_writable(path: str) -> bool:
    """
    Check if a path is writable.
    
    Args:
        path: Path to check
        
    Returns:
        True if writable, False otherwise
    """
    if os.path.exists(path):
        return os.access(path, os.W_OK)
    else:
        # Check if we can create the file
        directory = os.path.dirname(path)
        return os.access(directory, os.W_OK) if os.path.exists(directory) else False


def create_temp_file(suffix: str = "", prefix: str = "ai-themer-") -> str:
    """
    Create a temporary file and return its path.
    
    Args:
        suffix: File suffix
        prefix: File prefix
        
    Returns:
        Path to the temporary file
    """
    fd, temp_path = tempfile.mkstemp(suffix=suffix, prefix=prefix)
    os.close(fd)  # Close the file descriptor
    return temp_path


def cleanup_temp_files(temp_dir: Optional[str] = None) -> None:
    """
    Clean up temporary files created by AI Themer.
    
    Args:
        temp_dir: Specific temp directory to clean (None = system temp)
    """
    if temp_dir is None:
        temp_dir = tempfile.gettempdir()
    
    if not os.path.exists(temp_dir):
        return
    
    # Find and remove AI Themer temp files
    for filename in os.listdir(temp_dir):
        if filename.startswith("ai-themer-"):
            temp_path = os.path.join(temp_dir, filename)
            try:
                if os.path.isfile(temp_path):
                    os.remove(temp_path)
                elif os.path.isdir(temp_path):
                    shutil.rmtree(temp_path)
            except Exception:
                pass  # Ignore errors during cleanup 