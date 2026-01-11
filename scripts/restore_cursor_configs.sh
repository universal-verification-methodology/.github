#!/bin/bash
# Restore script for Cursor IDE and related configuration files
# This script restores configuration files from backups created by backup_cursor_configs.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/scripts/backups"

# Function to show usage
usage() {
    echo -e "${BLUE}Usage:${NC} $0 [backup_timestamp]"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  backup_timestamp    Timestamp of the backup to restore (e.g., 20240101_120000)"
    echo "                      If omitted, will show available backups"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0                           # List available backups"
    echo "  $0 20240101_120000          # Restore specific backup"
    echo "  $0 latest                   # Restore latest backup"
    echo ""
    exit 1
}

# List available backups
list_backups() {
    echo -e "${BLUE}=== Available Backups ===${NC}\n"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}No backup directory found: $BACKUP_DIR${NC}"
        echo -e "${BLUE}Run ./scripts/backup_cursor_configs.sh to create a backup${NC}"
        return 1
    fi
    
    BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "cursor_configs_*" | sort -r)
    
    if [ -z "$BACKUPS" ]; then
        echo -e "${YELLOW}No backups found in $BACKUP_DIR${NC}"
        echo -e "${BLUE}Run ./scripts/backup_cursor_configs.sh to create a backup${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Backups:${NC}"
    COUNT=1
    for backup in $BACKUPS; do
        TIMESTAMP=$(basename "$backup" | sed 's/cursor_configs_//')
        DATE_STR=$(echo "$TIMESTAMP" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        echo -e "  ${GREEN}$COUNT.${NC} $TIMESTAMP ($DATE_STR)"
        COUNT=$((COUNT + 1))
    done
    
    echo ""
    echo -e "${BLUE}To restore a backup:${NC}"
    echo -e "  ${YELLOW}$0 <timestamp>${NC}"
    echo -e "  ${YELLOW}$0 latest${NC}  # Restore latest backup"
    echo ""
    return 0
}

# Parse arguments
if [ $# -eq 0 ]; then
    list_backups
    exit 0
fi

BACKUP_TIMESTAMP="$1"

# Handle "latest" keyword
if [ "$BACKUP_TIMESTAMP" = "latest" ]; then
    BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "cursor_configs_*" | sort -r)
    if [ -z "$BACKUPS" ]; then
        echo -e "${RED}✗ No backups found${NC}"
        exit 1
    fi
    BACKUP_TIMESTAMP=$(basename $(echo "$BACKUPS" | head -1) | sed 's/cursor_configs_//')
    echo -e "${BLUE}Using latest backup: $BACKUP_TIMESTAMP${NC}\n"
fi

BACKUP_SUBDIR="$BACKUP_DIR/cursor_configs_$BACKUP_TIMESTAMP"

# Check if backup exists
if [ ! -d "$BACKUP_SUBDIR" ]; then
    echo -e "${RED}✗ Backup not found: $BACKUP_SUBDIR${NC}\n"
    list_backups
    exit 1
fi

echo -e "${BLUE}=== Restore Cursor Configuration Files ===${NC}\n"
echo -e "${BLUE}Backup location: ${BACKUP_SUBDIR}${NC}\n"

# Track restored files
FILES_RESTORED=0
FILES_SKIPPED=0

# Function to restore a file
restore_file() {
    local source_file="$1"
    local dest_file="$2"
    local create_dir="${3:-true}"
    
    if [ -f "$source_file" ]; then
        # Create destination directory if needed
        if [ "$create_dir" = "true" ]; then
            mkdir -p "$(dirname "$dest_file")"
        fi
        
        # Backup existing file if it exists
        if [ -f "$dest_file" ]; then
            BACKUP_EXT=".backup.$(date +%Y%m%d_%H%M%S)"
            mv "$dest_file" "${dest_file}${BACKUP_EXT}"
            echo -e "${YELLOW}⚠${NC} Backed up existing: $dest_file -> ${dest_file}${BACKUP_EXT}"
        fi
        
        # Copy the file
        cp "$source_file" "$dest_file"
        echo -e "${GREEN}✓${NC} Restored: $dest_file"
        FILES_RESTORED=$((FILES_RESTORED + 1))
        return 0
    else
        echo -e "${YELLOW}⊘${NC} Not in backup: $source_file"
        FILES_SKIPPED=$((FILES_SKIPPED + 1))
        return 1
    fi
}

# Detect OS for Cursor config paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    CURSOR_CONFIG_DIR="$HOME/Library/Application Support/Cursor/User"
    CURSOR_CONFIG_ALT="$HOME/.cursor"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CURSOR_CONFIG_DIR="$HOME/.config/Cursor/User"
    CURSOR_CONFIG_ALT="$HOME/.cursor"
else
    CURSOR_CONFIG_DIR="$HOME/.cursor"
    CURSOR_CONFIG_ALT=""
fi

# Check if we're in WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    WSL_MODE=true
    WINDOWS_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || echo "")
    if [ -n "$WINDOWS_USER" ]; then
        CURSOR_WIN_CONFIG_DIR="/mnt/c/Users/${WINDOWS_USER}/AppData/Roaming/Cursor/User"
        CURSOR_WIN_CONFIG_ALT="/mnt/c/Users/${WINDOWS_USER}/.cursor"
    fi
else
    WSL_MODE=false
fi

echo -e "${BLUE}Restoring Cursor IDE MCP configuration...${NC}"

# Restore Cursor MCP configuration (primary location - Linux)
if [ -f "$BACKUP_SUBDIR/.config/Cursor/User/mcp.json" ]; then
    restore_file "$BACKUP_SUBDIR/.config/Cursor/User/mcp.json" "$CURSOR_CONFIG_DIR/mcp.json"
fi

if [ -f "$BACKUP_SUBDIR/.config/Cursor/User/settings.json" ]; then
    restore_file "$BACKUP_SUBDIR/.config/Cursor/User/settings.json" "$CURSOR_CONFIG_DIR/settings.json"
fi

# Restore Cursor MCP configuration (alternative location)
if [ -f "$BACKUP_SUBDIR/.cursor/mcp.json" ]; then
    restore_file "$BACKUP_SUBDIR/.cursor/mcp.json" "$CURSOR_CONFIG_ALT/mcp.json"
fi

# Restore macOS specific path
if [ -f "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User/mcp.json" ]; then
    CURSOR_MAC_CONFIG_DIR="$HOME/Library/Application Support/Cursor/User"
    restore_file "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User/mcp.json" "$CURSOR_MAC_CONFIG_DIR/mcp.json"
fi

if [ -f "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User/settings.json" ]; then
    CURSOR_MAC_CONFIG_DIR="$HOME/Library/Application Support/Cursor/User"
    restore_file "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User/settings.json" "$CURSOR_MAC_CONFIG_DIR/settings.json"
fi

# Restore Windows Cursor config (WSL)
if [ "$WSL_MODE" = true ] && [ -n "${CURSOR_WIN_CONFIG_DIR:-}" ]; then
    if [ -f "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User/mcp.json" ]; then
        restore_file "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User/mcp.json" "$CURSOR_WIN_CONFIG_DIR/mcp.json"
    fi
    if [ -f "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User/settings.json" ]; then
        restore_file "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User/settings.json" "$CURSOR_WIN_CONFIG_DIR/settings.json"
    fi
fi

echo ""
echo -e "${BLUE}Restoring cursor-readme configuration...${NC}"

# Restore cursor-readme config files
restore_file "$BACKUP_SUBDIR/.config/cursor-readme/config.sh" "$HOME/.config/cursor-readme/config.sh"
restore_file "$BACKUP_SUBDIR/.config/cursor-readme/README.md" "$HOME/.config/cursor-readme/README.md"

# Make config.sh executable if it was restored
if [ -f "$HOME/.config/cursor-readme/config.sh" ]; then
    chmod +x "$HOME/.config/cursor-readme/config.sh" 2>/dev/null || true
fi

echo ""
echo -e "${BLUE}Restoring mcp-readme configuration...${NC}"

# Restore mcp-readme config files
restore_file "$BACKUP_SUBDIR/.config/mcp-readme/config.sh" "$HOME/.config/mcp-readme/config.sh"
restore_file "$BACKUP_SUBDIR/.config/mcp-readme/cursor-mcp.json" "$HOME/.config/mcp-readme/cursor-mcp.json"
restore_file "$BACKUP_SUBDIR/.config/mcp-readme/quickstart.sh" "$HOME/.config/mcp-readme/quickstart.sh"

# Make scripts executable if they were restored
if [ -f "$HOME/.config/mcp-readme/config.sh" ]; then
    chmod +x "$HOME/.config/mcp-readme/config.sh" 2>/dev/null || true
fi
if [ -f "$HOME/.config/mcp-readme/quickstart.sh" ]; then
    chmod +x "$HOME/.config/mcp-readme/quickstart.sh" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}=== Restore Complete ===${NC}\n"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Files restored: ${GREEN}${FILES_RESTORED}${NC}"
echo -e "  Files skipped: ${YELLOW}${FILES_SKIPPED}${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. ${YELLOW}Restart Cursor IDE${NC} (if MCP configs were restored)"
echo -e "  2. ${YELLOW}Source the configuration:${NC}"
echo -e "     source ~/.config/cursor-readme/config.sh"
echo -e "  3. ${YELLOW}Test the setup:${NC}"
echo -e "     ./scripts/check_cursor_ide.sh"
echo ""
