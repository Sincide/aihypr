#!/bin/bash

# Arch Linux ROCm + Ollama GPU Setup Script
# For AMD RX 7900 series and other supported GPUs
# Author: Based on troubleshooting session
# Version: 1.0

set -e  # Exit on any error

# Configuration
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_dry_run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $1"
    fi
}

# Wrapper function for executing commands with dry-run support
execute_command() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would execute: $*"
    else
        "$@"
    fi
}

# Check if running on Arch Linux
check_arch() {
    if ! command -v pacman &> /dev/null; then
        log_error "This script is designed for Arch Linux only!"
        exit 1
    fi
    log_success "Detected Arch Linux"
}

# Check for AMD GPU
check_amd_gpu() {
    if ! lspci | grep -i amd | grep -E "(VGA|3D)" > /dev/null; then
        log_warning "No AMD GPU detected. This script is for AMD GPUs."
        echo "Continue anyway? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        local gpu_info=$(lspci | grep -i amd | grep -E "(VGA|3D)")
        log_success "Found AMD GPU: $gpu_info"
    fi
}

# Detect GPU generation for HSA_OVERRIDE_GFX_VERSION
detect_gpu_generation() {
    local gpu_info=$(lspci | grep -i amd | grep -E "(VGA|3D)" | head -n1)
    
    if echo "$gpu_info" | grep -E "(RX 7[0-9][0-9][0-9]|Navi 31|Navi 32|Navi 33)" > /dev/null; then
        echo "11.0.0"  # RDNA 3 (RX 7000 series)
    elif echo "$gpu_info" | grep -E "(RX 6[0-9][0-9][0-9]|Navi 2[0-9])" > /dev/null; then
        echo "10.3.0"  # RDNA 2 (RX 6000 series)
    elif echo "$gpu_info" | grep -E "(RX 5[0-9][0-9][0-9]|Navi 1[0-9])" > /dev/null; then
        echo "10.1.0"  # RDNA 1 (RX 5000 series)
    else
        log_warning "Could not automatically detect GPU generation. Using 11.0.0 (RX 7000 series default)"
        echo "11.0.0"
    fi
}

# Check and install AUR helper
install_aur_helper() {
    if command -v yay &> /dev/null; then
        log_success "AUR helper 'yay' already installed"
        return
    fi
    
    if command -v paru &> /dev/null; then
        log_success "AUR helper 'paru' already installed"
        # Create yay alias for consistency
        echo "alias yay='paru'" >> ~/.bashrc
        return
    fi
    
    log_info "Installing AUR helper 'yay'..."
    
    # Install dependencies for building yay
    sudo pacman -S --needed --noconfirm git base-devel
    
    # Clone and build yay
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    
    log_success "AUR helper 'yay' installed"
}

# Update system
update_system() {
    log_info "Updating system packages..."
    sudo pacman -Syu --noconfirm
    log_success "System updated"
}

# Install ROCm packages
install_rocm() {
    log_info "Installing ROCm packages..."
    
    # Install ROCm packages from official repos
    sudo pacman -S --needed --noconfirm \
        rocm-opencl-runtime \
        hip-runtime-amd \
        rocm-hip-sdk \
        rocm-smi-lib \
        rocminfo \
        rocm-core
    
    # Install ROCm packages from AUR
    yay -S --needed --noconfirm \
        rocm-hip-sdk \
        rocm-opencl-sdk
    
    log_success "ROCm packages installed"
}

# Install Ollama with ROCm support
install_ollama() {
    log_info "Installing Ollama with ROCm support..."
    
    # Install ollama-rocm from AUR
    yay -S --needed --noconfirm ollama-rocm
    
    log_success "Ollama with ROCm support installed"
}

# Add user to required groups
setup_user_groups() {
    log_info "Adding user to render and video groups..."
    
    sudo usermod -a -G render,video "$USER"
    
    log_success "User added to render and video groups"
}

# Set up environment variables
setup_environment() {
    local gfx_version=$(detect_gpu_generation)
    log_info "Setting up environment variables (HSA_OVERRIDE_GFX_VERSION=$gfx_version)..."
    
    # Detect shell
    local shell_rc=""
    if [[ "$SHELL" == *"fish"* ]]; then
        shell_rc="$HOME/.config/fish/config.fish"
        mkdir -p "$(dirname "$shell_rc")"
        
        # Check if ROCm environment variables already exist
        if grep -q "# ROCm Environment Variables (Added by setup script)" "$shell_rc" 2>/dev/null; then
            log_info "ROCm environment variables already configured in Fish shell"
            
            # Check if HSA_OVERRIDE_GFX_VERSION needs updating
            local current_gfx=$(grep -o "HSA_OVERRIDE_GFX_VERSION [^ ]*" "$shell_rc" 2>/dev/null | cut -d' ' -f2)
            if [[ "$current_gfx" != "$gfx_version" ]]; then
                log_info "Updating HSA_OVERRIDE_GFX_VERSION from $current_gfx to $gfx_version"
                sed -i "s/set -gx HSA_OVERRIDE_GFX_VERSION .*/set -gx HSA_OVERRIDE_GFX_VERSION $gfx_version/" "$shell_rc"
            fi
        else
            # Fish shell syntax
            cat >> "$shell_rc" << EOF

# ROCm Environment Variables (Added by setup script)
set -gx PATH /opt/rocm/bin \$PATH
set -gx ROCM_PATH /opt/rocm
set -gx HSA_OVERRIDE_GFX_VERSION $gfx_version
set -gx LD_LIBRARY_PATH /usr/lib/ollama/rocm:/opt/rocm/lib
EOF
        fi
    else
        # Bash/Zsh syntax
        shell_rc="$HOME/.bashrc"
        
        # Check if ROCm environment variables already exist
        if grep -q "# ROCm Environment Variables (Added by setup script)" "$shell_rc" 2>/dev/null; then
            log_info "ROCm environment variables already configured in Bash shell"
            
            # Check if HSA_OVERRIDE_GFX_VERSION needs updating
            local current_gfx=$(grep -o "HSA_OVERRIDE_GFX_VERSION=[^ ]*" "$shell_rc" 2>/dev/null | cut -d'=' -f2)
            if [[ "$current_gfx" != "$gfx_version" ]]; then
                log_info "Updating HSA_OVERRIDE_GFX_VERSION from $current_gfx to $gfx_version"
                sed -i "s/export HSA_OVERRIDE_GFX_VERSION=.*/export HSA_OVERRIDE_GFX_VERSION=$gfx_version/" "$shell_rc"
            fi
        else
            cat >> "$shell_rc" << EOF

# ROCm Environment Variables (Added by setup script)
export PATH="/opt/rocm/bin:\$PATH"
export ROCM_PATH=/opt/rocm
export HSA_OVERRIDE_GFX_VERSION=$gfx_version
export LD_LIBRARY_PATH=/usr/lib/ollama/rocm:/opt/rocm/lib:\$LD_LIBRARY_PATH
EOF
        fi
    fi
    
    log_success "Environment variables configured in $shell_rc"
}

# Create systemd user service
create_ollama_service() {
    local gfx_version=$(detect_gpu_generation)
    log_info "Creating Ollama systemd user service..."
    
    # Create user systemd directory
    mkdir -p "$HOME/.config/systemd/user"
    
    # Create service file
    cat > "$HOME/.config/systemd/user/ollama.service" << EOF
[Unit]
Description=Ollama AI Platform
Documentation=https://ollama.com/
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
ExecStart=/usr/bin/ollama serve
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=HOME=%h
Environment=ROCM_PATH=/opt/rocm
Environment=HSA_OVERRIDE_GFX_VERSION=$gfx_version
Environment=LD_LIBRARY_PATH=/usr/lib/ollama/rocm:/opt/rocm/lib
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ollama

[Install]
WantedBy=default.target
EOF
    
    log_success "Ollama systemd service created"
}

# Enable and start service
start_ollama_service() {
    log_info "Enabling and starting Ollama service..."
    
    # Reload systemd user configuration
    systemctl --user daemon-reload
    
    # Enable service for auto-start
    systemctl --user enable ollama.service
    
    # Start service
    systemctl --user start ollama.service
    
    log_success "Ollama service enabled and started"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Wait a moment for service to start
    sleep 3
    
    # Check if ROCm tools work
    if /opt/rocm/bin/rocminfo > /dev/null 2>&1; then
        log_success "ROCm tools working"
    else
        log_error "ROCm tools not working properly"
        return 1
    fi
    
    # Check if service is running
    if systemctl --user is-active --quiet ollama.service; then
        log_success "Ollama service is running"
    else
        log_error "Ollama service failed to start"
        systemctl --user status ollama.service
        return 1
    fi
    
    # Test ollama
    log_info "Testing Ollama (this may take a moment)..."
    sleep 5  # Give service time to fully start
    
    if timeout 30 ollama list > /dev/null 2>&1; then
        log_success "Ollama is responding"
    else
        log_warning "Ollama test timed out or failed"
    fi
}

# Print verification commands
print_verification_commands() {
    cat << EOF

${GREEN}=== INSTALLATION COMPLETE ===${NC}

${YELLOW}Verification Commands:${NC}
1. Check GPU detection:
   rocminfo | grep -A5 "Marketing Name"

2. Check GPU usage:
   rocm-smi

3. Check Ollama service:
   systemctl --user status ollama

4. Test GPU acceleration:
   ollama run qwen2.5-coder:1.5b "write hello world in python"
   
   Then monitor GPU usage with:
   watch -n 1 rocm-smi

5. Check Ollama logs:
   journalctl --user -u ollama -f

${YELLOW}Expected Signs of Success:${NC}
- rocminfo shows your AMD GPU
- Ollama logs show "offloaded X/X layers to GPU"
- rocm-smi shows high GPU usage during inference
- Much faster model responses compared to CPU

${YELLOW}Note:${NC} You may need to logout/login or reboot for group membership to take effect.

${GREEN}Enjoy your GPU-accelerated AI setup!${NC}
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=true
                log_info "Running in DRY-RUN mode - no changes will be made"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help message
show_help() {
    cat << EOF
Arch Linux ROCm + Ollama GPU Setup Script

Usage: $0 [OPTIONS]

Options:
    -n, --dry-run    Run in dry-run mode (show what would be done)
    -h, --help       Show this help message

This script sets up ROCm and Ollama with GPU acceleration for AMD graphics cards.
It will install required packages, configure environment variables, and set up services.

The script is safe to run multiple times - it will detect existing configurations
and only make necessary changes.
EOF
}

# Main execution
main() {
    # Parse arguments first
    parse_arguments "$@"
    
    echo -e "${BLUE}=== Arch Linux ROCm + Ollama GPU Setup ===${NC}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}=== DRY-RUN MODE - No changes will be made ===${NC}"
    fi
    echo
    
    check_arch
    check_amd_gpu
    
    log_info "Starting installation process..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        install_aur_helper
        update_system
        install_rocm
        install_ollama
        setup_user_groups
        setup_environment
        create_ollama_service
        start_ollama_service
        
        if verify_installation; then
            print_verification_commands
            
            echo
            log_success "Setup completed successfully!"
            log_warning "Please logout and login (or reboot) for group membership changes to take effect."
        else
            log_error "Setup completed with errors. Check the logs above."
            exit 1
        fi
    else
        log_dry_run "Would install AUR helper"
        log_dry_run "Would update system packages"
        log_dry_run "Would install ROCm packages"
        log_dry_run "Would install Ollama"
        log_dry_run "Would setup user groups"
        log_dry_run "Would setup environment variables"
        log_dry_run "Would create Ollama service"
        log_dry_run "Would start Ollama service"
        log_info "DRY-RUN completed - use without --dry-run to perform actual installation"
    fi
}

# Run main function
main "$@"