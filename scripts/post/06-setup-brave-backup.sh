#!/bin/bash

# Brave Backup System Setup Script
# Author: Martin's Dotfiles - Modular Version
# Description: Setup intelligent Brave browser backup and restore system

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly LOG_DIR="${DOTFILES_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/brave-backup_$(date +%Y%m%d_%H%M%S).log"
readonly BRAVE_CONFIG_DIR="$HOME/.config/BraveSoftware/Brave-Browser"
readonly DEFAULT_BACKUP_BASE_DIR="/mnt/Stuff/brave-backups"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Flags
SKIP_CONFIRMATION=false
SKIP_AUTO_BACKUP=false
SKIP_RESTORE_SCAN=false
DRY_RUN=false
FORCE_RESTORE=false
BACKUP_BASE_DIR="$DEFAULT_BACKUP_BASE_DIR"

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    echo "Starting Brave backup system setup - $(date)" >> "$LOG_FILE"
    echo "[LOG] Script: $SCRIPT_NAME" >> "$LOG_FILE"
}

# Logging functions
log_info() {
    local msg="[INFO] ${1:-}"
    echo -e "${BLUE}$msg${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[SUCCESS] ${1:-}"
    echo -e "${GREEN}✓ $msg${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[ERROR] ${1:-}"
    echo -e "${RED}✗ $msg${NC}" >&2
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_warning() {
    local msg="[WARNING] ${1:-}"
    echo -e "${YELLOW}⚠ $msg${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_section() {
    local msg="${1:-}"
    echo -e "${CYAN}=== $msg ===${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [SECTION] $msg" >> "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as regular user
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run as root"
        exit 1
    fi
    
    # Check required tools
    local required_tools=("rsync" "tar" "gzip")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Check and select backup directory
check_backup_directory() {
    log_info "Checking backup directory permissions..."
    
    # Test if we can write to the backup directory
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        if [[ -w "$BACKUP_BASE_DIR" ]]; then
            log_success "Backup directory is writable: $BACKUP_BASE_DIR"
            return 0
        else
            log_warning "Backup directory exists but is not writable: $BACKUP_BASE_DIR"
        fi
    else
        # Try to create the directory
        if mkdir -p "$BACKUP_BASE_DIR" 2>/dev/null; then
            log_success "Created backup directory: $BACKUP_BASE_DIR"
            return 0
        else
            log_warning "Cannot create backup directory: $BACKUP_BASE_DIR"
        fi
    fi
    
    # If we get here, the default directory is not usable
    if [[ "$SKIP_CONFIRMATION" == "true" ]]; then
        log_error "Default backup directory not accessible and running in non-interactive mode"
        exit 1
    fi
    
    # Try to create the directory with sudo if user is in wheel group
    if groups | grep -q wheel; then
        log_info "Attempting to create backup directory with sudo..."
        if sudo mkdir -p "$BACKUP_BASE_DIR" 2>/dev/null; then
            # Set ownership to current user
            sudo chown "$USER:$USER" "$BACKUP_BASE_DIR" 2>/dev/null || true
            log_success "Created backup directory with sudo: $BACKUP_BASE_DIR"
            return 0
        else
            log_warning "Failed to create backup directory with sudo"
        fi
    fi
    
    # Offer alternative locations
    log_info "Please select an alternative backup location:"
    echo
    echo "Available options:"
    echo "  1. ~/brave-backups (home directory)"
    echo "  2. ~/Documents/brave-backups"
    echo "  3. ~/Downloads/brave-backups"
    echo "  4. Custom location"
    echo "  5. Skip backup creation"
    echo
    
    local choice
    read -p "Enter choice (1-5): " -r choice
    
    case $choice in
        1)
            BACKUP_BASE_DIR="$HOME/brave-backups"
            ;;
        2)
            BACKUP_BASE_DIR="$HOME/Documents/brave-backups"
            ;;
        3)
            BACKUP_BASE_DIR="$HOME/Downloads/brave-backups"
            ;;
        4)
            read -p "Enter custom backup directory path: " -r custom_path
            if [[ -n "$custom_path" ]]; then
                BACKUP_BASE_DIR="$custom_path"
            else
                log_error "No path provided"
                exit 1
            fi
            ;;
        5)
            log_info "Skipping backup creation"
            SKIP_AUTO_BACKUP=true
            return 0
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Try to create the selected directory
    if mkdir -p "$BACKUP_BASE_DIR" 2>/dev/null; then
        log_success "Using backup directory: $BACKUP_BASE_DIR"
    else
        log_error "Cannot create backup directory: $BACKUP_BASE_DIR"
        exit 1
    fi
}

# Check if Brave is installed and has configuration
check_brave_status() {
    log_section "Checking Brave Browser Status"
    
    # Check if Brave is installed
    if ! command -v brave &>/dev/null; then
        log_warning "Brave browser is not installed"
        return 1
    fi
    log_success "Brave browser is installed"
    
    # Check if Brave has been run (config directory exists)
    if [[ ! -d "$BRAVE_CONFIG_DIR" ]]; then
        log_info "Brave has not been run yet (no config directory)"
        return 2
    fi
    log_success "Brave configuration directory exists"
    
    # Check if Brave has user data
    local user_data_size
    user_data_size=$(du -sm "$BRAVE_CONFIG_DIR" 2>/dev/null | cut -f1)
    if [[ $user_data_size -lt 5 ]]; then
        log_info "Brave configuration is minimal (${user_data_size}MB)"
        return 3
    fi
    
    log_success "Brave has substantial user data (${user_data_size}MB)"
    return 0
}

# Find backup files (only .tar.gz in backup directory)
find_backup_locations() {
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        return 1
    fi
    
    local backup_files=()
    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" && -f "$backup_file" ]]; then
            backup_files+=("$backup_file")
        fi
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type f -name "*.tar.gz" 2>/dev/null | sort -r)
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        return 1
    fi
    
    printf '%s\n' "${backup_files[@]}"
}

# Display backup files
display_backup_locations() {
    local backups=("$@")
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log_info "No Brave backup files found" >&2
        return 1
    fi
    
    log_section "Found ${#backups[@]} Backup File(s)" >&2
    echo >&2
    
    for backup_file in "${backups[@]}"; do
        local file_size
        file_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
        local file_name
        file_name=$(basename "$backup_file")
        
        echo -e "  💾 ${GREEN}$file_name${NC}" >&2
        echo -e "     ${BLUE}Size:${NC} $file_size" >&2
        echo -e "     ${BLUE}Path:${NC} $backup_file" >&2
        echo >&2
    done
}

# Interactive backup selection with fzf
select_backup_with_fzf() {
    local backups=("$@")
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        return 1
    fi
    
    # Check if fzf is available
    if ! command -v fzf &>/dev/null; then
        log_warning "fzf not found, falling back to manual selection"
        return 1
    fi
    
    echo "[INFO] Use arrow keys to select a backup, Enter to confirm, Esc to cancel" >&2
    
    # Create formatted list for fzf
    local fzf_options=()
    for backup_file in "${backups[@]}"; do
        local file_size
        file_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
        local file_name
        file_name=$(basename "$backup_file")
        local file_date
        file_date=$(date -r "$backup_file" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        
        fzf_options+=("$backup_file|$file_name ($file_size) - $file_date")
    done
    
    # Use fzf for selection
    local selected
    selected=$(printf '%s\n' "${fzf_options[@]}" | \
               fzf --height=40% \
                   --border \
                   --header="Select Brave backup to restore:" \
                   --preview='echo "Path: {1}" | cut -d"|" -f1' \
                   --preview-window=down:2 \
                   --delimiter="|" \
                   --with-nth=2)
    
    if [[ -n "$selected" ]]; then
        # Extract the file path from selection
        echo "$selected" | cut -d"|" -f1
        return 0
    else
        return 1
    fi
}

# Create backup of current Brave configuration
create_brave_backup() {
    if [[ "$SKIP_AUTO_BACKUP" == "true" ]]; then
        log_info "Skipping automatic backup creation"
        return 0
    fi
    
    log_section "Creating Brave Configuration Backup"
    
    if [[ ! -d "$BRAVE_CONFIG_DIR" ]]; then
        log_warning "No Brave configuration to backup"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would create backup of Brave configuration"
        return 0
    fi
    
    # Backup directory should already be checked/created by check_backup_directory
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        log_error "Backup directory not available: $BACKUP_BASE_DIR"
        return 1
    fi
    
    local backup_name="brave-backup-$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_BASE_DIR/$backup_name"
    local archive_path="${backup_path}.tar.gz"
    
    log_info "Creating backup: $backup_name"
    
    # Stop Brave if running
    if pgrep -x brave-browser || pgrep -x brave &>/dev/null; then
        log_info "Stopping Brave browser..."
        pkill -x brave-browser || pkill -x brave 2>/dev/null || true
        sleep 2
    fi
    
    # Create backup using rsync for efficiency
    if rsync -av --exclude='Crash Reports' --exclude='ShaderCache' --exclude='GPUCache' \
              "$BRAVE_CONFIG_DIR/" "$backup_path/"; then
        
        # Create compressed archive
        if tar -czf "$archive_path" -C "$BACKUP_BASE_DIR" "$backup_name"; then
            rm -rf "$backup_path"
            
            # Show backup info
            local backup_size
            backup_size=$(du -h "$archive_path" | cut -f1)
            log_success "Backup created: $archive_path ($backup_size)"
            
            echo "$archive_path"
        else
            log_error "Failed to create compressed archive"
            rm -rf "$backup_path"
            return 1
        fi
    else
        log_error "Failed to create backup"
        return 1
    fi
}

# Restore Brave configuration from backup
restore_brave_backup() {
    local backup_path="${1:-}"
    
    if [[ -z "$backup_path" ]]; then
        log_error "No backup file specified"
        return 1
    fi
    
    if [[ ! -e "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        return 1
    fi
    
    log_section "Restoring Brave Configuration"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would restore from: $backup_path"
        return 0
    fi
    
    # Check if current config exists and create backup
    if [[ -d "$BRAVE_CONFIG_DIR" ]] && [[ "$FORCE_RESTORE" != "true" ]]; then
        local current_backup
        current_backup=$(create_brave_backup)
        if [[ -n "$current_backup" ]]; then
            log_info "Current configuration backed up to: $current_backup"
        fi
    fi
    
    # Stop Brave if running
    if pgrep -x brave-browser || pgrep -x brave &>/dev/null; then
        log_info "Stopping Brave browser..."
        pkill -x brave-browser || pkill -x brave 2>/dev/null || true
        sleep 2
    fi
    
    # Remove current configuration
    if [[ -d "$BRAVE_CONFIG_DIR" ]]; then
        rm -rf "$BRAVE_CONFIG_DIR"
        log_info "Removed current Brave configuration"
    fi
    
    # Create parent directory
    mkdir -p "$(dirname "$BRAVE_CONFIG_DIR")"
    
    # Restore from .tar.gz archive
    if [[ -f "$backup_path" && "$backup_path" == *.tar.gz ]]; then
        local temp_dir
        temp_dir=$(mktemp -d)
        if tar -xzf "$backup_path" -C "$temp_dir"; then
            local extracted_dir
            extracted_dir=$(find "$temp_dir" -type d -name "brave-backup-*" | head -1)
            if [[ -n "$extracted_dir" ]]; then
                mv "$extracted_dir" "$BRAVE_CONFIG_DIR"
                log_success "Restored from archive: $backup_path"
            else
                log_error "No backup directory found in archive"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log_error "Failed to extract backup archive"
            rm -rf "$temp_dir"
            return 1
        fi
        rm -rf "$temp_dir"
    else
        log_error "Invalid backup file: $backup_path (must be .tar.gz)"
        return 1
    fi
    
    # Fix permissions
    chmod -R u+rw "$BRAVE_CONFIG_DIR" 2>/dev/null || true
    
    log_success "Brave configuration restored successfully!"
}

# Setup automated backup script
setup_automated_backup() {
    log_section "Setting up Automated Backup Script"
    
    local backup_script="$HOME/.local/bin/brave-backup"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would create automated backup script: $backup_script"
        return 0
    fi
    
    mkdir -p "$(dirname "$backup_script")"
    
    cat > "$backup_script" << EOF
#!/bin/bash
# Automated Brave Backup Script

set -euo pipefail

BRAVE_CONFIG_DIR="\$HOME/.config/BraveSoftware/Brave-Browser"
BACKUP_BASE_DIR="$BACKUP_BASE_DIR"
MAX_BACKUPS=5

log_info() {
    echo -e "\033[0;34m[INFO] \${1:-}\033[0m"
}

log_success() {
    echo -e "\033[0;32m✓ [SUCCESS] \${1:-}\033[0m"
}

log_error() {
    echo -e "\033[0;31m✗ [ERROR] \${1:-}\033[0m" >&2
}

# Check if Brave config exists
if [[ ! -d "\$BRAVE_CONFIG_DIR" ]]; then
    log_error "Brave configuration directory not found"
    exit 1
fi

# Create backup directory
mkdir -p "\$BACKUP_BASE_DIR"

# Create backup name
backup_name="brave-backup-\$(date +%Y%m%d_%H%M%S)"
backup_path="\$BACKUP_BASE_DIR/\$backup_name"
archive_path="\${backup_path}.tar.gz"

log_info "Creating Brave backup: \$backup_name"

# Stop Brave if running
if pgrep -x brave-browser || pgrep -x brave &>/dev/null; then
    log_info "Stopping Brave browser..."
    pkill -x brave-browser || pkill -x brave 2>/dev/null || true
    sleep 2
fi

# Create backup
if rsync -av --exclude='Crash Reports' --exclude='ShaderCache' --exclude='GPUCache' \
          "\$BRAVE_CONFIG_DIR/" "\$backup_path/"; then
    
    # Create compressed archive
    if tar -czf "\$archive_path" -C "\$BACKUP_BASE_DIR" "\$backup_name"; then
        rm -rf "\$backup_path"
        
        backup_size=\$(du -h "\$archive_path" | cut -f1)
        log_success "Backup created: \$archive_path (\$backup_size)"
        
        # Clean up old backups
        log_info "Cleaning up old backups (keeping \$MAX_BACKUPS)..."
        cd "\$BACKUP_BASE_DIR"
        ls -t brave-backup-*.tar.gz 2>/dev/null | tail -n +\$((\$MAX_BACKUPS + 1)) | xargs -r rm -f
        
        current_count=\$(ls brave-backup-*.tar.gz 2>/dev/null | wc -l)
        log_info "Current backup count: \$current_count"
        
    else
        log_error "Failed to create compressed archive"
        rm -rf "\$backup_path"
        exit 1
    fi
else
    log_error "Failed to create backup"
    exit 1
fi
EOF
    
    chmod +x "$backup_script"
    log_success "Automated backup script created: $backup_script"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        log_info "Adding ~/.local/bin to PATH in shell configuration"
        # This will be handled by user-setup script
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Setup intelligent Brave browser backup and restore system.

OPTIONS:
    -h, --help              Show this help message
    -n, --dry-run           Show what would be done without making changes
    -y, --yes               Skip confirmation prompts
    --skip-backup           Skip creating backup of current configuration
    --skip-restore-scan     Skip scanning for existing backups
    --force-restore         Force restore without backing up current config
    --log-dir DIR           Custom log directory (default: ~/dotfiles/logs)
    --dotfiles-dir DIR      Custom dotfiles directory (default: auto-detect)
    --backup-dir DIR        Custom backup directory (default: /mnt/Stuff/brave-backups)

DESCRIPTION:
    This script sets up an intelligent backup and restore system for Brave browser.
    It can detect existing backups across all mounted drives and prioritize
    restoration on fresh installations.

FEATURES:
    • Automatic detection of existing backups
    • Smart backup creation with compression
    • Restoration from various backup formats
    • Automated backup script creation
    • Cleanup of old backups
    • Safe handling of current configurations

BEHAVIOR:
    - Fresh install: Scans for existing backups and offers restoration
    - Existing install: Creates backup and sets up automated backups
    - Handles both directory and archive formats
    - Excludes cache and temporary files from backups

EXAMPLES:
    $SCRIPT_NAME                    # Full backup system setup
    $SCRIPT_NAME --skip-restore-scan # Setup without scanning for existing backups
    $SCRIPT_NAME -n                 # Dry run to see what would be done
    $SCRIPT_NAME -y                 # Setup without confirmations
    $SCRIPT_NAME --backup-dir ~/brave-backups  # Use custom backup directory

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --skip-backup)
                SKIP_AUTO_BACKUP=true
                shift
                ;;
            --skip-restore-scan)
                SKIP_RESTORE_SCAN=true
                shift
                ;;
            --force-restore)
                FORCE_RESTORE=true
                shift
                ;;
            --log-dir)
                if [[ -n "${2:-}" ]]; then
                    LOG_DIR="$2"
                    LOG_FILE="${LOG_DIR}/brave-backup_$(date +%Y%m%d_%H%M%S).log"
                    shift 2
                else
                    log_error "--log-dir requires a directory path"
                    exit 1
                fi
                ;;
            --dotfiles-dir)
                if [[ -n "${2:-}" ]]; then
                    DOTFILES_DIR="$2"
                    shift 2
                else
                    log_error "--dotfiles-dir requires a directory path"
                    exit 1
                fi
                ;;
            --backup-dir)
                if [[ -n "${2:-}" ]]; then
                    BACKUP_BASE_DIR="$2"
                    shift 2
                else
                    log_error "--backup-dir requires a directory path"
                    exit 1
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"
    init_logging
    
    echo "=== Brave Backup System Setup ==="
    echo "Log file: $LOG_FILE"
    echo "Dotfiles directory: $DOTFILES_DIR"
    echo
    
    check_prerequisites
    
    # Check and setup backup directory
    check_backup_directory
    
    # Check Brave status
    local brave_status=0
    check_brave_status || brave_status=$?
    
    if [[ $brave_status -eq 1 ]]; then
        log_warning "Brave is not installed. Install Brave first."
        exit 1
    fi
    
    # Ask user what they want to do
    if [[ "$SKIP_CONFIRMATION" != "true" && "$DRY_RUN" != "true" ]]; then
        local choice
        if command -v fzf &>/dev/null; then
            log_info "Use arrow keys to select an action, Enter to confirm, Esc to exit"
            choice=$(printf '%s\n' \
                "1|Create backup of current Brave configuration" \
                "2|Restore Brave configuration from existing backup" \
                "3|Setup automated backup system only" \
                "4|Exit" | \
                fzf --height=40% \
                    --border \
                    --header="What would you like to do?" \
                    --delimiter="|" \
                    --with-nth=2 | \
                cut -d"|" -f1)
            
            if [[ -z "$choice" ]]; then
                log_info "No action selected. Exiting."
                exit 0
            fi
        else
            echo "What would you like to do?"
            echo "  1. Create backup of current Brave configuration"
            echo "  2. Restore Brave configuration from existing backup"
            echo "  3. Setup automated backup system only"
            echo "  4. Exit"
            echo
            read -p "Enter choice (1-4): " -r choice
        fi
        
        case $choice in
            1)
                log_info "Creating backup of current configuration..."
                create_brave_backup
                ;;
            2)
                log_info "Scanning for existing backups..."
                local existing_backups=()
                if existing_backups=$(find_backup_locations); then
                    readarray -t backup_array <<< "$existing_backups"
                    display_backup_locations "${backup_array[@]}"
                    
                    if [[ ${#backup_array[@]} -gt 0 ]]; then
                        # Try fzf first, fallback to manual selection
                        local selected_backup
                        if selected_backup=$(select_backup_with_fzf "${backup_array[@]}"); then
                            restore_brave_backup "$selected_backup"
                        else
                            # Fallback to manual selection
                            echo "Choose a backup to restore:"
                            for i in "${!backup_array[@]}"; do
                                echo "  $((i+1)). ${backup_array[i]}"
                            done
                            echo "  0. Cancel restoration"
                            echo
                            read -p "Enter choice (0-${#backup_array[@]}): " -r restore_choice
                            
                            if [[ "$restore_choice" =~ ^[1-9][0-9]*$ ]] && [[ $restore_choice -le ${#backup_array[@]} ]]; then
                                local selected_backup="${backup_array[$((restore_choice-1))]}"
                                restore_brave_backup "$selected_backup"
                            else
                                log_info "Cancelled backup restoration"
                            fi
                        fi
                    else
                        log_info "No existing backups found"
                    fi
                else
                    log_info "No existing backups found"
                fi
                ;;
            3)
                log_info "Setting up automated backup system only..."
                ;;
            4)
                log_info "Exiting without changes"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Exiting."
                exit 1
                ;;
        esac
    else
        # Auto mode - just setup automated backup
        log_info "Auto mode: Setting up automated backup system"
    fi
    
    # Setup automated backup system
    setup_automated_backup
    
    echo
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed - no changes were made"
    else
        log_success "Brave backup system setup completed!"
        log_info "Use 'brave-backup' command to create manual backups"
        log_info "Backups are stored in: $BACKUP_BASE_DIR"
    fi
    
    echo "Log file: $LOG_FILE"
}

# Run main function
main "$@" 