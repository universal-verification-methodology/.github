#!/bin/bash
#
# Upgrade Node.js to version 18+ for MCP compatibility
#

set -eo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Node.js Upgrade for MCP Compatibility ===${NC}\n"

# Check current Node.js version
CURRENT_NODE=$(node --version 2>/dev/null || echo "not installed")
echo -e "Current Node.js version: ${YELLOW}${CURRENT_NODE}${NC}"

# Check if nvm is installed
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    echo -e "${GREEN}✓ nvm is already installed${NC}"
    source "$HOME/.nvm/nvm.sh"
elif command -v nvm &> /dev/null; then
    echo -e "${GREEN}✓ nvm is available${NC}"
else
    echo -e "${BLUE}Installing nvm (Node Version Manager)...${NC}"
    
    # Install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Source nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Add to shell profile
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "NVM_DIR" "$HOME/.bashrc"; then
            echo '' >> "$HOME/.bashrc"
            echo 'export NVM_DIR="$HOME/.nvm"' >> "$HOME/.bashrc"
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$HOME/.bashrc"
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$HOME/.bashrc"
        fi
    fi
    
    echo -e "${GREEN}✓ nvm installed${NC}"
fi

# Source nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 18 LTS
echo -e "\n${BLUE}Installing Node.js 18 LTS...${NC}"
nvm install 18
nvm use 18
nvm alias default 18

# Verify installation
NEW_NODE=$(node --version)
NEW_NPM=$(npm --version)

echo -e "\n${GREEN}=== Upgrade Complete ===${NC}"
echo -e "New Node.js version: ${GREEN}${NEW_NODE}${NC}"
echo -e "New npm version: ${GREEN}${NEW_NPM}${NC}"

# Test MCP server availability
echo -e "\n${BLUE}Testing MCP server compatibility...${NC}"
if timeout 10 npx -y @modelcontextprotocol/server-filesystem --help &> /dev/null 2>&1 || true; then
    echo -e "${GREEN}✓ MCP servers should work with this Node.js version${NC}"
else
    echo -e "${YELLOW}⚠ MCP servers may need to be tested manually${NC}"
fi

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Restart your terminal or run: source ~/.bashrc"
echo "2. Verify: node --version (should show v18+)"
echo "3. Run MCP setup again: ./scripts/setup_mcp.sh"
