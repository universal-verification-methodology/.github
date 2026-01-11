#!/bin/bash
# Complete setup script for MCP Cursor + Ollama integration
# This script sets up everything needed for README generation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Complete Setup for MCP Cursor + Ollama ===${NC}\n"

# Check if we're in WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo -e "${BLUE}Detected WSL environment${NC}"
    WSL_MODE=true
else
    WSL_MODE=false
fi

ERRORS=0

# Step 1: Check and fix Node.js
echo -e "${BLUE}[1/8] Checking Node.js...${NC}"

# Try to load nvm if available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || true

# Check if node is available
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version | sed 's/v//' 2>/dev/null || echo "unknown")
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d'.' -f1 2>/dev/null || echo "0")
    echo -e "${GREEN}  ✓ Node.js installed: v${NODE_VERSION}${NC}"
    
    if [ "$NODE_MAJOR" -lt 18 ]; then
        echo -e "${YELLOW}  ⚠ Node.js 18+ recommended (current: v${NODE_VERSION})${NC}"
        
        # Check if nvm has Node.js 18
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            \. "$NVM_DIR/nvm.sh"
            if nvm list 18 2>/dev/null | grep -q "v18"; then
                echo -e "  ${BLUE}Switching to Node.js 18 via nvm...${NC}"
                nvm use 18 >/dev/null 2>&1
                nvm alias default 18 >/dev/null 2>&1
                NEW_VERSION=$(node --version | sed 's/v//' 2>/dev/null || echo "")
                if [ "$(echo "$NEW_VERSION" | cut -d'.' -f1)" -ge 18 ]; then
                    echo -e "${GREEN}  ✓ Switched to Node.js v${NEW_VERSION}${NC}"
                else
                    echo -e "${YELLOW}  ⚠ Failed to switch to Node.js 18${NC}"
                    if [ -f scripts/use_node18.sh ]; then
                        echo -e "  ${BLUE}Run: ./scripts/use_node18.sh${NC}"
                    fi
                fi
            else
                echo -e "  ${BLUE}Installing Node.js 18 via nvm...${NC}"
                export TMPDIR="${TMPDIR:-/tmp}"
                nvm install 18 >/dev/null 2>&1 && nvm use 18 >/dev/null 2>&1 && nvm alias default 18 >/dev/null 2>&1 && {
                    echo -e "${GREEN}  ✓ Installed and switched to Node.js 18${NC}"
                } || {
                    echo -e "${YELLOW}  ⚠ Failed to install Node.js 18${NC}"
                    if [ -f scripts/upgrade_nodejs.sh ]; then
                        echo -e "  ${BLUE}Run: ./scripts/upgrade_nodejs.sh${NC}"
                    fi
                }
            fi
        else
            echo -e "  ${BLUE}Note: Node.js 12 works for basic scripts, but Node.js 18+ is recommended for MCP servers${NC}"
            echo -e "  ${BLUE}To upgrade: ./scripts/upgrade_nodejs.sh${NC}"
            echo -e "  ${YELLOW}(This is OK - Ollama doesn't require Node.js 18+)${NC}"
        fi
    else
        echo -e "${GREEN}  ✓ Node.js version is compatible (v${NODE_VERSION})${NC}"
    fi
else
    echo -e "${RED}  ✗ Node.js not installed${NC}"
    
    # Try to use nvm
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
        echo -e "  ${BLUE}Installing Node.js 18 via nvm...${NC}"
        export TMPDIR="${TMPDIR:-/tmp}"
        nvm install 18 >/dev/null 2>&1 && nvm use 18 >/dev/null 2>&1 && nvm alias default 18 >/dev/null 2>&1 && {
            echo -e "${GREEN}  ✓ Installed Node.js 18${NC}"
        } || {
            echo -e "${RED}  ✗ Failed to install Node.js${NC}"
            echo -e "  ${BLUE}Run: ./scripts/upgrade_nodejs.sh${NC}"
            ERRORS=$((ERRORS + 1))
        }
    else
        echo -e "  ${BLUE}Install: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs${NC}"
        echo -e "  ${BLUE}Or: ./scripts/upgrade_nodejs.sh${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Verify current node version after any changes
if command -v node >/dev/null 2>&1; then
    FINAL_VERSION=$(node --version)
    echo -e "  ${BLUE}Current Node.js: ${FINAL_VERSION}${NC}"
fi

# Step 2: Check and fix npx
echo -e "\n${BLUE}[2/8] Checking npx...${NC}"
if command -v npx >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ npx available${NC}"
else
    echo -e "${RED}  ✗ npx not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Step 3: Check and fix Ollama
echo -e "\n${BLUE}[3/8] Checking Ollama...${NC}"
if command -v ollama >/dev/null 2>&1; then
    OLLAMA_VERSION=$(ollama --version 2>/dev/null || echo "installed")
    echo -e "${GREEN}  ✓ Ollama installed: $OLLAMA_VERSION${NC}"
    
    # Check if Ollama is running
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Ollama is running${NC}"
        
        # Check available models
        MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -3 || echo "")
        if [ -n "$MODELS" ]; then
            echo -e "${GREEN}  ✓ Available models: $MODELS${NC}"
        else
            echo -e "${YELLOW}  ⚠ No models found. Pull one with: ollama pull llama3${NC}"
            echo -e "  ${BLUE}Installing llama3...${NC}"
            ollama pull llama3 >/dev/null 2>&1 || {
                echo -e "${YELLOW}  ⚠ Failed to pull llama3 automatically${NC}"
                echo -e "  ${BLUE}Manual: ollama pull llama3${NC}"
            }
        fi
    else
        echo -e "${YELLOW}  ⚠ Ollama is installed but not running${NC}"
        echo -e "  ${BLUE}Starting Ollama...${NC}"
        nohup ollama serve >/dev/null 2>&1 &
        sleep 3
        
        if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo -e "${GREEN}  ✓ Ollama started successfully${NC}"
        else
            echo -e "${RED}  ✗ Failed to start Ollama${NC}"
            echo -e "  ${BLUE}Manual start: ollama serve &${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    echo -e "${RED}  ✗ Ollama not installed${NC}"
    echo -e "  ${BLUE}Install: curl -fsSL https://ollama.ai/install.sh | sh${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Step 4: Check and fix jq
echo -e "\n${BLUE}[4/8] Checking jq (JSON processor)...${NC}"
if command -v jq >/dev/null 2>&1; then
    JQ_VERSION=$(jq --version 2>/dev/null || echo "installed")
    echo -e "${GREEN}  ✓ jq installed: $JQ_VERSION${NC}"
else
    echo -e "${RED}  ✗ jq not installed${NC}"
    echo -e "  ${BLUE}Installing jq...${NC}"
    if [ "$WSL_MODE" = true ]; then
        sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y jq >/dev/null 2>&1 || {
            echo -e "${YELLOW}  ⚠ Failed to install jq automatically${NC}"
            echo -e "  ${BLUE}Manual: sudo apt-get install -y jq${NC}"
            ERRORS=$((ERRORS + 1))
        }
    else
        echo -e "  ${BLUE}Install: sudo apt-get install -y jq${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    if command -v jq >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ jq installed successfully${NC}"
    fi
fi

# Step 5: Check and fix Cursor IDE detection
echo -e "\n${BLUE}[5/8] Checking Cursor IDE...${NC}"

CURSOR_FOUND=false

# Check if we're in WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    WSL_MODE=true
    echo -e "  ${BLUE}Detected WSL - checking Windows for Cursor IDE...${NC}"
    
    # Check Windows processes via tasklist.exe
    if command -v tasklist.exe >/dev/null 2>&1; then
        CURSOR_WIN_PROCESS=$(tasklist.exe /FI "IMAGENAME eq Cursor.exe" /NH 2>/dev/null | grep -i cursor || echo "")
        if [ -n "$CURSOR_WIN_PROCESS" ]; then
            CURSOR_FOUND=true
            echo -e "${GREEN}  ✓ Cursor IDE process found on Windows${NC}"
            echo -e "    $CURSOR_WIN_PROCESS" | sed 's/^/    /'
        fi
    fi
    
    # Check Windows config directories
    WINDOWS_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || echo "")
    if [ -n "$WINDOWS_USER" ] && [ "$CURSOR_FOUND" = false ]; then
        CURSOR_WIN_CONFIGS=(
            "/mnt/c/Users/${WINDOWS_USER}/AppData/Roaming/Cursor"
            "/mnt/c/Users/${WINDOWS_USER}/.cursor"
        )
        
        for config_path in "${CURSOR_WIN_CONFIGS[@]}"; do
            if [ -d "$config_path" ]; then
                CURSOR_FOUND=true
                echo -e "${GREEN}  ✓ Cursor IDE configuration found on Windows${NC}"
                echo -e "    Config: $config_path"
                # Check if recently modified
                if find "$config_path" -type f -mmin -60 2>/dev/null | grep -q .; then
                    echo -e "    ${GREEN}✓ Config recently modified (likely running)${NC}"
                fi
                break
            fi
        done
    fi
else
    # Native Linux - check processes directly
    CURSOR_PROCESS=$(pgrep -f -i cursor 2>/dev/null | head -1 || echo "")
    if [ -n "$CURSOR_PROCESS" ]; then
        CURSOR_FOUND=true
        echo -e "${GREEN}  ✓ Cursor IDE process found (PID: $CURSOR_PROCESS)${NC}"
    fi
fi

# Check WSL config directory
if [ "$CURSOR_FOUND" = false ] && [ -d "$HOME/.cursor" ]; then
    CURSOR_FOUND=true
    echo -e "${GREEN}  ✓ Cursor IDE configuration exists${NC}"
    echo -e "    Config: $HOME/.cursor"
fi

if [ "$CURSOR_FOUND" = false ]; then
    echo -e "${YELLOW}  ⚠ Cursor IDE not detected${NC}"
    if [ "$WSL_MODE" = true ]; then
        echo -e "  ${BLUE}Note: Cursor IDE runs on Windows host (not in WSL)${NC}"
        echo -e "  ${BLUE}To verify: Open Cursor IDE on Windows or check Task Manager${NC}"
    fi
    echo -e "  ${BLUE}This is OK - Ollama works independently${NC}"
fi

# Step 6: Check and fix configuration
echo -e "\n${BLUE}[6/8] Checking configuration...${NC}"
CONFIG_DIR="$HOME/.config/cursor-readme"
CONFIG_FILE="$CONFIG_DIR/config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}  ⚠ Config file not found${NC}"
    echo -e "  ${BLUE}Creating configuration...${NC}"
    ./scripts/configure_cursor_ai.sh >/dev/null 2>&1 || {
        echo -e "${RED}  ✗ Failed to create config${NC}"
        ERRORS=$((ERRORS + 1))
    }
fi

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}  ✓ Config file exists: $CONFIG_FILE${NC}"
    
    # Verify config is valid
    if bash -n "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Config file syntax is valid${NC}"
    else
        echo -e "${RED}  ✗ Config file has syntax errors${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Step 7: Test Ollama API
echo -e "\n${BLUE}[7/8] Testing Ollama API...${NC}"
MODEL="llama3"
MODEL=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1 | sed 's/:latest$//' | sed 's/:.*$//' || echo "llama3")

if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    TEST_DATA=$(jq -n --arg model "$MODEL" --arg prompt "Say hello" '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        max_tokens: 10
    }' 2>/dev/null)
    
    if [ -n "$TEST_DATA" ]; then
        TEST_RESPONSE=$(curl -s -X POST http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "$TEST_DATA" 2>/dev/null)
        
        if [ -n "$TEST_RESPONSE" ]; then
            TEST_CONTENT=$(echo "$TEST_RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || echo "")
            if [ -n "$TEST_CONTENT" ] && [ "$TEST_CONTENT" != "null" ]; then
                echo -e "${GREEN}  ✓ Ollama API works: $TEST_CONTENT${NC}"
            else
                echo -e "${YELLOW}  ⚠ Ollama API returned empty content${NC}"
                ERRORS=$((ERRORS + 1))
            fi
        else
            echo -e "${YELLOW}  ⚠ Ollama API returned empty response${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${YELLOW}  ⚠ Failed to create test JSON${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}  ✗ Ollama is not responding${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Step 8: Update configuration to use direct Ollama (most reliable)
echo -e "\n${BLUE}[8/8] Optimizing configuration...${NC}"
if [ -f "$CONFIG_FILE" ]; then
    # Update to use local provider directly for reliability
    if ! grep -q "^export AI_PROVIDER=local$" "$CONFIG_FILE" && ! grep -q "^export AI_PROVIDER=local " "$CONFIG_FILE"; then
        # Create backup
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Update config to use local provider (most reliable)
        sed -i 's/^export AI_PROVIDER=cursor-agent$/export AI_PROVIDER=local  # Direct Ollama - most reliable/' "$CONFIG_FILE" 2>/dev/null || true
        
        echo -e "${GREEN}  ✓ Configuration optimized for direct Ollama${NC}"
        echo -e "  ${BLUE}Changed: AI_PROVIDER=cursor-agent → AI_PROVIDER=local${NC}"
    else
        echo -e "${GREEN}  ✓ Configuration already optimized${NC}"
    fi
    
    # Ensure AI_MODEL is set
    if ! grep -q "^export AI_MODEL=" "$CONFIG_FILE"; then
        echo "export AI_MODEL=$MODEL" >> "$CONFIG_FILE"
        echo -e "${GREEN}  ✓ Added AI_MODEL=$MODEL to config${NC}"
    fi
    
    # Ensure AI_BASE_URL is set
    if ! grep -q "^export AI_BASE_URL=" "$CONFIG_FILE"; then
        sed -i '/^export AI_MODEL=/a export AI_BASE_URL=http://localhost:11434/v1' "$CONFIG_FILE" 2>/dev/null || \
        echo "export AI_BASE_URL=http://localhost:11434/v1" >> "$CONFIG_FILE"
        echo -e "${GREEN}  ✓ Added AI_BASE_URL to config${NC}"
    fi
fi

# Final Summary
echo ""
echo -e "${BLUE}=== Setup Summary ===${NC}\n"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}✓ Setup is complete${NC}\n"
else
    echo -e "${YELLOW}⚠ Found $ERRORS issue(s) that need attention${NC}\n"
fi

echo -e "${BLUE}Current Configuration:${NC}"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE" 2>/dev/null || true
fi

echo -e "  AI_ENABLED: ${AI_ENABLED:-false}"
echo -e "  AI_PROVIDER: ${AI_PROVIDER:-not set}"
echo -e "  AI_MODEL: ${AI_MODEL:-not set}"
echo -e "  AI_BASE_URL: ${AI_BASE_URL:-not set}"
echo ""

# Test script
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. ${GREEN}Source the configuration:${NC}"
echo -e "     ${YELLOW}source ~/.config/cursor-readme/config.sh${NC}"
echo ""
echo -e "  2. ${GREEN}Test README generation:${NC}"
echo -e "     ${YELLOW}./scripts/generate_readme.sh universal-verification-methodology cocotb${NC}"
echo ""
echo -e "  3. ${GREEN}Check the generated README:${NC}"
echo -e "     ${YELLOW}head -50 README.md${NC}"
echo ""

# Verify everything works
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}=== Ready to Generate READMEs! ===${NC}\n"
    
    # Quick test
    echo -e "${BLUE}Running quick test...${NC}"
    if [ -f scripts/generate_readme.sh ]; then
        source "$CONFIG_FILE" 2>/dev/null || true
        export AI_ENABLED=true
        export AI_PROVIDER="${AI_PROVIDER:-local}"
        export AI_BASE_URL="${AI_BASE_URL:-http://localhost:11434/v1}"
        export AI_MODEL="${AI_MODEL:-llama3}"
        
        # Test a simple AI call
        echo -e "${BLUE}Testing AI call (this may take a moment)...${NC}"
        timeout 30 bash -c 'source scripts/generate_readme.sh >/dev/null 2>&1; 
        AI_PROVIDER=local AI_BASE_URL=http://localhost:11434/v1 AI_MODEL=llama3 \
        bash -c "source scripts/generate_readme.sh >/dev/null 2>&1; 
        ai_call \"Say hello\" \"You are helpful\" 2>/dev/null | head -c 50"' 2>&1 | head -1 || {
            echo -e "${YELLOW}  ⚠ Quick test timeout or failed (this is OK - may need full test)${NC}"
        }
    fi
else
    echo -e "${YELLOW}=== Fix the issues above, then test ===${NC}\n"
fi

echo -e "${BLUE}For detailed diagnostics:${NC}"
echo -e "  ${YELLOW}./scripts/check_cursor_ide.sh${NC}  # Check Cursor IDE status"
echo -e "  ${YELLOW}./scripts/test_ollama.sh${NC}       # Test Ollama directly"
echo -e "  ${YELLOW}./scripts/test_cursor_mcp.sh${NC}   # Test full integration"
echo ""
