#!/bin/bash
# Check if Cursor IDE is running and MCP is accessible

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Checking Cursor IDE Status ===${NC}\n"

# Check 1: Process check (handle WSL + Windows)
echo -e "${BLUE}1. Checking if Cursor IDE process is running...${NC}"

# Detect if we're in WSL
WSL_MODE=false
if grep -qi microsoft /proc/version 2>/dev/null; then
    WSL_MODE=true
fi

CURSOR_PROCESS=""
CURSOR_FOUND=false

# Method 1: Check Linux processes (native Linux or Cursor IDE in WSL)
CURSOR_PROCESS=$(pgrep -f -i cursor 2>/dev/null || pgrep -f -i "Cursor" 2>/dev/null || echo "")
if [ -n "$CURSOR_PROCESS" ]; then
    CURSOR_FOUND=true
    echo -e "${GREEN}  ✓ Cursor IDE process found in Linux (PID: $CURSOR_PROCESS)${NC}"
    ps -p "$CURSOR_PROCESS" -o comm=,args= 2>/dev/null | head -1 | while read -r line; do
        echo -e "    Process: $line"
    done
fi

# Method 2: Check Windows processes from WSL (if in WSL)
if [ "$WSL_MODE" = true ] && [ "$CURSOR_FOUND" = false ]; then
    # Check for Cursor IDE in Windows paths accessible from WSL
    WINDOWS_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || echo "")
    if [ -n "$WINDOWS_USER" ]; then
        # Check Windows AppData for Cursor IDE
        CURSOR_WIN_CONFIGS=(
            "/mnt/c/Users/${WINDOWS_USER}/AppData/Roaming/Cursor"
            "/mnt/c/Users/${WINDOWS_USER}/.cursor"
            "/mnt/c/Users/${WINDOWS_USER}/AppData/Local/Programs/Cursor"
        )
        
        for config_path in "${CURSOR_WIN_CONFIGS[@]}"; do
            if [ -d "$config_path" ]; then
                # Check if config files have been recently modified (indicates recent use)
                if find "$config_path" -type f -mmin -60 2>/dev/null | grep -q .; then
                    CURSOR_FOUND=true
                    echo -e "${GREEN}  ✓ Cursor IDE detected on Windows (config recently modified)${NC}"
                    echo -e "    Config path: $config_path"
                    break
                elif [ -d "$config_path" ]; then
                    # Config exists, IDE might be running
                    CURSOR_FOUND=true
                    echo -e "${GREEN}  ✓ Cursor IDE configuration found on Windows${NC}"
                    echo -e "    Config path: $config_path"
                    echo -e "    ${YELLOW}(Note: Running on Windows, not directly visible from WSL)${NC}"
                    break
                fi
            fi
        done
        
        # Try using tasklist.exe to check Windows processes
        if command -v tasklist.exe >/dev/null 2>&1; then
            CURSOR_WIN_PROCESS=$(tasklist.exe /FI "IMAGENAME eq Cursor.exe" /NH 2>/dev/null | grep -i cursor || echo "")
            if [ -n "$CURSOR_WIN_PROCESS" ]; then
                CURSOR_FOUND=true
                echo -e "${GREEN}  ✓ Cursor IDE process found on Windows:${NC}"
                echo -e "    $CURSOR_WIN_PROCESS" | sed 's/^/    /'
            fi
        fi
    fi
fi

# Method 3: Check for Cursor IDE in WSL config directory
if [ "$CURSOR_FOUND" = false ] && [ -d "$HOME/.cursor" ]; then
    # Check if config has been recently modified
    if find "$HOME/.cursor" -type f -mmin -60 2>/dev/null | grep -q .; then
        CURSOR_FOUND=true
        echo -e "${GREEN}  ✓ Cursor IDE config recently modified (likely running)${NC}"
        echo -e "    Config: $HOME/.cursor"
    elif [ -d "$HOME/.cursor" ]; then
        CURSOR_FOUND=true
        echo -e "${GREEN}  ✓ Cursor IDE configuration exists${NC}"
        echo -e "    Config: $HOME/.cursor"
        echo -e "    ${YELLOW}(Config exists, but process not directly visible)${NC}"
    fi
fi

if [ "$CURSOR_FOUND" = false ]; then
    echo -e "${YELLOW}  ⚠ Cursor IDE process not directly visible${NC}"
    if [ "$WSL_MODE" = true ]; then
        echo -e "    ${BLUE}Note: In WSL, Cursor IDE runs on Windows${NC}"
        echo -e "    ${BLUE}Check Windows Task Manager or use: tasklist.exe /FI \"IMAGENAME eq Cursor.exe\"${NC}"
    else
        echo -e "    Cursor IDE may not be running"
    fi
fi

# Store result for summary
if [ "$CURSOR_FOUND" = true ]; then
    CURSOR_PROCESS="detected"
fi

# Check 2: Window/display check (Linux)
if [ "$XDG_SESSION_TYPE" = "x11" ] || [ "$WAYLAND_DISPLAY" ]; then
    echo ""
    echo -e "${BLUE}2. Checking for Cursor IDE windows...${NC}"
    if command -v wmctrl >/dev/null 2>&1; then
        WINDOWS=$(wmctrl -l 2>/dev/null | grep -i cursor || echo "")
        if [ -n "$WINDOWS" ]; then
            echo -e "${GREEN}  ✓ Cursor IDE windows found:${NC}"
            echo "$WINDOWS" | head -3 | sed 's/^/    /'
        else
            echo -e "${YELLOW}  ⚠ No Cursor IDE windows found${NC}"
        fi
    elif command -v xdotool >/dev/null 2>&1; then
        WINDOWS=$(xdotool search --name -i cursor 2>/dev/null || echo "")
        if [ -n "$WINDOWS" ]; then
            echo -e "${GREEN}  ✓ Cursor IDE windows found${NC}"
        else
            echo -e "${YELLOW}  ⚠ No Cursor IDE windows found${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ Window manager tools not available (wmctrl/xdotool)${NC}"
    fi
fi

# Check 3: MCP server check
echo ""
echo -e "${BLUE}3. Checking MCP server accessibility...${NC}"
if [ -n "${MCP_SERVER:-}" ]; then
    echo -e "  MCP Server: ${MCP_SERVER}"
    
    # Try to run the MCP server command to see if it's accessible
    if command -v npx >/dev/null 2>&1; then
        # Extract the package name from MCP_SERVER
        MCP_PKG=$(echo "$MCP_SERVER" | grep -oE '@modelcontextprotocol/[^[:space:]]+' | head -1 || echo "")
        if [ -n "$MCP_PKG" ]; then
            echo -e "  Testing MCP package: $MCP_PKG"
            if timeout 5 npx -y "$MCP_PKG" --help >/dev/null 2>&1 || timeout 5 npx -y "$MCP_PKG" >/dev/null 2>&1; then
                echo -e "${GREEN}  ✓ MCP server package is accessible${NC}"
            else
                echo -e "${YELLOW}  ⚠ MCP server package may not be available${NC}"
            fi
        fi
    fi
else
    echo -e "${YELLOW}  ⚠ MCP_SERVER not configured${NC}"
fi

# Check 4: Cursor IDE configuration files
echo ""
echo -e "${BLUE}4. Checking Cursor IDE configuration...${NC}"

# Check for Cursor config directories
CURSOR_CONFIGS=(
    "$HOME/.config/Cursor"
    "$HOME/.cursor"
    "$HOME/Library/Application Support/Cursor"
    "$HOME/AppData/Roaming/Cursor"
)

FOUND_CONFIG=false
for config_dir in "${CURSOR_CONFIGS[@]}"; do
    if [ -d "$config_dir" ]; then
        echo -e "${GREEN}  ✓ Found Cursor config: $config_dir${NC}"
        FOUND_CONFIG=true
        
        # Check for MCP config
        if [ -f "$config_dir/mcp.json" ] || [ -f "$config_dir/User/settings.json" ]; then
            echo -e "    Contains MCP configuration files"
        fi
    fi
done

if [ "$FOUND_CONFIG" = false ]; then
    echo -e "${YELLOW}  ⚠ No Cursor IDE configuration directory found${NC}"
    echo -e "    This might mean Cursor IDE hasn't been run yet"
fi

# Check 5: Cursor IDE API endpoints (if available)
echo ""
echo -e "${BLUE}5. Checking Cursor IDE API endpoints...${NC}"
CURSOR_ENDPOINTS=(
    "http://localhost:3000/v1/chat/completions"
    "http://localhost:8080/v1/chat/completions"
    "http://127.0.0.1:3000/v1/chat/completions"
)

FOUND_API=false
for endpoint in "${CURSOR_ENDPOINTS[@]}"; do
    if timeout 2 curl -s "$endpoint" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Found accessible endpoint: $endpoint${NC}"
        FOUND_API=true
    fi
done

if [ "$FOUND_API" = false ]; then
    echo -e "${YELLOW}  ⚠ No accessible Cursor IDE API endpoints found${NC}"
    echo -e "    This is normal - Cursor IDE may not expose public API endpoints"
fi

# Check 6: Environment variables (check config file directly)
echo ""
echo -e "${BLUE}6. Checking Cursor-related environment variables...${NC}"

if [ -f ~/.config/cursor-readme/config.sh ]; then
    echo -e "  Reading configuration from ~/.config/cursor-readme/config.sh..."
    
    # Read variables from config file
    CONFIG_AI_PROVIDER=$(grep "^export AI_PROVIDER=" ~/.config/cursor-readme/config.sh 2>/dev/null | cut -d'=' -f2 | tr -d "'\"" || echo "")
    CONFIG_MCP_SERVER=$(grep "^export MCP_SERVER=" ~/.config/cursor-readme/config.sh 2>/dev/null | cut -d'=' -f2 | tr -d "'\"" || echo "")
    CONFIG_CURSOR_MODE=$(grep "^export CURSOR_AGENT_MODE=" ~/.config/cursor-readme/config.sh 2>/dev/null | cut -d'=' -f2 | tr -d "'\"" || echo "")
    CONFIG_AI_MODEL=$(grep "^export AI_MODEL=" ~/.config/cursor-readme/config.sh 2>/dev/null | tail -1 | cut -d'=' -f2 | tr -d "'\"" || echo "")
    
    if [ -n "$CONFIG_AI_PROVIDER" ]; then
        echo -e "  ${GREEN}✓${NC} AI_PROVIDER (from config): $CONFIG_AI_PROVIDER"
    fi
    
    if [ -n "$CONFIG_MCP_SERVER" ]; then
        echo -e "  ${GREEN}✓${NC} MCP_SERVER (from config): $CONFIG_MCP_SERVER"
    else
        echo -e "  ${YELLOW}⚠${NC} MCP_SERVER not found in config file"
    fi
    
    if [ -n "$CONFIG_CURSOR_MODE" ]; then
        echo -e "  ${GREEN}✓${NC} CURSOR_AGENT_MODE: $CONFIG_CURSOR_MODE"
    fi
    
    if [ -n "$CONFIG_AI_MODEL" ]; then
        echo -e "  ${GREEN}✓${NC} AI_MODEL: $CONFIG_AI_MODEL"
    fi
    
    # Check current environment
    echo -e "\n  ${BLUE}Current environment (after sourcing config):${NC}"
    if [ -n "${AI_PROVIDER:-}" ]; then
        echo -e "    AI_PROVIDER in env: ${GREEN}${AI_PROVIDER}${NC}"
    else
        echo -e "    AI_PROVIDER in env: ${YELLOW}not set${NC}"
        echo -e "      ${YELLOW}→ Run: source ~/.config/cursor-readme/config.sh${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ Config file not found: ~/.config/cursor-readme/config.sh${NC}"
    echo -e "    Run: ./scripts/configure_cursor_ai.sh"
fi

# Summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"

if [ -n "$CURSOR_PROCESS" ]; then
    echo -e "${GREEN}✓ Cursor IDE appears to be running${NC}"
    echo ""
    echo -e "${BLUE}Note:${NC}"
    echo -e "  - Cursor IDE process is active"
    echo -e "  - MCP integration may work if configured in Cursor IDE settings"
    echo -e "  - The script will use Ollama as fallback (which is working)"
else
    echo -e "${YELLOW}⚠ Cursor IDE process not detected${NC}"
    echo ""
    echo -e "${BLUE}This means:${NC}"
    echo -e "  - Cursor IDE's built-in MCP servers may not be available"
    echo -e "  - The script will use Ollama directly (which works fine!)"
    echo -e "  - No action needed - Ollama is a good fallback"
fi

echo ""
echo -e "${BLUE}Recommendation:${NC}"
if [ -n "$CURSOR_PROCESS" ]; then
    echo -e "  ${GREEN}✓ Cursor IDE is running - MCP may be available${NC}"
    echo -e "  Test with: ${YELLOW}./scripts/generate_readme.sh owner repo${NC}"
else
    echo -e "  ${GREEN}✓ Use Ollama directly (works great without Cursor IDE)${NC}"
    echo -e "  Set: ${YELLOW}export AI_PROVIDER=local${NC}"
    echo -e "  Or continue with cursor-agent mode (uses Ollama fallback)"
fi

echo ""
