#!/bin/bash
# Configure to use Cursor's internal AI API (if available)
# This attempts to connect to Cursor IDE's internal API endpoints

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Configuring to Use Cursor Internal AI ===${NC}\n"

CONFIG_FILE="$HOME/.config/cursor-readme/config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ Configuration file not found: $CONFIG_FILE${NC}"
    echo -e "  Run: ./scripts/configure_cursor_ai.sh"
    exit 1
fi

# Update CURSOR_AGENT_MODE to try internal API first
if grep -q "^export CURSOR_AGENT_MODE=" "$CONFIG_FILE"; then
    sed -i 's/^export CURSOR_AGENT_MODE=.*/export CURSOR_AGENT_MODE=internal  # Try Cursor internal API first/' "$CONFIG_FILE"
    echo -e "${GREEN}✓ Updated CURSOR_AGENT_MODE to 'internal'${NC}"
else
    # Insert after AI_PROVIDER line
    sed -i '/^export AI_PROVIDER=/a export CURSOR_AGENT_MODE=internal  # Try Cursor internal API first' "$CONFIG_FILE"
    echo -e "${GREEN}✓ Added CURSOR_AGENT_MODE=internal${NC}"
fi

# Optional: Set CURSOR_API_URL if you know a specific endpoint
# Uncomment and modify if you have a specific Cursor API endpoint:
# sed -i '/^export CURSOR_AGENT_MODE=/a export CURSOR_API_URL=http://localhost:3000/v1/chat/completions' "$CONFIG_FILE"

echo -e "\n${BLUE}Configuration updated!${NC}"
echo -e "${YELLOW}Note:${NC} Cursor IDE's internal API may not be accessible without authentication."
echo -e "If the internal API doesn't work, it will fall back to Ollama (local model).\n"

echo -e "${BLUE}To test if Cursor's internal API is available:${NC}"
echo -e "  1. Ensure Cursor IDE is running"
echo -e "  2. Try: curl -s http://localhost:3000/v1/chat/completions"
echo -e "  3. Or: curl -s http://localhost:8080/v1/chat/completions\n"

echo -e "${BLUE}To use this configuration:${NC}"
echo -e "  ${YELLOW}source ~/.config/cursor-readme/config.sh${NC}"
echo -e "  ${YELLOW}./scripts/generate_readme.sh owner repo${NC}\n"

echo -e "${BLUE}Current AI Provider Strategy:${NC}"
echo -e "  1. Try Cursor's internal API endpoints (localhost:3000, :8080, api.cursor.com)"
echo -e "  2. If that fails, fall back to Ollama (local model: ${AI_MODEL:-llama3})\n"
