#!/bin/bash
# Fix script to ensure MCP Cursor + Ollama works correctly

set -e

echo "=== Fixing MCP Cursor + Ollama Integration ==="

# 1. Test Ollama directly
echo ""
echo "1. Testing Ollama directly..."
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "ERROR: Ollama is not running"
    echo "Start it with: ollama serve"
    exit 1
fi
echo "✓ Ollama is running"

# 2. Test model
MODEL="llama3"
MODEL=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1 | sed 's/:latest$//' | sed 's/:.*$//' || echo "llama3")
echo "✓ Using model: $MODEL"

# 3. Test API call
echo ""
echo "2. Testing Ollama API call..."
TEST_DATA=$(jq -n --arg model "$MODEL" --arg prompt "Hello" '{
    model: $model,
    messages: [{role: "user", content: $prompt}],
    max_tokens: 10
}')

RESPONSE=$(curl -s -X POST http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "$TEST_DATA")

if [ -z "$RESPONSE" ]; then
    echo "ERROR: Empty response from Ollama"
    exit 1
fi

CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || echo "")
if [ -z "$CONTENT" ] || [ "$CONTENT" = "null" ]; then
    echo "ERROR: Could not extract content from response"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✓ Ollama API works: $CONTENT"

# 4. Update configuration to use direct Ollama
echo ""
echo "3. Updating configuration to use direct Ollama..."

CONFIG_FILE="$HOME/.config/cursor-readme/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    # Backup original
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    
    # Update to use local provider directly
    sed -i 's/export AI_PROVIDER=cursor-agent/export AI_PROVIDER=local/' "$CONFIG_FILE" || true
    sed -i 's/# export AI_PROVIDER=local/export AI_PROVIDER=local/' "$CONFIG_FILE" || true
    
    # Ensure AI_MODEL is set
    if ! grep -q "export AI_MODEL=" "$CONFIG_FILE"; then
        echo "export AI_MODEL=$MODEL" >> "$CONFIG_FILE"
    else
        sed -i "s/export AI_MODEL=.*/export AI_MODEL=$MODEL/" "$CONFIG_FILE" || true
    fi
    
    echo "✓ Configuration updated"
    echo "  AI_PROVIDER=local (direct Ollama)"
    echo "  AI_MODEL=$MODEL"
else
    echo "⚠ Config file not found: $CONFIG_FILE"
fi

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Test it with:"
echo "  source ~/.config/cursor-readme/config.sh"
echo "  ./scripts/generate_readme.sh universal-verification-methodology cocotb"
echo ""
echo "Or keep using cursor-agent (which should now work with the fixes):"
echo "  export AI_PROVIDER=cursor-agent"
echo "  ./scripts/generate_readme.sh universal-verification-methodology cocotb"
