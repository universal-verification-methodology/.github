#!/bin/bash
#
# Setup script for MCP (Model Context Protocol) integration
# with README generation
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MCP Setup for README Generation ===${NC}\n"

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js is not installed${NC}"
    echo "  Please install Node.js 18+ from https://nodejs.org/"
    exit 1
else
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js installed: ${NODE_VERSION}${NC}"
fi

# Check npm/npx
if ! command -v npx &> /dev/null; then
    echo -e "${RED}✗ npx is not available${NC}"
    exit 1
else
    echo -e "${GREEN}✓ npx available${NC}"
fi

# Test MCP servers availability
echo -e "\n${BLUE}Testing MCP servers...${NC}"

# Test filesystem server
echo -n "Testing filesystem MCP server... "
if timeout 5 npx -y @modelcontextprotocol/server-filesystem --help &> /dev/null 2>&1 || \
   npx -y @modelcontextprotocol/server-filesystem /tmp &> /dev/null 2>&1; then
    echo -e "${GREEN}✓ Available${NC}"
    FILESYSTEM_AVAILABLE=true
else
    echo -e "${YELLOW}⚠ May need installation${NC}"
    FILESYSTEM_AVAILABLE=false
fi

# Test GitHub server
echo -n "Testing GitHub MCP server... "
if timeout 5 npx -y @modelcontextprotocol/server-github --help &> /dev/null 2>&1 || true; then
    echo -e "${GREEN}✓ Available${NC}"
    GITHUB_AVAILABLE=true
else
    echo -e "${YELLOW}⚠ May need installation${NC}"
    GITHUB_AVAILABLE=false
fi

# Create configuration directory
CONFIG_DIR="$HOME/.config/mcp-readme"
mkdir -p "$CONFIG_DIR"

# Create configuration file
CONFIG_FILE="$CONFIG_DIR/config.sh"

echo -e "\n${BLUE}Creating MCP configuration...${NC}"

cat > "$CONFIG_FILE" << 'CONFIG_EOF'
#!/bin/bash
# MCP Configuration for README Generation
# Source this file: source ~/.config/mcp-readme/config.sh

# Enable AI
export AI_ENABLED=true

# RECOMMENDED: Use Cursor Agent (NO API KEY NEEDED!)
# This uses Cursor IDE's built-in AI when Cursor is running
export AI_PROVIDER=cursor-agent
export CURSOR_AGENT_MODE=mcp

# ALTERNATIVE: Use MCP provider (requires API key for fallback)
# export AI_PROVIDER=mcp
# export MCP_FALLBACK_PROVIDER=openai
# export AI_API_KEY=sk-your-openai-api-key-here

# MCP Server Configuration
# Option 1: Filesystem server (for reading repository files)
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'

# Option 2: GitHub server (uncomment to use)
# export MCP_SERVER='npx -y @modelcontextprotocol/server-github'

# API Keys (Only needed if not using cursor-agent)
# export AI_API_KEY=sk-your-openai-api-key-here
# export GITHUB_TOKEN=ghp-your-github-token-here  # If using GitHub MCP server

# Optional: Specific resource or tool
# export MCP_RESOURCE_URI='file:///path/to/repo/README.md'
# export MCP_TOOL_NAME='read_file'

# Optional: Model selection
# export AI_MODEL=gpt-4o-mini  # or gpt-4, claude-3-haiku, etc.
CONFIG_EOF

chmod +x "$CONFIG_FILE"

echo -e "${GREEN}✓ Configuration file created: ${CONFIG_FILE}${NC}"

# Create Cursor IDE configuration template
CURSOR_CONFIG="$CONFIG_DIR/cursor-mcp.json"

cat > "$CURSOR_CONFIG" << 'CURSOR_EOF'
{
  "mcp": {
    "servers": {
      "filesystem": {
        "command": "npx",
        "args": [
          "-y",
          "@modelcontextprotocol/server-filesystem",
          "${workspaceFolder}"
        ]
      },
      "github": {
        "command": "npx",
        "args": [
          "-y",
          "@modelcontextprotocol/server-github"
        ],
        "env": {
          "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token_here"
        }
      }
    }
  }
}
CURSOR_EOF

echo -e "${GREEN}✓ Cursor IDE config template created: ${CURSOR_CONFIG}${NC}"

# Create quick start script
QUICKSTART="$CONFIG_DIR/quickstart.sh"

cat > "$QUICKSTART" << 'QUICKSTART_EOF'
#!/bin/bash
# Quick start script for MCP-enabled README generation

# Load MCP configuration
source ~/.config/mcp-readme/config.sh

# Check if API key is set
if [ -z "${AI_API_KEY:-}" ]; then
    echo "Error: AI_API_KEY not set in ~/.config/mcp-readme/config.sh"
    echo "Please edit the config file and add your OpenAI API key"
    exit 1
fi

# Usage
if [ $# -lt 2 ]; then
    echo "Usage: $0 owner repo-name [output_file] [branch]"
    echo ""
    echo "Example:"
    echo "  $0 universal-verification-methodology cocotb"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATE_SCRIPT="$SCRIPT_DIR/scripts/generate_readme.sh"

if [ ! -f "$GENERATE_SCRIPT" ]; then
    echo "Error: generate_readme.sh not found at $GENERATE_SCRIPT"
    exit 1
fi

# Run README generation
"$GENERATE_SCRIPT" "$@"
QUICKSTART_EOF

chmod +x "$QUICKSTART"

echo -e "${GREEN}✓ Quick start script created: ${QUICKSTART}${NC}"

# Summary
echo -e "\n${GREEN}=== Setup Complete ===${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Edit the configuration file:"
echo -e "   ${YELLOW}${CONFIG_FILE}${NC}"
echo "   - Add your OpenAI API key"
echo "   - Add GitHub token if using GitHub MCP server"
echo "   - Customize MCP server settings"
echo ""
echo "2. Source the configuration:"
echo -e "   ${YELLOW}source ${CONFIG_FILE}${NC}"
echo ""
echo "3. Test README generation:"
echo -e "   ${YELLOW}source ${CONFIG_FILE}${NC}"
echo -e "   ${YELLOW}./scripts/generate_readme.sh owner repo-name${NC}"
echo ""
echo "   Or use the quick start script:"
echo -e "   ${YELLOW}${QUICKSTART} owner repo-name${NC}"
echo ""
echo "4. (Optional) Configure Cursor IDE:"
echo "   - Copy ${CURSOR_CONFIG} to your Cursor settings"
echo "   - Or manually add MCP servers in Cursor settings"
echo "   - Restart Cursor IDE"
echo ""
echo -e "${BLUE}For more information, see:${NC}"
echo "   - scripts/MCP_SETUP.md"
echo "   - scripts/AI_README_GENERATION.md"
echo ""
