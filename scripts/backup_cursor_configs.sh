#!/bin/bash
# Backup script for Cursor IDE and related configuration files
# This script backs up all configuration files created by our setup scripts
# to a local directory for easy restoration in new environments

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Backup Cursor Configuration Files ===${NC}\n"

# Get script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/scripts/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_SUBDIR="$BACKUP_DIR/cursor_configs_$TIMESTAMP"

# Create backup directory
mkdir -p "$BACKUP_SUBDIR"
mkdir -p "$BACKUP_SUBDIR/.config/cursor-readme"
mkdir -p "$BACKUP_SUBDIR/.config/mcp-readme"

# Track if any files were backed up
FILES_BACKED_UP=0
FILES_SKIPPED=0

echo -e "${BLUE}Backup location: ${BACKUP_SUBDIR}${NC}\n"

# Function to backup a file if it exists
backup_file() {
    local source_file="$1"
    local dest_file="$2"
    
    if [ -f "$source_file" ]; then
        # Create destination directory if needed
        mkdir -p "$(dirname "$dest_file")"
        
        # Copy the file
        cp "$source_file" "$dest_file"
        echo -e "${GREEN}✓${NC} Backed up: $source_file"
        FILES_BACKED_UP=$((FILES_BACKED_UP + 1))
        return 0
    else
        echo -e "${YELLOW}⊘${NC} Not found: $source_file"
        FILES_SKIPPED=$((FILES_SKIPPED + 1))
        return 1
    fi
}

# Function to backup a directory if it exists
backup_dir() {
    local source_dir="$1"
    local dest_dir="$2"
    
    if [ -d "$source_dir" ]; then
        # Create destination directory
        mkdir -p "$dest_dir"
        
        # Copy the directory
        cp -r "$source_dir"/* "$dest_dir/" 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Backed up directory: $source_dir"
        FILES_BACKED_UP=$((FILES_BACKED_UP + 1))
        return 0
    else
        echo -e "${YELLOW}⊘${NC} Directory not found: $source_dir"
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

echo -e "${BLUE}Backing up Cursor IDE MCP configuration...${NC}"

# Backup Cursor MCP configuration (primary location)
if [ -f "$CURSOR_CONFIG_DIR/mcp.json" ]; then
    backup_file "$CURSOR_CONFIG_DIR/mcp.json" "$BACKUP_SUBDIR/.config/Cursor/User/mcp.json"
    mkdir -p "$BACKUP_SUBDIR/.config/Cursor/User"
fi

# Backup Cursor settings.json if it exists and contains MCP config
if [ -f "$CURSOR_CONFIG_DIR/settings.json" ]; then
    if grep -q "mcp" "$CURSOR_CONFIG_DIR/settings.json" 2>/dev/null; then
        backup_file "$CURSOR_CONFIG_DIR/settings.json" "$BACKUP_SUBDIR/.config/Cursor/User/settings.json"
        mkdir -p "$BACKUP_SUBDIR/.config/Cursor/User"
    fi
fi

# Backup Cursor MCP configuration (alternative location)
if [ -n "$CURSOR_CONFIG_ALT" ] && [ -f "$CURSOR_CONFIG_ALT/mcp.json" ]; then
    backup_file "$CURSOR_CONFIG_ALT/mcp.json" "$BACKUP_SUBDIR/.cursor/mcp.json"
    mkdir -p "$BACKUP_SUBDIR/.cursor"
fi

# Backup Windows Cursor config (WSL)
if [ "$WSL_MODE" = true ] && [ -n "${CURSOR_WIN_CONFIG_DIR:-}" ]; then
    if [ -f "$CURSOR_WIN_CONFIG_DIR/mcp.json" ]; then
        backup_file "$CURSOR_WIN_CONFIG_DIR/mcp.json" "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User/mcp.json"
        mkdir -p "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User"
    fi
    if [ -f "$CURSOR_WIN_CONFIG_DIR/settings.json" ]; then
        if grep -q "mcp" "$CURSOR_WIN_CONFIG_DIR/settings.json" 2>/dev/null; then
            backup_file "$CURSOR_WIN_CONFIG_DIR/settings.json" "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User/settings.json"
            mkdir -p "$BACKUP_SUBDIR/windows_AppData_Roaming_Cursor_User"
        fi
    fi
fi

# macOS specific path
if [[ "$OSTYPE" == "darwin"* ]]; then
    CURSOR_MAC_CONFIG_DIR="$HOME/Library/Application Support/Cursor/User"
    if [ -f "$CURSOR_MAC_CONFIG_DIR/mcp.json" ]; then
        backup_file "$CURSOR_MAC_CONFIG_DIR/mcp.json" "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User/mcp.json"
        mkdir -p "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User"
    fi
    if [ -f "$CURSOR_MAC_CONFIG_DIR/settings.json" ]; then
        if grep -q "mcp" "$CURSOR_MAC_CONFIG_DIR/settings.json" 2>/dev/null; then
            backup_file "$CURSOR_MAC_CONFIG_DIR/settings.json" "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User/settings.json"
            mkdir -p "$BACKUP_SUBDIR/macos_Library_Application_Support_Cursor_User"
        fi
    fi
fi

echo ""
echo -e "${BLUE}Backing up cursor-readme configuration...${NC}"

# Backup cursor-readme config files
backup_file "$HOME/.config/cursor-readme/config.sh" "$BACKUP_SUBDIR/.config/cursor-readme/config.sh"
backup_file "$HOME/.config/cursor-readme/README.md" "$BACKUP_SUBDIR/.config/cursor-readme/README.md"

echo ""
echo -e "${BLUE}Backing up mcp-readme configuration...${NC}"

# Backup mcp-readme config files
backup_file "$HOME/.config/mcp-readme/config.sh" "$BACKUP_SUBDIR/.config/mcp-readme/config.sh"
backup_file "$HOME/.config/mcp-readme/cursor-mcp.json" "$BACKUP_SUBDIR/.config/mcp-readme/cursor-mcp.json"
backup_file "$HOME/.config/mcp-readme/quickstart.sh" "$BACKUP_SUBDIR/.config/mcp-readme/quickstart.sh"

# Create a manifest file with backup information
MANIFEST_FILE="$BACKUP_SUBDIR/manifest.txt"
cat > "$MANIFEST_FILE" << EOF
Cursor Configuration Backup Manifest
====================================
Backup Date: $(date)
Backup Location: $BACKUP_SUBDIR

Files Backed Up:
- Cursor IDE MCP configuration (mcp.json)
- Cursor IDE settings (settings.json, if MCP-related)
- cursor-readme configuration (~/.config/cursor-readme/)
- mcp-readme configuration (~/.config/mcp-readme/)

Original Locations:
- Cursor Config (Linux): ~/.config/Cursor/User/
- Cursor Config (macOS): ~/Library/Application Support/Cursor/User/
- Cursor Config (Alt): ~/.cursor/
- cursor-readme: ~/.config/cursor-readme/
- mcp-readme: ~/.config/mcp-readme/

To restore, run:
  ./scripts/restore_cursor_configs.sh $TIMESTAMP
EOF

echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}\n"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Files backed up: ${GREEN}${FILES_BACKED_UP}${NC}"
echo -e "  Files skipped: ${YELLOW}${FILES_SKIPPED}${NC}"
echo -e "  Backup location: ${YELLOW}${BACKUP_SUBDIR}${NC}"
echo ""
echo -e "${BLUE}To restore this backup:${NC}"
echo -e "  ${YELLOW}./scripts/restore_cursor_configs.sh $TIMESTAMP${NC}"
echo ""
echo -e "${BLUE}To list all backups:${NC}"
echo -e "  ${YELLOW}ls -la scripts/backups/${NC}"
echo ""
