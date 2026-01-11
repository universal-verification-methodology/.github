#!/bin/bash
# Test script to debug Ollama API calls

echo "=== Testing Ollama API ==="

# Test 1: Check if Ollama is running
echo "1. Checking Ollama status..."
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "   ✓ Ollama is running"
else
    echo "   ✗ Ollama is NOT running"
    echo "   Start it with: ollama serve"
    exit 1
fi

# Test 2: List available models
echo ""
echo "2. Available models:"
ollama list 2>/dev/null | head -5

# Test 3: Test Ollama API call
echo ""
echo "3. Testing Ollama API call..."
MODEL="llama3"
PROMPT='{"model":"'$MODEL'","messages":[{"role":"user","content":"Say hello"}],"max_tokens":20}'

RESPONSE=$(curl -s -X POST http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "$PROMPT" 2>&1)

echo "   Response status: $?"
if [ -n "$RESPONSE" ]; then
    echo "   Response length: ${#RESPONSE} characters"
    echo "   Response preview:"
    echo "$RESPONSE" | head -c 500
    echo ""
    
    # Try to extract content
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // .message.content // empty' 2>/dev/null || echo "")
    if [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
        echo "   ✓ Content extracted: $CONTENT"
    else
        echo "   ✗ Could not extract content from response"
        echo "   Full response:"
        echo "$RESPONSE"
    fi
else
    echo "   ✗ Empty response"
fi

echo ""
echo "4. Testing with jq parsing..."
if command -v jq >/dev/null 2>&1; then
    echo "   ✓ jq is installed"
    echo "$RESPONSE" | jq '.' 2>/dev/null | head -20 || echo "   ✗ Invalid JSON"
else
    echo "   ✗ jq is not installed"
fi
