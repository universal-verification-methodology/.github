#!/bin/bash
# Setup script for Cursor IDE MCP configuration
# This helps configure MCP in Cursor IDE settings

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Cursor IDE MCP Configuration Setup ===${NC}\n"

# Detect OS
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

echo -e "${BLUE}Detected Cursor configuration locations:${NC}"
echo -e "  Primary: ${CURSOR_CONFIG_DIR}"
if [ -n "$CURSOR_CONFIG_ALT" ]; then
    echo -e "  Alternative: ${CURSOR_CONFIG_ALT}"
fi
echo ""

# Check if Cursor config directory exists
if [ ! -d "$CURSOR_CONFIG_DIR" ] && [ ! -d "$CURSOR_CONFIG_ALT" ]; then
    echo -e "${YELLOW}⚠ Cursor IDE configuration directory not found${NC}"
    echo -e "  Make sure Cursor IDE is installed and has been run at least once"
    echo -e "  Creating alternative location: ${CURSOR_CONFIG_ALT:-$CURSOR_CONFIG_DIR}"
    mkdir -p "${CURSOR_CONFIG_ALT:-$CURSOR_CONFIG_DIR}"
fi

# Determine which config to use
if [ -d "$CURSOR_CONFIG_DIR" ]; then
    CONFIG_DIR="$CURSOR_CONFIG_DIR"
elif [ -d "$CURSOR_CONFIG_ALT" ]; then
    CONFIG_DIR="$CURSOR_CONFIG_ALT"
else
    CONFIG_DIR="${CURSOR_CONFIG_ALT:-$CURSOR_CONFIG_DIR}"
    mkdir -p "$CONFIG_DIR"
fi

# Create MCP configuration file
MCP_CONFIG="$CONFIG_DIR/mcp.json"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

echo -e "${BLUE}Creating MCP configuration...${NC}"

# Check if settings.json exists and has MCP config
if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "mcp" "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ MCP configuration found in settings.json${NC}"
        echo -e "${YELLOW}  You may want to review: $SETTINGS_FILE${NC}"
    fi
fi

# Create standalone MCP config
cat > "$MCP_CONFIG" << 'MCP_EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "${workspaceFolder}"
      ],
      "description": "Filesystem access for reading repository files"
    },
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_GITHUB_TOKEN_HERE"
      },
      "description": "GitHub API access for repository information"
    }
  }
}
MCP_EOF

echo -e "${GREEN}✓ MCP configuration created: $MCP_CONFIG${NC}"

# Check for GitHub token
if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo -e "${BLUE}Updating GitHub token in MCP config...${NC}"
    sed -i "s/YOUR_GITHUB_TOKEN_HERE/$GITHUB_TOKEN/g" "$MCP_CONFIG"
    echo -e "${GREEN}✓ GitHub token configured${NC}"
else
    echo -e "${YELLOW}⚠ GitHub token not set${NC}"
    echo -e "  To use GitHub MCP server, edit: $MCP_CONFIG"
    echo -e "  Replace YOUR_GITHUB_TOKEN_HERE with your token"
fi

# Check Node.js
echo ""
echo -e "${BLUE}Checking dependencies...${NC}"
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js: $NODE_VERSION${NC}"
    
    # Check if version is 18+
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -lt 18 ]; then
        echo -e "${YELLOW}⚠ Node.js 18+ recommended for MCP servers${NC}"
    fi
else
    echo -e "${RED}✗ Node.js not found${NC}"
    echo -e "  Install Node.js: https://nodejs.org/"
    echo -e "  Or run: ./scripts/use_node18.sh"
fi

if command -v npx >/dev/null 2>&1; then
    echo -e "${GREEN}✓ npx available${NC}"
else
    echo -e "${RED}✗ npx not found (comes with Node.js)${NC}"
fi

# Test MCP server installation
echo ""
echo -e "${BLUE}Testing MCP server availability...${NC}"
if command -v npx >/dev/null 2>&1; then
    echo -e "${BLUE}  Testing filesystem server...${NC}"
    if npx -y @modelcontextprotocol/server-filesystem --help >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Filesystem MCP server available${NC}"
    else
        echo -e "${YELLOW}  ⚠ Filesystem MCP server may need to be installed${NC}"
        echo -e "    It will be installed automatically on first use"
    fi
fi

# Create instructions
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}\n"
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. ${YELLOW}Restart Cursor IDE${NC} to load MCP configuration"
echo -e "  2. Verify MCP is working:"
echo -e "     - Open Cursor IDE"
echo -e "     - Press ${GREEN}Ctrl+Shift+P${NC} (or ${GREEN}Cmd+Shift+P${NC} on Mac)"
echo -e "     - Search for 'MCP' commands"
echo -e "  3. For README generation, use:"
echo -e "     ${GREEN}source ~/.config/cursor-readme/config.sh${NC}"
echo -e "     ${GREEN}./scripts/generate_readme.sh owner repo${NC}"
echo ""
echo -e "${BLUE}Configuration file:${NC}"
echo -e "  ${YELLOW}$MCP_CONFIG${NC}"
echo ""
echo -e "${BLUE}Note:${NC}"
echo -e "  - MCP filesystem/GitHub servers provide ${YELLOW}context only${NC}"
echo -e "  - For AI generation, the script uses ${GREEN}Ollama${NC} (fallback)"
echo -e "  - Cursor IDE's built-in AI may be available if configured"
echo ""
