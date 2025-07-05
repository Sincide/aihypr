#!/bin/bash

# External Drives Setup Script
# Author: Martin's Dotfiles - Modular Version
# Description: Auto-mount external drives with labels and setup fstab entries

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly LOG_DIR="${DOTFILES_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/external-drives_$(date +%Y%m%d_%H%M%S).log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Flags
SKIP_CONFIRMATION=false
SKIP_FSTAB=false
SKIP_SYMLINKS=false
DRY_RUN=false

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    echo "Starting external drives setup - $(date)" >> "$LOG_FILE"
    echo "[LOG] Script: $SCRIPT_NAME" >> "$LOG_FILE"
}

# Logging functions
log_info() {
    local msg="[INFO] $1"
    echo -e "${BLUE}$msg${NC}" >&2
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}✓ $msg${NC}" >&2
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[ERROR] $1"
    echo -e "${RED}✗ $msg${NC}" >&2
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}⚠ $msg${NC}" >&2
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_section() {
    local msg="$1"
    echo -e "${CYAN}=== $msg ===${NC}" >&2
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
    
    # Check sudo access
    if ! sudo -v &>/dev/null; then
        log_error "No sudo access"
        exit 1
    fi
    
    # Check required tools
    local required_tools=("lsblk" "findmnt" "mount" "umount")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Get system drive information
get_system_drives() {
    local system_root_uuid
    system_root_uuid=$(findmnt -n -o UUID / 2>/dev/null || echo "")
    local boot_uuid
    boot_uuid=$(findmnt -n -o UUID /boot 2>/dev/null || echo "")
    
    echo "$system_root_uuid|$boot_uuid"
}

# Find all external drives (both mounted and unmounted) - data only
find_all_external_drives_data() {
    local system_info
    system_info=$(get_system_drives)
    local system_root_uuid="${system_info%|*}"
    local boot_uuid="${system_info#*|}"
    
    local all_drives=()
    
    # Find all drives with labels, excluding system partitions
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            all_drives+=("$line")
        fi
    done < <(lsblk -rno NAME,LABEL,FSTYPE,UUID,MOUNTPOINT | \
             awk -v root_uuid="$system_root_uuid" -v boot_uuid="$boot_uuid" '
             $3 != "" && $3 != "swap" && $2 != "" && 
             $4 != root_uuid && $4 != boot_uuid && 
             $1 !~ /nvme0n1p[12]/ && $1 !~ /sda[12]/ {
                 mount_status = ($5 == "") ? "UNMOUNTED" : "MOUNTED:" $5
                 print $1 "|" $2 "|" $3 "|" $4 "|" mount_status
             }')
    
    if [[ ${#all_drives[@]} -eq 0 ]]; then
        return 1
    fi
    
    printf '%s\n' "${all_drives[@]}"
}

# Display external drives for user selection
display_external_drives() {
    local drives=("$@")
    
    if [[ ${#drives[@]} -eq 0 ]]; then
        log_info "No external drives with labels found"
        return 1
    fi
    
    log_section "Found ${#drives[@]} External Drive(s)"
    echo >&2
    
    local count=1
    for drive_info in "${drives[@]}"; do
        IFS='|' read -r device label fstype uuid mount_status <<< "$drive_info"
        echo -e "  ${CYAN}[$count]${NC} 📱 ${GREEN}/dev/$device${NC}" >&2
        echo -e "      ${BLUE}Label:${NC} $label" >&2
        echo -e "      ${BLUE}Type:${NC}  $fstype" >&2
        echo -e "      ${BLUE}Status:${NC} $mount_status" >&2
        echo -e "      ${BLUE}UUID:${NC}  $uuid" >&2
        
        # Check if already in fstab
        if grep -q "$uuid" /etc/fstab 2>/dev/null; then
            echo -e "      ${GREEN}✓ Already in /etc/fstab${NC}" >&2
        else
            echo -e "      ${YELLOW}⚠ Not in /etc/fstab${NC}" >&2
        fi
        echo >&2
        count=$((count + 1))
    done
}

# Select drives for fstab management
select_drives_for_fstab() {
    local all_drives=("$@")
    local selected_drives=()
    
    if [[ ${#all_drives[@]} -eq 0 ]]; then
        return 0
    fi
    
    echo "Select drives to add/manage in /etc/fstab for automatic mounting:"
    echo "Enter drive numbers separated by spaces (e.g., 1 3 5), or 'all' for all drives, or 'none' to skip:"
    read -p "Selection: " -r selection
    
    if [[ "$selection" =~ ^[Aa]ll$ ]]; then
        selected_drives=("${all_drives[@]}")
    elif [[ "$selection" =~ ^[Nn]one$ ]] || [[ -z "$selection" ]]; then
        log_info "No drives selected for fstab management"
        return 0
    else
        # Parse individual numbers
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#all_drives[@]} ]]; then
                selected_drives+=("${all_drives[$((num-1))]}")
            else
                log_warning "Invalid selection: $num (ignoring)"
            fi
        done
    fi
    
    if [[ ${#selected_drives[@]} -gt 0 ]]; then
        log_info "Selected ${#selected_drives[@]} drive(s) for fstab management"
        printf '%s\n' "${selected_drives[@]}"
    else
        log_info "No valid drives selected"
        return 0
    fi
}

# Mount external drives
mount_external_drives() {
    local drives=("$@")
    
    if [[ ${#drives[@]} -eq 0 ]]; then
        log_warning "No drives to mount"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would mount ${#drives[@]} drives"
        for drive_info in "${drives[@]}"; do
            IFS='|' read -r device label fstype uuid <<< "$drive_info"
            local clean_label
            clean_label=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_-')
            echo "  Would mount: /dev/$device → /mnt/$clean_label"
        done
        return 0
    fi
    
    local mount_base="/mnt"
    local mounted_drives=()
    
    for drive_info in "${drives[@]}"; do
        IFS='|' read -r device label fstype uuid <<< "$drive_info"
        
        # Clean label for use as directory name
        local clean_label
        clean_label=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        local mount_point="$mount_base/$clean_label"
        
        log_info "📁 Setting up mount point: $mount_point"
        
        # Create mount point
        if sudo mkdir -p "$mount_point"; then
            log_success "Created mount point: $mount_point"
        else
            log_warning "Failed to create mount point: $mount_point"
            continue
        fi
        
        # Mount the drive
        log_info "🔗 Mounting /dev/$device to $mount_point..."
        if sudo mount "/dev/$device" "$mount_point"; then
            log_success "Mounted: /dev/$device → $mount_point"
            mounted_drives+=("$device|$mount_point|$uuid")
            
            # Set proper permissions
            sudo chown "$USER:$USER" "$mount_point" 2>/dev/null || true
        else
            log_warning "Failed to mount /dev/$device"
            sudo rmdir "$mount_point" 2>/dev/null || true
        fi
        echo >&2
    done
    
    printf '%s\n' "${mounted_drives[@]}"
}

# Add drives to fstab
setup_fstab() {
    local drives=("$@")
    
    if [[ ${#drives[@]} -eq 0 ]]; then
        log_warning "No drives to add to fstab"
        return 0
    fi
    
    if [[ "$SKIP_FSTAB" == "true" ]]; then
        log_info "Skipping fstab setup"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would add ${#drives[@]} drives to fstab"
        return 0
    fi
    
    log_section "Adding Drives to /etc/fstab"
    
    local fstab_backup="/etc/fstab.backup.$(date +%s)"
    sudo cp /etc/fstab "$fstab_backup"
    log_info "Backed up /etc/fstab to $fstab_backup"
    
    local added_count=0
    
    for drive_info in "${drives[@]}"; do
        local device mount_point uuid
        if [[ "$drive_info" =~ \|.*\|.*\|.* ]]; then
            # Mounted drive format: device|mount_point|uuid
            IFS='|' read -r device mount_point uuid <<< "$drive_info"
        else
            # Unmounted drive format: device|label|fstype|uuid
            IFS='|' read -r device label fstype uuid <<< "$drive_info"
            local clean_label
            clean_label=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_-')
            mount_point="/mnt/$clean_label"
        fi
        
        # Check if entry already exists
        if grep -q "$uuid" /etc/fstab; then
            log_info "Entry for $device already exists in /etc/fstab"
            continue
        fi
        
        # Add fstab entry with permanent mounting to /mnt
        local fstab_entry="UUID=$uuid $mount_point auto defaults,user,x-systemd.automount,x-systemd.device-timeout=10 0 2"
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
        log_success "Added /dev/$device to /etc/fstab"
        added_count=$((added_count + 1))
    done
    
    if [[ $added_count -gt 0 ]]; then
        # Reload systemd
        sudo systemctl daemon-reload
        log_success "Reloaded systemd configuration"
    fi
    
    log_success "Added $added_count drives to fstab"
}



# Setup selected drives
setup_selected_drives() {
    local drives=("$@")
    local drives_to_mount=()
    local drives_for_fstab=()
    
    # Process each selected drive
    for drive_info in "${drives[@]}"; do
        IFS='|' read -r device label fstype uuid mount_status <<< "$drive_info"
        
        local clean_label
        clean_label=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        local target_mount_point="/mnt/$clean_label"
        
        if [[ "$mount_status" == "UNMOUNTED" ]]; then
            # Need to mount this drive first
            drives_to_mount+=("$device|$label|$fstype|$uuid")
        else
            # Already mounted somewhere else, need to remount to /mnt/
            local current_mount_point="${mount_status#MOUNTED:}"
            
            if [[ "$current_mount_point" != "$target_mount_point" ]]; then
                log_info "Remounting /dev/$device from $current_mount_point to $target_mount_point"
                
                # Create target mount point
                sudo mkdir -p "$target_mount_point"
                
                # Unmount from current location
                if sudo umount "$current_mount_point" 2>/dev/null; then
                    log_success "Unmounted /dev/$device from $current_mount_point"
                    
                    # Mount to target location
                    if sudo mount "/dev/$device" "$target_mount_point"; then
                        log_success "Mounted /dev/$device to $target_mount_point"
                        sudo chown "$USER:$USER" "$target_mount_point" 2>/dev/null || true
                        drives_for_fstab+=("$device|$target_mount_point|$uuid")
                    else
                        log_error "Failed to mount /dev/$device to $target_mount_point"
                        # Try to remount to original location
                        sudo mount "/dev/$device" "$current_mount_point" 2>/dev/null || true
                    fi
                else
                    log_warning "Could not unmount /dev/$device from $current_mount_point, adding to fstab as-is"
                    drives_for_fstab+=("$device|$current_mount_point|$uuid")
                fi
            else
                # Already mounted at correct location
                log_info "/dev/$device already mounted at correct location: $target_mount_point"
                drives_for_fstab+=("$device|$target_mount_point|$uuid")
            fi
        fi
    done
    
    # Mount unmounted drives
    if [[ ${#drives_to_mount[@]} -gt 0 ]]; then
        log_info "Mounting ${#drives_to_mount[@]} unmounted drive(s)..."
        local newly_mounted=()
        readarray -t newly_mounted < <(mount_external_drives "${drives_to_mount[@]}")
        
        # Add newly mounted drives to fstab list
        drives_for_fstab+=("${newly_mounted[@]}")
    fi
    
    # Setup fstab for all drives
    if [[ ${#drives_for_fstab[@]} -gt 0 ]]; then
        setup_fstab "${drives_for_fstab[@]}"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Auto-mount external drives with labels and setup persistent mounting.

OPTIONS:
    -h, --help              Show this help message
    -n, --dry-run           Show what would be done without making changes
    -y, --yes               Skip confirmation prompts
    --skip-fstab            Skip adding entries to /etc/fstab
    --log-dir DIR           Custom log directory (default: ~/dotfiles/logs)
    --dotfiles-dir DIR      Custom dotfiles directory (default: auto-detect)

DESCRIPTION:
    This script automatically detects external drives with labels and sets up
    convenient mounting. It handles both unmounted drives (mounts them) and
    already mounted drives (adds to fstab for persistence).

FEATURES:
    • Auto-detection of external drives with labels
    • Safe mounting with proper permissions
    • Persistent mounting via /etc/fstab entries
    • Handles both new and existing installations

SAFETY:
    • Excludes system partitions automatically
    • Creates backups of /etc/fstab before changes
    • Uses systemd automount for reliable mounting
    • Handles already mounted drives gracefully

EXAMPLES:
    $SCRIPT_NAME                    # Full external drive setup
    $SCRIPT_NAME --skip-fstab       # Mount only, no persistence
    $SCRIPT_NAME -n                 # Dry run to see what would be done
    $SCRIPT_NAME -y                 # Setup without confirmations

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
            --skip-fstab)
                SKIP_FSTAB=true
                shift
                ;;
            --log-dir)
                if [[ -n "${2:-}" ]]; then
                    LOG_DIR="$2"
                    LOG_FILE="${LOG_DIR}/external-drives_$(date +%Y%m%d_%H%M%S).log"
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
    
    echo "=== External Drives Setup ==="
    echo "Log file: $LOG_FILE"
    echo "Dotfiles directory: $DOTFILES_DIR"
    echo
    
    check_prerequisites
    
    # Find all external drives (mounted and unmounted)
    local all_drives
    all_drives=$(find_all_external_drives_data)
    local find_result=$?
    
    if [[ $find_result -ne 0 ]] || [[ -z "$all_drives" ]]; then
        log_info "No external drives found. Exiting."
        echo "Log file: $LOG_FILE"
        return 0
    fi
    
    # Convert output to array and display
    readarray -t drive_array <<< "$all_drives"
    display_external_drives "${drive_array[@]}"
    
    # Let user select which drives to manage (unless in auto mode)
    local selected_drives=()
    if [[ "$SKIP_CONFIRMATION" == "true" ]]; then
        # Auto mode - select all drives
        selected_drives=("${drive_array[@]}")
        log_info "Auto mode: Managing all ${#selected_drives[@]} external drives"
    else
        # Interactive mode - let user choose
        if selected_drives_output=$(select_drives_for_fstab "${drive_array[@]}"); then
            if [[ -n "$selected_drives_output" ]]; then
                readarray -t selected_drives <<< "$selected_drives_output"
            fi
        fi
    fi
    
    # Process selected drives
    if [[ ${#selected_drives[@]} -gt 0 ]]; then
        setup_selected_drives "${selected_drives[@]}"
    else
        log_info "No drives selected for setup"
    fi
    
    echo
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed - no changes were made"
    else
        log_success "External drives setup completed!"
        if [[ ${#selected_drives[@]} -gt 0 ]]; then
            log_info "Selected drives will auto-mount on boot via systemd automount"
            log_info "Access your drives at: /mnt/[drive-label]"
        fi
    fi
    
    echo "Log file: $LOG_FILE"
}

# Run main function
main "$@" 