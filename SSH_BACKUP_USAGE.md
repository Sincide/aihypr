# SSH Key Manager - Interactive Backup & Restore System

This repository includes a comprehensive interactive SSH key management system for safely managing your SSH keys during fresh installations and day-to-day operations.

## 📋 Overview

The SSH Key Manager provides:
- **Interactive menu system** with 7 different options
- **Simple local backup** to `/mnt/Stuff/backups/`
- **Proper permission handling** for SSH keys
- **Automatic compression** with tar.gz
- **Backup metadata** with system information
- **Safe restore** with current key backup
- **Interactive confirmation** before destructive operations
- **SSH connection testing** tools
- **Current key inspection** capabilities

## 🚀 Getting Started

### Launch SSH Key Manager

```bash
./scripts/ssh-manager.sh
```

This launches the interactive menu system with all available options.

## 📋 Menu Options

### Main Menu Interface

```
╔════════════════════════════════════════════════════════════════╗
║                    🔐 SSH Key Manager                          ║
║                Interactive Backup & Restore                    ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  1) 📦 Create New Backup                                       ║
║  2) 📋 List Available Backups                                  ║
║  3) 🔄 Restore from Backup                                     ║
║  4) 🗑️  Delete Old Backups                                     ║
║  5) 🔍 Show Current SSH Keys                                   ║
║  6) 🧪 Test SSH Connections                                    ║
║  7) ⚙️  Settings & Info                                        ║
║  0) ❌ Exit                                                     ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

### 1) 📦 Create New Backup

- Shows current SSH files to be backed up
- Interactive confirmation before proceeding
- Creates timestamped backup archive
- Sets proper file permissions automatically
- Includes metadata with system information
- Compresses to `.tar.gz` format

### 2) 📋 List Available Backups

- Displays all available backups in table format
- Shows backup name, size, and creation date
- Displays total backup count and combined size
- No destructive actions - safe to explore

### 3) 🔄 Restore from Backup

- Lists numbered backup options for selection
- **Automatically backs up current keys before restore**
- Interactive backup selection by number
- Double confirmation before proceeding
- Proper permission restoration
- Validation of restored configuration

### 4) 🗑️ Delete Old Backups

- Lists all available backups with selection numbers
- Interactive selection by number
- **Double confirmation** before deletion (irreversible)
- Safely removes selected backup files
- Helps manage storage space

### 5) 🔍 Show Current SSH Keys

- Displays detailed information about current SSH setup
- Lists all files in SSH directory with permissions
- Shows SSH key fingerprints for verification
- Checks SSH agent status and loaded keys
- Non-destructive inspection tool

### 6) 🧪 Test SSH Connections

- Tests common SSH connections (GitHub, GitLab, etc.)
- Checks SSH agent status and loaded keys
- Shows which keys are available vs loaded
- Provides helpful testing commands
- Helps diagnose connection issues

### 7) ⚙️ Settings & Info

- Displays current configuration paths
- Shows system statistics (key count, backup count, sizes)
- Provides system information
- Shows customization options
- Help and information screen

## 🛠️ Usage Scenarios

### Fresh Installation Setup

1. **Before wiping system**: Run SSH Manager and create backup
   ```bash
   ./scripts/ssh-manager.sh
   # Select option 1 to create backup
   ```

2. **After fresh installation**: Restore keys
   ```bash
   # Clone dotfiles repository
   git clone https://github.com/yourusername/aihypr.git
   cd aihypr
   
   # Launch SSH Manager
   ./scripts/ssh-manager.sh
   # Select option 2 to list backups
   # Select option 3 to restore from backup
   ```

### Regular Maintenance

```bash
# Launch SSH Manager for all operations
./scripts/ssh-manager.sh

# Use the interactive menu to:
# - Create monthly backups (option 1)
# - Clean old backups (option 4)
# - Check current keys (option 5)
# - Test connections (option 6)
```

## 📁 What Gets Backed Up

The backup includes **all files** from `~/.ssh/` directory:
- **Private keys**: `id_rsa`, `id_ed25519`, etc.
- **Public keys**: `id_rsa.pub`, `id_ed25519.pub`, etc.
- **SSH config**: `config` file with host configurations
- **Known hosts**: `known_hosts` file with server fingerprints
- **Authorized keys**: `authorized_keys` file
- **Any other SSH-related files**

## 🔒 Security Considerations

### Local Storage Security
- Backups are stored on local drive (`/mnt/Stuff/backups/`)
- **No encryption** applied (as requested for local storage)
- Files maintain proper SSH permissions (600/644)
- Backup directory should be secured at filesystem level

### Permission Handling
- **Private keys**: 600 (owner read/write only)
- **Public keys**: 644 (world readable)
- **Config files**: 600 (owner read/write only)
- **SSH directory**: 700 (owner access only)

## 🧪 Testing After Restore

After restoring SSH keys, test your connections:

```bash
# Test GitHub SSH connection
ssh -T git@github.com

# Test server connections
ssh user@yourserver.com

# Load keys into SSH agent
ssh-add ~/.ssh/id_rsa
ssh-add ~/.ssh/id_ed25519

# List loaded keys
ssh-add -l

# Check key fingerprints
ssh-keygen -lf ~/.ssh/id_rsa.pub
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

## 📂 File Structure

```
/mnt/Stuff/backups/
├── ssh-keys-20241201_143022.tar.gz
├── ssh-keys-20241201_150322.tar.gz
├── ssh-keys-current-20241201_160322.tar.gz
└── ...

Each archive contains:
├── id_rsa (600)
├── id_rsa.pub (644)
├── id_ed25519 (600)
├── id_ed25519.pub (644)
├── config (600)
├── known_hosts (644)
├── backup-info.txt (metadata)
└── ... (other SSH files)
```

## 🔧 Customization

### Change Backup Location

Edit the SSH Manager script and modify the `BACKUP_DIR` variable:
```bash
BACKUP_DIR="/your/custom/backup/path"
```

You can also view current settings using **Option 7) Settings & Info** in the SSH Manager.

### Add to Installation Script

The SSH Manager is standalone and doesn't need integration, but you can add it to your dotfiles installation process if needed. Simply call `./scripts/ssh-manager.sh` in your setup scripts.

## 🎯 Best Practices

1. **Regular backups**: Use SSH Manager (option 1) before major system changes
2. **Test functionality**: Use the built-in testing tools (option 6) regularly
3. **Monitor your keys**: Check current status (option 5) periodically 
4. **Clean house**: Remove old backups (option 4) to manage storage
5. **Verify after restore**: Always test connections after restoring backups

## 🆘 Troubleshooting

### Using SSH Manager Tools

The SSH Manager includes built-in troubleshooting tools:

**Option 5) Show Current SSH Keys**: 
- Displays file permissions
- Shows key fingerprints
- Checks SSH agent status

**Option 6) Test SSH Connections**:
- Tests GitHub/GitLab connections
- Verifies SSH agent functionality
- Shows loaded vs available keys
- Provides helpful test commands

### Manual Troubleshooting

If you need to fix issues manually:

```bash
# Fix SSH directory permissions (also shown in option 5)
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub

# Start SSH agent (guided in option 6)
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa

# Debug SSH connection (commands shown in option 6)
ssh -v user@server.com
ssh -F ~/.ssh/config -T git@github.com
```

---

**💡 Remember**: The SSH Key Manager prioritizes simplicity, safety, and user-friendliness for local backup management. All operations are interactive with confirmations to prevent accidents. For remote or cloud storage, consider adding encryption layers to the backup files.

## 🎉 Quick Start Summary

1. **Launch**: `./scripts/ssh-manager.sh`
2. **Create backup**: Choose option 1
3. **List backups**: Choose option 2  
4. **Restore backup**: Choose option 3
5. **Test everything**: Choose option 6

The interactive menu makes SSH key management safe and straightforward! 