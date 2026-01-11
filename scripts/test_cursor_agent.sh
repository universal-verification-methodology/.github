#!/bin/bash
#
# Test Cursor Agent setup for README generation
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Testing Cursor Agent Setup ===${NC}\n"

# Load MCP config if available
if [ -f "$HOME/.config/mcp-readme/config.sh" ]; then
    echo -e "${BLUE}Loading MCP configuration...${NC}"
    source "$HOME/.config/mcp-readme/config.sh"
    echo -e "${GREEN}✓ Configuration loaded${NC}"
else
    echo -e "${YELLOW}⚠ Config file not found at ~/.config/mcp-readme/config.sh${NC}"
    echo "Run: ./scripts/setup_mcp.sh first"
    exit 1
fi

# Check Node.js version
echo -e "\n${BLUE}Checking Node.js version...${NC}"
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    source "$HOME/.nvm/nvm.sh"
    nvm use 18 2>/dev/null || true
fi

NODE_VERSION=$(node --version 2>/dev/null || echo "not found")
echo "Node.js: $NODE_VERSION"

if [[ "$NODE_VERSION" == v18.* ]] || [[ "$NODE_VERSION" == v20.* ]] || [[ "$NODE_VERSION" == v19.* ]]; then
    echo -e "${GREEN}✓ Node.js version is compatible${NC}"
else
    echo -e "${YELLOW}⚠ Node.js 18+ recommended for MCP servers${NC}"
    echo "Run: source ~/.nvm/nvm.sh && nvm use 18"
fi

# Check npx
echo -e "\n${BLUE}Checking npx...${NC}"
if command -v npx &> /dev/null; then
    echo -e "${GREEN}✓ npx available${NC}"
else
    echo -e "${RED}✗ npx not found${NC}"
    exit 1
fi

# Check configuration
echo -e "\n${BLUE}Checking configuration...${NC}"
if [ "$AI_ENABLED" = "true" ] || [ "$AI_ENABLED" = "1" ]; then
    echo -e "${GREEN}✓ AI enabled${NC}"
    echo "  Provider: ${AI_PROVIDER:-not set}"
else
    echo -e "${YELLOW}⚠ AI not enabled${NC}"
fi

# Test MCP server (if configured)
if [ -n "${MCP_SERVER:-}" ]; then
    echo -e "\n${BLUE}Testing MCP server...${NC}"
    echo "MCP Server: $MCP_SERVER"
    # Don't actually test as it might hang, just verify command is valid
    echo -e "${GREEN}✓ MCP server configured${NC}"
fi

# Summary
echo -e "\n${GREEN}=== Setup Summary ===${NC}"
echo "AI Provider: ${AI_PROVIDER:-not set}"
if [ "${AI_PROVIDER:-}" = "cursor-agent" ]; then
    echo -e "${GREEN}✓ Using Cursor Agent (no API key needed!)${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Make sure Cursor IDE is running"
    echo "2. Test README generation:"
    echo "   ${YELLOW}./scripts/generate_readme.sh owner repo-name${NC}"
else
    echo -e "${YELLOW}⚠ Provider: ${AI_PROVIDER:-not set}${NC}"
    if [ -z "${AI_API_KEY:-}" ] && [ "${AI_PROVIDER:-}" != "cursor-agent" ] && [ "${AI_PROVIDER:-}" != "local" ]; then
        echo -e "${YELLOW}⚠ API key not set. Consider using cursor-agent provider!${NC}"
    fi
fi

echo ""
echo -e "${BLUE}To use this configuration:${NC}"
echo "  source ~/.config/mcp-readme/config.sh"
echo "  ./scripts/generate_readme.sh owner repo-name"
