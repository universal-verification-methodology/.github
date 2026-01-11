#!/bin/bash
# Fix MCP config file

cat > "$HOME/.config/mcp-readme/config.sh" << 'ENDOFFILE'
#!/bin/bash
# MCP Configuration for README Generation
# Source this file: source ~/.config/mcp-readme/config.sh

# Enable AI
export AI_ENABLED=true

# RECOMMENDED: Use Cursor Agent (NO API KEY NEEDED!)
# This uses Cursor IDE's built-in AI when Cursor is running
export AI_PROVIDER=cursor-agent
export CURSOR_AGENT_MODE=mcp

# Ensure Node.js 18 is used (required for MCP servers)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 18 2>/dev/null || true

# MCP Server Configuration
# Option 1: Filesystem server (for reading repository files)
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'

# Optional: Specific resource or tool
# export MCP_RESOURCE_URI='file:///path/to/repo/README.md'
# export MCP_TOOL_NAME='read_file'

# ALTERNATIVE: Use MCP provider with fallback (requires API key)
# export AI_PROVIDER=mcp
# export MCP_FALLBACK_PROVIDER=openai
# export AI_API_KEY=sk-your-openai-api-key-here
ENDOFFILE

chmod +x "$HOME/.config/mcp-readme/config.sh"
echo "✓ Config file fixed"
