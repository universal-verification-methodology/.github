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
                    temperature: 0.7
                }')
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
    
    response=$(curl -s "${headers[@]}" -d "$data" "$api_url" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        return 1
    fi
    
    # Extract content based on provider
    case "$AI_PROVIDER" in
        openai|local|cursor)
            echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null || echo ""
            ;;
        anthropic)
            echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null || echo ""
            ;;
        mcp)
            # MCP responses are handled separately
            echo "$response" | jq -r '.result.content[0].text // .result // empty' 2>/dev/null || echo ""
            ;;
    esac
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
    local fallback_provider="${MCP_FALLBACK_PROVIDER:-openai}"
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
    
    # Try to use Cursor's MCP servers first (available when Cursor IDE is running)
    if [ "${CURSOR_AGENT_MODE:-mcp}" = "mcp" ]; then
        # Check if we can access Cursor's MCP servers
        # Cursor IDE typically exposes MCP servers when running
        if [ -n "$MCP_SERVER" ]; then
            log_info "Using MCP server: $MCP_SERVER"
            # Use MCP approach
            local original_provider="$AI_PROVIDER"
            AI_PROVIDER="mcp"
            ai_call_with_mcp "$prompt" "$system_prompt"
            local result=$?
            AI_PROVIDER="$original_provider"
            if [ $result -eq 0 ]; then
                return 0
            fi
        fi
        
        # Try to detect Cursor's MCP servers automatically
        # Cursor IDE may expose MCP servers through environment or standard locations
        local cursor_mcp_servers=(
            "$HOME/.cursor/mcp"
            "$HOME/.config/cursor/mcp"
        )
        
        for mcp_path in "${cursor_mcp_servers[@]}"; do
            if [ -d "$mcp_path" ] || [ -f "$mcp_path" ]; then
                log_info "Found potential Cursor MCP configuration at: $mcp_path"
                # Try to use it
                break
            fi
        done
    fi
    
    # If MCP doesn't work, try using Cursor's internal API (if accessible)
    # Note: Cursor's internal API may not be directly accessible from scripts
    # This is a placeholder for future Cursor API integration
    if [ "${CURSOR_AGENT_MODE:-mcp}" = "internal" ]; then
        log_warning "Cursor internal API mode not yet fully implemented"
        log_info "Falling back to MCP mode"
        CURSOR_AGENT_MODE="mcp"
        ai_call_cursor_agent "$prompt" "$system_prompt"
        return $?
    fi
    
    # Final fallback: Use MCP with a local fallback or inform user
    log_warning "Cursor agent not available. Make sure Cursor IDE is running with MCP enabled."
    log_info "You can:"
    log_info "  1. Ensure Cursor IDE is running"
    log_info "  2. Configure MCP servers in Cursor settings"
    log_info "  3. Or set AI_PROVIDER to 'openai' with an API key"
    
    return 1
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

    local prompt="Analyze this GitHub repository and provide:
1. A concise, engaging 2-3 sentence description that explains what this project does and why it's useful
2. A list of 5-7 key features based on the repository information
3. A brief use case or example of when someone would use this project

Be specific and technical. Focus on what makes this repository valuable.

Repository context:
${context}"

    ai_call "$prompt" "You are a technical documentation expert specializing in open-source software repositories."
}

# Generate usage examples with AI
ai_generate_usage() {
    local owner="$1"
    local repo="$2"
    local language="$3"
    local example_files="$4"
    
    local prompt="Generate practical usage examples for a ${language} project called ${repo}.

${example_files}

Provide:
1. A basic usage example (3-5 lines of code)
2. A brief explanation of what the example does
3. Common use cases

Format the code example properly for ${language}."

    ai_call "$prompt" "You are a software documentation expert. Generate clear, practical code examples."
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
        -H "Authorization: token ${GITHUB_TOKEN}"
        -H "User-Agent: README-Generator/1.0"
    )

    if [ -n "$data" ]; then
        curl_args+=(-d "$data")
    fi

    local response
    local http_code
    response=$(curl -w "\n%{http_code}" "${curl_args[@]}" "$url" 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "$response"
    elif [ "$http_code" -eq 404 ]; then
        log_warning "Resource not found: $endpoint"
        echo "{}"
    elif [ "$http_code" -eq 429 ]; then
        log_error "Rate limit exceeded. Please wait before retrying."
        exit 1
    else
        log_error "API request failed: HTTP $http_code"
        echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error"
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

    if [ -n "$description" ]; then
        readme+="${description}\n\n"
    fi

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
            local preferred_workflows="ci.yml test.yml build.yml build-test.yml build-test-dev.yml"
            workflow_file=""
            for preferred in $preferred_workflows; do
                if echo "$workflows_check" | jq -r '.[] | select(.type == "file") | .name' 2>/dev/null | grep -q "^${preferred}$"; then
                    workflow_file="$preferred"
                    break
                fi
            done
            # If no preferred workflow found, get first non-backport workflow
            if [ -z "$workflow_file" ]; then
                workflow_file=$(echo "$workflows_check" | jq -r '.[] | select(.type == "file") | select(.name | test("backport|release|dependabot") | not) | .name' 2>/dev/null | head -n1 || echo "")
            fi
            # Fallback to any workflow if still empty
            if [ -z "$workflow_file" ]; then
                workflow_file=$(echo "$workflows_check" | jq -r '.[] | select(.type == "file") | .name' 2>/dev/null | head -n1 || echo "")
            fi
        fi
        # Generate CI badge
        if [ -n "$workflow_file" ]; then
            badges+=("[![CI](https://github.com/${owner}/${repo}/actions/workflows/${workflow_file}/badge.svg?branch=${branch})](https://github.com/${owner}/${repo}/actions/workflows/${workflow_file})")
        else
            # Fallback to generic CI badge
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
    
    if [ "$AI_ENABLED" = "true" ] || [ "$AI_ENABLED" = "1" ]; then
        log_info "Using AI to analyze repository and generate enhanced content..."
        ai_overview=$(ai_analyze_repo "$owner" "$repo" "$description" "$language" "$topics" "$languages" 2>/dev/null || echo "")
        
        if [ -n "$ai_overview" ]; then
            # Try to parse AI response (format may vary)
            ai_description=$(echo "$ai_overview" | head -n 3 | grep -v "^[0-9]" | sed 's/^description:\s*//i' | head -n 1 || echo "")
            ai_features=$(echo "$ai_overview" | grep -E "^-|^[0-9]+\.|- " | head -n 7 || echo "")
        fi
    fi

    # Overview
    readme+="## Overview\n\n"
    
    if [ -n "$ai_description" ]; then
        readme+="${ai_description}\n\n"
    elif [ -n "$description" ]; then
        readme+="${description}\n\n"
    fi
    
    if [ -z "$ai_description" ]; then
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
        echo "$ai_features" | while IFS= read -r feature; do
            if [ -n "$feature" ]; then
                # Ensure it starts with - for markdown list
                if [[ ! "$feature" =~ ^- ]]; then
                    feature="- ${feature}"
                fi
                readme+="${feature}\n"
            fi
        done
        readme+="\n"
    else
        # Fallback to default features
        readme+="- Comprehensive verification IP implementation\n"
        readme+="- Well-structured testbench framework\n"
        readme+="- Support for modern verification methodologies\n"
        if [ -n "$languages" ]; then
            readme+="- Implemented in ${languages}\n"
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
    if [ "$AI_ENABLED" = "true" ] || [ "$AI_ENABLED" = "1" ]; then
        # Collect example file info for AI
        local example_info=""
        if [ "$has_examples" = true ] && [ ${#example_dirs[@]} -gt 0 ]; then
            example_info="Example directories found: ${example_dirs[*]}"
        fi
        
        log_info "Generating usage examples with AI..."
        local ai_usage
        ai_usage=$(ai_generate_usage "$owner" "$repo" "$language" "$example_info" 2>/dev/null || echo "")
        
        if [ -n "$ai_usage" ]; then
            readme+="## Usage\n\n"
            readme+="${ai_usage}\n\n"
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
    
    # Add other common directories (limit to 3 more)
    local other_count=0
    for dir in "${top_dirs[@]}"; do
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
    local i=0
    for dir_entry in "${dir_list[@]}"; do
        if [ $i -eq $((${#dir_list[@]} - 1)) ]; then
            # Last entry
            readme+="${dir_entry/├──/└──}\n"
        else
            readme+="${dir_entry}\n"
        fi
        ((i++))
    done
    
    readme+="└── README.md\n"
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
    readme+="This project is licensed under the ${license_name} License"
    if [ "$has_license" = true ]; then
        readme+=" - see the [LICENSE](LICENSE) file for details."
    else
        readme+="."
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
