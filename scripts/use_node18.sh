#!/bin/bash
#
# Switch to Node.js 18 using nvm (if already installed)
#

# Source nvm if available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Setting up Node.js 18 for MCP ===${NC}\n"

# Check if nvm is available
if ! command -v nvm &> /dev/null && [ ! -s "$NVM_DIR/nvm.sh" ]; then
    echo -e "${RED}Error: nvm is not installed or not sourced${NC}"
    echo "Please run: ./scripts/upgrade_nodejs.sh"
    exit 1
fi

# Load nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Check if Node.js 18 is installed
if nvm list 18 &> /dev/null | grep -q "v18"; then
    echo -e "${GREEN}✓ Node.js 18 is already installed${NC}"
    nvm use 18
    nvm alias default 18
else
    echo -e "${BLUE}Installing Node.js 18 LTS...${NC}"
    # Set TMPDIR to avoid unbound variable error
    export TMPDIR="${TMPDIR:-/tmp}"
    nvm install 18
    nvm use 18
    nvm alias default 18
fi

# Verify
NEW_NODE=$(node --version)
NEW_NPM=$(npm --version)

echo -e "\n${GREEN}=== Success ===${NC}"
echo -e "Node.js version: ${GREEN}${NEW_NODE}${NC}"
echo -e "npm version: ${GREEN}${NEW_NPM}${NC}"

# Add to bashrc if not already there
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "NVM_DIR" "$HOME/.bashrc" || ! grep -q "nvm use 18" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Node.js 18 for MCP" >> "$HOME/.bashrc"
        echo 'export NVM_DIR="$HOME/.nvm"' >> "$HOME/.bashrc"
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$HOME/.bashrc"
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$HOME/.bashrc"
        echo 'nvm use 18 2>/dev/null || true' >> "$HOME/.bashrc"
        echo -e "\n${GREEN}✓ Added nvm setup to ~/.bashrc${NC}"
    fi
fi

echo -e "\n${BLUE}To use Node.js 18 in this session:${NC}"
echo "  source ~/.bashrc"
echo "  # or"
echo "  nvm use 18"
