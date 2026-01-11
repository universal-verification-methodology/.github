#!/bin/bash
# Configuration script for using Cursor MCP and AI (no external API key needed)
# This script helps set up the environment to use Cursor's MCP with local AI (Ollama)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Cursor MCP + AI Configuration (No API Key Required) ===${NC}\n"

# Check if we're in WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo -e "${YELLOW}Detected WSL environment${NC}"
    WSL_MODE=true
else
    WSL_MODE=false
fi

# Create config directory
CONFIG_DIR="$HOME/.config/cursor-readme"
mkdir -p "$CONFIG_DIR"

CONFIG_FILE="$CONFIG_DIR/config.sh"

echo -e "${GREEN}Creating configuration file: ${CONFIG_FILE}${NC}\n"

cat > "$CONFIG_FILE" << 'EOF'
#!/bin/bash
# Cursor MCP + AI Configuration (No External API Key Required)
# Source this file before running generate_readme.sh:
#   source ~/.config/cursor-readme/config.sh

# Enable AI
export AI_ENABLED=true

# Use Cursor Agent mode (tries Cursor MCP first, falls back to local Ollama)
export AI_PROVIDER=cursor-agent

# MCP Configuration for Cursor
# Option 1: Use filesystem MCP server (reads repository files for context)
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'

# Option 2: Use GitHub MCP server (requires GITHUB_TOKEN)
# export MCP_SERVER='npx -y @modelcontextprotocol/server-github'
# export GITHUB_TOKEN=ghp-your-token-here

# Cursor Agent Mode: 'mcp' to use MCP servers, 'internal' to try Cursor API
export CURSOR_AGENT_MODE=mcp

# MCP Fallback Provider: 'local' for Ollama (no API key), 'openai' for OpenAI (requires key)
export MCP_FALLBACK_PROVIDER=local  # Use Ollama by default (no API key needed)

# Optional: Specific MCP resource or tool
# export MCP_RESOURCE_URI='file:///path/to/repo/README.md'
# export MCP_TOOL_NAME='read_file'

# Local AI model configuration (fallback - used when MCP_FALLBACK_PROVIDER=local)
# If Cursor MCP is not available, will use local Ollama
export AI_BASE_URL=http://localhost:11434/v1

# Auto-detect available Ollama model
if command -v ollama >/dev/null 2>&1 && curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    AVAILABLE_MODEL=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1 | sed 's/:latest$//' | sed 's/:.*$//' || echo "llama2")
    export AI_MODEL="${AVAILABLE_MODEL:-llama2}"
    echo "Detected available Ollama model: $AI_MODEL"
else
    export AI_MODEL=llama2  # Default fallback
fi

# Optional: GitHub token for repository access
# export GITHUB_TOKEN=ghp-your-github-token-here
EOF

chmod +x "$CONFIG_FILE"
echo -e "${GREEN}✓ Configuration file created${NC}\n"

# Check for Node.js and npx
echo -e "${BLUE}Checking dependencies...${NC}"
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js installed: ${NODE_VERSION}${NC}"
else
    echo -e "${YELLOW}⚠ Node.js not found. MCP servers require Node.js.${NC}"
    echo -e "  Install Node.js: https://nodejs.org/"
    if [ "$WSL_MODE" = true ]; then
        echo -e "  Or in WSL: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    fi
fi

if command -v npx >/dev/null 2>&1; then
    echo -e "${GREEN}✓ npx available${NC}"
else
    echo -e "${YELLOW}⚠ npx not found (comes with Node.js)${NC}"
fi

# Check for Ollama (local AI fallback)
echo ""
if command -v ollama >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama installed (local AI fallback available)${NC}"
    echo -e "${BLUE}Available models:${NC}"
    ollama list 2>/dev/null | head -n 10 || echo "  (run 'ollama list' to see models)"
else
    echo -e "${YELLOW}⚠ Ollama not installed (optional - provides local AI fallback)${NC}"
    echo -e "  Install Ollama: https://ollama.ai/"
    echo -e "  Or run: curl -fsSL https://ollama.ai/install.sh | sh"
    echo -e "  Then: ollama pull llama2"
fi

# Check if Cursor IDE is running (optional check)
echo ""
if pgrep -f cursor >/dev/null 2>&1 || pgrep -f Cursor >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Cursor IDE appears to be running${NC}"
else
    echo -e "${YELLOW}⚠ Cursor IDE may not be running (optional - helpful for MCP)${NC}"
fi

# Create usage instructions
cat > "$CONFIG_DIR/README.md" << 'INSTRUCTIONS_EOF'
# Cursor MCP + AI Configuration (No API Key Required)

This configuration allows you to use Cursor's MCP (Model Context Protocol) capabilities
with local AI models (Ollama) as a fallback, eliminating the need for external API keys.

## Quick Start

1. **Source the configuration:**
   ```bash
   source ~/.config/cursor-readme/config.sh
   ```

2. **Generate a README:**
   ```bash
   ./scripts/generate_readme.sh universal-verification-methodology cocotb
   ```

## How It Works

1. **Primary: Cursor MCP** - Uses MCP servers to get context from your repository
2. **Fallback: Local Ollama** - If MCP isn't available, uses local AI model
3. **No API Key Required** - Everything runs locally or through Cursor IDE

## Setup Options

### Option 1: MCP + Local Ollama (Recommended - No API Key)

```bash
# 1. Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# 2. Pull a model (choose one)
ollama pull llama2        # General purpose
ollama pull codellama     # Code-focused
ollama pull mistral       # Fast and efficient

# 3. Source the config
source ~/.config/cursor-readme/config.sh

# 4. Generate README
./scripts/generate_readme.sh owner repo
```

### Option 2: MCP + Cursor IDE (If Cursor is running)

If Cursor IDE is running with MCP configured:

```bash
# 1. Ensure Cursor IDE is running
# 2. Configure MCP in Cursor settings (File > Preferences > Settings > MCP)

# 3. Source the config
source ~/.config/cursor-readme/config.sh

# 4. Generate README
./scripts/generate_readme.sh owner repo
```

### Option 3: Just Local Ollama (Simplest)

```bash
# 1. Install and pull a model
ollama pull llama2

# 2. Configure to use local only
export AI_ENABLED=true
export AI_PROVIDER=local
export AI_BASE_URL=http://localhost:11434/v1
export AI_MODEL=llama2

# 3. Generate README
./scripts/generate_readme.sh owner repo
```

## Troubleshooting

### MCP Server Not Found
- Ensure Node.js is installed: `node --version`
- Try manually: `npx -y @modelcontextprotocol/server-filesystem`

### Ollama Not Working
- Check if Ollama is running: `ollama list`
- Start Ollama: `ollama serve` (in another terminal)
- Pull a model: `ollama pull llama2`

### Cursor IDE Integration
- Ensure Cursor IDE is running
- Check Cursor settings for MCP configuration
- Set `CURSOR_MCP_PATH` environment variable if needed

## Configuration File Location

- Config: `~/.config/cursor-readme/config.sh`
- Source before running: `source ~/.config/cursor-readme/config.sh`
INSTRUCTIONS_EOF

echo -e "\n${GREEN}✓ Setup complete!${NC}\n"
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Source the configuration:"
echo -e "     ${YELLOW}source ~/.config/cursor-readme/config.sh${NC}"
echo -e ""
echo -e "  2. (Optional) Install Ollama for local AI:"
echo -e "     ${YELLOW}curl -fsSL https://ollama.ai/install.sh | sh${NC}"
echo -e "     ${YELLOW}ollama pull llama2${NC}"
echo -e ""
echo -e "  3. Generate a README:"
echo -e "     ${YELLOW}./scripts/generate_readme.sh owner repo-name${NC}"
echo -e ""
echo -e "${BLUE}For more information, see:${NC}"
echo -e "  ${YELLOW}~/.config/cursor-readme/README.md${NC}\n"
