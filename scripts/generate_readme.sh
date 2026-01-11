#!/bin/bash
#
# Generate README.md for GitHub repositories using the GitHub API
# without cloning the repositories locally.
#
# Usage:
#   ./generate_readme.sh owner repo_name [output_file] [branch]
#   ./generate_readme.sh owner --org [output_dir] [branch]
#

set -euo pipefail

# Default GitHub token (can be overridden with GITHUB_TOKEN env var)
DEFAULT_TOKEN="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"
GITHUB_TOKEN="${GITHUB_TOKEN:-$DEFAULT_TOKEN}"
GITHUB_API="https://api.github.com"

# AI Configuration (optional - set to enable AI-powered README generation)
# Supported providers: "openai", "anthropic", "local", "cursor", "cursor-agent", "mcp" (via Ollama/OpenRouter)
AI_ENABLED="${AI_ENABLED:-false}"
AI_PROVIDER="${AI_PROVIDER:-openai}"  # openai, anthropic, local, cursor, cursor-agent, mcp
AI_API_KEY="${AI_API_KEY:-}"  # Optional for cursor-agent and local providers
AI_MODEL="${AI_MODEL:-gpt-4o-mini}"  # gpt-4o-mini, gpt-4, claude-3-haiku, etc.
AI_BASE_URL="${AI_BASE_URL:-}"  # For local models (Ollama: http://localhost:11434/v1)
# Cursor-specific: Cursor uses OpenAI/Anthropic models, set CURSOR_API_URL if using Cursor's API
CURSOR_API_URL="${CURSOR_API_URL:-https://api.cursor.com/v1}"  # Cursor API endpoint (if available)
# Cursor Agent: Use Cursor IDE's built-in AI (no API key needed if Cursor is running)
# When using cursor-agent, the script will attempt to use Cursor's MCP servers or internal AI
CURSOR_AGENT_MODE="${CURSOR_AGENT_MODE:-mcp}"  # "mcp" to use MCP, "internal" for Cursor's internal API
# MCP Configuration: MCP (Model Context Protocol) for Cursor and other MCP-compatible tools
MCP_SERVER="${MCP_SERVER:-}"  # MCP server command (e.g., "npx -y @modelcontextprotocol/server-filesystem")
MCP_RESOURCE_URI="${MCP_RESOURCE_URI:-}"  # Specific MCP resource URI to use
MCP_TOOL_NAME="${MCP_TOOL_NAME:-}"  # MCP tool name to invoke (if using tools instead of resources)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# AI-powered content generation functions
ai_call() {
    local prompt="$1"
    local system_prompt="${2:-You are a helpful assistant that generates high-quality README content for software repositories.}"
    
    if [ "$AI_ENABLED" != "true" ] && [ "$AI_ENABLED" != "1" ]; then
        return 1
    fi
    
    # Handle MCP provider separately
    if [ "$AI_PROVIDER" = "mcp" ]; then
        ai_call_with_mcp "$prompt" "$system_prompt"
        return $?
    fi
    
    # Handle cursor-agent (Cursor's built-in AI, no API key needed)
    if [ "$AI_PROVIDER" = "cursor-agent" ]; then
        ai_call_cursor_agent "$prompt" "$system_prompt"
        return $?
    fi
    
    if [ -z "$AI_API_KEY" ] && [ "$AI_PROVIDER" != "local" ] && [ "$AI_PROVIDER" != "mcp" ] && [ "$AI_PROVIDER" != "cursor-agent" ]; then
        log_warning "AI_API_KEY not set, skipping AI generation"
        return 1
    fi
    
    local response=""
    local api_url=""
    local headers=()
    local data=""
    
    case "$AI_PROVIDER" in
        openai)
            api_url="${AI_BASE_URL:-https://api.openai.com/v1/chat/completions}"
            headers=(-H "Authorization: Bearer ${AI_API_KEY}" -H "Content-Type: application/json")
            data=$(jq -n \
                --arg model "$AI_MODEL" \
                --arg system "$system_prompt" \
                --arg user "$prompt" \
                '{
                    model: $model,
                    messages: [
                        {role: "system", content: $system},
                        {role: "user", content: $user}
                    ],
                    temperature: 0.7,
                    max_tokens: 1000
                }')
            ;;
        anthropic)
            api_url="${AI_BASE_URL:-https://api.anthropic.com/v1/messages}"
            headers=(-H "x-api-key: ${AI_API_KEY}" -H "Content-Type: application/json" -H "anthropic-version: 2023-06-01")
            data=$(jq -n \
                --arg model "$AI_MODEL" \
                --arg system "$system_prompt" \
                --arg user "$prompt" \
                '{
                    model: $model,
                    max_tokens: 1000,
                    system: $system,
                    messages: [{role: "user", content: $user}]
                }')
            ;;
        local)
            # For local models (Ollama, OpenRouter compatible)
            api_url="${AI_BASE_URL:-http://localhost:11434/v1/chat/completions}"
            if [ -n "$AI_API_KEY" ]; then
                headers=(-H "Authorization: Bearer ${AI_API_KEY}" -H "Content-Type: application/json")
            else
                headers=(-H "Content-Type: application/json")
            fi
            
            # Auto-detect model if not set or default is OpenAI model
            local model="${AI_MODEL:-llama2}"
            if echo "$model" | grep -qiE "gpt|claude|openai|anthropic"; then
                log_info "Auto-detecting available Ollama model (current: $model is not an Ollama model)..."
                # Try to get first available model
                if command -v ollama >/dev/null 2>&1 && curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                    local available_model=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1 | sed 's/:latest$//' | sed 's/:.*$//' || echo "")
                    if [ -n "$available_model" ]; then
                        model="$available_model"
                        log_info "Using available Ollama model: $model"
                    else
                        log_warning "No Ollama models found. Pull one with: ollama pull llama2"
                        model="llama2"  # Default fallback
                    fi
                else
                    log_warning "Ollama not running or not available. Using default model: llama2"
                    model="llama2"  # Default fallback
                fi
            fi
            
            data=$(jq -n \
                --arg model "$model" \
                --arg system "$system_prompt" \
                --arg user "$prompt" \
                '{
                    model: $model,
                    messages: [
                        {role: "system", content: $system},
                        {role: "user", content: $user}
                    ],
                    temperature: 0.7,
                    max_tokens: 2000
                }' 2>&1)
            
            # Debug: Check if data was created successfully
            if [ $? -ne 0 ] || [ -z "$data" ]; then
                log_error "Failed to create JSON data for Ollama API call"
                log_error "jq error: $data"
                return 1
            fi
            ;;
        cursor)
            # Cursor API (OpenAI-compatible, uses OpenAI models)
            # Note: Cursor typically uses OpenAI models, so this uses OpenAI-compatible format
            # If Cursor has a custom API, set CURSOR_API_URL
            api_url="${CURSOR_API_URL:-${AI_BASE_URL:-https://api.openai.com/v1/chat/completions}}"
            if [ -z "$AI_API_KEY" ]; then
                log_warning "Cursor provider requires AI_API_KEY. Cursor typically uses OpenAI API keys."
                return 1
            fi
            headers=(-H "Authorization: Bearer ${AI_API_KEY}" -H "Content-Type: application/json")
            # Default to gpt-4 if no model specified (Cursor's default)
            local cursor_model="${AI_MODEL:-gpt-4}"
            data=$(jq -n \
                --arg model "$cursor_model" \
                --arg system "$system_prompt" \
                --arg user "$prompt" \
                '{
                    model: $model,
                    messages: [
                        {role: "system", content: $system},
                        {role: "user", content: $user}
                    ],
                    temperature: 0.7,
                    max_tokens: 1000
                }')
            ;;
        *)
            log_error "Unsupported AI provider: $AI_PROVIDER"
            return 1
            ;;
    esac
    
    # Make the API call
    # Capture stdout (response) and stderr (errors) separately
    local curl_stderr_file
    curl_stderr_file=$(mktemp)
    local curl_stdout
    curl_stdout=$(curl -s "${headers[@]}" -d "$data" "$api_url" 2>"$curl_stderr_file")
    local curl_exit=$?
    local curl_stderr
    curl_stderr=$(cat "$curl_stderr_file" 2>/dev/null || echo "")
    rm -f "$curl_stderr_file"
    response="$curl_stdout"
    
    # Check for curl errors
    if [ $curl_exit -ne 0 ]; then
        log_error "Curl failed with exit code: $curl_exit"
        log_error "API URL: $api_url"
        if [ -n "$curl_stderr" ]; then
            log_error "Curl error: $(echo "$curl_stderr" | head -c 200)"
        fi
        if [ -n "$response" ]; then
            log_error "Response (first 200 chars): $(echo "$response" | head -c 200)"
        fi
        return 1
    fi
    
    # Check if response is empty
    if [ -z "$response" ]; then
        log_error "Empty response from API: $api_url"
        if [ -n "$curl_stderr" ]; then
            log_error "Curl stderr: $(echo "$curl_stderr" | head -c 200)"
        fi
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_error "Invalid JSON response from API: $api_url"
        log_error "Response (first 300 chars): $(echo "$response" | head -c 300)"
        if [ -n "$curl_stderr" ]; then
            log_error "Curl stderr: $(echo "$curl_stderr" | head -c 200)"
        fi
        return 1
    fi
    
    # Extract content based on provider
    local content=""
    case "$AI_PROVIDER" in
        openai|local|cursor)
            content=$(echo "$response" | jq -r '.choices[0].message.content // .message.content // empty' 2>/dev/null || echo "")
            ;;
        anthropic)
            content=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null || echo "")
            ;;
        mcp)
            # MCP responses are handled separately
            content=$(echo "$response" | jq -r '.result.content[0].text // .result.content // .result // empty' 2>/dev/null || echo "")
            ;;
    esac
    
    # Check if content was extracted
    if [ -z "$content" ] || [ "$content" = "null" ] || [ "$content" = "" ]; then
        log_error "Failed to extract content from API response"
        log_error "Response structure: $(echo "$response" | jq 'keys' 2>/dev/null || echo "invalid JSON")"
        log_error "Full response (first 500 chars): $(echo "$response" | head -c 500)"
        return 1
    fi
    
    # Return the extracted content (to stdout)
    echo "$content"
    return 0
}

# MCP (Model Context Protocol) support functions
# MCP allows tools to provide context to AI models via resources and tools

# Call MCP server via JSON-RPC (stdio)
mcp_call_stdio() {
    local method="$1"
    local params="$2"
    local server_cmd="${MCP_SERVER:-}"
    
    if [ -z "$server_cmd" ]; then
        log_error "MCP_SERVER not configured. Set MCP_SERVER environment variable."
        return 1
    fi
    
    # Create JSON-RPC request
    local request
    request=$(jq -n \
        --arg method "$method" \
        --argjson params "$params" \
        '{
            jsonrpc: "2.0",
            id: 1,
            method: $method,
            params: $params
        }')
    
    # Send request to MCP server via stdio
    echo "$request" | eval "$server_cmd" 2>/dev/null || return 1
}

# Fetch MCP resource
mcp_fetch_resource() {
    local uri="${1:-$MCP_RESOURCE_URI}"
    
    if [ -z "$uri" ]; then
        log_error "MCP resource URI not provided"
        return 1
    fi
    
    local params
    params=$(jq -n --arg uri "$uri" '{uri: $uri}')
    
    local response
    response=$(mcp_call_stdio "resources/read" "$params")
    
    if [ -z "$response" ]; then
        return 1
    fi
    
    # Extract resource content
    echo "$response" | jq -r '.result.contents[0].text // .result // empty' 2>/dev/null || echo ""
}

# Invoke MCP tool
mcp_invoke_tool() {
    local tool_name="${1:-$MCP_TOOL_NAME}"
    local tool_args="${2:-{}}"
    
    if [ -z "$tool_name" ]; then
        log_error "MCP tool name not provided"
        return 1
    fi
    
    local params
    params=$(jq -n \
        --arg name "$tool_name" \
        --argjson arguments "$tool_args" \
        '{name: $name, arguments: $arguments}')
    
    local response
    response=$(mcp_call_stdio "tools/call" "$params")
    
    if [ -z "$response" ]; then
        return 1
    fi
    
    # Extract tool result
    echo "$response" | jq -r '.result.content[0].text // .result // empty' 2>/dev/null || echo ""
}

# AI call using MCP (fetches context from MCP resources first)
ai_call_with_mcp() {
    local prompt="$1"
    local system_prompt="${2:-You are a helpful assistant that generates high-quality README content for software repositories.}"
    
    if [ "$AI_PROVIDER" != "mcp" ]; then
        # If not using MCP provider, fall back to regular AI call
        ai_call "$prompt" "$system_prompt"
        return $?
    fi
    
    # Collect context from MCP resources if available
    local mcp_context=""
    if [ -n "$MCP_RESOURCE_URI" ]; then
        log_info "Fetching context from MCP resource: $MCP_RESOURCE_URI"
        mcp_context=$(mcp_fetch_resource "$MCP_RESOURCE_URI")
        if [ -n "$mcp_context" ]; then
            prompt="Context from repository:\n${mcp_context}\n\nUser request: ${prompt}"
        fi
    fi
    
    # If MCP tool is configured, use it to generate content
    if [ -n "$MCP_TOOL_NAME" ]; then
        log_info "Invoking MCP tool: $MCP_TOOL_NAME"
        local tool_args
        tool_args=$(jq -n \
            --arg prompt "$prompt" \
            --arg system "$system_prompt" \
            '{prompt: $prompt, system_prompt: $system}')
        
        mcp_invoke_tool "$MCP_TOOL_NAME" "$tool_args"
        return $?
    fi
    
    # Otherwise, try to use MCP with a standard AI provider
    # This allows MCP to provide context to OpenAI/Anthropic/etc.
    if [ -n "$mcp_context" ]; then
        # Enhance prompt with MCP context
        prompt="Context from MCP:\n${mcp_context}\n\n${prompt}"
    fi
    
    # Fall back to regular AI call with enhanced context
    # Use a fallback provider if MCP is just for context
    # Default to 'local' (Ollama) for no-API-key setup, but allow override
    local fallback_provider="${MCP_FALLBACK_PROVIDER:-local}"
    
    # If fallback is 'local', check if Ollama is available, otherwise use openai (but warn about key)
    if [ "$fallback_provider" = "local" ]; then
        if ! command -v ollama >/dev/null 2>&1; then
            log_warning "Ollama not found, falling back to OpenAI (requires API key)"
            log_info "Install Ollama for free local AI: curl -fsSL https://ollama.ai/install.sh | sh"
            fallback_provider="openai"
        else
            # Ensure Ollama is running
            if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                log_warning "Ollama not running, falling back to OpenAI (requires API key)"
                log_info "Start Ollama: ollama serve"
                fallback_provider="openai"
            else
                # Set local provider defaults
                AI_BASE_URL="${AI_BASE_URL:-http://localhost:11434/v1}"
                AI_MODEL="${AI_MODEL:-llama2}"
            fi
        fi
    fi
    
    local original_provider="$AI_PROVIDER"
    AI_PROVIDER="$fallback_provider"
    ai_call "$prompt" "$system_prompt"
    local result=$?
    AI_PROVIDER="$original_provider"
    return $result
}

# AI call using Cursor's built-in agent (no API key needed)
ai_call_cursor_agent() {
    local prompt="$1"
    local system_prompt="${2:-You are a helpful assistant that generates high-quality README content for software repositories.}"
    
    log_info "Using Cursor's built-in AI agent (no API key required)"
    
    # Strategy 1: Try MCP only if we have a specific AI tool configured
    # NOTE: Most MCP servers (like filesystem) provide context, not AI completions
    # Only use MCP if we have an MCP_TOOL_NAME that can generate AI responses
    if [ "${CURSOR_AGENT_MODE:-mcp}" = "mcp" ] && [ -n "${MCP_TOOL_NAME:-}" ] && [ -n "${MCP_SERVER:-}" ]; then
        log_info "Attempting to use MCP tool: $MCP_TOOL_NAME"
        local original_provider="$AI_PROVIDER"
        AI_PROVIDER="mcp"
        local mcp_response=$(ai_call_with_mcp "$prompt" "$system_prompt" 2>/dev/null)
        local result=$?
        AI_PROVIDER="$original_provider"
        # Only use MCP response if it's non-empty and doesn't look like log messages
        if [ $result -eq 0 ] && [ -n "$mcp_response" ] && [ "$mcp_response" != "" ] && ! echo "$mcp_response" | grep -qE "^\[INFO\]|^\[WARNING\]|^\[ERROR\]"; then
            echo "$mcp_response"
            return 0
        fi
        log_info "MCP tool did not return valid AI response, falling back to Ollama..."
    fi
        
    
    # Strategy 2: Try to use Cursor's internal API endpoint (if accessible without key)
    # Cursor IDE might expose a local API endpoint
    if [ "${CURSOR_AGENT_MODE:-mcp}" = "internal" ] || [ -z "${CURSOR_AGENT_MODE}" ]; then
        log_info "Attempting to use Cursor's internal API..."
        
        # Try Cursor's local API endpoint (common ports for local services)
        local cursor_endpoints=(
            "http://localhost:3000/v1/chat/completions"
            "http://localhost:8080/v1/chat/completions"
            "${CURSOR_API_URL:-https://api.cursor.com/v1/chat/completions}"
        )
        
        for endpoint in "${cursor_endpoints[@]}"; do
            log_info "Trying Cursor API endpoint: $endpoint"
            local test_response=$(curl -s -X POST "$endpoint" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"cursor\",\"messages\":[{\"role\":\"system\",\"content\":\"test\"},{\"role\":\"user\",\"content\":\"test\"}]}" \
                2>/dev/null || echo "")
            
            if [ -n "$test_response" ] && ! echo "$test_response" | grep -q "error\|401\|403"; then
                log_info "Cursor API endpoint appears to be available: $endpoint"
                # Use this endpoint for the actual request
                local response=$(curl -s -X POST "$endpoint" \
                    -H "Content-Type: application/json" \
                    -d "$(jq -n \
                        --arg model "${AI_MODEL:-cursor}" \
                        --arg system "$system_prompt" \
                        --arg user "$prompt" \
                        '{
                            model: $model,
                            messages: [
                                {role: "system", content: $system},
                                {role: "user", content: $user}
                            ],
                            temperature: 0.7,
                            max_tokens: 2000
                        }')" 2>/dev/null || echo "")
                
                if [ -n "$response" ]; then
                    local content=$(echo "$response" | jq -r '.choices[0].message.content // .content // empty' 2>/dev/null || echo "")
                    if [ -n "$content" ] && [ "$content" != "null" ]; then
                        echo "$content"
                        return 0
                    fi
                fi
            fi
        done
    fi
    
    # Strategy 3: Try using local Ollama (primary method for cursor-agent)
    # Since MCP servers typically don't generate AI completions, Ollama is the reliable fallback
    if command -v ollama >/dev/null 2>&1; then
        log_info "Using local Ollama for AI generation..."
        
        # Check if Ollama is running
        if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            log_warning "Ollama is installed but not running. Start it with: ollama serve"
            log_info "Trying to start Ollama in background..."
            # Try to start Ollama (non-blocking)
            nohup ollama serve >/dev/null 2>&1 &
            sleep 2
            # Check again
            if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                log_warning "Could not start Ollama. Please start it manually: ollama serve"
                return 1
            fi
        fi
        
        # Get and normalize model name (strip :latest tag for API call)
        local model="${AI_MODEL:-llama2}"
        # Strip any tags for API call (Ollama API accepts base name)
        model=$(echo "$model" | sed 's/:latest$//' | sed 's/:.*$//')
        
        # Verify model exists (optional check - can be slow, so we'll just try the API call)
        log_info "Preparing to use Ollama model: $model"
        
        # Use Ollama for AI call
        log_info "Using Ollama model: $model"
        local original_provider="$AI_PROVIDER"
        local original_base_url="$AI_BASE_URL"
        local original_model="$AI_MODEL"
        
        AI_PROVIDER="local"
        AI_BASE_URL="http://localhost:11434/v1"
        AI_MODEL="$model"
        
        # Call ai_call and capture ONLY stdout (AI response content)
        # ai_call outputs content to stdout and logs to stderr (>&2)
        # So we redirect stderr to /dev/null to discard logs
        local ollama_response
        ollama_response=$(ai_call "$prompt" "$system_prompt" 2>/dev/null)
        local result=$?
        
        # Restore original values
        AI_PROVIDER="$original_provider"
        AI_BASE_URL="$original_base_url"
        AI_MODEL="$original_model"
        
        # Check if we got a valid response
        if [ $result -eq 0 ] && [ -n "$ollama_response" ] && [ "$ollama_response" != "" ]; then
            # Verify it's actual content, not error messages
            if ! echo "$ollama_response" | grep -qE "^\[|^Curl|^API|^Failed|^Empty|^Invalid|^jq"; then
                log_info "Ollama response received (${#ollama_response} chars): $(echo "$ollama_response" | head -c 100)..."
                # Return the response (this goes to stdout)
                echo "$ollama_response"
                return 0
            else
                log_warning "Ollama response appears to be error messages, not content"
                log_info "Response preview: $(echo "$ollama_response" | head -c 200)"
            fi
        else
            if [ $result -ne 0 ]; then
                log_warning "ai_call failed with exit code: $result"
            fi
            if [ -z "$ollama_response" ]; then
                log_warning "ai_call returned empty response"
            fi
        fi
        
        # If we got here, ai_call failed - try direct API call as fallback
        log_info "ai_call failed, trying direct Ollama API call as fallback..."
        local direct_data
        direct_data=$(jq -n \
            --arg model "$model" \
            --arg system "$system_prompt" \
            --arg user "$prompt" \
            '{
                model: $model,
                messages: [
                    {role: "system", content: $system},
                    {role: "user", content: $user}
                ],
                temperature: 0.7,
                max_tokens: 2000
            }' 2>&1)
        
        if [ $? -ne 0 ] || [ -z "$direct_data" ]; then
            log_error "Failed to create JSON data for direct API call"
            log_error "jq error: $direct_data"
            return 1
        fi
        
        local direct_response
        direct_response=$(curl -s -X POST http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "$direct_data" 2>&1)
        local curl_result=$?
        
        if [ $curl_result -ne 0 ] || [ -z "$direct_response" ]; then
            log_error "Direct API call failed with exit code: $curl_result"
            log_error "Response: $(echo "$direct_response" | head -c 200)"
            return 1
        fi
        
        # Check if response is valid JSON
        if ! echo "$direct_response" | jq . >/dev/null 2>&1; then
            log_error "Direct API returned invalid JSON: $(echo "$direct_response" | head -c 300)"
            return 1
        fi
        
        # Extract content
        local direct_content
        direct_content=$(echo "$direct_response" | jq -r '.choices[0].message.content // .message.content // empty' 2>/dev/null || echo "")
        
        if [ -n "$direct_content" ] && [ "$direct_content" != "null" ] && [ "$direct_content" != "" ]; then
            log_info "Direct Ollama API call SUCCESS (${#direct_content} chars): $(echo "$direct_content" | head -c 100)..."
            echo "$direct_content"
            return 0
        else
            log_error "Direct API call returned JSON but no content field"
            log_error "Response structure: $(echo "$direct_response" | jq 'keys' 2>/dev/null || echo "invalid")"
            log_error "Full response: $(echo "$direct_response" | head -c 500)"
            return 1
        fi
    fi
    
    # Final fallback: Provide helpful instructions
    log_warning "Could not connect to any AI provider. Options:"
    log_info "  1. Install and start Ollama (recommended - no API key needed):"
    log_info "     curl -fsSL https://ollama.ai/install.sh | sh"
    log_info "     ollama pull llama2"
    log_info "     ollama serve"
    log_info "  2. Ensure Cursor IDE is running with MCP configured"
    log_info "  3. Set AI_PROVIDER='local' with Ollama running"
    log_info "  4. Or set AI_PROVIDER='openai' with an API key"
    
    return 1
}

# Parse structured AI response for repository analysis
parse_ai_repo_response() {
    local response="$1"
    
    # Extract DESCRIPTION section (everything after "DESCRIPTION:" until next section)
    local description=$(echo "$response" | sed -n '/^DESCRIPTION:/,/^FEATURES:/p' | sed '1d;$d' | grep -v "^\[" | grep -v "^FEATURES:" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract FEATURES section (everything after "FEATURES:" until next section or end)
    local features=$(echo "$response" | sed -n '/^FEATURES:/,/^USE_CASE:/p' | sed '1d;$d' | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//' | sed 's/^-[[:space:]]*/- /' | sed 's/^\[//;s/\]$//' | sed 's/^Feature [0-9]\+:\s*//i' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract USE_CASE section (everything after "USE_CASE:" until end or next section)
    local use_case=$(echo "$response" | sed -n '/^USE_CASE:/,$p' | sed '1d' | grep -v "^INSTRUCTIONS:" | grep -v "^\[" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -n 5 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # If parsing failed, try fallback methods
    if [ -z "$description" ] || [ "$description" = "" ]; then
        # Try finding description in first few lines (common formats)
        description=$(echo "$response" | head -n 15 | grep -v "^FEATURES:" | grep -v "^USE_CASE:" | grep -v "^INSTRUCTIONS:" | grep -v "^\[" | sed 's/^description:\s*//i' | sed 's/^DESCRIPTION:\s*//i' | head -n 3 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    if [ -z "$features" ] || [ -z "$(echo "$features" | grep -v '^[[:space:]]*$')" ]; then
        # Try finding features as bullet points (anywhere in response)
        features=$(echo "$response" | grep -E "^-|^[[:space:]]+-|^[0-9]+\.|^[[:space:]]*[0-9]+\." | head -n 7 | sed 's/^[[:space:]]*//' | sed 's/^[0-9]\+\.\s*/- /' | sed 's/^\[//;s/\]$//' | sed 's/^Feature [0-9]\+:\s*//i' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    # Clean up description - remove placeholder text
    description=$(echo "$description" | sed 's/\[Write.*\]//g' | sed 's/\[.*\]//g' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Return as structured format
    echo "DESCRIPTION:${description}"
    if [ -n "$features" ]; then
        echo "$features" | while IFS= read -r line; do
            # Skip empty lines and placeholder text
            if [ -n "$line" ] && ! echo "$line" | grep -qE "^\[|^Feature [0-9]+:"; then
                # Ensure it starts with - for markdown
                if [[ ! "$line" =~ ^- ]]; then
                    line="- ${line}"
                fi
                echo "FEATURE:${line}"
            fi
        done
    fi
    if [ -n "$use_case" ] && ! echo "$use_case" | grep -qE "^\["; then
        echo "USE_CASE:${use_case}"
    fi
}

# Parse structured AI response for usage examples
parse_ai_usage_response() {
    local response="$1"
    
    # Extract USAGE_EXAMPLE section (code block)
    # Look for section between USAGE_EXAMPLE: and EXPLANATION: or COMMON_USE_CASES:
    local usage_section=$(echo "$response" | sed -n '/^USAGE_EXAMPLE:/,/^EXPLANATION:\|^COMMON_USE_CASES:/p' | sed '1d;$d')
    
    # Extract code from code blocks (between ``` markers)
    local usage_example=""
    if echo "$usage_section" | grep -q '```'; then
        # Extract code between first ``` and second ``` markers (excluding the markers)
        # Use a while loop for robust multi-line extraction
        local in_block=false
        usage_example=""
        while IFS= read -r line; do
            # Check if line starts with ```
            if echo "$line" | grep -q '^```'; then
                if [ "$in_block" = false ]; then
                    in_block=true
                    # Skip the opening ``` line
                    continue
                else
                    # Found closing ```, stop extracting
                    break
                fi
            elif [ "$in_block" = true ]; then
                # We're inside the code block, add this line
                if [ -z "$usage_example" ]; then
                    usage_example="$line"
                else
                    usage_example="${usage_example}
${line}"
                fi
            fi
        done < <(printf '%s\n' "$usage_section")
        
        # Clean up the extracted code - limit length but preserve structure
        if [ -n "$usage_example" ]; then
            # Limit to 20 lines to avoid extremely long examples
            usage_example=$(echo -e "$usage_example" | head -n 20)
        fi
    else
        # No code block markers, extract everything except section headers
        usage_example=$(echo "$usage_section" | grep -v "^EXPLANATION:" | grep -v "^COMMON_USE_CASES:" | grep -v "^INSTRUCTIONS:" | grep -v "^USAGE_EXAMPLE:" | sed 's/^[[:space:]]*//' | head -n 15)
    fi
    
    # Extract EXPLANATION section
    local explanation=$(echo "$response" | sed -n '/^EXPLANATION:/,/^COMMON_USE_CASES:/p' | sed '1d;$d' | grep -v '^```' | grep -v "^COMMON_USE_CASES:" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract COMMON_USE_CASES section
    local use_cases=$(echo "$response" | sed -n '/^COMMON_USE_CASES:/,$p' | sed '1d' | grep -v "^INSTRUCTIONS:" | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//' | head -n 5)
    
    # Fallback: try to find code blocks directly if structured format not found
    if [ -z "$usage_example" ] || [ "$usage_example" = "" ]; then
        if echo "$response" | grep -q '```'; then
            # Find first code block (between ``` markers) - extract content between markers
            local in_block=false
            usage_example=""
            while IFS= read -r line; do
                if echo "$line" | grep -q '^```'; then
                    if [ "$in_block" = false ]; then
                        in_block=true
                    else
                        break  # Found closing ```
                    fi
                elif [ "$in_block" = true ]; then
                    if [ -z "$usage_example" ]; then
                        usage_example="$line"
                    else
                        usage_example="${usage_example}
${line}"
                    fi
                fi
            done < <(printf '%s\n' "$response")
            # Clean up
            usage_example=$(echo "$usage_example" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | head -n 15)
        fi
    fi
    
    # Fallback: try to extract explanation from common formats
    if [ -z "$explanation" ]; then
        explanation=$(echo "$response" | grep -i "explanation\|explains\|does\|shows" | head -n 2 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    # Return structured format
    echo "USAGE_EXAMPLE:${usage_example}"
    echo "EXPLANATION:${explanation}"
    if [ -n "$use_cases" ]; then
        echo "$use_cases" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                echo "USE_CASE:${line}"
            fi
        done
    fi
}

# Analyze repository with AI to generate better descriptions
ai_analyze_repo() {
    local owner="$1"
    local repo="$2"
    local description="$3"
    local language="$4"
    local topics="$5"
    local languages="$6"
    
    local context="Repository: ${owner}/${repo}
Description: ${description}
Primary Language: ${language}
Languages: ${languages}
Topics: ${topics}"

    local prompt="You are analyzing a GitHub repository for hardware verification and SystemVerilog projects. Generate comprehensive README content.

REPOSITORY INFORMATION:
${context}

YOUR TASK:
Analyze this repository and provide EXACTLY the following in this format:

DESCRIPTION:
[Write 2-3 sentences explaining what this project does, its purpose, and why it's valuable. Be specific about the verification methodology, testbench framework, or verification IP it provides. If it's about RISC-V cores, mention which cores. If it's about cocotb, mention it's a coroutine-based testbench framework. Do NOT start with the repository name.]

FEATURES:
- [Feature 1: Be specific and technical, e.g., \"Coroutine-based testbench framework for Python\" not \"Well-structured framework\"]
- [Feature 2: Another specific technical feature]
- [Feature 3: Another specific feature]
- [Feature 4: Another specific feature]
- [Feature 5: Another specific feature]
- [Feature 6: Additional specific feature if applicable]
- [Feature 7: Additional specific feature if applicable]

USE_CASE:
[1-2 sentences about when and why someone would use this project. Be specific about the verification use case.]

INSTRUCTIONS:
- Be specific and technical, avoid generic phrases like \"comprehensive\" or \"well-structured\" without context
- Focus on what makes this repository unique and valuable
- For verification projects, mention specific methodologies (UVM, SystemVerilog, cocotb, etc.)
- If the project is for specific cores or IP, mention them
- Write in clear, professional technical documentation style
- Do NOT repeat the repository name in every feature
- Output ONLY the three sections above (DESCRIPTION, FEATURES, USE_CASE) with nothing else"

    ai_call "$prompt" "You are an expert technical writer specializing in hardware verification methodologies, SystemVerilog, RISC-V cores, and open-source verification projects. You write clear, specific, and technically accurate documentation."
}

# Generate usage examples with AI
ai_generate_usage() {
    local owner="$1"
    local repo="$2"
    local language="$3"
    local example_files="$4"
    
    local prompt="You are generating usage examples for a ${language} project called ${repo} in the hardware verification/SystemVerilog domain.

${example_files}

YOUR TASK:
Generate practical, runnable code examples in this EXACT format:

USAGE_EXAMPLE:
\`\`\`${language}
[3-8 lines of actual runnable code showing basic usage]
\`\`\`

EXPLANATION:
[1-2 sentences explaining what this code does and how it works. Be specific about the API calls, setup, or workflow.]

COMMON_USE_CASES:
- [Use case 1: Specific scenario when someone would use this]
- [Use case 2: Another specific scenario]
- [Use case 3: Another scenario if applicable]

INSTRUCTIONS:
- Provide ACTUAL runnable code, not pseudo-code or placeholders
- If this is a verification project (cocotb, SystemVerilog, UVM), show realistic testbench or test setup code
- If this is a Python project, include proper imports
- If example files were provided, base your example on them but make it simpler and more beginner-friendly
- Make the code example practical and immediately useful
- Explain what each key part does
- Use proper ${language} syntax and best practices
- If ${language} is \"Makefile\" or \"Shell\", show actual commands
- Output ONLY the three sections above (USAGE_EXAMPLE, EXPLANATION, COMMON_USE_CASES) with nothing else
- Do NOT add markdown headers or extra formatting beyond what's specified"

    ai_call "$prompt" "You are an expert in ${language} programming and hardware verification. You create clear, accurate, and immediately useful code examples that help developers get started quickly."
}

# Analyze project structure with AI
ai_analyze_structure() {
    local owner="$1"
    local repo="$2"
    local structure_info="$3"
    
    local prompt="Analyze this project structure and provide:
1. A brief explanation of the directory organization
2. What each major directory likely contains
3. How the project is organized

Project structure:
${structure_info}"

    ai_call "$prompt" "You are a software architecture expert. Analyze project structures and explain them clearly."
}

# Make API request with error handling
api_request() {
    local method="${1:-GET}"
    local endpoint="$2"
    local data="${3:-}"
    local url="${GITHUB_API}/${endpoint#/}"

    local curl_args=(
        -s
        -X "$method"
        -H "Accept: application/vnd.github.v3+json"
        -H "User-Agent: README-Generator/1.0"
    )
    
    # Only add Authorization header if token is provided
    if [ -n "$GITHUB_TOKEN" ]; then
        curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
    fi

    if [ -n "$data" ]; then
        curl_args+=(-d "$data")
    fi

    local response
    local http_code
    local curl_stderr
    
    # Capture curl stderr for better error diagnostics
    curl_stderr=$(curl -w "\n%{http_code}" "${curl_args[@]}" "$url" 2>&1)
    response=$(echo "$curl_stderr" | sed '$d')
    http_code=$(echo "$curl_stderr" | tail -n1)
    
    # Handle curl failures (HTTP 000 means curl itself failed)
    if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
        log_error "Failed to connect to GitHub API: $endpoint"
        log_error "Curl error: $(echo "$curl_stderr" | head -n 5)"
        log_info "This could be due to:"
        log_info "  1. Network connectivity issues"
        log_info "  2. GitHub API being unavailable"
        log_info "  3. Firewall/proxy blocking connections"
        log_info "  4. DNS resolution issues"
        return 1
    fi

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "$response"
    elif [ "$http_code" -eq 404 ]; then
        log_warning "Resource not found: $endpoint"
        echo "{}"
    elif [ "$http_code" -eq 401 ]; then
        log_warning "Authentication failed. If using a token, check it's valid."
        log_info "For public repos, you can run without GITHUB_TOKEN"
        echo "{}"
    elif [ "$http_code" -eq 403 ]; then
        log_warning "Access forbidden. Rate limit may be exceeded or token lacks permissions."
        log_info "Check your GitHub token permissions or wait before retrying"
        return 1
    elif [ "$http_code" -eq 429 ]; then
        log_error "Rate limit exceeded. Please wait before retrying."
        return 1
    else
        log_error "API request failed: HTTP $http_code"
        echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "$response"
        return 1
    fi
}

# Get repository information
get_repo_info() {
    local owner="$1"
    local repo="$2"
    api_request "GET" "repos/${owner}/${repo}"
}

# Get default branch
get_default_branch() {
    local owner="$1"
    local repo="$2"
    local repo_info
    repo_info=$(get_repo_info "$owner" "$repo")
    echo "$repo_info" | jq -r '.default_branch // "main"'
}

# Get file content from repository
get_file_content() {
    local owner="$1"
    local repo="$2"
    local path="$3"
    local branch="${4:-}"
    local endpoint="repos/${owner}/${repo}/contents/${path}"
    local params=""

    if [ -n "$branch" ]; then
        params="?ref=${branch}"
    fi

    local response
    response=$(api_request "GET" "${endpoint}${params}")

    if [ "$response" = "{}" ] || [ -z "$response" ]; then
        return 1
    fi

    local content
    local encoding
    content=$(echo "$response" | jq -r '.content // empty')
    encoding=$(echo "$response" | jq -r '.encoding // "base64"')

    if [ "$encoding" = "base64" ] && [ -n "$content" ]; then
        echo "$content" | base64 -d 2>/dev/null || return 1
    else
        echo "$content"
    fi
}

# List repository contents
list_repo_contents() {
    local owner="$1"
    local repo="$2"
    local path="${3:-}"
    local branch="${4:-}"
    local endpoint="repos/${owner}/${repo}/contents/${path}"
    local params=""

    if [ -n "$branch" ]; then
        params="?ref=${branch}"
    fi

    api_request "GET" "${endpoint}${params}"
}

# Get repository languages
get_repo_languages() {
    local owner="$1"
    local repo="$2"
    api_request "GET" "repos/${owner}/${repo}/languages"
}

# Generate README content
generate_readme() {
    local owner="$1"
    local repo="$2"
    local branch="$3"

    log_info "Analyzing repository: ${owner}/${repo}"

    # Get repository info
    local repo_info
    repo_info=$(get_repo_info "$owner" "$repo")
    local repo_name
    repo_name=$(echo "$repo_info" | jq -r '.name // "'"$repo"'"')
    local description
    description=$(echo "$repo_info" | jq -r '.description // ""')
    local language
    language=$(echo "$repo_info" | jq -r '.language // ""')
    local license_name
    license_name=$(echo "$repo_info" | jq -r '.license.name // "Unknown"')
    local stars
    stars=$(echo "$repo_info" | jq -r '.stargazers_count // 0')
    local topics
    topics=$(echo "$repo_info" | jq -r '.topics | join(", ") // ""')

    # Check for existing files
    local has_license=false
    local has_contributing=false
    local has_requirements=false
    local has_github_actions=false
    local has_readthedocs=false
    local has_pypi=false
    local has_gitpod=false
    local has_codecov=false

    if get_file_content "$owner" "$repo" "LICENSE" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" "LICENSE.txt" "$branch" >/dev/null 2>&1; then
        has_license=true
    fi

    if get_file_content "$owner" "$repo" "CONTRIBUTING.md" "$branch" >/dev/null 2>&1; then
        has_contributing=true
    fi

    if get_file_content "$owner" "$repo" "requirements.txt" "$branch" >/dev/null 2>&1; then
        has_requirements=true
    fi

    # Check for GitHub Actions workflows
    local workflows
    workflows=$(list_repo_contents "$owner" "$repo" ".github/workflows" "$branch" 2>/dev/null || echo "[]")
    if [ "$workflows" != "[]" ] && [ -n "$workflows" ]; then
        local workflow_count
        workflow_count=$(echo "$workflows" | jq '. | length' 2>/dev/null || echo "0")
        if [ "$workflow_count" -gt 0 ]; then
            has_github_actions=true
        fi
    fi

    # Check for Read the Docs configuration
    if get_file_content "$owner" "$repo" ".readthedocs.yml" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" "readthedocs.yml" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" ".readthedocs.yaml" "$branch" >/dev/null 2>&1; then
        has_readthedocs=true
    fi

    # Check for PyPI package indicators
    if get_file_content "$owner" "$repo" "setup.py" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" "pyproject.toml" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" "setup.cfg" "$branch" >/dev/null 2>&1; then
        has_pypi=true
    fi
    # Also check if repo name matches common PyPI package naming
    if echo "$repo" | grep -qiE "^(cocotb|uvm|systemverilog|verilog)" || \
       echo "$topics" | grep -qi "pypi"; then
        has_pypi=true
    fi

    # Check for Gitpod configuration
    if get_file_content "$owner" "$repo" ".gitpod.yml" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" ".gitpod.yaml" "$branch" >/dev/null 2>&1; then
        has_gitpod=true
    fi

    # Check for Codecov configuration
    if get_file_content "$owner" "$repo" ".codecov.yml" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" "codecov.yml" "$branch" >/dev/null 2>&1 || \
       get_file_content "$owner" "$repo" ".codecov.yaml" "$branch" >/dev/null 2>&1; then
        has_codecov=true
    fi
    # Also check if codecov is mentioned in GitHub Actions workflows
    if [ "$has_github_actions" = true ]; then
        local workflow_files
        workflow_files=$(echo "$workflows" | jq -r '.[] | select(.type == "file") | .name' 2>/dev/null || echo "")
        if echo "$workflow_files" | grep -qi "codecov"; then
            has_codecov=true
        fi
    fi

    # Detect repository structure and files
    local root_contents
    root_contents=$(list_repo_contents "$owner" "$repo" "" "$branch" 2>/dev/null || echo "[]")
    
    local has_examples=false
    local has_tests_dir=false
    local has_docs_dir=false
    local has_src_dir=false
    local has_makefile=false
    local has_pytest=false
    local has_config_file=false
    local example_dirs=()
    local test_dirs=()
    local top_dirs=()
    
    if [ "$root_contents" != "[]" ] && [ -n "$root_contents" ]; then
        # Check for common directories
        local dirs
        dirs=$(echo "$root_contents" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")
        
        while IFS= read -r dir; do
            [ -z "$dir" ] && continue
            top_dirs+=("$dir")
            
            case "$dir" in
                examples|example|samples|sample|demos|demo)
                    has_examples=true
                    example_dirs+=("$dir")
                    ;;
                tests|test|t|testsuite|testbench|tb)
                    has_tests_dir=true
                    test_dirs+=("$dir")
                    ;;
                docs|doc|documentation)
                    has_docs_dir=true
                    ;;
                src|source|lib|libs|rtl|design)
                    has_src_dir=true
                    ;;
            esac
        done <<< "$dirs"
        
        # Check for files
        local files
        files=$(echo "$root_contents" | jq -r '.[] | select(.type == "file") | .name' 2>/dev/null || echo "")
        
        if echo "$files" | grep -qiE "^(Makefile|makefile|GNUmakefile)"; then
            has_makefile=true
        fi
        
        if echo "$files" | grep -qiE "^(pytest\.ini|setup\.cfg|tox\.ini|\.pytestrc)"; then
            has_pytest=true
        fi
        
        if echo "$files" | grep -qiE "^(\.env|config\.|settings\.|\.config)"; then
            has_config_file=true
        fi
    fi

    # Get languages
    local languages_json
    languages_json=$(get_repo_languages "$owner" "$repo")
    local languages
    languages=$(echo "$languages_json" | jq -r 'keys | join(", ") // ""')

    # Build README
    local readme=""
    readme+="# ${repo_name}\n\n"

    # Description will be added in Overview section, not here to avoid duplication

    # Badges
    local badges=()
    
    # License badge
    if [ "$license_name" != "Unknown" ] && [ "$license_name" != "null" ]; then
        # Remove quotes and encode special characters for URL
        local license_url=$(echo "$license_name" | sed 's/"//g' | sed 's/ /%20/g' | sed 's/&/%26/g')
        badges+=("![License](https://img.shields.io/badge/license-${license_url}-blue.svg)")
    fi
    
    # GitHub stats badges
    badges+=("![GitHub Stars](https://img.shields.io/github/stars/${owner}/${repo}?style=flat-square&logo=github)")
    badges+=("![GitHub Forks](https://img.shields.io/github/forks/${owner}/${repo}?style=flat-square&logo=github)")
    badges+=("![GitHub Issues](https://img.shields.io/github/issues/${owner}/${repo}?style=flat-square&logo=github)")
    badges+=("![GitHub Pull Requests](https://img.shields.io/github/issues-pr/${owner}/${repo}?style=flat-square&logo=github)")
    
    # Language badge (if primary language exists)
    if [ -n "$language" ] && [ "$language" != "null" ]; then
        local lang_color=""
        case "$language" in
            "Python") lang_color="3776AB" ;;
            "JavaScript") lang_color="F7DF1E" ;;
            "TypeScript") lang_color="3178C6" ;;
            "Java") lang_color="ED8B00" ;;
            "C++") lang_color="00599C" ;;
            "C") lang_color="A8B9CC" ;;
            "SystemVerilog") lang_color="DAE1C2" ;;
            "Verilog") lang_color="DAE1C2" ;;
            "Shell") lang_color="89e051" ;;
            "Makefile") lang_color="427819" ;;
            *) lang_color="blue" ;;
        esac
        badges+=("![Language](https://img.shields.io/badge/language-$(echo "$language" | sed 's/ /%20/g')-${lang_color}?style=flat-square)")
    fi
    
    # Last commit badge
    badges+=("![Last Commit](https://img.shields.io/github/last-commit/${owner}/${repo}?style=flat-square&logo=git)")
    
    # Repository size badge
    badges+=("![Repo Size](https://img.shields.io/github/repo-size/${owner}/${repo}?style=flat-square)")
    
    # CI/CD badges (GitHub Actions)
    if [ "$has_github_actions" = true ]; then
        # Try to find a common workflow file name, prefer main CI workflows
        local workflow_file=""
        local workflows_check
        workflows_check=$(list_repo_contents "$owner" "$repo" ".github/workflows" "$branch" 2>/dev/null || echo "[]")
        if [ "$workflows_check" != "[]" ] && [ -n "$workflows_check" ]; then
            # Prefer common CI workflow names (in order of preference)
            # Only select .yml or .yaml workflow files
            local preferred_workflows="ci.yml test.yml build.yml build-test.yml build-test-dev.yml"
            workflow_file=""
            for preferred in $preferred_workflows; do
                if echo "$workflows_check" | jq -r '.[] | select(.type == "file") | .name' 2>/dev/null | grep -qE "^${preferred}$"; then
                    workflow_file="$preferred"
                    break
                fi
            done
            # If no preferred workflow found, get first valid workflow file (.yml or .yaml only)
            if [ -z "$workflow_file" ]; then
                workflow_file=$(echo "$workflows_check" | jq -r '.[] | select(.type == "file") | select(.name | test("\\.ya?ml$")) | select(.name | test("backport|release|dependabot") | not) | .name' 2>/dev/null | head -n1 || echo "")
            fi
            # Fallback to any valid workflow file (.yml or .yaml) if still empty
            if [ -z "$workflow_file" ]; then
                workflow_file=$(echo "$workflows_check" | jq -r '.[] | select(.type == "file") | select(.name | test("\\.ya?ml$")) | .name' 2>/dev/null | head -n1 || echo "")
            fi
        fi
        # Generate CI badge
        if [ -n "$workflow_file" ]; then
            badges+=("[![CI](https://github.com/${owner}/${repo}/actions/workflows/${workflow_file}/badge.svg?branch=${branch})](https://github.com/${owner}/${repo}/actions/workflows/${workflow_file})")
        else
            # Fallback to generic CI badge - link to actions page (no specific workflow)
            badges+=("[![CI](https://github.com/${owner}/${repo}/actions/workflows/ci.yml/badge.svg?branch=${branch})](https://github.com/${owner}/${repo}/actions)")
        fi
    fi
    
    # Documentation badge (Read the Docs)
    if [ "$has_readthedocs" = true ]; then
        # Try to determine the project name (usually repo name or from config)
        local rtd_project=$(echo "$repo" | tr '[:upper:]' '[:lower:]')
        # Use "latest" version for badge (more standard than branch name)
        # Try to get actual docs URL from readthedocs config if possible, otherwise construct standard URL
        local docs_url="https://${rtd_project}.readthedocs.io/"
        badges+=("[![Documentation Status](https://readthedocs.org/projects/${rtd_project}/badge/?version=latest)](${docs_url})")
    fi
    
    # PyPI badge
    if [ "$has_pypi" = true ]; then
        local pypi_package=$(echo "$repo" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
        badges+=("[![PyPI](https://img.shields.io/pypi/dm/${pypi_package}.svg?label=PyPI%20downloads)](https://pypi.org/project/${pypi_package}/)")
    fi
    
    # Gitpod badge
    if [ "$has_gitpod" = true ]; then
        badges+=("[![Gitpod Ready-to-Code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/${owner}/${repo})")
    fi
    
    # Codecov badge
    if [ "$has_codecov" = true ]; then
        badges+=("[![codecov](https://codecov.io/gh/${owner}/${repo}/branch/${branch}/graph/badge.svg)](https://codecov.io/gh/${owner}/${repo})")
    fi
    
    # Format badges (one per line for better readability)
    if [ ${#badges[@]} -gt 0 ]; then
        readme+="$(printf '%s\n' "${badges[@]}")\n\n"
    fi

    # Table of Contents
    readme+="## Table of Contents\n\n"
    readme+="- [Overview](#overview)\n"
    readme+="- [Features](#features)\n"
    readme+="- [Requirements](#requirements)\n"
    readme+="- [Installation](#installation)\n"
    readme+="- [Project Structure](#project-structure)\n"
    readme+="- [Configuration](#configuration)\n"
    readme+="- [Testing](#testing)\n"
    readme+="- [Contributing](#contributing)\n"
    readme+="- [License](#license)\n"
    readme+="- [Acknowledgments](#acknowledgments)\n\n"

    # AI Analysis (if enabled) - do this once and reuse
    local ai_overview=""
    local ai_features=""
    local ai_description=""
    
    # Check for Cursor IDE manually generated content first (via environment variables)
    if [ -n "${CURSOR_MANUAL_DESCRIPTION:-}" ] || [ -n "${CURSOR_MANUAL_FEATURES:-}" ]; then
        log_info "Using Cursor IDE manually generated content from environment variables..."
        # Use Cursor-generated content directly
        if [ -n "${CURSOR_MANUAL_DESCRIPTION:-}" ]; then
            ai_description="${CURSOR_MANUAL_DESCRIPTION}"
            log_info "Using Cursor-generated description: $(echo "$ai_description" | cut -c1-80)..."
        fi
        if [ -n "${CURSOR_MANUAL_FEATURES:-}" ]; then
            ai_features="${CURSOR_MANUAL_FEATURES}"
            local feature_count=$(echo "$ai_features" | grep -c "^-" || echo "0")
            log_info "Using Cursor-generated features: ${feature_count} features"
        fi
    elif [ "$AI_ENABLED" = "true" ] || [ "$AI_ENABLED" = "1" ]; then
        log_info "Using AI to analyze repository and generate enhanced content..."
        # Capture only stdout (AI response), discard stderr (log messages)
        ai_overview=$(ai_analyze_repo "$owner" "$repo" "$description" "$language" "$topics" "$languages" 2>/dev/null || echo "")
        
        # Debug: Log AI response (first 200 chars) - only if it's actual content
        if [ -n "$ai_overview" ] && [ "$ai_overview" != "" ]; then
            # Check if it's not just log messages
            if ! echo "$ai_overview" | grep -qE "^\[INFO\]|^\[WARNING\]|^\[ERROR\]"; then
                log_info "AI response received: $(echo "$ai_overview" | head -c 200)..."
            else
                log_warning "AI response appears to be log messages, not actual content"
                ai_overview=""  # Clear it so we use fallback
            fi
        else
            log_warning "AI returned empty response - using fallback content"
        fi
        
        if [ -n "$ai_overview" ] && [ "$ai_overview" != "" ]; then
            # Parse structured AI response
            local parsed=$(parse_ai_repo_response "$ai_overview")
            ai_description=$(echo "$parsed" | grep "^DESCRIPTION:" | sed 's/^DESCRIPTION://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Extract all FEATURE lines and join with newlines
            ai_features=$(echo "$parsed" | grep "^FEATURE:" | sed 's/^FEATURE://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '\n' '\n')
            local ai_use_case=$(echo "$parsed" | grep "^USE_CASE:" | sed 's/^USE_CASE://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Log parsed results for debugging
            if [ -n "$ai_description" ]; then
                log_info "AI description extracted: $(echo "$ai_description" | cut -c1-80)..."
            fi
            if [ -n "$ai_features" ]; then
                local feature_count=$(echo "$ai_features" | wc -l)
                log_info "AI features extracted: ${feature_count} features"
            fi
            if [ -n "$ai_use_case" ]; then
                log_info "AI use case extracted: $(echo "$ai_use_case" | cut -c1-80)..."
            fi
        fi
    fi

    # Overview
    readme+="## Overview\n\n"
    
    if [ -n "$ai_description" ]; then
        # Use AI-generated description
        readme+="${ai_description}\n\n"
    elif [ -n "$description" ]; then
        # Format GitHub description properly
        # If description starts with repo name and colon, remove the prefix and format as sentence
        local clean_description="$description"
        local formatted_description=""
        
        # Check if description starts with repo name (case-insensitive check)
        if echo "$clean_description" | grep -qiE "^${repo_name}[: ]"; then
            # Remove repo name prefix (case-insensitive)
            clean_description=$(echo "$clean_description" | sed -E "s/^${repo_name}[: ]+\s*//i" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Capitalize first letter of description part
            clean_description="$(echo "$clean_description" | sed 's/^./\U&/')"
            # Format as proper sentence: "repo_name is description"
            # Preserve repo name as-is (don't capitalize) - common in technical docs
            formatted_description="${repo_name} is ${clean_description}"
            # Add period if not present
            if ! echo "$formatted_description" | grep -q '\.$'; then
                formatted_description="${formatted_description}."
            fi
            readme+="${formatted_description}\n\n"
        else
            # Description doesn't start with repo name, use as-is
            readme+="${clean_description}\n\n"
        fi
    else
        # No description available, use template
        readme+="${repo_name} is "
        if [ -n "$language" ] && [ "$language" != "null" ]; then
            readme+="a ${language} project "
        fi
        if [ -n "$topics" ]; then
            readme+="focused on $(echo "$topics" | cut -d',' -f1-3). "
        fi
        readme+="This project provides verification IP, testbenches, or utilities "
        readme+="for hardware verification methodologies.\n\n"
    fi
    
    readme+="This repository is part of the ${owner} "
    readme+="organization, which aims to improve open-source verification "
    readme+="projects by providing comprehensive documentation and examples.\n\n"

    # Features
    readme+="## Features\n\n"
    
    if [ -n "$ai_features" ]; then
        # Use AI-generated features
        # Use process substitution to avoid subshell issue
        while IFS= read -r feature; do
            if [ -n "$feature" ]; then
                # Ensure it starts with - for markdown list
                if [[ ! "$feature" =~ ^- ]]; then
                    feature="- ${feature}"
                fi
                readme+="${feature}\n"
            fi
        done < <(printf '%s\n' "$ai_features")
        readme+="\n"
    else
        # Fallback to default features
        readme+="- Comprehensive verification IP implementation\n"
        readme+="- Well-structured testbench framework\n"
        readme+="- Support for modern verification methodologies\n"
        if [ -n "$languages" ]; then
            # Format languages list (limit to first 5, add "and more" if longer)
            # Normalize: remove extra spaces, ensure single space after comma, then take first 5
            local languages_normalized=$(echo "$languages" | sed 's/[[:space:]]*,[[:space:]]*/, /g' | sed 's/[[:space:]]\+/ /g')
            local languages_list=$(echo "$languages_normalized" | cut -d',' -f1-5 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local lang_count=$(echo "$languages_normalized" | awk -F',' '{print NF}')
            if [ "$lang_count" -gt 5 ]; then
                readme+="- Implemented in ${languages_list}, and more\n"
            else
                readme+="- Implemented in ${languages_list}\n"
            fi
        fi
        readme+="- Extensive test suite with multiple test scenarios\n\n"
    fi

    # Requirements
    readme+="## Requirements\n\n"
    readme+="### Tools\n\n"
    readme+="- SystemVerilog simulator (e.g., Questa, VCS, Xcelium)\n"
    if echo "$languages" | grep -qi "python"; then
        readme+="- Python 3.8+\n"
    fi
    readme+="\n### Dependencies\n\n"
    if [ "$has_requirements" = true ]; then
        readme+="See \`requirements.txt\` for Python dependencies.\n"
    else
        readme+="- No external dependencies required\n"
    fi
    readme+="\n"

    # Installation
    readme+="## Installation\n\n"
    readme+="### Method 1: Clone from GitHub\n\n"
    readme+="\`\`\`bash\n"
    readme+="git clone https://github.com/${owner}/${repo}.git\n"
    readme+="cd ${repo}\n"
    readme+="git checkout ${branch}\n"
    readme+="\`\`\`\n\n"

    # Usage (with AI-generated examples if enabled)
    if [ -n "${CURSOR_MANUAL_USAGE:-}" ] || [ -n "${CURSOR_MANUAL_EXPLANATION:-}" ]; then
        # Use Cursor IDE manually generated usage content
        log_info "Using Cursor IDE manually generated usage content from environment variables..."
        local usage_example="${CURSOR_MANUAL_USAGE:-}"
        local explanation="${CURSOR_MANUAL_EXPLANATION:-}"
        local use_cases="${CURSOR_MANUAL_USE_CASES:-}"
        
        # Format usage section if we have content
        if [ -n "$usage_example" ] || [ -n "$explanation" ]; then
            readme+="## Usage\n\n"
            
            # Only add usage example if it has actual content (not just empty or whitespace)
            if [ -n "$usage_example" ] && [ -n "$(echo -e "$usage_example" | tr -d '[:space:]')" ]; then
                readme+="### Basic Example\n\n"
                # Use Python for cocotb, SystemVerilog for verification projects, or detected language
                local code_lang="${language}"
                if [ "$repo" = "cocotb" ] || echo "$repo" | grep -qi "cocotb"; then
                    code_lang="python"
                elif echo "$topics" | grep -qi "systemverilog\|verilog\|uvm"; then
                    code_lang="systemverilog"
                elif [ -z "$code_lang" ] || [ "$code_lang" = "null" ]; then
                    code_lang="bash"  # Default fallback
                fi
                readme+="\`\`\`${code_lang}\n"
                readme+="${usage_example}\n"
                readme+="\`\`\`\n\n"
            fi
            
            if [ -n "$explanation" ]; then
                readme+="${explanation}\n\n"
            fi
            
            if [ -n "$use_cases" ]; then
                readme+="### Common Use Cases\n\n"
                # Use process substitution to avoid subshell issue
                while IFS= read -r use_case; do
                    if [ -n "$use_case" ]; then
                        if [[ ! "$use_case" =~ ^- ]]; then
                            use_case="- ${use_case}"
                        fi
                        readme+="${use_case}\n"
                    fi
                done < <(printf '%s\n' "$use_cases")
                readme+="\n"
            fi
        fi
        
        # Log parsed results for debugging
        if [ -n "$usage_example" ]; then
            log_info "Cursor usage example extracted: $(echo "$usage_example" | head -n 1 | cut -c1-60)..."
        fi
    elif [ "$AI_ENABLED" = "true" ] || [ "$AI_ENABLED" = "1" ]; then
        # Collect example file info for AI
        local example_info=""
        if [ "$has_examples" = true ] && [ ${#example_dirs[@]} -gt 0 ]; then
            example_info="Example directories found: ${example_dirs[*]}"
        fi
        
        log_info "Generating usage examples with AI..."
        local ai_usage_raw
        # Capture only stdout (AI response), discard stderr (log messages)
        ai_usage_raw=$(ai_generate_usage "$owner" "$repo" "$language" "$example_info" 2>/dev/null || echo "")
        
        # Debug: Log AI usage response (first 200 chars) - only if it's actual content
        if [ -n "$ai_usage_raw" ] && [ "$ai_usage_raw" != "" ]; then
            # Check if it's not just log messages
            if ! echo "$ai_usage_raw" | grep -qE "^\[INFO\]|^\[WARNING\]|^\[ERROR\]"; then
                log_info "AI usage response received: $(echo "$ai_usage_raw" | head -c 200)..."
            else
                log_warning "AI usage response appears to be log messages, not actual content"
                ai_usage_raw=""  # Clear it so we skip usage section
            fi
        else
            log_warning "AI usage returned empty response - skipping usage section"
        fi
        
        if [ -n "$ai_usage_raw" ] && [ "$ai_usage_raw" != "" ]; then
            # Parse structured AI response
            local parsed_usage=$(parse_ai_usage_response "$ai_usage_raw")
            
            # Extract USAGE_EXAMPLE (may span multiple lines)
            # The parse function outputs "USAGE_EXAMPLE:<code>\nEXPLANATION:..."
            # where <code> may contain newlines. We need to extract everything between
            # USAGE_EXAMPLE: and the next section marker (EXPLANATION: or USE_CASE:)
            local usage_example=""
            local in_usage=false
            while IFS= read -r line; do
                if echo "$line" | grep -q "^EXPLANATION:\|^USE_CASE:"; then
                    break  # Found next section, stop
                elif echo "$line" | grep -q "^USAGE_EXAMPLE:"; then
                    # Remove the prefix and get the rest of the line (if any)
                    local content=$(echo "$line" | sed 's/^USAGE_EXAMPLE://' | sed 's/^[[:space:]]*//')
                    if [ -n "$content" ] && [ -n "$(echo "$content" | tr -d '[:space:]')" ]; then
                        usage_example="$content"
                    fi
                    in_usage=true
                elif [ "$in_usage" = true ]; then
                    # We're in the usage section, collect lines until we hit EXPLANATION: or USE_CASE:
                    if [ -z "$usage_example" ]; then
                        usage_example="$line"
                    else
                        usage_example="${usage_example}
${line}"
                    fi
                fi
            done < <(printf '%s\n' "$parsed_usage")
            
            # Clean up: just ensure we have valid content (leading/trailing blank lines won't hurt)
            if [ -z "$usage_example" ] || [ -z "$(echo -e "$usage_example" | tr -d '[:space:]')" ]; then
                usage_example=""
            fi
            
            # Extract EXPLANATION (single line)
            local explanation=$(echo "$parsed_usage" | grep "^EXPLANATION:" | sed 's/^EXPLANATION://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -n1)
            # Extract all USE_CASE lines
            local use_cases=$(echo "$parsed_usage" | grep "^USE_CASE:" | sed 's/^USE_CASE://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Format usage section if we have content
            if [ -n "$usage_example" ] || [ -n "$explanation" ]; then
                readme+="## Usage\n\n"
                
                # Only add usage example if it has actual content (not just empty or whitespace)
                if [ -n "$usage_example" ] && [ -n "$(echo "$usage_example" | tr -d '[:space:]')" ]; then
                    readme+="### Basic Example\n\n"
                    # Use Python for cocotb, SystemVerilog for verification projects, or detected language
                    local code_lang="${language}"
                    if [ "$repo" = "cocotb" ] || echo "$repo" | grep -qi "cocotb"; then
                        code_lang="python"
                    elif echo "$topics" | grep -qi "systemverilog\|verilog\|uvm"; then
                        code_lang="systemverilog"
                    elif [ -z "$code_lang" ] || [ "$code_lang" = "null" ]; then
                        code_lang="bash"  # Default fallback
                    fi
                    readme+="\`\`\`${code_lang}\n"
                    readme+="${usage_example}\n"
                    readme+="\`\`\`\n\n"
                fi
                
                if [ -n "$explanation" ]; then
                    readme+="${explanation}\n\n"
                fi
                
                if [ -n "$use_cases" ]; then
                    readme+="### Common Use Cases\n\n"
                    # Use process substitution to avoid subshell issue
                    while IFS= read -r use_case; do
                        if [ -n "$use_case" ]; then
                            if [[ ! "$use_case" =~ ^- ]]; then
                                use_case="- ${use_case}"
                            fi
                            readme+="${use_case}\n"
                        fi
                    done < <(printf '%s\n' "$use_cases")
                    readme+="\n"
                fi
            fi
            
            # Log parsed results for debugging
            if [ -n "$usage_example" ]; then
                log_info "AI usage example extracted: $(echo "$usage_example" | head -n 1 | cut -c1-60)..."
            fi
        fi
    fi

    # Project Structure
    readme+="## Project Structure\n\n"
    readme+="\`\`\`\n"
    readme+="${repo}/\n"
    
    # Build tree structure from detected directories
    local dir_list=()
    
    # Add important directories in order
    if [ "$has_src_dir" = true ]; then
        for dir in "${top_dirs[@]}"; do
            case "$dir" in
                src|source|lib|libs|rtl|design)
                    dir_list+=("├── ${dir}/")
                    break
                    ;;
            esac
        done
    fi
    
    if [ "$has_tests_dir" = true ]; then
        for dir in "${top_dirs[@]}"; do
            case "$dir" in
                tests|test|t|testsuite|testbench|tb)
                    dir_list+=("├── ${dir}/")
                    break
                    ;;
            esac
        done
    fi
    
    if [ "$has_examples" = true ]; then
        for dir in "${example_dirs[@]}"; do
            dir_list+=("├── ${dir}/")
            break
        done
    fi
    
    if [ "$has_docs_dir" = true ]; then
        for dir in "${top_dirs[@]}"; do
            case "$dir" in
                docs|doc|documentation)
                    dir_list+=("├── ${dir}/")
                    break
                    ;;
            esac
        done
    fi
    
    # Add other common directories (limit to 3 more, exclude hidden dirs)
    local other_count=0
    for dir in "${top_dirs[@]}"; do
        # Skip hidden directories (starting with .)
        if [[ "$dir" == .* ]]; then
            continue
        fi
        
        case "$dir" in
            src|source|lib|libs|rtl|design|tests|test|t|testsuite|testbench|tb|docs|doc|documentation|examples|example|samples|sample|demos|demo)
                continue
                ;;
            *)
                if [ "$other_count" -lt 3 ]; then
                    dir_list+=("├── ${dir}/")
                    other_count=$((other_count + 1))
                fi
                ;;
        esac
    done
    
    # Output directory tree
    # If there are directories, all use ├── except the last one before README.md
    # If there are no directories, just show README.md with └──
    if [ ${#dir_list[@]} -gt 0 ]; then
        # All directories use ├── (they're not the last item)
        for dir_entry in "${dir_list[@]}"; do
            readme+="${dir_entry}\n"
        done
        # README.md is the last item, so use └──
        readme+="└── README.md\n"
    else
        # No directories, just README.md
        readme+="└── README.md\n"
    fi
    readme+="\`\`\`\n\n"
    
    readme+="Key directories:\n"
    if [ "$has_src_dir" = true ]; then
        readme+="- Source code and modules\n"
    fi
    if [ "$has_tests_dir" = true ]; then
        readme+="- Test directories for verification testbenches\n"
    fi
    if [ "$has_examples" = true ]; then
        readme+="- Example code and usage patterns\n"
    fi
    if [ "$has_docs_dir" = true ]; then
        readme+="- Documentation\n"
    fi
    readme+="\n"

    # Configuration
    readme+="## Configuration\n\n"
    if [ "$has_config_file" = true ]; then
        readme+="This project uses configuration files for settings. Check the repository root for configuration files.\n\n"
    fi
    readme+="Configuration options can typically be set through:\n"
    readme+="- Environment variables\n"
    if [ "$has_config_file" = true ]; then
        readme+="- Configuration files (present in this repository)\n"
    else
        readme+="- Configuration files (if present)\n"
    fi
    readme+="- Command-line arguments\n\n"
    if [ "$has_examples" = true ]; then
        readme+="See the examples and source code for detailed configuration options.\n\n"
    else
        readme+="See the source code for detailed configuration options.\n\n"
    fi

    # Testing
    readme+="## Testing\n\n"
    if [ "$has_tests_dir" = true ] || [ "$has_pytest" = true ] || [ "$has_makefile" = true ]; then
        readme+="To run the test suite:\n\n"
        readme+="\`\`\`bash\n"
        
        if [ "$has_pytest" = true ]; then
            readme+="# Run tests with pytest\n"
            readme+="pytest\n"
            if [ "$has_tests_dir" = true ] && [ ${#test_dirs[@]} -gt 0 ]; then
                readme+="# Or run tests from the test directory\n"
                readme+="cd ${test_dirs[0]}\n"
                readme+="pytest\n"
            fi
        elif [ "$has_makefile" = true ]; then
            readme+="# Run tests with make\n"
            readme+="make test\n"
            if [ "$has_tests_dir" = true ] && [ ${#test_dirs[@]} -gt 0 ]; then
                readme+="# Or navigate to test directory first\n"
                readme+="cd ${test_dirs[0]}\n"
                readme+="make test\n"
            fi
        elif [ "$has_tests_dir" = true ] && [ ${#test_dirs[@]} -gt 0 ]; then
            readme+="# Navigate to test directory\n"
            readme+="cd ${test_dirs[0]}\n"
            readme+="# Run tests (check for Makefile or test scripts)\n"
            readme+="make test  # or run test scripts directly\n"
        fi
        readme+="\`\`\`\n\n"
    else
        readme+="This project includes tests. Check the repository for test files and run them using the appropriate test runner for your language.\n\n"
    fi

    # Contributing
    readme+="## Contributing\n\n"
    readme+="Contributions are welcome! Please follow these guidelines:\n\n"
    readme+="- Follow the existing code style\n"
    readme+="- Add tests for new features\n"
    readme+="- Update documentation as needed\n"
    readme+="- Submit pull requests with clear descriptions\n\n"
    if [ "$has_contributing" = true ]; then
        readme+="See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.\n\n"
    fi

    # License
    readme+="## License\n\n"
    # Handle different license name cases
    if [ "$license_name" = "Unknown" ] || [ "$license_name" = "null" ] || [ -z "$license_name" ]; then
        if [ "$has_license" = true ]; then
            readme+="This project is licensed - see the [LICENSE](LICENSE) file for details."
        else
            readme+="License information is not available."
        fi
    elif [ "$license_name" = "Other" ]; then
        if [ "$has_license" = true ]; then
            readme+="This project is licensed under a custom license - see the [LICENSE](LICENSE) file for details."
        else
            readme+="This project uses a custom license. Please check the repository for license details."
        fi
    elif echo "$license_name" | grep -qi "license"; then
        readme+="This project is licensed under the ${license_name}"
        if [ "$has_license" = true ]; then
            readme+=" - see the [LICENSE](LICENSE) file for details."
        else
            readme+="."
        fi
    else
        readme+="This project is licensed under the ${license_name} License"
        if [ "$has_license" = true ]; then
            readme+=" - see the [LICENSE](LICENSE) file for details."
        else
            readme+="."
        fi
    fi
    readme+="\n\n"

    # Acknowledgments
    readme+="## Acknowledgments\n\n"
    readme+="- ${owner} organization\n"
    readme+="- Original repository: [https://github.com/${owner}/${repo}](https://github.com/${owner}/${repo})\n"
    readme+="- All contributors to this project\n"

    echo -e "$readme"
}

# Process single repository
process_repo() {
    local owner="$1"
    local repo="$2"
    local output_file="${3:-README.md}"
    local branch="${4:-}"

    if [ -z "$branch" ]; then
        branch=$(get_default_branch "$owner" "$repo")
    fi

    log_info "Generating README for repository: ${owner}/${repo} (branch: ${branch})"

    # Generate README
    local readme_content
    readme_content=$(generate_readme "$owner" "$repo" "$branch")

    # Save to file
    echo -e "$readme_content" > "$output_file"
    log_success "README.md generated: ${output_file}"
}

# Process all repositories in organization
process_org() {
    local owner="$1"
    local output_dir="${2:-.}"
    local branch="${3:-}"
    local page=1
    local per_page=100

    log_info "Generating READMEs for all repositories in organization: ${owner}"

    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"

    while true; do
        local repos
        repos=$(api_request "GET" "orgs/${owner}/repos?per_page=${per_page}&page=${page}")

        if [ "$repos" = "[]" ] || [ "$repos" = "{}" ] || [ -z "$repos" ]; then
            break
        fi

        local repo_count
        repo_count=$(echo "$repos" | jq '. | length')
        log_info "Processing page ${page} (${repo_count} repositories)"

        echo "$repos" | jq -r '.[] | "\(.name)"' | while read -r repo_name; do
            if [ -n "$repo_name" ]; then
                local output_file="${output_dir}/${repo_name}/README.md"
                mkdir -p "${output_dir}/${repo_name}"
                process_repo "$owner" "$repo_name" "$output_file" "$branch" || true
                # Small delay to avoid rate limits
                sleep 1
            fi
        done

        if [ "$repo_count" -lt "$per_page" ]; then
            break
        fi

        page=$((page + 1))
    done

    log_success "Finished generating READMEs for organization: ${owner}"
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 owner repo_name [output_file] [branch]"
        echo "       $0 owner --org [output_dir] [branch]"
        echo ""
        echo "Examples:"
        echo "  $0 universal-verification-methodology .github"
        echo "  $0 universal-verification-methodology .github README.md main"
        echo "  $0 universal-verification-methodology --org"
        echo "  $0 universal-verification-methodology --org ./readmes main"
        echo ""
        echo "AI-Powered README Generation (Optional):"
        echo "  Enable AI to generate enhanced descriptions, features, and usage examples:"
        echo "  export AI_ENABLED=true"
        echo "  export AI_PROVIDER=openai  # or 'anthropic', 'local', 'cursor', 'cursor-agent', 'mcp'"
        echo "  export AI_API_KEY=your_api_key"
        echo "  export AI_MODEL=gpt-4o-mini  # or claude-3-haiku, etc."
        echo ""
        echo "  For Cursor Agent (NO API KEY NEEDED - uses Cursor IDE's built-in AI):"
        echo "  export AI_ENABLED=true"
        echo "  export AI_PROVIDER=cursor-agent"
        echo "  # No API key required! Cursor IDE must be running with MCP enabled"
        echo "  # Optional: export CURSOR_AGENT_MODE=mcp  # or 'internal'"
        echo ""
        echo "  For Cursor (uses OpenAI-compatible API):"
        echo "  export AI_ENABLED=true"
        echo "  export AI_PROVIDER=cursor"
        echo "  export AI_API_KEY=your_openai_api_key  # Cursor uses OpenAI keys"
        echo "  export AI_MODEL=gpt-4  # Cursor's default"
        echo "  # Optional: export CURSOR_API_URL=https://api.cursor.com/v1"
        echo ""
        echo "  For MCP (Model Context Protocol) with Cursor:"
        echo "  export AI_ENABLED=true"
        echo "  export AI_PROVIDER=mcp"
        echo "  export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'"
        echo "  export MCP_RESOURCE_URI='file:///path/to/resource'  # Optional"
        echo "  export MCP_TOOL_NAME='tool_name'  # Optional"
        echo "  export MCP_FALLBACK_PROVIDER=openai  # Fallback if MCP only provides context"
        echo ""
        echo "  For local models (Ollama):"
        echo "  export AI_ENABLED=true"
        echo "  export AI_PROVIDER=local"
        echo "  export AI_BASE_URL=http://localhost:11434/v1"
        echo "  export AI_MODEL=llama2  # or your local model name"
        exit 1
    fi

    local owner="$1"
    local repo_or_flag="$2"
    local arg3="${3:-}"
    local arg4="${4:-}"

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Please install jq first."
        log_info "On Ubuntu/Debian: sudo apt-get install jq"
        log_info "On macOS: brew install jq"
        exit 1
    fi

    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed."
        exit 1
    fi

    if [ "$repo_or_flag" = "--org" ]; then
        local output_dir="${arg3:-.}"
        local branch="${arg4:-}"
        process_org "$owner" "$output_dir" "$branch"
    else
        local repo="$repo_or_flag"
        local output_file="${arg3:-README.md}"
        local branch="${arg4:-}"
        process_repo "$owner" "$repo" "$output_file" "$branch"
    fi
}

# Run main function
main "$@"
