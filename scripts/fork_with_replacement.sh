#!/bin/bash

# Script to fork a repository by replacing an existing one with the same name
# WARNING: This will DELETE the existing repository!
#
# Usage: ./fork_with_replacement.sh <source_repo> <existing_repo_to_replace> [github_token]
#
# Example: ./fork_with_replacement.sh chiggs/UVM universal-verification-methodology/UVM

set -euo pipefail

# Configuration
TARGET_ORG="universal-verification-methodology"
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

print_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
}

# Function to make GitHub API requests
github_api_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local response
    
    if ([ "$method" = "POST" ] || [ "$method" = "PATCH" ] || [ "$method" = "PUT" ] || [ "$method" = "DELETE" ]) && [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "$url")
    fi
    
    echo "$response"
}

# Function to check if repository exists
repo_exists() {
    local repo_name="$1"
    local url="${GITHUB_API_BASE}/repos/${repo_name}"
    local response=$(github_api_request "GET" "$url")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] && echo "$body" | grep -q '"name"'; then
        return 0  # Repository exists
    else
        return 1  # Repository does not exist
    fi
}

# Function to delete a repository
delete_repository() {
    local repo_name="$1"
    local url="${GITHUB_API_BASE}/repos/${repo_name}"
    
    print_info "Deleting repository ${repo_name}..."
    local response=$(github_api_request "DELETE" "$url")
    local http_code=$(echo "$response" | tail -n1)
    
    # DELETE requests return 204 No Content on success
    if [ "$http_code" = "204" ]; then
        # Wait a moment and verify deletion
        sleep 2
        if ! repo_exists "$repo_name"; then
            print_success "Successfully deleted ${repo_name}"
            return 0
        else
            print_warn "Repository deletion reported success but repository still exists"
            return 1
        fi
    else
        local body=$(echo "$response" | sed '$d')
        local error_msg=$(echo "$body" | grep -oE '"message"\s*:\s*"[^"]*"' | sed -E 's/"message"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$body" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        print_error "Failed to delete repository ${repo_name}: HTTP ${http_code} - ${error_msg:-Unknown error}"
        return 1
    fi
}

main() {
    if [ $# -lt 2 ]; then
        print_error "Usage: $0 <source_repo> <existing_repo_to_replace> [github_token]"
        print_info "Example: $0 chiggs/UVM universal-verification-methodology/UVM"
        print_warn ""
        print_warn "WARNING: This script will DELETE the existing repository!"
        print_warn "Make sure you have backups if needed."
        exit 1
    fi
    
    local source_repo="$1"
    local existing_repo="$2"
    local token="${3:-${GITHUB_TOKEN:-}}"
    
    if [ -z "$token" ]; then
        print_error "GitHub token is required!"
        print_info "Please set GITHUB_TOKEN environment variable or provide it as the third argument"
        exit 1
    fi
    
    export GITHUB_TOKEN="$token"
    
    local owner=$(echo "$source_repo" | cut -d'/' -f1)
    local repo_name=$(echo "$source_repo" | cut -d'/' -f2)
    
    print_warn "=========================================="
    print_warn "WARNING: This will DELETE ${existing_repo}"
    print_warn "and replace it with a fork of ${source_repo}"
    print_warn "=========================================="
    print_info ""
    print_info "Source repository: ${source_repo}"
    print_info "Existing repository to delete: ${existing_repo}"
    print_info "New fork will be: ${TARGET_ORG}/${repo_name}"
    print_info ""
    
    # Verify existing repo exists
    if ! repo_exists "$existing_repo"; then
        print_warn "Repository ${existing_repo} does not exist. Nothing to delete."
    else
        print_warn "Repository ${existing_repo} exists and will be DELETED."
        print_info "Press Ctrl+C within 5 seconds to cancel..."
        sleep 5
        print_info "Proceeding with deletion..."
        
        if ! delete_repository "$existing_repo"; then
            print_error "Failed to delete existing repository. Aborting."
            exit 1
        fi
        
        # Wait a bit for GitHub to fully process the deletion
        print_info "Waiting for GitHub to process deletion..."
        sleep 3
    fi
    
    # Now fork the repository using the fork_repos.sh script
    print_info "Creating fork of ${source_repo}..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if bash "${SCRIPT_DIR}/fork_repos.sh" "$source_repo" "$token"; then
        print_success "Successfully forked ${source_repo}!"
        return 0
    else
        print_error "Failed to fork ${source_repo}."
        return 1
    fi
}

main "$@"
