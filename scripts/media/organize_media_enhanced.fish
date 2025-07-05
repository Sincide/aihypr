#!/usr/bin/env fish

set dryrun 0
set debug 0
set preview 0

# Parse command line arguments
for arg in $argv
    switch $arg
        case "--dry-run"
            set dryrun 1
        case "--debug"
            set debug 1
        case "--preview"
            set preview 1
            set dryrun 1  # Preview implies dry run
        case "*"
            echo "❌ Unknown argument: $arg"
            echo "Usage: $argv[0] [--dry-run] [--debug] [--preview]"
            exit 1
    end
end

set root_dir "/mnt/Media"
set tmp_dir "$root_dir/.staging"
set logfile "$HOME/filebot.log"

function log
    echo (date "+%F %T")" – $argv" >> $logfile
end

function notify
    echo "💬 $argv"
    log "$argv"
end

function debug_log
    if test $debug -eq 1
        echo "🔍 DEBUG: $argv"
        log "DEBUG: $argv"
    end
end

function preview_log
    if test $preview -eq 1
        echo "👁️  PREVIEW: $argv"
        log "PREVIEW: $argv"
    end
end

function debug_section
    if test $debug -eq 1
        echo ""
        echo "🔍 === DEBUG SECTION: $argv ==="
        log "DEBUG SECTION: $argv"
    end
end

function preview_section
    if test $preview -eq 1
        echo ""
        echo "👁️  === PREVIEW: $argv ==="
        log "PREVIEW SECTION: $argv"
    end
end

# Show mode info at start
if test $preview -eq 1
    echo "👁️  PREVIEW MODE - No files will be moved or deleted"
    echo "👁️  This will show you exactly what would happen"
    echo ""
else if test $dryrun -eq 1
    echo "🧪 DRY RUN MODE - FileBot will test but not move files"
    echo ""
end

if test $debug -eq 1
    echo "🔍 DEBUG MODE ENABLED"
    echo "🔍 Root directory: $root_dir"
    echo "🔍 Staging directory: $tmp_dir"
    echo "🔍 Log file: $logfile"
    echo "🔍 Dry run: $dryrun"
    echo "🔍 Preview: $preview"
    echo ""
end

# Enhanced junk file patterns - more aggressive cleanup
set junk_extensions "*.nfo" "*.sfv" "*.txt" "*.url" "*.jpg" "*.jpeg" "*.png" "*.gif" "*.bmp" "*.sample*" "*.rar" "*.zip" "*.par2" "*.torrent" "*.db" "*.tmp" "*.log" "*.diz" "*.1st" "*.md5" "*.sha1" "*.crc" "*.idx" "*.sub" "*.htm" "*.html"

set junk_filenames "Thumbs.db" "desktop.ini" ".DS_Store" "folder.jpg" "poster.jpg" "fanart.jpg" "banner.jpg" "clearart.png" "disc.png" "logo.png"

# Ensure critical libs for FileBot
set missing_libs ""
if not test -e /usr/lib/libmediainfo.so -o -e /usr/lib64/libmediainfo.so -o -e /usr/lib/x86_64-linux-gnu/libmediainfo.so
    set missing_libs "$missing_libs libmediainfo"
end
if not command -v filebot >/dev/null
    echo "❌ FileBot not found in PATH"
    exit 1
end
if not test -e /usr/lib/libzen.so -o -e /usr/lib64/libzen.so -o -e /usr/lib/x86_64-linux-gnu/libzen.so
    set missing_libs "$missing_libs libzen"
end
if test -n "$missing_libs"
    echo "⚠️  Missing:$missing_libs. FileBot might fail. Run: yay -S$missing_libs"
end

debug_log "Dependency check completed. Missing libs: $missing_libs"

# Init
log "Enhanced media organization starting..."
if test $preview -eq 0; and test $dryrun -eq 0
    mkdir -p $tmp_dir
    debug_log "Created staging directory: $tmp_dir"
else
    debug_log "Skipping staging directory creation (preview=$preview, dryrun=$dryrun)"
end

# Enhanced junk file cleanup function
function cleanup_junk_files
    set junk_count 0
    
    preview_section "JUNK FILE CLEANUP"
    
    # Find junk files by extension
    debug_log "Searching for junk files by extension..."
    for pattern in $junk_extensions
        set found_files (find $root_dir -mindepth 1 -maxdepth 4 -iname "$pattern" \
            -not -path "$root_dir/Movies/*" -not -path "$root_dir/TV Shows/*" -not -path "$tmp_dir/*" 2>/dev/null)
        
        for junk in $found_files
            if test $preview -eq 1; or test $dryrun -eq 1
                if test $preview -eq 1
                    preview_log "Would delete junk file: $junk"
                else
                    debug_log "DRY RUN: Would delete junk file: $junk"
                end
            else
                debug_log "Deleting junk file: $junk"
                rm -f "$junk"
            end
            set junk_count (math "$junk_count + 1")
        end
    end
    
    # Find junk files by exact filename
    debug_log "Searching for junk files by filename..."
    for filename in $junk_filenames
        set found_files (find $root_dir -mindepth 1 -maxdepth 4 -name "$filename" \
            -not -path "$root_dir/Movies/*" -not -path "$root_dir/TV Shows/*" -not -path "$tmp_dir/*" 2>/dev/null)
        
        for junk in $found_files
            if test $preview -eq 1; or test $dryrun -eq 1
                if test $preview -eq 1
                    preview_log "Would delete junk file: $junk"
                else
                    debug_log "DRY RUN: Would delete junk file: $junk"
                end
            else
                debug_log "Deleting junk file: $junk"
                rm -f "$junk"
            end
            set junk_count (math "$junk_count + 1")
        end
    end
    
    # Find small text files that are likely junk (under 10KB)
    debug_log "Searching for small text files (likely junk)..."
    set small_text_files (find $root_dir -mindepth 1 -maxdepth 4 \
        \( -iname "*.txt" -o -iname "*.nfo" -o -iname "*.diz" \) \
        -size -10k \
        -not -path "$root_dir/Movies/*" -not -path "$root_dir/TV Shows/*" -not -path "$tmp_dir/*" 2>/dev/null)
    
    for small_file in $small_text_files
        if test $preview -eq 1; or test $dryrun -eq 1
            if test $preview -eq 1
                preview_log "Would delete small text file: $small_file"
            else
                debug_log "DRY RUN: Would delete small text file: $small_file"
            end
        else
            debug_log "Deleting small text file: $small_file"
            rm -f "$small_file"
        end
        set junk_count (math "$junk_count + 1")
    end
    
    notify "🗑️  Found $junk_count junk files"
    return $junk_count
end

# Enhanced directory cleanup function  
function cleanup_empty_directories
    set dir_count 0
    
    preview_section "DIRECTORY CLEANUP"
    
    # Multiple passes to handle nested empty directories
    for pass in (seq 1 5)
        debug_log "Directory cleanup pass $pass"
        
        set empty_dirs (find $root_dir -mindepth 1 -maxdepth 4 -type d -empty \
            -not -path "$root_dir/Movies" -not -path "$root_dir/TV Shows" -not -path "$tmp_dir" 2>/dev/null)
        
        if test (count $empty_dirs) -eq 0
            debug_log "No more empty directories found in pass $pass"
            break
        end
        
        for empty_dir in $empty_dirs
            if test $preview -eq 1; or test $dryrun -eq 1
                if test $preview -eq 1
                    preview_log "Would delete empty directory: $empty_dir"
                else
                    debug_log "DRY RUN: Would delete empty directory: $empty_dir"
                end
            else
                debug_log "Deleting empty directory: $empty_dir"
                rmdir "$empty_dir" 2>/dev/null
            end
            set dir_count (math "$dir_count + 1")
        end
    end
    
    notify "📁 Found $dir_count empty directories"
    return $dir_count
end

# Enhanced subtitle matching function
function match_subtitles_to_video
    set video_file "$argv[1]"
    set all_subtitles $argv[2..-1]
    
    set video_basename (basename "$video_file")
    set video_name_clean (string replace -r '\.[^.]*$' '' "$video_basename")
    set video_name_normalized (string lower (string replace -ra '[^a-z0-9]+' '' "$video_name_clean"))
    
    set matched_subtitles
    
    debug_log "Matching subtitles for: $video_basename"
    debug_log "  Normalized video name: $video_name_normalized"
    
    for subtitle in $all_subtitles
        set sub_basename (basename "$subtitle")
        set sub_name_clean (string replace -r '\.[^.]*$' '' "$sub_basename")
        set sub_name_normalized (string lower (string replace -ra '[^a-z0-9]+' '' "$sub_name_clean"))
        
        # Multiple matching strategies
        set matched 0
        
        # Strategy 1: Exact normalized match
        if test "$video_name_normalized" = "$sub_name_normalized"
            set matched 1
            debug_log "  ✅ Exact match: $sub_basename"
        end
        
        # Strategy 2: Video name contains subtitle name (>=70% of subtitle name)
        set sub_len (string length "$sub_name_normalized")
        if test $sub_len -gt 5; and test $matched -eq 0
            if string match -q "*$sub_name_normalized*" "$video_name_normalized"
                set matched 1
                debug_log "  ✅ Video contains subtitle name: $sub_basename"
            end
        end
        
        # Strategy 3: Subtitle name contains video name (>=70% of video name)  
        set video_len (string length "$video_name_normalized")
        if test $video_len -gt 5; and test $matched -eq 0
            if string match -q "*$video_name_normalized*" "$sub_name_normalized"
                set matched 1  
                debug_log "  ✅ Subtitle contains video name: $sub_basename"
            end
        end
        
        # Strategy 4: Common prefix (at least 10 characters)
        if test $matched -eq 0
            set common_len 0
            set min_len (math "min($video_len, $sub_len)")
            
            for i in (seq 1 $min_len)
                if test (string sub -s $i -l 1 "$video_name_normalized") = (string sub -s $i -l 1 "$sub_name_normalized")
                    set common_len $i
                else
                    break
                end
            end
            
            if test $common_len -ge 10
                set matched 1
                debug_log "  ✅ Common prefix ($common_len chars): $sub_basename"
            end
        end
        
        if test $matched -eq 1
            set matched_subtitles $matched_subtitles "$subtitle"
        else
            debug_log "  ❌ No match: $sub_basename"
        end
    end
    
    echo $matched_subtitles
end

# Run initial junk cleanup
cleanup_junk_files
set junk_files_found $status

# Run directory cleanup after junk removal
cleanup_empty_directories  
set empty_dirs_found $status

# Find and move new media files (min size 150MB) and subtitle files (any size)
debug_section "SEARCHING FOR MEDIA FILES"
set moved 0
set found_files

preview_section "MEDIA FILE DISCOVERY"

debug_log "Searching for media files in: $root_dir (maxdepth 4)"
debug_log "Excluding paths: Movies/*, TV Shows/*, $tmp_dir/*"

# Find large media files (150MB+)
for f in (find $root_dir -mindepth 1 -maxdepth 4 \
    \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" \
     -o -iname "*.m4v" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" \
     -o -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.ts" -o -iname "*.m2ts" \
     -o -iname "*.mts" -o -iname "*.flac" -o -iname "*.mp3" \) \
    -size +150M -not -path "$root_dir/Movies/*" -not -path "$root_dir/TV Shows/*" -not -path "$tmp_dir/*" 2>/dev/null)
    
    set found_files $found_files "$f"
    debug_log "Found large media file: $f"
    if test $preview -eq 1
        preview_log "Would move to staging: "(basename "$f")
    end
end

# Find subtitle files (any size) - more flexible search
for f in (find $root_dir -mindepth 1 -maxdepth 4 \
    \( -iname "*.srt" -o -iname "*.sub" -o -iname "*.ass" -o -iname "*.ssa" -o -iname "*.vtt" \) \
    -not -path "$root_dir/Movies/*" -not -path "$root_dir/TV Shows/*" -not -path "$tmp_dir/*" 2>/dev/null)
    
    set found_files $found_files "$f"
    debug_log "Found subtitle file: $f"
    if test $preview -eq 1
        preview_log "Would move to staging: "(basename "$f")
    end
end

debug_log "Total files found: "(count $found_files)

if test $preview -eq 1; or test $dryrun -eq 1
    if test $preview -eq 1
        preview_section "STAGING OPERATIONS"
        for f in $found_files
            preview_log "Would move: $f -> $tmp_dir/"(basename "$f")
        end
    else
        debug_log "DRY RUN: Would move files to staging directory:"
        for f in $found_files
            debug_log "  DRY RUN: Would move: $f -> $tmp_dir/"(basename "$f")
        end
    end
else
    for f in $found_files
        debug_log "Moving: $f -> $tmp_dir"
        if mv -vn "$f" "$tmp_dir"
            set moved 1
            debug_log "✅ Successfully moved: $f"
        else
            debug_log "❌ Failed to move: $f"
        end
    end
end

if test (count $found_files) -eq 0
    notify "No new media files found. Nothing to process."
    debug_log "No files found, exiting"
    exit 0
end

if test $preview -eq 1; or test $dryrun -eq 1
    set moved 1  # Pretend we moved files for preview/dry run
end

debug_section "ANALYZING STAGING FILES"

# For preview and dry run mode, simulate staging files
if test $preview -eq 1; or test $dryrun -eq 1
    set staging_files $found_files
else
    set staging_files (find "$tmp_dir" -type f 2>/dev/null)
end

debug_log "Files in staging directory:"
for f in $staging_files
    debug_log "  - "(basename "$f")
end

# Enhanced file classification with better subtitle matching
set tv_files
set movie_files  
set audio_files
set all_subtitle_files

preview_section "FILE CLASSIFICATION"

# Collect all subtitle files first
for f in $staging_files
    if string match -rq '(?i)\.(srt|sub|ass|ssa|vtt)$' "$f"
        set all_subtitle_files $all_subtitle_files "$f"
        debug_log "Found subtitle file: "(basename "$f")
        if test $preview -eq 1
            preview_log "Subtitle file to process: "(basename "$f")
        end
    end
end

debug_log "Total subtitle files found: "(count $all_subtitle_files)

# Process video files and match subtitles
for f in $staging_files
    if string match -rq '(?i)\.(mkv|mp4|avi|mov|m4v|wmv|flv|webm|mpg|mpeg|ts|m2ts|mts)$' "$f"
        set filename (basename "$f")
        debug_log "Analyzing video file: $filename"
        
        # Enhanced TV show detection patterns
        if string match -rq '(?i).*(s\d{1,2}e\d{1,2}|\d{1,2}x\d{1,2}|season[.\s_-]?\d+|episode[.\s_-]?\d+|\.s\d{2}\.|\.e\d{2}\.)' "$filename"
            set tv_files $tv_files "$f"
            debug_log "  → Classified as TV SHOW: $filename"
            if test $preview -eq 1
                preview_log "TV Show: $filename"
            end
            
            # Find matching subtitles using enhanced matching
            set matched_subs (match_subtitles_to_video "$f" $all_subtitle_files)
            for sub in $matched_subs
                set tv_files $tv_files "$sub"
                debug_log "  → Matched subtitle: "(basename "$sub")
                if test $preview -eq 1
                    preview_log "  + Subtitle: "(basename "$sub")
                end
            end
        else
            set movie_files $movie_files "$f"
            debug_log "  → Classified as MOVIE: $filename"
            if test $preview -eq 1
                preview_log "Movie: $filename"
            end
            
            # Find matching subtitles using enhanced matching
            set matched_subs (match_subtitles_to_video "$f" $all_subtitle_files)
            for sub in $matched_subs
                set movie_files $movie_files "$sub"
                debug_log "  → Matched subtitle: "(basename "$sub")
                if test $preview -eq 1
                    preview_log "  + Subtitle: "(basename "$sub")
                end
            end
        end
    end
end

# Audio files (music)
for f in $staging_files
    if string match -rq '(?i)\.(flac|mp3|m4a|aac|ogg|wav)$' "$f"
        set audio_files $audio_files "$f"
        debug_log "Found audio file: "(basename "$f")
        if test $preview -eq 1
            preview_log "Audio file: "(basename "$f")
        end
    end
end

# Find unmatched subtitle files
set unmatched_subtitles
for sub in $all_subtitle_files
    set is_matched 0
    for matched in $tv_files $movie_files
        if test "$sub" = "$matched"
            set is_matched 1
            break
        end
    end
    if test $is_matched -eq 0
        set unmatched_subtitles $unmatched_subtitles "$sub"
    end
end

debug_log "Classification complete:"
debug_log "  TV Shows (including subtitles): "(count $tv_files)
debug_log "  Movies (including subtitles): "(count $movie_files)  
debug_log "  Audio: "(count $audio_files)
debug_log "  Unmatched subtitles: "(count $unmatched_subtitles)

if test $preview -eq 1
    preview_section "FILEBOT OPERATIONS"
    if test (count $unmatched_subtitles) -gt 0
        echo "👁️  Unmatched subtitles that will be processed separately:"
        for sub in $unmatched_subtitles
            preview_log "  Orphaned subtitle: "(basename "$sub")
        end
    end
    
    # Show what FileBot commands would be run
    if test (count $tv_files) -gt 0
        preview_log "Would run FileBot for TV Shows with "(count $tv_files)" files"
        preview_log "  Command: filebot -rename TV_FILES --db TheTVDB --format 'TV Shows/{n}/Season {s}/{n} - {s00e00} - {t}'"
    end
    
    if test (count $movie_files) -gt 0
        preview_log "Would run FileBot for Movies with "(count $movie_files)" files"
        preview_log "  Command: filebot -rename MOVIE_FILES --db TheMovieDB --format 'Movies/{n} ({y})/{n} ({y})'"
    end
    
    if test (count $audio_files) -gt 0
        preview_log "Would run FileBot for Audio with "(count $audio_files)" files"
        preview_log "  Command: filebot -rename AUDIO_FILES --db AudioDB --format 'Music/{artist}/{album}/{artist} - {t}'"
    end
    
    if test (count $unmatched_subtitles) -gt 0
        preview_log "Would process unmatched subtitles with FileBot"
    end
    
    preview_section "PERMISSION FIXING"
    preview_log "Would fix Emby permissions (644 for files, 755 for directories)"
    
    preview_section "FINAL CLEANUP"
    preview_log "Would run final junk cleanup after FileBot processing"
    preview_log "Would remove empty directories"
    preview_log "Would clean up staging directory if empty"
    
    echo ""
    echo "👁️  === PREVIEW COMPLETE ==="
    echo "👁️  Run without --preview to execute these operations"
    echo "👁️  Add --debug for detailed logging during execution"
    echo ""
    exit 0
end

# Set action based on dry run
if test $dryrun -eq 1
    set action "test"
    debug_log "Using FileBot action: test (dry run)"
else
    set action "move"
    debug_log "Using FileBot action: move"
end

# Fix Java temp directory issues
set java_tmpdir "/tmp/filebot-$USER"
if not test -d "$java_tmpdir"
    mkdir -p "$java_tmpdir" 2>/dev/null
    debug_log "Created Java temp directory: $java_tmpdir"
end

# Process TV Shows with enhanced subtitle handling
if test (count $tv_files) -gt 0
    debug_section "PROCESSING TV SHOWS"
    notify "📺 Processing "(count $tv_files)" TV Show files..."
    
    debug_log "FileBot command for TV shows:"
    debug_log "  filebot -rename TV_FILES --output $root_dir --action $action --db TheTVDB --format 'TV Shows/{n}/Season {s}/{n} - {s00e00} - {t}'"
    
    env JAVA_OPTS="-Djava.io.tmpdir=$java_tmpdir" filebot -rename $tv_files \
        --output "$root_dir" \
        --action $action \
        --conflict auto \
        --db TheTVDB \
        --format "TV Shows/{n}/Season {s}/{n} - {s00e00} - {t}" \
        --log-file "$logfile" \
        --apply prune
    
    set tv_status $status
    debug_log "FileBot TV shows exit status: $tv_status"
    
    if test $tv_status -eq 0
        notify "✅ TV Shows processed successfully"
    else
        notify "⚠️  TV Shows processing had issues (status: $tv_status)"
    end
end

# Process Movies with enhanced subtitle handling
if test (count $movie_files) -gt 0
    debug_section "PROCESSING MOVIES"
    notify "🎬 Processing "(count $movie_files)" Movie files..."
    
    debug_log "FileBot command for movies:"
    debug_log "  filebot -rename MOVIE_FILES --output $root_dir --action $action --db TheMovieDB --format 'Movies/{n} ({y})/{n} ({y})'"
    
    env JAVA_OPTS="-Djava.io.tmpdir=$java_tmpdir" filebot -rename $movie_files \
        --output "$root_dir" \
        --action $action \
        --conflict auto \
        --db TheMovieDB \
        --format "Movies/{n} ({y})/{n} ({y})" \
        --log-file "$logfile" \
        --apply prune
    
    set movie_status $status
    debug_log "FileBot movies exit status: $movie_status"
    
    if test $movie_status -eq 0
        notify "✅ Movies processed successfully"
    else
        notify "⚠️  Movies processing had issues (status: $movie_status)"
    end
end

# Process Audio Files
if test (count $audio_files) -gt 0
    debug_section "PROCESSING AUDIO FILES"
    notify "🎵 Processing "(count $audio_files)" Audio files..."
    
    debug_log "FileBot command for audio:"
    debug_log "  filebot -rename AUDIO_FILES --output $root_dir --action $action --db AudioDB --format 'Music/{artist}/{album}/{artist} - {t}'"
    
    env JAVA_OPTS="-Djava.io.tmpdir=$java_tmpdir" filebot -rename $audio_files \
        --output "$root_dir" \
        --action $action \
        --conflict auto \
        --db AudioDB \
        --format "Music/{artist}/{album}/{artist} - {t}" \
        --log-file "$logfile" \
        --apply prune
    
    set audio_status $status
    debug_log "FileBot audio exit status: $audio_status"
    
    if test $audio_status -eq 0
        notify "✅ Audio files processed successfully"
    else
        notify "⚠️  Audio processing had issues (status: $audio_status)"
    end
end

# Process unmatched subtitle files - try both TV and Movie databases
if test (count $unmatched_subtitles) -gt 0
    debug_section "PROCESSING UNMATCHED SUBTITLES"
    notify "📝 Processing "(count $unmatched_subtitles)" unmatched subtitle files..."
    
    debug_log "Unmatched subtitles:"
    for sub in $unmatched_subtitles
        debug_log "  - "(basename "$sub")
    end
    
    # Try TV database first
    debug_log "Trying TV database for unmatched subtitles"
    env JAVA_OPTS="-Djava.io.tmpdir=$java_tmpdir" filebot -rename $unmatched_subtitles \
        --output "$root_dir" \
        --action $action \
        --conflict skip \
        --db TheTVDB \
        --format "TV Shows/{n}/Season {s}/{n} - {s00e00} - {t}" \
        --log-file "$logfile" \
        --apply prune
    
    set subtitle_tv_status $status
    debug_log "FileBot unmatched subtitles (TV) exit status: $subtitle_tv_status"
    
    # Check if any subtitles remain and try movie database
    if not test $action = "test"
        set remaining_subs (find "$tmp_dir" -name "*.srt" -o -name "*.sub" -o -name "*.ass" -o -name "*.ssa" -o -name "*.vtt" 2>/dev/null)
    else
        set remaining_subs $unmatched_subtitles  # In test mode, simulate remaining
    end
    
    if test (count $remaining_subs) -gt 0
        debug_log "Trying movie database for remaining subtitles"
        env JAVA_OPTS="-Djava.io.tmpdir=$java_tmpdir" filebot -rename $remaining_subs \
            --output "$root_dir" \
            --action $action \
            --conflict skip \
            --db TheMovieDB \
            --format "Movies/{n} ({y})/{n} ({y})" \
            --log-file "$logfile" \
            --apply prune
        
        set subtitle_movie_status $status
        debug_log "FileBot unmatched subtitles (Movie) exit status: $subtitle_movie_status"
    end
    
    notify "✅ Unmatched subtitles processed"
end

# Fix permissions for Emby compatibility
debug_section "FIXING PERMISSIONS"
notify "🔒 Fixing permissions for Emby compatibility..."

function fix_media_permissions
    if test $preview -eq 1; or test $dryrun -eq 1
        if test $preview -eq 1
            preview_log "Would fix permissions for media files in $root_dir"
        else
            debug_log "DRY RUN: Would fix permissions for media files in $root_dir"
        end
        return 0
    end
    
    debug_log "Setting 644 permissions for media files..."
    set media_files_fixed (find "$root_dir" -type f \( \
        -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o \
        -name "*.wmv" -o -name "*.flv" -o -name "*.webm" -o -name "*.m4v" -o \
        -name "*.mpg" -o -name "*.mpeg" -o -name "*.ts" -o -name "*.m2ts" -o \
        -name "*.mts" -o -name "*.srt" -o -name "*.sub" -o -name "*.ass" -o \
        -name "*.ssa" -o -name "*.vtt" -o -name "*.mp3" -o -name "*.flac" -o \
        -name "*.m4a" -o -name "*.aac" -o -name "*.ogg" -o -name "*.wav" \
    \) -exec chmod 644 {} \; -print | wc -l)
    
    debug_log "Setting 755 permissions for directories..."
    set dirs_fixed (find "$root_dir" -type d -exec chmod 755 {} \; -print | wc -l)
    
    notify "✅ Fixed permissions: $media_files_fixed files, $dirs_fixed directories"
    debug_log "Media permissions fixed: $media_files_fixed files, $dirs_fixed directories"
end

fix_media_permissions

# Final cleanup - run junk cleanup again after FileBot processing
debug_section "FINAL CLEANUP"
notify "🧹 Running final cleanup..."

cleanup_junk_files
cleanup_empty_directories

# Cleanup staging directory
if test $dryrun -eq 1
    debug_log "DRY RUN: Would check for staging directory cleanup"
    if test -d "$tmp_dir"
        debug_log "DRY RUN: Staging directory exists, would remove it if empty"
    else
        debug_log "DRY RUN: No staging directory to clean up"
    end
else if test -d "$tmp_dir"
    set remaining_files (find "$tmp_dir" -mindepth 1 2>/dev/null)
    debug_log "Files remaining in staging: "(count $remaining_files)
    
    if test (count $remaining_files) -eq 0
        log "Cleaning up empty staging dir..."
        debug_log "Staging directory is empty, removing it"
        rm -rf "$tmp_dir"
        notify "✅ Staging directory cleaned"
        debug_log "Staging directory removed successfully"
    else
        notify "⚠️  Staging not empty – left untouched: $tmp_dir"
        debug_log "Staging directory not empty, leaving it untouched"
        for f in $remaining_files
            debug_log "  Remaining file: "(basename "$f")
        end
    end
else
    notify "✅ Staging directory already cleaned up"
    debug_log "Staging directory doesn't exist (already cleaned)"
end

debug_section "SCRIPT COMPLETION"

# Cleanup Java temp directory
if test -d "$java_tmpdir"; and test $dryrun -eq 0
    debug_log "Cleaning up Java temp directory: $java_tmpdir"
    rm -rf "$java_tmpdir" 2>/dev/null
end

notify "✅ Enhanced media organization complete!"
debug_log "Enhanced script execution completed" 