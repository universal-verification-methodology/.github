#!/bin/bash
# Test script to verify MCP Cursor + Ollama integration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Testing MCP Cursor + Ollama Integration ===${NC}\n"

# Source configuration
if [ -f ~/.config/cursor-readme/config.sh ]; then
    echo -e "${GREEN}Loading configuration...${NC}"
    source ~/.config/cursor-readme/config.sh
else
    echo -e "${YELLOW}⚠ Configuration not found, using defaults${NC}"
    export AI_ENABLED=true
    export AI_PROVIDER=cursor-agent
    export CURSOR_AGENT_MODE=mcp
    export MCP_FALLBACK_PROVIDER=local
    export AI_BASE_URL=http://localhost:11434/v1
    export AI_MODEL=llama3
fi

echo -e "${BLUE}Configuration:${NC}"
echo -e "  AI_ENABLED: ${AI_ENABLED:-false}"
echo -e "  AI_PROVIDER: ${AI_PROVIDER:-not set}"
echo -e "  AI_MODEL: ${AI_MODEL:-not set}"
echo -e "  MCP_SERVER: ${MCP_SERVER:-not set}"
echo ""

# Test 1: Check Ollama
echo -e "${BLUE}Test 1: Checking Ollama...${NC}"
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Ollama is running${NC}"
    MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -3 || echo "")
    echo -e "  Available models: $MODELS"
else
    echo -e "${RED}  ✗ Ollama is NOT running${NC}"
    echo -e "  Start it with: ollama serve"
    exit 1
fi

# Test 2: Test direct Ollama API call
echo ""
echo -e "${BLUE}Test 2: Testing direct Ollama API call...${NC}"
MODEL="${AI_MODEL:-llama3}"
MODEL=$(echo "$MODEL" | sed 's/:latest$//' | sed 's/:.*$//')

TEST_DATA=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "Say hello in one sentence" \
    '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        max_tokens: 20
    }')

RESPONSE=$(curl -s -X POST http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "$TEST_DATA" 2>&1)

if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || echo "")
    if [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
        echo -e "${GREEN}  ✓ Direct Ollama API works${NC}"
        echo -e "  Response: $CONTENT"
    else
        echo -e "${YELLOW}  ⚠ Direct API returned JSON but no content${NC}"
        echo -e "  Response: $(echo "$RESPONSE" | head -c 200)"
    fi
else
    echo -e "${RED}  ✗ Direct Ollama API failed${NC}"
    echo -e "  Response: $(echo "$RESPONSE" | head -c 200)"
    exit 1
fi

# Test 3: Test ai_call function from script
echo ""
echo -e "${BLUE}Test 3: Testing ai_call function from generate_readme.sh...${NC}"

# Source the script to get the ai_call function
if [ -f scripts/generate_readme.sh ]; then
    # Create a test function that calls ai_call
    TEST_FUNC=$(cat << 'EOF'
source scripts/generate_readme.sh >/dev/null 2>&1 || true

AI_PROVIDER=local
AI_BASE_URL=http://localhost:11434/v1
AI_MODEL=llama3

RESPONSE=$(ai_call "Say hello in one sentence" "You are a helpful assistant" 2>/dev/null)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] && [ -n "$RESPONSE" ] && [ "$RESPONSE" != "" ]; then
    echo "SUCCESS: $RESPONSE"
else
    echo "FAILED: exit_code=$EXIT_CODE, response_length=${#RESPONSE}"
    if [ -n "$RESPONSE" ]; then
        echo "Response: $(echo "$RESPONSE" | head -c 200)"
    fi
fi
EOF
)
    
    TEST_RESULT=$(bash -c "$TEST_FUNC" 2>&1)
    
    if echo "$TEST_RESULT" | grep -q "SUCCESS"; then
        echo -e "${GREEN}  ✓ ai_call function works${NC}"
        echo -e "  $(echo "$TEST_RESULT" | grep "SUCCESS")"
    else
        echo -e "${YELLOW}  ⚠ ai_call function had issues${NC}"
        echo -e "  $TEST_RESULT"
    fi
else
    echo -e "${YELLOW}  ⚠ generate_readme.sh not found${NC}"
fi

# Test 4: Test cursor-agent flow
echo ""
echo -e "${BLUE}Test 4: Testing cursor-agent → Ollama flow...${NC}"

if [ -f scripts/generate_readme.sh ]; then
    CURSOR_AGENT_TEST=$(cat << 'EOF'
source scripts/generate_readme.sh >/dev/null 2>&1 || true

AI_PROVIDER=cursor-agent
CURSOR_AGENT_MODE=mcp
MCP_FALLBACK_PROVIDER=local
AI_BASE_URL=http://localhost:11434/v1
AI_MODEL=llama3

RESPONSE=$(ai_call_cursor_agent "Say hello in one sentence" "You are a helpful assistant" 2>&1)
EXIT_CODE=$?

# Filter out log messages
CONTENT=$(echo "$RESPONSE" | grep -v "^\[INFO\]" | grep -v "^\[WARNING\]" | grep -v "^\[ERROR\]" | grep -v "Using Cursor" | grep -v "Attempting to use" | grep -v "Using local Ollama" | grep -v "Preparing to use" | head -1)

if [ -n "$CONTENT" ] && [ "$CONTENT" != "" ] && ! echo "$CONTENT" | grep -qE "^\[|^Using|^Attempting|^Preparing"; then
    echo "SUCCESS: $CONTENT"
else
    echo "FAILED: exit_code=$EXIT_CODE"
    echo "Raw response: $(echo "$RESPONSE" | head -c 300)"
fi
EOF
)
    
    AGENT_RESULT=$(bash -c "$CURSOR_AGENT_TEST" 2>&1)
    
    if echo "$AGENT_RESULT" | grep -q "SUCCESS"; then
        echo -e "${GREEN}  ✓ cursor-agent → Ollama flow works${NC}"
        echo -e "  $(echo "$AGENT_RESULT" | grep "SUCCESS")"
    else
        echo -e "${YELLOW}  ⚠ cursor-agent → Ollama flow had issues${NC}"
        echo -e "  $(echo "$AGENT_RESULT" | head -5)"
    fi
fi

echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "Run the full README generation to see complete flow:"
echo -e "  ${GREEN}source ~/.config/cursor-readme/config.sh${NC}"
echo -e "  ${GREEN}./scripts/generate_readme.sh owner repo${NC}"
