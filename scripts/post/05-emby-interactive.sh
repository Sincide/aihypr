#!/bin/bash
set -eo pipefail

# Emby Server Interactive Setup Script for Arch Linux with Hyprland
# Version: 2.0 (Bash conversion)
# Author: System Administrator
# Description: Comprehensive installation and setup script with backup/restore functionality

# Configuration
readonly SCRIPT_NAME="Emby Server Setup"
readonly SCRIPT_VERSION="2.0"
readonly LOG_FILE="/tmp/emby_setup_$(date +%Y%m%d_%H%M%S).log"
EMBY_DATA_DIR="/var/lib/emby"  # Default, will be auto-detected
readonly MEDIA_DIR="/mnt/Media"
readonly BACKUP_DIR="/mnt/Stuff/backups"
DEBUG_MODE=0

# Color definitions
readonly COLOR_INFO='\033[0;34m'
readonly COLOR_SUCCESS='\033[0;32m'
readonly COLOR_WARNING='\033[0;33m'
readonly COLOR_ERROR='\033[0;31m'
readonly COLOR_RESET='\033[0m'

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=0

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    case "$level" in
        INFO)
            echo -e "${COLOR_INFO}ℹ  $message${COLOR_RESET}"
            ;;
        SUCCESS)
            echo -e "${COLOR_SUCCESS}✓ $message${COLOR_RESET}"
            ;;
        WARNING)
            echo -e "${COLOR_WARNING}⚠  $message${COLOR_RESET}"
            ;;
        ERROR)
            echo -e "${COLOR_ERROR}✗ $message${COLOR_RESET}" >&2
            ;;
        DEBUG)
            if [[ $DEBUG_MODE -eq 1 ]]; then
                echo -e "${COLOR_INFO}[DEBUG] $message${COLOR_RESET}"
            fi
            ;;
    esac
    
    echo "$log_entry" >> "$LOG_FILE"
}

# Progress indicator
init_progress() {
    local total="$1"
    TOTAL_STEPS="$total"
    CURRENT_STEP=0
    log_message INFO "Starting $SCRIPT_NAME v$SCRIPT_VERSION with $total steps"
}

update_progress() {
    local step_name="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    log_message INFO "Step $CURRENT_STEP/$TOTAL_STEPS ($percent%): $step_name"
}

# Get Emby service ownership
get_emby_ownership() {
    if [[ -d "$EMBY_DATA_DIR" ]]; then
        local ownership
        ownership=$(sudo stat -c "%u:%g" "$EMBY_DATA_DIR" 2>/dev/null)
        if [[ -n "$ownership" ]]; then
            echo "$ownership"
            return 0
        fi
    fi
    
    # Fallback: try to get from running process
    local pid
    pid=$(pgrep -f "EmbyServer.dll" | head -1)
    if [[ -n "$pid" ]]; then
        local ownership
        ownership=$(ps -o uid:1,gid:1 -p "$pid" --no-headers 2>/dev/null | tr -s ' ' ':' | sed 's/^://')
        if [[ -n "$ownership" ]]; then
            echo "$ownership"
            return 0
        fi
    fi
    
    # Final fallback
    echo "65534:65534"
    return 1
}

# Detect Emby data directory
detect_emby_data_dir() {
    log_message DEBUG "Auto-detecting Emby data directory..."
    
    # Check if /var/lib/emby is a symlink and resolve it
    if [[ -L "/var/lib/emby" ]]; then
        local resolved_path
        resolved_path=$(readlink -f "/var/lib/emby" 2>/dev/null)
        if [[ -n "$resolved_path" && -d "$resolved_path" ]]; then
            log_message DEBUG "Found symlink: /var/lib/emby -> $resolved_path"
            # Check if the resolved path has Emby structure
            if sudo test -d "$resolved_path/config" 2>/dev/null || sudo test -d "$resolved_path/data" 2>/dev/null || sudo test -d "$resolved_path/logs" 2>/dev/null; then
                EMBY_DATA_DIR="$resolved_path"
                log_message SUCCESS "Auto-detected Emby data directory: $resolved_path (via symlink)"
                return 0
            fi
        fi
    fi
    
    # Common locations to check (prioritize private dir over symlink)
    local possible_dirs=("/var/lib/private/emby" "/var/lib/emby" "/home/emby/.config/emby-server" "/opt/emby-server/programdata")
    
    for dir in "${possible_dirs[@]}"; do
        if sudo test -d "$dir" 2>/dev/null; then
            log_message DEBUG "Found potential data directory: $dir"
            # Check if it looks like an Emby data directory
            if sudo test -d "$dir/config" 2>/dev/null || sudo test -d "$dir/data" 2>/dev/null || sudo test -d "$dir/logs" 2>/dev/null; then
                EMBY_DATA_DIR="$dir"
                log_message SUCCESS "Auto-detected Emby data directory: $dir"
                return 0
            fi
        fi
    done
    
    # If not found, try to find from systemd service configuration
    local state_dir
    state_dir=$(sudo systemctl show emby-server.service -p StateDirectory --value 2>/dev/null)
    if [[ -n "$state_dir" ]]; then
        # Try both /var/lib/private and /var/lib locations
        for base_path in "/var/lib/private" "/var/lib"; do
            local potential_dir="$base_path/$state_dir"
            if [[ -d "$potential_dir" ]]; then
                EMBY_DATA_DIR="$potential_dir"
                log_message SUCCESS "Detected Emby data directory from systemd config: $potential_dir"
                return 0
            fi
        done
    fi
    
    # If still not found, try to find from systemd logs
    local log_dir
    log_dir=$(sudo journalctl -u emby-server.service --no-pager -n 100 2>/dev/null | grep "Loading live tv data from" | tail -1 | sed -n 's/.*Loading live tv data from \(.*\)\/data\/livetv.*/\1/p')
    if [[ -n "$log_dir" && -d "$log_dir" ]]; then
        EMBY_DATA_DIR="$log_dir"
        log_message SUCCESS "Detected Emby data directory from logs: $log_dir"
        return 0
    fi
    
    log_message WARNING "Could not auto-detect Emby data directory, using default: $EMBY_DATA_DIR"
    return 1
}

# User confirmation function
confirm() {
    local prompt="${1:-Continue?}"
    
    while true; do
        echo -e -n "${COLOR_WARNING}$prompt [y/N]: ${COLOR_RESET}"
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo]|"")
                return 1
                ;;
            *)
                echo -e "${COLOR_ERROR}Please answer y or n${COLOR_RESET}"
                ;;
        esac
    done
}

# Auto-fix prompt function
should_fix() {
    local problem="$1"
    local solution="$2"
    echo -e "${COLOR_WARNING}Problem detected: $problem${COLOR_RESET}"
    echo -e "${COLOR_INFO}Proposed solution: $solution${COLOR_RESET}"
    
    if confirm "Should I fix this for you?"; then
        log_message INFO "User approved fix: $solution"
        return 0
    else
        log_message INFO "User declined fix. Manual intervention required."
        return 1
    fi
}

# System requirements check
check_system_requirements() {
    log_message INFO "Checking system requirements..."
    
    # Check if running on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        if should_fix "Not running on Arch Linux" "Continue anyway (unsupported)"; then
            log_message WARNING "Continuing on non-Arch system (unsupported)"
        else
            log_message ERROR "Aborting: This script is designed for Arch Linux"
            return 1
        fi
    fi
    
    # Check if running as regular user (not root)
    if [[ $(id -u) -eq 0 ]]; then
        if should_fix "Running as root user" "Continue with elevated privileges"; then
            log_message WARNING "Continuing as root user"
        else
            log_message ERROR "Aborting: Please run as regular user"
            return 1
        fi
    fi
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        if should_fix "No passwordless sudo access detected" "Authenticate with sudo password"; then
            log_message INFO "Please enter your sudo password to continue..."
            if sudo true; then
                log_message SUCCESS "Sudo authentication successful"
            else
                log_message ERROR "Sudo authentication failed"
                return 1
            fi
        else
            log_message ERROR "Sudo access required for installation"
            return 1
        fi
    else
        log_message SUCCESS "Passwordless sudo access confirmed"
    fi
    
    # Check available disk space (minimum 10GB)
    local available_space
    available_space=$(df / --output=avail -BG | tail -n1 | tr -d 'G')
    if [[ $available_space -lt 10 ]]; then
        if should_fix "Insufficient disk space: ${available_space}GB" "Continue with limited space"; then
            log_message WARNING "Continuing with limited disk space"
        else
            log_message ERROR "Aborting: Insufficient disk space"
            return 1
        fi
    fi
    
    # Check memory (minimum 2GB)
    local memory_gb
    memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $memory_gb -lt 2 ]]; then
        if should_fix "Low memory: ${memory_gb}GB" "Continue with limited memory"; then
            log_message WARNING "Continuing with limited memory"
        else
            log_message ERROR "Aborting: Insufficient memory"
            return 1
        fi
    fi
    
    log_message SUCCESS "System requirements check completed"
    return 0
}

# Check dependencies
check_dependencies() {
    log_message INFO "Checking required dependencies..."
    
    local required_commands=(sudo systemctl curl wget)
    local missing_deps=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        if should_fix "Missing dependencies: ${missing_deps[*]}" "Install missing dependencies"; then
            for dep in "${missing_deps[@]}"; do
                log_message INFO "Installing $dep..."
                if ! sudo pacman -S --needed --noconfirm "$dep"; then
                    log_message ERROR "Failed to install $dep"
                    return 1
                fi
            done
        else
            log_message ERROR "Aborting: Missing required dependencies"
            return 1
        fi
    fi
    
    log_message SUCCESS "All dependencies satisfied"
    return 0
}

# Check and install AUR helper
ensure_aur_helper() {
    log_message INFO "Checking for AUR helper..."
    
    if command -v yay >/dev/null; then
        log_message SUCCESS "yay found"
        return 0
    elif command -v paru >/dev/null; then
        log_message SUCCESS "paru found"
        return 0
    else
        if should_fix "No AUR helper found" "Install yay AUR helper"; then
            log_message INFO "Installing yay..."
            
            # Install base-devel if not present
            sudo pacman -S --needed --noconfirm base-devel git
            
            # Create temporary directory for yay installation
            local temp_dir
            temp_dir=$(mktemp -d)
            cd "$temp_dir"
            
            if git clone https://aur.archlinux.org/yay.git; then
                cd yay
                if makepkg -si --noconfirm --needed; then
                    log_message SUCCESS "yay installed successfully"
                    cd /
                    rm -rf "$temp_dir"
                    return 0
                else
                    log_message ERROR "Failed to build yay"
                    cd /
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                log_message ERROR "Failed to clone yay repository"
                cd /
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log_message ERROR "AUR helper required for Emby installation"
            return 1
        fi
    fi
}

# Hyprland compatibility setup
setup_hyprland_compatibility() {
    log_message INFO "Setting up Hyprland compatibility..."
    
    # Check if Hyprland is running
    if ! pgrep -x "Hyprland" >/dev/null; then
        log_message WARNING "Hyprland not currently running"
        if ! confirm "Continue anyway?"; then
            return 1
        fi
    fi
    
    # Install required packages for Wayland/Hyprland compatibility
    local hyprland_packages=(xdg-desktop-portal-hyprland pipewire wireplumber)
    log_message INFO "Installing Hyprland compatibility packages..."
    
    for package in "${hyprland_packages[@]}"; do
        if ! pacman -Qi "$package" >/dev/null 2>&1; then
            log_message INFO "Installing $package..."
            if ! sudo pacman -S --needed --noconfirm "$package"; then
                if should_fix "Failed to install $package" "Continue without $package"; then
                    log_message WARNING "Continuing without $package"
                else
                    return 1
                fi
            fi
        fi
    done
    
    # Set up environment variables for Wayland compatibility
    local env_file="$HOME/.config/fish/conf.d/emby-hyprland.fish"
    
    if should_fix "Configure Wayland environment variables" "Create environment configuration"; then
        log_message INFO "Creating Wayland environment configuration..."
        
        mkdir -p "$(dirname "$env_file")"
        
        cat > "$env_file" << 'EOF'
# Emby Server Hyprland compatibility configuration
set -gx XDG_CURRENT_DESKTOP Hyprland
set -gx XDG_SESSION_TYPE wayland
set -gx XDG_SESSION_DESKTOP Hyprland
set -gx ELECTRON_OZONE_PLATFORM_HINT auto
set -gx GDK_BACKEND wayland
EOF
        
        log_message SUCCESS "Wayland environment configuration created"
    fi
    
    log_message SUCCESS "Hyprland compatibility setup completed"
    return 0
}

# Install Emby Server
install_emby_server() {
    log_message INFO "Installing Emby Server..."
    
    # Check if already installed
    if pacman -Qi emby-server >/dev/null 2>&1; then
        log_message INFO "Emby Server already installed"
        if confirm "Reinstall Emby Server?"; then
            log_message INFO "Reinstalling Emby Server..."
        else
            return 0
        fi
    fi
    
    # Try official repository first
    log_message INFO "Attempting installation from official repository..."
    if sudo pacman -S --needed --noconfirm emby-server; then
        log_message SUCCESS "Emby Server installed from official repository"
        return 0
    else
        log_message WARNING "Official repository installation failed"
        
        if should_fix "Official package installation failed" "Try AUR package"; then
            log_message INFO "Attempting AUR installation..."
            
            # Determine AUR helper
            local aur_helper=""
            if command -v yay >/dev/null; then
                aur_helper="yay"
            elif command -v paru >/dev/null; then
                aur_helper="paru"
            else
                log_message ERROR "No AUR helper available"
                return 1
            fi
            
            # Install from AUR
            if "$aur_helper" -S --needed --noconfirm emby-server; then
                log_message SUCCESS "Emby Server installed from AUR"
                return 0
            else
                log_message ERROR "AUR installation also failed"
                return 1
            fi
        else
            log_message ERROR "Emby Server installation failed"
            return 1
        fi
    fi
}

# Configure Emby Server
configure_emby_server() {
    log_message INFO "Configuring Emby Server..."
    
    # Create media directory
    if [[ ! -d "$MEDIA_DIR" ]]; then
        if should_fix "Media directory $MEDIA_DIR doesn't exist" "Create media directory"; then
            log_message INFO "Creating media directory: $MEDIA_DIR"
            if sudo mkdir -p "$MEDIA_DIR"; then
                sudo chown "$USER:users" "$MEDIA_DIR"
                sudo chmod 755 "$MEDIA_DIR"
                log_message SUCCESS "Media directory created"
            else
                log_message ERROR "Failed to create media directory"
                return 1
            fi
        fi
    fi
    
    # Create backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        if should_fix "Backup directory $BACKUP_DIR doesn't exist" "Create backup directory"; then
            log_message INFO "Creating backup directory: $BACKUP_DIR"
            if sudo mkdir -p "$BACKUP_DIR"; then
                sudo chown "$USER:users" "$BACKUP_DIR"
                sudo chmod 755 "$BACKUP_DIR"
                log_message SUCCESS "Backup directory created"
            else
                log_message ERROR "Failed to create backup directory"
                return 1
            fi
        fi
    fi
    
    # Set up media group permissions
    if should_fix "Configure media group permissions" "Set up proper permissions"; then
        log_message INFO "Setting up media group permissions..."
        
        # Create media group if it doesn't exist
        if ! getent group media >/dev/null; then
            sudo groupadd media
        fi
        
        # Add current user to media group
        sudo usermod -aG media "$USER"
        
        # Set permissions on media directory
        sudo chgrp -R media "$MEDIA_DIR"
        find "$MEDIA_DIR" -type d -exec sudo chmod 775 {} \;
        find "$MEDIA_DIR" -type f -exec sudo chmod 664 {} \;
        
        log_message SUCCESS "Media group permissions configured"
    fi
    
    # Configure systemd service
    if should_fix "Configure Emby systemd service" "Set up service configuration"; then
        log_message INFO "Configuring Emby systemd service..."
        
        # Create service override directory
        sudo mkdir -p /etc/systemd/system/emby-server.service.d
        
        # Create override configuration
        local override_conf="/etc/systemd/system/emby-server.service.d/override.conf"
        
        sudo tee "$override_conf" >/dev/null << EOF
[Service]
SupplementaryGroups=media
ReadWritePaths=$MEDIA_DIR
UMask=0002
EOF
        
        # Reload systemd
        sudo systemctl daemon-reload
        
        log_message SUCCESS "Systemd service configured"
    fi
    
    log_message SUCCESS "Emby Server configuration completed"
    return 0
}

# Check for port conflicts
check_port_conflicts() {
    log_message INFO "Checking for port conflicts..."
    
    # Check if port 8096 is in use
    if netstat -tlnp 2>/dev/null | grep -q ":8096 "; then
        local process_info
        process_info=$(netstat -tlnp 2>/dev/null | grep ":8096 " | head -1)
        log_message WARNING "Port 8096 is already in use:"
        echo "  $process_info"
        
        if should_fix "Port 8096 conflict detected" "Kill process using port 8096"; then
            local pid
            pid=$(echo "$process_info" | awk '{print $7}' | cut -d'/' -f1)
            if [[ -n "$pid" && "$pid" != "-" ]]; then
                log_message INFO "Killing process $pid..."
                if sudo kill "$pid"; then
                    sleep 2
                    log_message SUCCESS "Process killed"
                else
                    log_message ERROR "Failed to kill process"
                    return 1
                fi
            else
                log_message WARNING "Could not identify process ID"
            fi
        else
            return 1
        fi
    fi
    
    return 0
}

# Start and enable Emby Server
start_emby_service() {
    log_message INFO "Starting and enabling Emby Server service..."
    
    # Check if service is already running
    if sudo systemctl is-active emby-server.service >/dev/null; then
        log_message INFO "Emby Server is already running"
        if confirm "Service is already active. Restart it?"; then
            log_message INFO "Restarting Emby Server..."
            if sudo systemctl restart emby-server.service; then
                log_message SUCCESS "Emby Server restarted successfully"
            else
                log_message ERROR "Failed to restart Emby Server"
                return 1
            fi
        fi
        return 0
    fi
    
    # Check for port conflicts before starting
    if ! check_port_conflicts; then
        log_message ERROR "Port conflict detected, cannot start service"
        return 1
    fi
    
    # Enable service
    if sudo systemctl enable emby-server.service; then
        log_message SUCCESS "Emby Server service enabled"
    else
        log_message ERROR "Failed to enable Emby Server service"
        return 1
    fi
    
    # Start service
    if sudo systemctl start emby-server.service; then
        log_message SUCCESS "Emby Server service started"
    else
        if should_fix "Failed to start Emby Server service" "Check service status and logs"; then
            log_message INFO "Service status:"
            sudo systemctl status emby-server.service
            log_message INFO "Recent logs:"
            sudo journalctl -u emby-server.service --no-pager -n 20
            
            if confirm "Try starting service again?"; then
                if sudo systemctl start emby-server.service; then
                    log_message SUCCESS "Service started successfully on retry"
                else
                    log_message ERROR "Service still failed to start"
                    return 1
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    fi
    
    # Wait for service to be fully started
    log_message INFO "Waiting for service to fully start..."
    local attempts=0
    while [[ $attempts -lt 30 ]]; do
        if sudo systemctl is-active emby-server.service >/dev/null; then
            log_message SUCCESS "Emby Server is now running"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    log_message WARNING "Service may not be fully started yet"
    return 0
}

# Backup Emby data
backup_emby_data() {
    log_message INFO "Starting Emby data backup..."
    
    # Auto-detect data directory
    if ! detect_emby_data_dir; then
        log_message WARNING "Could not detect Emby data directory"
    fi
    
    if ! sudo test -d "$EMBY_DATA_DIR" 2>/dev/null; then
        log_message ERROR "Emby data directory not found: $EMBY_DATA_DIR"
        log_message INFO "Searched locations:"
        echo "  - /var/lib/emby (symlink)"
        echo "  - /var/lib/private/emby (private namespace)"
        echo "  - /home/emby/.config/emby-server"
        echo "  - /opt/emby-server/programdata"
        return 1
    fi
    
    # Create timestamped backup directory
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/emby_backup_$timestamp"
    
    if sudo mkdir -p "$backup_path"; then
        sudo chown "$USER:$USER" "$backup_path"
        log_message SUCCESS "Created backup directory: $backup_path"
    else
        log_message ERROR "Failed to create backup directory"
        return 1
    fi
    
    # Stop Emby service before backup
    log_message INFO "Stopping Emby service for backup..."
    sudo systemctl stop emby-server.service
    
    # First, check what's actually in the data directory
    log_message DEBUG "Checking contents of $EMBY_DATA_DIR:"
    sudo ls -la "$EMBY_DATA_DIR" 2>/dev/null | head -10
    
    # Backup all contents of the data directory (not just predefined folders)
    log_message INFO "Backing up all Emby data..."
    if sudo cp -r "$EMBY_DATA_DIR"/* "$backup_path/" 2>/dev/null; then
        # Fix ownership of copied files
        sudo chown -R "$USER:$USER" "$backup_path/"
        log_message SUCCESS "Backed up all Emby data"
    else
        log_message WARNING "No data found or failed to backup, trying individual directories..."
        
        # Fallback: try common directory names
        local essential_dirs=(config data logs plugins metadata cache)
        local backed_up_any=false
        
        for dir in "${essential_dirs[@]}"; do
            if sudo test -d "$EMBY_DATA_DIR/$dir" 2>/dev/null; then
                log_message INFO "Backing up $dir..."
                if sudo cp -r "$EMBY_DATA_DIR/$dir" "$backup_path/"; then
                    sudo chown -R "$USER:$USER" "$backup_path/$dir"
                    log_message SUCCESS "Backed up $dir"
                    backed_up_any=true
                else
                    log_message ERROR "Failed to backup $dir"
                fi
            else
                log_message DEBUG "Directory not found: $EMBY_DATA_DIR/$dir"
            fi
        done
        
        if [[ "$backed_up_any" == "false" ]]; then
            log_message ERROR "No Emby data found to backup"
            sudo systemctl start emby-server.service
            return 1
        fi
    fi
    
    # Create backup metadata
    cat > "$backup_path/backup_info.txt" << EOF
Emby Server Backup
Timestamp: $timestamp
Emby Version: $(pacman -Qi emby-server | grep Version | cut -d: -f2 | tr -d ' ')
System: $(uname -a)
User: $USER
EOF
    
    # Create compressed archive
    log_message INFO "Creating compressed archive..."
    if tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$(basename "$backup_path")"; then
        log_message SUCCESS "Compressed backup created: $backup_path.tar.gz"
        rm -rf "$backup_path"
    else
        log_message WARNING "Failed to create compressed archive, keeping uncompressed backup"
    fi
    
    # Restart Emby service
    log_message INFO "Restarting Emby service..."
    sudo systemctl start emby-server.service
    
    log_message SUCCESS "Backup completed successfully"
    return 0
}

# Restore Emby data
restore_emby_data() {
    log_message INFO "Starting Emby data restore..."
    
    # Auto-detect data directory
    detect_emby_data_dir
    
    # Check if backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_message ERROR "Backup directory not found: $BACKUP_DIR"
        return 1
    fi
    
    # List available backups
    log_message INFO "Available backups:"
    local backup_files=()
    mapfile -t backup_files < <(find "$BACKUP_DIR" -name "emby_backup_*.tar.gz" -o -name "emby_backup_*" -type d 2>/dev/null | sort)
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        log_message ERROR "No backups found in $BACKUP_DIR"
        return 1
    fi
    
    # Display backup options
    local backup_index=1
    for backup in "${backup_files[@]}"; do
        echo "$backup_index) $(basename "$backup")"
        ((backup_index++))
    done
    
    # Get user selection
    while true; do
        echo -n "Select backup to restore (1-${#backup_files[@]}, or 0 to cancel): "
        read -r choice
        if [[ "$choice" == "0" ]]; then
            log_message INFO "Restore cancelled by user"
            return 0
        elif [[ "$choice" -ge 1 && "$choice" -le ${#backup_files[@]} ]]; then
            local selected_backup="${backup_files[$((choice-1))]}"
            log_message INFO "Selected backup: $(basename "$selected_backup")"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
    
    # Confirm restore
    if ! confirm "This will overwrite current Emby data. Continue?"; then
        log_message INFO "Restore cancelled by user"
        return 0
    fi
    
    # Stop Emby service
    log_message INFO "Stopping Emby service..."
    sudo systemctl stop emby-server.service
    
    # Backup current data
    local current_backup="$BACKUP_DIR/emby_before_restore_$(date +%Y%m%d_%H%M%S)"
    log_message INFO "Backing up current data to: $current_backup"
    if cp -r "$EMBY_DATA_DIR" "$current_backup"; then
        log_message SUCCESS "Current data backed up"
    else
        log_message ERROR "Failed to backup current data"
        sudo systemctl start emby-server.service
        return 1
    fi
    
    # Clear existing data
    log_message INFO "Clearing existing Emby data..."
    sudo rm -rf "${EMBY_DATA_DIR:?}"/*
    
    # Restore from backup
    log_message INFO "Restoring from backup..."
    if [[ "$selected_backup" == *.tar.gz ]]; then
        # Extract compressed backup
        local temp_dir
        temp_dir=$(mktemp -d)
        if tar -xzf "$selected_backup" -C "$temp_dir"; then
            if sudo cp -r "$temp_dir"/*/* "$EMBY_DATA_DIR"; then
                log_message SUCCESS "Data restored from compressed backup"
                rm -rf "$temp_dir"
            else
                log_message ERROR "Failed to copy restored data"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log_message ERROR "Failed to extract backup archive"
            return 1
        fi
    else
        # Restore from uncompressed backup
        if sudo cp -r "$selected_backup"/* "$EMBY_DATA_DIR"; then
            log_message SUCCESS "Data restored from uncompressed backup"
        else
            log_message ERROR "Failed to restore data"
            return 1
        fi
    fi
    
    # Fix permissions (detect dynamic user ownership)
    log_message INFO "Fixing permissions..."
    
    # Get the actual ownership
    local actual_owner
    actual_owner=$(get_emby_ownership)
    log_message DEBUG "Detected ownership: $actual_owner"
    
    if sudo chown -R "$actual_owner" "$EMBY_DATA_DIR"; then
        log_message SUCCESS "Permissions fixed using detected ownership ($actual_owner)"
    else
        log_message WARNING "Failed to fix permissions with detected ownership, trying systemd-managed approach"
        # Let systemd handle the permissions by restarting the service
        sudo systemctl restart emby-server.service
        sleep 3
        log_message INFO "Systemd will handle dynamic user permissions automatically"
    fi
    
    # Restart Emby service
    log_message INFO "Starting Emby service..."
    if sudo systemctl start emby-server.service; then
        log_message SUCCESS "Emby service restarted"
    else
        log_message ERROR "Failed to start Emby service"
        return 1
    fi
    
    log_message SUCCESS "Restore completed successfully"
    return 0
}

# Verify installation
verify_installation() {
    log_message INFO "Verifying Emby Server installation..."
    
    # Auto-detect data directory
    detect_emby_data_dir
    
    # Check if service is running
    if sudo systemctl is-active emby-server.service >/dev/null; then
        log_message SUCCESS "Emby Server service is running"
    else
        log_message ERROR "Emby Server service is not running"
        return 1
    fi
    
    # Check if service is enabled
    if sudo systemctl is-enabled emby-server.service >/dev/null; then
        log_message SUCCESS "Emby Server service is enabled"
    else
        log_message WARNING "Emby Server service is not enabled for autostart"
    fi
    
    # Check if web interface is accessible
    log_message INFO "Checking web interface accessibility..."
    local attempts=0
    local max_attempts=10
    local interface_ready=false
    
    while [[ $attempts -lt $max_attempts ]]; do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8096 2>/dev/null)
        if [[ "$http_code" =~ ^(200|302)$ ]]; then
            interface_ready=true
            break
        fi
        sleep 2
        ((attempts++))
        log_message DEBUG "Attempt $attempts/$max_attempts: HTTP $http_code"
    done
    
    if [[ "$interface_ready" == "true" ]]; then
        log_message SUCCESS "Web interface is accessible at http://localhost:8096"
    else
        log_message WARNING "Web interface not ready after $max_attempts attempts (HTTP $http_code)"
        log_message INFO "Try accessing http://localhost:8096 manually in a few minutes"
    fi
    
    # Check media directory
    if [[ -d "$MEDIA_DIR" ]]; then
        log_message SUCCESS "Media directory exists: $MEDIA_DIR"
    else
        log_message WARNING "Media directory not found: $MEDIA_DIR"
    fi
    
    # Check backup directory
    if [[ -d "$BACKUP_DIR" ]]; then
        log_message SUCCESS "Backup directory exists: $BACKUP_DIR"
    else
        log_message WARNING "Backup directory not found: $BACKUP_DIR"
    fi
    
    log_message SUCCESS "Installation verification completed"
    return 0
}

# Clean up any existing installations
cleanup_existing_installation() {
    log_message INFO "Cleaning up any existing Emby installations..."
    
    # Stop service if running
    if sudo systemctl is-active emby-server.service >/dev/null; then
        log_message INFO "Stopping existing Emby service..."
        sudo systemctl stop emby-server.service
    fi
    
    # Kill any processes using port 8096
    if netstat -tlnp 2>/dev/null | grep -q ":8096 "; then
        log_message INFO "Killing processes using port 8096..."
        local pids
        mapfile -t pids < <(netstat -tlnp 2>/dev/null | grep ":8096 " | awk '{print $7}' | cut -d'/' -f1 | grep -v '^-$')
        for pid in "${pids[@]}"; do
            if [[ -n "$pid" ]]; then
                sudo kill "$pid" 2>/dev/null
            fi
        done
        sleep 3
    fi
    
    log_message SUCCESS "Cleanup completed"
    return 0
}

# Full installation process
full_installation() {
    log_message INFO "Starting full Emby Server installation..."
    
    init_progress 9
    
    update_progress "Cleaning up existing installations"
    if ! cleanup_existing_installation; then
        log_message ERROR "Cleanup failed"
        return 1
    fi
    
    update_progress "Checking system requirements"
    if ! check_system_requirements; then
        log_message ERROR "System requirements check failed"
        return 1
    fi
    
    update_progress "Checking dependencies"
    if ! check_dependencies; then
        log_message ERROR "Dependency check failed"
        return 1
    fi
    
    update_progress "Ensuring AUR helper is available"
    if ! ensure_aur_helper; then
        log_message ERROR "AUR helper setup failed"
        return 1
    fi
    
    update_progress "Setting up Hyprland compatibility"
    if ! setup_hyprland_compatibility; then
        log_message ERROR "Hyprland compatibility setup failed"
        return 1
    fi
    
    update_progress "Installing Emby Server"
    if ! install_emby_server; then
        log_message ERROR "Emby Server installation failed"
        return 1
    fi
    
    update_progress "Configuring Emby Server"
    if ! configure_emby_server; then
        log_message ERROR "Emby Server configuration failed"
        return 1
    fi
    
    update_progress "Starting Emby service"
    if ! start_emby_service; then
        log_message ERROR "Emby service startup failed"
        return 1
    fi
    
    update_progress "Verifying installation"
    if ! verify_installation; then
        log_message WARNING "Installation verification had issues"
    fi
    
    log_message SUCCESS "Full installation completed successfully!"
    echo ""
    echo "=== Installation Complete ==="
    echo "• Emby Server is now running"
    echo "• Web interface: http://localhost:8096"
    echo "• Media directory: $MEDIA_DIR"
    echo "• Backup directory: $BACKUP_DIR"
    echo "• Log file: $LOG_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Open http://localhost:8096 in your browser"
    echo "2. Complete the initial setup wizard"
    echo "3. Add your media libraries"
    echo "4. Configure users and permissions"
    echo ""
}

# Service management submenu
service_management() {
    while true; do
        echo ""
        echo "=== Service Management ==="
        echo "1. Start Emby Server"
        echo "2. Stop Emby Server"
        echo "3. Restart Emby Server"
        echo "4. Enable Emby Server (autostart)"
        echo "5. Disable Emby Server (no autostart)"
        echo "6. View Service Status"
        echo "7. View Service Logs"
        echo "0. Back to Main Menu"
        echo ""
        
        echo -n "Select an option: "
        read -r choice
        
        case "$choice" in
            1)
                log_message INFO "Starting Emby Server..."
                sudo systemctl start emby-server.service
                ;;
            2)
                log_message INFO "Stopping Emby Server..."
                sudo systemctl stop emby-server.service
                ;;
            3)
                log_message INFO "Restarting Emby Server..."
                sudo systemctl restart emby-server.service
                ;;
            4)
                log_message INFO "Enabling Emby Server for autostart..."
                sudo systemctl enable emby-server.service
                ;;
            5)
                log_message INFO "Disabling Emby Server autostart..."
                sudo systemctl disable emby-server.service
                ;;
            6)
                echo ""
                sudo systemctl status emby-server.service
                ;;
            7)
                echo ""
                sudo journalctl -u emby-server.service --no-pager -n 50
                ;;
            0)
                return 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# View logs
view_logs() {
    echo ""
    echo "=== Script Logs ==="
    echo "Log file: $LOG_FILE"
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 50 "$LOG_FILE"
    else
        echo "No log file found."
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Toggle debug mode
toggle_debug_mode() {
    if [[ $DEBUG_MODE -eq 0 ]]; then
        DEBUG_MODE=1
        log_message INFO "Debug mode enabled"
    else
        DEBUG_MODE=0
        log_message INFO "Debug mode disabled"
    fi
}

# Main menu
show_main_menu() {
    while true; do
        echo ""
        echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
        echo "1. Full Installation"
        echo "2. Backup Emby Data"
        echo "3. Restore Emby Data"
        echo "4. Verify Installation"
        echo "5. View Logs"
        echo "6. Service Management"
        echo "7. Emergency Cleanup"
        echo "8. Debug Mode Toggle"
        echo "0. Exit"
        echo ""
        
        echo -n "Select an option: "
        read -r choice
        
        case "$choice" in
            1)
                full_installation || log_message ERROR "Full installation failed"
                ;;
            2)
                backup_emby_data || log_message ERROR "Backup failed"
                ;;
            3)
                restore_emby_data || log_message ERROR "Restore failed"
                ;;
            4)
                verify_installation || log_message ERROR "Verification failed"
                ;;
            5)
                view_logs
                ;;
            6)
                service_management
                ;;
            7)
                cleanup_existing_installation || log_message ERROR "Cleanup failed"
                ;;
            8)
                toggle_debug_mode
                ;;
            0)
                log_message INFO "Exiting $SCRIPT_NAME"
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Cleanup function
cleanup() {
    log_message INFO "Cleaning up temporary files..."
    # Add cleanup code here if needed
    echo -e "${COLOR_RESET}"
}

# Signal handling
handle_interrupt() {
    log_message WARNING "Script interrupted by user"
    cleanup
    exit 130
}

# Main execution
main() {
    # Set up signal handling
    trap handle_interrupt INT TERM
    
    # Create log file
    touch "$LOG_FILE"
    
    # Display welcome message
    echo ""
    echo "======================================"
    echo "   $SCRIPT_NAME v$SCRIPT_VERSION"  
    echo "======================================"
    echo ""
    echo "This script will help you:"
    echo "• Install Emby Server on Arch Linux"
    echo "• Configure it for Hyprland compatibility"
    echo "• Set up media directories"
    echo "• Manage backups and restores"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Go directly to main menu
    show_main_menu
}

# Run main function
main "$@"