#!/bin/bash

# qBittorrent-nox Setup Script
# Sets up qBittorrent headless client with proper systemd service

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
readonly LOG_DIR="${DOTFILES_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/qbittorrent-setup_$(date +%Y%m%d_%H%M%S).log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging functions
log_info() {
    local msg="$1"
    echo -e "\033[36m[INFO]\033[0m $msg" | tee -a "$LOG_FILE"
}

log_success() {
    local msg="$1"
    echo -e "\033[32m[SUCCESS]\033[0m $msg" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "\033[31m[ERROR]\033[0m $msg" | tee -a "$LOG_FILE"
}

log_warning() {
    local msg="$1"
    echo -e "\033[33m[WARNING]\033[0m $msg" | tee -a "$LOG_FILE"
}

log_section() {
    local msg="$1"
    echo -e "\n\033[35m=== $msg ===\033[0m" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Check if qbittorrent-nox is installed
check_qbittorrent_installed() {
    if ! command -v qbittorrent-nox &> /dev/null; then
        log_error "qbittorrent-nox is not installed. Please run package installation script first."
        exit 1
    fi
    log_success "qbittorrent-nox is installed"
}

# Create qbittorrent system user and group
create_qbittorrent_user() {
    log_info "Creating qbittorrent system user and group..."
    
    # Create group if it doesn't exist
    if ! getent group qbittorrent >/dev/null 2>&1; then
        sudo groupadd -r qbittorrent
        log_success "Created qbittorrent group"
    else
        log_info "qbittorrent group already exists"
    fi
    
    # Create user if it doesn't exist
    if ! getent passwd qbittorrent >/dev/null 2>&1; then
        sudo useradd -r -g qbittorrent -d /var/lib/qbittorrent -s /usr/bin/nologin -c "qBittorrent service user" qbittorrent
        log_success "Created qbittorrent user"
    else
        log_info "qbittorrent user already exists"
    fi
}

# Create working directory with proper permissions
setup_working_directory() {
    log_info "Setting up qBittorrent working directory..."
    
    local work_dir="/var/lib/qbittorrent"
    
    # Create directory if it doesn't exist
    if [[ ! -d "$work_dir" ]]; then
        sudo mkdir -p "$work_dir"
        log_success "Created $work_dir"
    fi
    
    # Set proper ownership and permissions
    sudo chown qbittorrent:qbittorrent "$work_dir"
    sudo chmod 755 "$work_dir"
    log_success "Set permissions for $work_dir"
    
    # Create config directory
    local config_dir="$work_dir/.config/qBittorrent"
    if [[ ! -d "$config_dir" ]]; then
        sudo mkdir -p "$config_dir"
        sudo chown qbittorrent:qbittorrent "$config_dir"
        sudo chmod 755 "$config_dir"
        log_success "Created config directory"
    fi
}

# Create systemd service file
create_systemd_service() {
    log_info "Creating qBittorrent systemd service..."
    
    local service_file="/etc/systemd/system/qbittorrent-nox.service"
    
    # Create service file
    sudo tee "$service_file" > /dev/null << 'EOF'
[Unit]
Description=qBittorrent-nox service
After=network.target

[Service]
User=qbittorrent
Group=qbittorrent
ExecStart=/usr/bin/qbittorrent-nox
WorkingDirectory=/var/lib/qbittorrent
Restart=on-failure
TimeoutStopSec=30
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Created systemd service file"
}

# Create user service link for convenience
create_user_service_link() {
    log_info "Creating user service link..."
    
    local user_service_dir="$HOME/.config/systemd/user"
    local user_service_file="$user_service_dir/qbittorrent-nox.service"
    
    # Create user systemd directory if it doesn't exist
    mkdir -p "$user_service_dir"
    
    # Create user service file that starts the system service
    cat > "$user_service_file" << 'EOF'
[Unit]
Description=qBittorrent-nox (User Control)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/sudo /usr/bin/systemctl start qbittorrent-nox.service
ExecStop=/usr/bin/sudo /usr/bin/systemctl stop qbittorrent-nox.service
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF
    
    log_success "Created user service link"
}

# Setup sudo permissions for service control
setup_sudo_permissions() {
    log_info "Setting up sudo permissions for qBittorrent service control..."
    
    local sudoers_file="/etc/sudoers.d/qbittorrent-$(whoami)"
    
    # Create sudoers file for qbittorrent service control
    sudo tee "$sudoers_file" > /dev/null << EOF
# Allow $(whoami) to control qbittorrent-nox service without password
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl start qbittorrent-nox.service
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop qbittorrent-nox.service
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart qbittorrent-nox.service
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl status qbittorrent-nox.service
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl enable qbittorrent-nox.service
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl disable qbittorrent-nox.service
EOF
    
    log_success "Created sudo permissions for service control"
}

# Enable and start the service
enable_and_start_service() {
    log_info "Enabling and starting qBittorrent service..."
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable the service
    sudo systemctl enable qbittorrent-nox.service
    log_success "Enabled qbittorrent-nox.service"
    
    # Start the service
    sudo systemctl start qbittorrent-nox.service
    
    # Check if service started successfully
    if sudo systemctl is-active --quiet qbittorrent-nox.service; then
        log_success "qBittorrent service started successfully"
    else
        log_warning "qBittorrent service failed to start. Check logs with: journalctl -u qbittorrent-nox.service"
    fi
}

# Setup web UI access information
show_access_info() {
    log_section "qBittorrent Setup Complete"
    
    echo "qBittorrent Web UI Access:" | tee -a "$LOG_FILE"
    echo "  URL: http://localhost:9090" | tee -a "$LOG_FILE"
    echo "  Default Username: admin" | tee -a "$LOG_FILE"
    echo "  Default Password: adminadmin" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Service Management:" | tee -a "$LOG_FILE"
    echo "  Start:   sudo systemctl start qbittorrent-nox.service" | tee -a "$LOG_FILE"
    echo "  Stop:    sudo systemctl stop qbittorrent-nox.service" | tee -a "$LOG_FILE"
    echo "  Restart: sudo systemctl restart qbittorrent-nox.service" | tee -a "$LOG_FILE"
    echo "  Status:  sudo systemctl status qbittorrent-nox.service" | tee -a "$LOG_FILE"
    echo "  Logs:    journalctl -u qbittorrent-nox.service -f" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "⚠️  Remember to change the default password after first login!" | tee -a "$LOG_FILE"
}

# Setup qBittorrent configuration
setup_qbittorrent_config() {
    log_info "Setting up qBittorrent configuration..."
    
    local config_file="/var/lib/qbittorrent/.config/qBittorrent/qBittorrent.conf"
    
    # Create initial configuration with port 9090
    sudo tee "$config_file" > /dev/null << 'EOF'
[BitTorrent]
Session\DefaultSavePath=/var/lib/qbittorrent/downloads
Session\TempPath=/var/lib/qbittorrent/temp

[Core]
AutoDeleteAddedTorrentFile=Never

[Network]
PortRangeMin=6881
Proxy\OnlyForTorrents=false

[Preferences]
Advanced\RecheckOnCompletion=false
Advanced\trackerPort=9000
Bittorrent\AddTrackers=false
Bittorrent\DHT=true
Bittorrent\Encryption=1
Bittorrent\LSD=true
Bittorrent\MaxRatio=-1
Bittorrent\PeX=true
Bittorrent\uTP=true
Connection\PortRangeMin=6881
Connection\UPnP=true
Downloads\SavePath=/var/lib/qbittorrent/downloads
Downloads\TempPath=/var/lib/qbittorrent/temp
General\Locale=
Queueing\MaxActiveDownloads=3
Queueing\MaxActiveTorrents=5
Queueing\MaxActiveUploads=3
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=true
WebUI\ClickjackingProtection=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\CertificatePath=
WebUI\HTTPS\Enabled=false
WebUI\HTTPS\KeyPath=
WebUI\HostHeaderValidation=true
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=9090
WebUI\RootFolder=
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\UseUPnP=false
WebUI\Username=admin
EOF
    
    # Set proper ownership
    sudo chown qbittorrent:qbittorrent "$config_file"
    sudo chmod 644 "$config_file"
    
    # Create download directories
    sudo mkdir -p "/var/lib/qbittorrent/downloads"
    sudo mkdir -p "/var/lib/qbittorrent/temp"
    sudo chown -R qbittorrent:qbittorrent "/var/lib/qbittorrent/downloads"
    sudo chown -R qbittorrent:qbittorrent "/var/lib/qbittorrent/temp"
    sudo chmod 755 "/var/lib/qbittorrent/downloads"
    sudo chmod 755 "/var/lib/qbittorrent/temp"
    
    log_success "Created qBittorrent configuration with port 9090"
}

# Check for port conflicts
check_port_conflicts() {
    log_info "Checking for port conflicts on 9090..."
    
    if netstat -tuln 2>/dev/null | grep -q ":9090 "; then
        log_warning "Port 9090 is already in use. You may need to configure qBittorrent to use a different port."
        log_info "To change port: Web UI → Tools → Options → Web UI → Port"
    else
        log_success "Port 9090 is available"
    fi
}

# Main execution
main() {
    log_section "qBittorrent-nox Setup"
    log_info "Starting qBittorrent setup for user: $(whoami)"
    log_info "Log file: $LOG_FILE"
    
    check_root
    check_qbittorrent_installed
    create_qbittorrent_user
    setup_working_directory
    setup_qbittorrent_config
    create_systemd_service
    create_user_service_link
    setup_sudo_permissions
    check_port_conflicts
    enable_and_start_service
    show_access_info
    
    log_success "qBittorrent setup completed successfully!"
    log_info "Check the log file for details: $LOG_FILE"
}

# Run main function
main "$@"