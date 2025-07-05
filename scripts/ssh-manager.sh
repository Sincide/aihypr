#!/bin/bash

# SSH Key Manager - Interactive Backup & Restore System
# Comprehensive SSH key management with menu-driven interface

set -e

# Configuration
BACKUP_DIR="/mnt/Stuff/backups"
SSH_DIR="$HOME/.ssh"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to display the main menu
show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🔐 SSH Key Manager                          ║${NC}"
    echo -e "${CYAN}║                Interactive Backup & Restore                    ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}║  ${YELLOW}1)${NC} 📦 Create New Backup                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}2)${NC} 📋 List Available Backups                               ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}3)${NC} 🔄 Restore from Backup                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}4)${NC} 🗑️  Delete Old Backups                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}5)${NC} 🔍 Show Current SSH Keys                               ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}6)${NC} 🧪 Test SSH Connections                               ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}7)${NC} ⚙️  Settings & Info                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}0)${NC} ❌ Exit                                                ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Current SSH Directory: ${SSH_DIR}${NC}"
    echo -e "${GREEN}Backup Directory: ${BACKUP_DIR}${NC}"
    echo ""
}

# Function to create a new backup
create_backup() {
    clear
    echo -e "${BLUE}📦 Creating SSH Key Backup${NC}"
    echo "=================================="
    echo ""
    
    # Check if SSH directory exists
    if [ ! -d "$SSH_DIR" ]; then
        echo -e "${RED}❌ SSH directory not found: $SSH_DIR${NC}"
        echo -e "${YELLOW}💡 No SSH keys to backup${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show what will be backed up
    echo -e "${BLUE}📋 Current SSH files to backup:${NC}"
    ls -la "$SSH_DIR" 2>/dev/null || echo "No files found"
    echo ""
    
    # Confirm backup
    echo -e "${YELLOW}🤔 Create backup of current SSH keys?${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Backup cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Create backup
    BACKUP_NAME="ssh-keys-${TIMESTAMP}"
    BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
    
    echo -e "${BLUE}📦 Creating backup: $BACKUP_NAME${NC}"
    mkdir -p "$BACKUP_PATH"
    
    # Copy SSH directory contents
    echo -e "${BLUE}📋 Copying SSH keys and configurations...${NC}"
    cp -r "$SSH_DIR"/* "$BACKUP_PATH/" 2>/dev/null || true
    
    # Create metadata file
    echo -e "${BLUE}📝 Creating backup metadata...${NC}"
    cat > "$BACKUP_PATH/backup-info.txt" << EOF
SSH Key Backup Information
==========================
Backup Date: $(date)
Source: $SSH_DIR
Backup Path: $BACKUP_PATH
Hostname: $(hostname)
User: $(whoami)
OS: $(uname -a)

Files backed up:
$(ls -la "$BACKUP_PATH" | grep -v backup-info.txt)
EOF
    
    # Set proper permissions
    echo -e "${BLUE}🔒 Setting proper permissions...${NC}"
    chmod 700 "$BACKUP_PATH"
    find "$BACKUP_PATH" -name "id_*" -not -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true
    find "$BACKUP_PATH" -name "*.pub" -exec chmod 644 {} \; 2>/dev/null || true
    find "$BACKUP_PATH" -name "config" -exec chmod 600 {} \; 2>/dev/null || true
    find "$BACKUP_PATH" -name "known_hosts*" -exec chmod 644 {} \; 2>/dev/null || true
    
    # Create compressed archive
    echo -e "${BLUE}🗜️  Creating compressed archive...${NC}"
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    ARCHIVE_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    
    # Clean up uncompressed directory
    rm -rf "$BACKUP_PATH"
    
    echo ""
    echo -e "${GREEN}✅ SSH keys backed up successfully!${NC}"
    echo -e "${GREEN}📍 Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"
    echo -e "${GREEN}📊 Archive size: ${ARCHIVE_SIZE}${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Function to list available backups
list_backups() {
    clear
    echo -e "${BLUE}📚 Available SSH Key Backups${NC}"
    echo "=================================="
    echo ""
    
    if ls "$BACKUP_DIR"/ssh-keys-*.tar.gz 1> /dev/null 2>&1; then
        echo -e "${GREEN}Found the following backups:${NC}"
        echo ""
        
        # Create a table of backups
        printf "%-5s %-30s %-10s %-20s\n" "No." "Backup Name" "Size" "Date"
        printf "%-5s %-30s %-10s %-20s\n" "----" "------------------------------" "----------" "--------------------"
        
        i=1
        for backup in "$BACKUP_DIR"/ssh-keys-*.tar.gz; do
            filename=$(basename "$backup")
            size=$(du -h "$backup" | cut -f1)
            date=$(stat -c %y "$backup" | cut -d' ' -f1)
            printf "%-5s %-30s %-10s %-20s\n" "$i)" "$filename" "$size" "$date"
            ((i++))
        done
        
        echo ""
        echo -e "${CYAN}📊 Total backups: $((i-1))${NC}"
        
        # Show total size
        total_size=$(du -sh "$BACKUP_DIR"/ssh-keys-*.tar.gz 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
        echo -e "${CYAN}💾 Total size: $(du -sh "$BACKUP_DIR"/ssh-keys-*.tar.gz 2>/dev/null | tail -1 | cut -f1)${NC}"
        
    else
        echo -e "${YELLOW}📭 No SSH key backups found${NC}"
        echo -e "${YELLOW}💡 Create your first backup with option 1${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to restore from backup
restore_backup() {
    clear
    echo -e "${BLUE}🔄 Restore SSH Keys from Backup${NC}"
    echo "=================================="
    echo ""
    
    # Check if backups exist
    if ! ls "$BACKUP_DIR"/ssh-keys-*.tar.gz 1> /dev/null 2>&1; then
        echo -e "${RED}❌ No SSH key backups found${NC}"
        echo -e "${YELLOW}💡 Create a backup first with option 1${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # List available backups
    echo -e "${BLUE}📚 Available backups:${NC}"
    echo ""
    
    backups=()
    i=1
    for backup in "$BACKUP_DIR"/ssh-keys-*.tar.gz; do
        filename=$(basename "$backup")
        size=$(du -h "$backup" | cut -f1)
        date=$(stat -c %y "$backup" | cut -d' ' -f1)
        printf "%-5s %-30s %-10s %-20s\n" "$i)" "$filename" "$size" "$date"
        backups+=("$backup")
        ((i++))
    done
    
    echo ""
    echo -e "${YELLOW}Enter backup number to restore (0 to cancel):${NC}"
    read -p "Choice: " choice
    
    # Validate choice
    if [[ ! $choice =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ]; then
        echo -e "${YELLOW}❌ Restore cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        echo -e "${RED}❌ Invalid choice${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get selected backup
    selected_backup="${backups[$((choice-1))]}"
    backup_name=$(basename "$selected_backup")
    
    echo ""
    echo -e "${BLUE}Selected backup: $backup_name${NC}"
    echo -e "${BLUE}File size: $(du -h "$selected_backup" | cut -f1)${NC}"
    echo ""
    
    # Backup current SSH keys if they exist
    if [ -d "$SSH_DIR" ]; then
        echo -e "${YELLOW}⚠️  Current SSH keys will be backed up before restore${NC}"
        
        CURRENT_BACKUP_NAME="ssh-keys-current-${TIMESTAMP}"
        CURRENT_BACKUP_PATH="${BACKUP_DIR}/${CURRENT_BACKUP_NAME}"
        
        echo -e "${BLUE}🔄 Backing up current SSH keys...${NC}"
        mkdir -p "$CURRENT_BACKUP_PATH"
        cp -r "$SSH_DIR"/* "$CURRENT_BACKUP_PATH/" 2>/dev/null || true
        
        cd "$BACKUP_DIR"
        tar -czf "${CURRENT_BACKUP_NAME}.tar.gz" "$CURRENT_BACKUP_NAME"
        rm -rf "$CURRENT_BACKUP_PATH"
        
        echo -e "${GREEN}✅ Current keys backed up to: ${CURRENT_BACKUP_NAME}.tar.gz${NC}"
        echo ""
    fi
    
    # Final confirmation
    echo -e "${YELLOW}🤔 Are you sure you want to restore from this backup?${NC}"
    echo -e "${YELLOW}   This will replace your current SSH configuration.${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Restore cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Perform restore
    echo -e "${BLUE}📂 Extracting backup...${NC}"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    tar -xzf "$selected_backup"
    
    # Find extracted directory
    EXTRACTED_DIR=$(find . -name "ssh-keys-*" -type d | head -1)
    if [ -z "$EXTRACTED_DIR" ]; then
        echo -e "${RED}❌ Could not find extracted SSH keys${NC}"
        rm -rf "$TEMP_DIR"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Create SSH directory if it doesn't exist
    mkdir -p "$SSH_DIR"
    
    # Copy files back
    echo -e "${BLUE}📋 Restoring SSH keys...${NC}"
    cp -r "$EXTRACTED_DIR"/* "$SSH_DIR/" 2>/dev/null || true
    rm -f "$SSH_DIR/backup-info.txt"
    
    # Set proper permissions
    echo -e "${BLUE}🔒 Setting proper permissions...${NC}"
    chmod 700 "$SSH_DIR"
    find "$SSH_DIR" -name "id_*" -not -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true
    find "$SSH_DIR" -name "*.pub" -exec chmod 644 {} \; 2>/dev/null || true
    find "$SSH_DIR" -name "config" -exec chmod 600 {} \; 2>/dev/null || true
    find "$SSH_DIR" -name "known_hosts*" -exec chmod 644 {} \; 2>/dev/null || true
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    echo ""
    echo -e "${GREEN}✅ SSH keys restored successfully!${NC}"
    echo -e "${GREEN}📍 Restored to: $SSH_DIR${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Function to delete old backups
delete_backups() {
    clear
    echo -e "${BLUE}🗑️  Delete Old SSH Key Backups${NC}"
    echo "=================================="
    echo ""
    
    if ! ls "$BACKUP_DIR"/ssh-keys-*.tar.gz 1> /dev/null 2>&1; then
        echo -e "${YELLOW}📭 No SSH key backups found to delete${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}📚 Available backups:${NC}"
    echo ""
    
    backups=()
    i=1
    for backup in "$BACKUP_DIR"/ssh-keys-*.tar.gz; do
        filename=$(basename "$backup")
        size=$(du -h "$backup" | cut -f1)
        date=$(stat -c %y "$backup" | cut -d' ' -f1)
        printf "%-5s %-30s %-10s %-20s\n" "$i)" "$filename" "$size" "$date"
        backups+=("$backup")
        ((i++))
    done
    
    echo ""
    echo -e "${YELLOW}Enter backup number to delete (0 to cancel):${NC}"
    read -p "Choice: " choice
    
    # Validate choice
    if [[ ! $choice =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ]; then
        echo -e "${YELLOW}❌ Delete cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        echo -e "${RED}❌ Invalid choice${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get selected backup
    selected_backup="${backups[$((choice-1))]}"
    backup_name=$(basename "$selected_backup")
    
    echo ""
    echo -e "${RED}⚠️  Are you sure you want to delete: $backup_name?${NC}"
    echo -e "${RED}   This action cannot be undone!${NC}"
    echo ""
    read -p "Delete? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Delete cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Delete backup
    rm -f "$selected_backup"
    echo -e "${GREEN}✅ Backup deleted: $backup_name${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Function to show current SSH keys
show_current_keys() {
    clear
    echo -e "${BLUE}🔍 Current SSH Keys${NC}"
    echo "=================================="
    echo ""
    
    if [ ! -d "$SSH_DIR" ]; then
        echo -e "${YELLOW}📭 No SSH directory found${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}📂 SSH Directory: $SSH_DIR${NC}"
    echo ""
    
    # Show files with detailed info
    if ls "$SSH_DIR"/* 1> /dev/null 2>&1; then
        echo -e "${GREEN}Files in SSH directory:${NC}"
        ls -la "$SSH_DIR"
        echo ""
        
        # Show key fingerprints
        echo -e "${GREEN}Key fingerprints:${NC}"
        for key in "$SSH_DIR"/*.pub; do
            if [ -f "$key" ]; then
                echo -e "${CYAN}$(basename "$key"):${NC}"
                ssh-keygen -lf "$key" 2>/dev/null || echo "  Could not read key"
            fi
        done
        
        # Show SSH agent status
        echo ""
        echo -e "${GREEN}SSH Agent Status:${NC}"
        if ssh-add -l 2>/dev/null; then
            echo -e "${GREEN}✅ SSH agent is running with loaded keys${NC}"
        else
            echo -e "${YELLOW}⚠️  SSH agent not running or no keys loaded${NC}"
        fi
        
    else
        echo -e "${YELLOW}📭 No files in SSH directory${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to test SSH connections
test_connections() {
    clear
    echo -e "${BLUE}🧪 Test SSH Connections${NC}"
    echo "=================================="
    echo ""
    
    if [ ! -d "$SSH_DIR" ]; then
        echo -e "${RED}❌ No SSH directory found${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}Testing common SSH connections...${NC}"
    echo ""
    
    # Test GitHub
    echo -e "${CYAN}Testing GitHub SSH connection...${NC}"
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo -e "${GREEN}✅ GitHub SSH connection works${NC}"
    else
        echo -e "${YELLOW}⚠️  GitHub SSH connection failed or not configured${NC}"
    fi
    
    # Test SSH agent
    echo ""
    echo -e "${CYAN}Testing SSH agent...${NC}"
    if ssh-add -l 2>/dev/null; then
        echo -e "${GREEN}✅ SSH agent is working${NC}"
    else
        echo -e "${YELLOW}⚠️  SSH agent not running${NC}"
        echo -e "${YELLOW}💡 Start with: eval \$(ssh-agent) && ssh-add${NC}"
    fi
    
    # Show available keys
    echo ""
    echo -e "${CYAN}Available private keys:${NC}"
    for key in "$SSH_DIR"/id_*; do
        if [ -f "$key" ] && [[ ! "$key" == *.pub ]]; then
            keyname=$(basename "$key")
            echo -e "${GREEN}• $keyname${NC}"
            
            # Check if key is loaded
            if ssh-add -l 2>/dev/null | grep -q "$key"; then
                echo -e "  ${GREEN}✅ Loaded in SSH agent${NC}"
            else
                echo -e "  ${YELLOW}⚠️  Not loaded in SSH agent${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}💡 Test commands you can try:${NC}"
    echo -e "${YELLOW}   • ssh -T git@github.com${NC}"
    echo -e "${YELLOW}   • ssh -T git@gitlab.com${NC}"
    echo -e "${YELLOW}   • ssh user@yourserver.com${NC}"
    echo -e "${YELLOW}   • ssh-add ~/.ssh/id_rsa${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Function to show settings and info
show_settings() {
    clear
    echo -e "${BLUE}⚙️  Settings & Information${NC}"
    echo "=================================="
    echo ""
    
    echo -e "${CYAN}📂 Directories:${NC}"
    echo -e "${GREEN}SSH Directory: $SSH_DIR${NC}"
    echo -e "${GREEN}Backup Directory: $BACKUP_DIR${NC}"
    echo ""
    
    echo -e "${CYAN}📊 Statistics:${NC}"
    if [ -d "$SSH_DIR" ]; then
        key_count=$(ls "$SSH_DIR"/id_* 2>/dev/null | wc -l)
        echo -e "${GREEN}SSH Keys: $key_count${NC}"
    else
        echo -e "${YELLOW}SSH Keys: 0 (no SSH directory)${NC}"
    fi
    
    if ls "$BACKUP_DIR"/ssh-keys-*.tar.gz 1> /dev/null 2>&1; then
        backup_count=$(ls "$BACKUP_DIR"/ssh-keys-*.tar.gz | wc -l)
        total_size=$(du -sh "$BACKUP_DIR"/ssh-keys-*.tar.gz 2>/dev/null | tail -1 | cut -f1)
        echo -e "${GREEN}Backups: $backup_count${NC}"
        echo -e "${GREEN}Total Backup Size: $total_size${NC}"
    else
        echo -e "${YELLOW}Backups: 0${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}🖥️  System Information:${NC}"
    echo -e "${GREEN}Hostname: $(hostname)${NC}"
    echo -e "${GREEN}User: $(whoami)${NC}"
    echo -e "${GREEN}OS: $(uname -o)${NC}"
    echo -e "${GREEN}Date: $(date)${NC}"
    
    echo ""
    echo -e "${CYAN}🔧 Customization:${NC}"
    echo -e "${YELLOW}To change backup directory, edit the BACKUP_DIR variable in this script${NC}"
    echo -e "${YELLOW}Current backup directory: $BACKUP_DIR${NC}"
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    # Check if backup directory exists, create if not
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    while true; do
        show_menu
        read -p "Enter your choice (0-7): " choice
        
        case $choice in
            1)
                create_backup
                ;;
            2)
                list_backups
                ;;
            3)
                restore_backup
                ;;
            4)
                delete_backups
                ;;
            5)
                show_current_keys
                ;;
            6)
                test_connections
                ;;
            7)
                show_settings
                ;;
            0)
                clear
                echo -e "${GREEN}👋 Thanks for using SSH Key Manager!${NC}"
                echo -e "${GREEN}🔐 Your SSH keys are safe and secure${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 0-7${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run the main function
main "$@" 