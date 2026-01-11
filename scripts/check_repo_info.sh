#!/bin/bash

# Script to check repository information including whether it's a fork
#
# Usage: ./check_repo_info.sh <owner/repo> [github_token]

set -euo pipefail

# Configuration
GITHUB_API_BASE="https://api.github.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to make GitHub API requests
github_api_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local response
    
    if ([ "$method" = "POST" ] || [ "$method" = "PATCH" ] || [ "$method" = "PUT" ]) && [ -n "$data" ]; then
        response=$(curl -s -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url")
    else
        response=$(curl -s -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "$url")
    fi
    
    echo "$response"
}

main() {
    if [ $# -lt 1 ]; then
        print_error "Usage: $0 <owner/repo> [github_token]"
        print_info "Example: $0 universal-verification-methodology/UVM"
        exit 1
    fi
    
    local repo_name="$1"
    local token="${2:-${GITHUB_TOKEN:-}}"
    
    if [ -z "$token" ]; then
        print_error "GitHub token is required!"
        print_info "Please set GITHUB_TOKEN environment variable or provide it as the second argument"
        exit 1
    fi
    
    export GITHUB_TOKEN="$token"
    
    local url="${GITHUB_API_BASE}/repos/${repo_name}"
    local response=$(github_api_request "GET" "$url")
    
    # Check if repository exists
    if ! echo "$response" | grep -q '"name"'; then
        local error_msg=$(echo "$response" | grep -oE '"message"\s*:\s*"[^"]*"' | sed -E 's/"message"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        print_error "Repository ${repo_name} not found: ${error_msg:-Unknown error}"
        exit 1
    fi
    
    # Extract information
    local full_name=$(echo "$response" | grep -oE '"full_name"\s*:\s*"[^"]*"' | sed -E 's/"full_name"\s*:\s*"([^"]*)"/\1/' | head -1)
    if [ -z "$full_name" ]; then
        full_name=$(echo "$response" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4 | head -1)
    fi
    
    local html_url=$(echo "$response" | grep -oE '"html_url"\s*:\s*"[^"]*"' | sed -E 's/"html_url"\s*:\s*"([^"]*)"/\1/' | head -1)
    if [ -z "$html_url" ]; then
        html_url=$(echo "$response" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4 | head -1)
    fi
    
    local is_fork=$(echo "$response" | grep -oE '"fork"\s*:\s*(true|false)' | grep -oE '(true|false)' | head -1)
    
    local parent=""
    if [ "$is_fork" = "true" ]; then
        parent=$(echo "$response" | grep -oE '"parent"\s*:\s*{[^}]*"full_name"\s*:\s*"[^"]*"' | grep -oE '"full_name"\s*:\s*"[^"]*"' | sed -E 's/"full_name"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$parent" ]; then
            parent=$(echo "$response" | grep -o '"parent"[^}]*"full_name":"[^"]*"' | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
    fi
    
    local description=$(echo "$response" | grep -oE '"description"\s*:\s*"[^"]*"' | sed -E 's/"description"\s*:\s*"([^"]*)"/\1/' | head -1)
    if [ -z "$description" ] || [ "$description" = "null" ]; then
        description=$(echo "$response" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 | head -1)
        if [ "$description" = "null" ]; then
            description="(no description)"
        fi
    fi
    
    # Print information
    echo ""
    print_info "Repository Information:"
    echo "  Full Name: ${full_name}"
    echo "  URL: ${html_url}"
    echo "  Description: ${description}"
    echo "  Is Fork: ${is_fork}"
    
    if [ "$is_fork" = "true" ] && [ -n "$parent" ]; then
        echo "  Parent Repository: ${parent}"
    elif [ "$is_fork" = "true" ]; then
        print_warn "  Parent information not available"
    else
        echo "  Parent Repository: (not a fork)"
    fi
    echo ""
}

main "$@"
