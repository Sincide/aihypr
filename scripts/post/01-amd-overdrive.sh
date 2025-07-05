#!/bin/bash
#
# AMD Overdrive Enabler Script
# Enables AMD GPU overclocking and power control features
#

set -e  # Exit on any error

# Text formatting
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}${BOLD}Error: This script must be run as root!${RESET}"
    echo "Please run again with sudo: sudo $0"
    exit 1
fi

# Check if system has AMD GPU
check_amd_gpu() {
    if ! lspci | grep -i "VGA\|3D" | grep -i "AMD\|ATI" > /dev/null; then
        echo -e "${YELLOW}${BOLD}Warning: No AMD GPU detected in this system!${RESET}"
        echo "This script is intended for systems with AMD graphics cards."
        read -p "Continue anyway? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 0
        fi
    else
        echo -e "${GREEN}AMD GPU detected.${RESET}"
    fi
}

# Apply kernel parameters for AMD Overdrive with systemd-boot
apply_kernel_parameters() {
    echo -e "${BLUE}${BOLD}Configuring systemd-boot for AMD Overdrive...${RESET}"
    
    # Check if systemd-boot entries directory exists
    if [ ! -d "/boot/loader/entries" ]; then
        echo -e "${RED}${BOLD}Error: systemd-boot entries directory not found!${RESET}"
        echo "This system doesn't appear to be using systemd-boot or it's configured in a non-standard way."
        echo "Please manually add 'amdgpu.ppfeaturemask=0xffffffff' to your kernel parameters."
        exit 1
    fi
    
    # Find all kernel entries
    local entries=($(find /boot/loader/entries -name "*.conf"))
    
    if [ ${#entries[@]} -eq 0 ]; then
        echo -e "${RED}No systemd-boot entries found in /boot/loader/entries/.${RESET}"
        exit 1
    fi
    
    echo -e "${BLUE}Found ${#entries[@]} systemd-boot entries to modify.${RESET}"
    
    for entry in "${entries[@]}"; do
        echo -e "${BLUE}Processing entry: $(basename "$entry")${RESET}"
        
        # Skip if already configured
        if grep -q "amdgpu.ppfeaturemask=0xffffffff" "$entry"; then
            echo -e "${GREEN}AMD Overdrive already enabled in this entry.${RESET}"
            continue
        fi
        
        # Backup entry
        cp "$entry" "${entry}.backup"
        
        # Add parameter to options line
        if grep -q "^options" "$entry"; then
            sed -i 's/^options \(.*\)/options \1 amdgpu.ppfeaturemask=0xffffffff/' "$entry"
        else
            echo "options amdgpu.ppfeaturemask=0xffffffff" >> "$entry"
        fi
        
        echo -e "${GREEN}AMD Overdrive enabled in $(basename "$entry").${RESET}"
    done
    
    echo -e "${GREEN}${BOLD}systemd-boot configuration completed successfully!${RESET}"
}

# Configure kernel module parameters via modprobe
configure_modprobe() {
    echo -e "${BLUE}Configuring AMD GPU module parameters...${RESET}"
    
    # Create modprobe.d config file
    local config_file="/etc/modprobe.d/amdgpu-overdrive.conf"
    
    # Check if file already exists with right content
    if [ -f "$config_file" ] && grep -q "options amdgpu ppfeaturemask=0xffffffff" "$config_file"; then
        echo -e "${GREEN}Modprobe configuration already exists.${RESET}"
    else
        # Backup if exists
        [ -f "$config_file" ] && cp "$config_file" "${config_file}.backup"
        
        # Create/overwrite the file
        echo "# Enable AMD Overdrive features" > "$config_file"
        echo "options amdgpu ppfeaturemask=0xffffffff" >> "$config_file"
        
        echo -e "${GREEN}Created modprobe configuration for AMD Overdrive.${RESET}"
    fi
}

# Apply changes to running system (without reboot)
apply_runtime_settings() {
    echo -e "${BLUE}Trying to apply settings to running system...${RESET}"
    
    if [ -d "/sys/module/amdgpu/parameters/" ]; then
        if [ -f "/sys/module/amdgpu/parameters/ppfeaturemask" ]; then
            # First try using tee which works better with sudo
            if echo "0xffffffff" | sudo tee /sys/module/amdgpu/parameters/ppfeaturemask >/dev/null 2>&1; then
                echo -e "${GREEN}Applied settings to running system! No reboot needed.${RESET}"
            else
                echo -e "${YELLOW}Cannot modify running kernel parameters due to permissions.${RESET}"
                echo -e "${YELLOW}This is normal on some systems with locked-down sysfs.${RESET}"
                echo -e "${YELLOW}A reboot is required for changes to take effect.${RESET}"
            fi
        else
            echo -e "${YELLOW}AMD GPU parameter file not found. Reboot required.${RESET}"
        fi
    else
        echo -e "${YELLOW}AMD GPU module not loaded or accessible. Reboot required.${RESET}"
    fi
}

# Print a summary of changes
print_summary() {
    echo ""
    echo -e "${BLUE}${BOLD}=== AMD Overdrive Configuration Summary ===${RESET}"
    echo -e "${GREEN}✓ systemd-boot kernel parameters configured for AMD Overdrive${RESET}"
    echo -e "${GREEN}✓ Module parameters set via modprobe${RESET}"
    
    # Check current state
    local current_mask=""
    if [ -f "/sys/module/amdgpu/parameters/ppfeaturemask" ]; then
        current_mask=$(cat /sys/module/amdgpu/parameters/ppfeaturemask)
        if [ "$current_mask" = "0xffffffff" ]; then
            echo -e "${GREEN}✓ AMD Overdrive is ACTIVE in current session${RESET}"
        else
            echo -e "${YELLOW}✗ AMD Overdrive is NOT ACTIVE in current session (reboot required)${RESET}"
        fi
    else
        echo -e "${YELLOW}✗ Cannot determine current AMD GPU status${RESET}"
    fi
    
    echo ""
    echo -e "${BOLD}What's next?${RESET}"
    if [ "$current_mask" != "0xffffffff" ]; then
        echo -e "${YELLOW}Please reboot your system to activate AMD Overdrive.${RESET}"
    fi
    echo -e "After reboot, you can use tools like ${BOLD}CoreCtrl${RESET} or ${BOLD}radeon-profile${RESET} to manage your GPU settings."
    echo -e "You can also check if Overdrive is enabled with: ${BOLD}cat /sys/module/amdgpu/parameters/ppfeaturemask${RESET}"
    echo -e "The value should be ${BOLD}0xffffffff${RESET} when enabled."
}

# Main execution
echo -e "${BLUE}${BOLD}=== AMD Overdrive Enabler for systemd-boot ===${RESET}"
echo "This script will enable AMD GPU Overdrive features by setting kernel parameters."
echo -e "${YELLOW}This may void your warranty and could potentially damage your hardware if used improperly.${RESET}"
read -p "Continue? [y/N] " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Execute functions
check_amd_gpu
apply_kernel_parameters
configure_modprobe
apply_runtime_settings
print_summary

exit 0 