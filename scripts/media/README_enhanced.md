# Enhanced Media Organizer

Enhanced version of the media organization script with improved subtitle matching, aggressive junk cleanup, and Emby permission fixing.

## 🚀 Features

### ✅ Fixed Issues
- **All SRT files processed** - Smart subtitle matching with 4 strategies
- **Aggressive junk cleanup** - Removes torrent files, small text files, and more  
- **Empty directory removal** - Multiple passes to clean nested directories
- **Preview mode** - See exactly what would happen before running

### 🔧 New Capabilities
- **Enhanced subtitle matching**: Exact match, substring match, prefix match (10+ chars)
- **Unmatched subtitle processing**: Tries both TV and Movie databases
- **Automatic Emby permissions**: Sets 644 for files, 755 for directories  
- **True dry run mode**: Zero filesystem changes in `--dry-run`
- **Comprehensive logging**: Debug mode shows all operations

## 📋 Usage

```fish
# Preview mode - Shows what would happen (safe)
./organize_media_enhanced.fish --preview

# Preview with debug info
./organize_media_enhanced.fish --preview --debug

# Dry run - FileBot tests, no filesystem changes
./organize_media_enhanced.fish --dry-run

# Dry run with debug logging
./organize_media_enhanced.fish --dry-run --debug

# Real execution
./organize_media_enhanced.fish

# Real execution with debug logging
./organize_media_enhanced.fish --debug
```

## 🔄 Workflow

1. **Junk File Cleanup** - Removes torrent files, small text files, URLs, etc.
2. **Empty Directory Cleanup** - Multiple passes to remove nested empty dirs
3. **Media Discovery** - Finds video (150MB+), audio, and subtitle files
4. **Staging** - Moves files to temporary `.staging` directory
5. **Classification** - Smart detection of TV shows vs movies vs music
6. **Subtitle Matching** - Advanced algorithms to pair subtitles with videos
7. **FileBot Processing** - Organizes files using online databases
8. **Permission Fixing** - Sets proper Emby-compatible permissions
9. **Final Cleanup** - Removes remaining junk and empty directories

## 🎯 Subtitle Matching Strategies

1. **Exact Match** - Normalized filename match (removes spaces, special chars)
2. **Video Contains Subtitle** - Video filename contains subtitle name (70%+ match)  
3. **Subtitle Contains Video** - Subtitle filename contains video name (70%+ match)
4. **Common Prefix** - Shared prefix of 10+ characters

## 🗑️ Junk File Patterns

**Extensions:** `.torrent`, `.nfo`, `.sfv`, `.txt`, `.url`, `.jpg`, `.png`, `.gif`, `.sample*`, `.rar`, `.zip`, `.par2`, `.db`, `.tmp`, `.log`, `.md5`, `.sha1`, `.crc`, `.htm`, `.html`

**Filenames:** `Thumbs.db`, `desktop.ini`, `.DS_Store`, `folder.jpg`, `poster.jpg`, etc.

**Small Files:** Text files under 10KB (likely junk)

## 🔒 Emby Permissions

- **Media Files**: 644 (readable by all, writable by owner)
- **Directories**: 755 (executable/traversable by all)
- **Supported Formats**: 
- **Video**: .mkv .mp4 .avi .mov .m4v .wmv .flv .webm .mpg .mpeg .ts .m2ts .mts
- **Audio**: .mp3 .flac .m4a .aac .ogg .wav
- **Subtitles**: .srt .sub .ass .ssa .vtt

## ⚙️ Configuration

- **Root Directory**: `/mnt/Media`
- **Staging Directory**: `/mnt/Media/.staging` 
- **Log File**: `~/filebot.log`
- **Size Threshold**: 150MB for video files
- **Max Depth**: 4 directory levels
- **Excluded Paths**: `Movies/`, `TV Shows/`, `.staging/`

## 🧪 Testing

The script has been tested with:
- ✅ Preview mode (no filesystem changes)
- ✅ Dry run mode (no filesystem changes) 
- ✅ Debug logging
- ✅ Permission fixing simulation
- ✅ Java temp directory fix (eliminates FileBot warnings)
- ✅ All mode combinations

Safe to use in production!

## 🔧 Java Warnings Fix

The script automatically creates a custom Java temp directory (`/tmp/filebot-$USER`) to eliminate FileBot's "java.io.tmpdir directory does not exist" warnings. This directory is automatically cleaned up after processing. 