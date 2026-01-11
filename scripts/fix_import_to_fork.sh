#!/bin/bash

# Script to fix an incorrectly imported repository by deleting it and creating a true fork
#
# Usage: ./fix_import_to_fork.sh <repo_owner/repo_name> <incorrectly_imported_repo_name> [github_token]
#
# Example: ./fix_import_to_fork.sh chiggs/UVM chiggs-UVM

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

# Function to check if repository exists
repo_exists() {
    local repo_name="$1"
    local url="${GITHUB_API_BASE}/repos/${repo_name}"
    local response=$(github_api_request "GET" "$url")
    
    if echo "$response" | grep -q '"name"'; then
        return 0  # Repository exists
    else
        return 1  # Repository does not exist
    fi
}

# Function to check if a repository is a fork of a specific source
is_fork_of() {
    local repo_name="$1"
    local source_repo="$2"
    local url="${GITHUB_API_BASE}/repos/${repo_name}"
    
    local response=$(github_api_request "GET" "$url")
    
    # Check if it's a fork
    if ! echo "$response" | grep -q '"fork":\s*true'; then
        return 1  # Not a fork
    fi
    
    # Check if the parent matches the source
    local parent=$(echo "$response" | grep -oE '"parent"\s*:\s*{[^}]*"full_name"\s*:\s*"[^"]*"' | grep -oE '"full_name"\s*:\s*"[^"]*"' | sed -E 's/"full_name"\s*:\s*"([^"]*)"/\1/' | head -1)
    if [ -z "$parent" ]; then
        parent=$(echo "$response" | grep -o '"parent"[^}]*"full_name":"[^"]*"' | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4 | head -1)
    fi
    
    if [ "$parent" = "$source_repo" ]; then
        return 0  # Is a fork of the source
    else
        return 1  # Is a fork but not of the source
    fi
}

# Function to delete a repository
delete_repository() {
    local repo_name="$1"
    local url="${GITHUB_API_BASE}/repos/${repo_name}"
    
    print_info "Deleting repository ${repo_name}..."
    github_api_request "DELETE" "$url" >/dev/null
    
    # DELETE requests return 204 No Content on success
    # Wait a moment and check if the repo no longer exists
    sleep 2
    if ! repo_exists "$repo_name"; then
        print_success "Successfully deleted ${repo_name}"
        return 0
    else
        print_error "Failed to delete ${repo_name}. Repository still exists."
        return 1
    fi
}

main() {
    if [ $# -lt 2 ]; then
        print_error "Usage: $0 <source_repo> <incorrectly_imported_repo_name> [github_token]"
        print_info "Example: $0 chiggs/UVM chiggs-UVM"
        exit 1
    fi
    
    local source_repo="$1"
    local incorrect_repo_name="$2"
    local token="${3:-${GITHUB_TOKEN:-}}"
    
    if [ -z "$token" ]; then
        print_error "GitHub token is required!"
        print_info "Please set GITHUB_TOKEN environment variable or provide it as the third argument"
        exit 1
    fi
    
    export GITHUB_TOKEN="$token"
    
    local incorrect_full="${TARGET_ORG}/${incorrect_repo_name}"
    local owner=$(echo "$source_repo" | cut -d'/' -f1)
    local repo_name=$(echo "$source_repo" | cut -d'/' -f2)
    local expected_fork="${TARGET_ORG}/${repo_name}"
    
    print_info "Fixing incorrectly imported repository..."
    print_info "Source repository: ${source_repo}"
    print_info "Incorrectly imported repository: ${incorrect_full}"
    print_info "Expected fork name: ${expected_fork}"
    
    # Check if the incorrectly imported repo exists
    if repo_exists "$incorrect_full"; then
        # Check if it's actually a fork (it shouldn't be)
        if is_fork_of "$incorrect_full" "$source_repo"; then
            print_info "Repository ${incorrect_full} is already a true fork of ${source_repo}. No action needed."
            return 0
        else
            print_warn "Repository ${incorrect_full} exists but is not a true fork (likely an import)."
            print_info "Deleting incorrectly imported repository..."
            if delete_repository "$incorrect_full"; then
                print_success "Successfully deleted ${incorrect_full}"
            else
                print_error "Failed to delete ${incorrect_full}. Please delete it manually."
                return 1
            fi
        fi
    else
        print_info "Repository ${incorrect_full} does not exist. Nothing to delete."
    fi
    
    # Check if the expected fork already exists
    if repo_exists "$expected_fork"; then
        if is_fork_of "$expected_fork" "$source_repo"; then
            print_success "Repository ${expected_fork} already exists and is a true fork of ${source_repo}!"
            return 0
        else
            print_error "Repository ${expected_fork} already exists but is not a fork of ${source_repo}."
            print_error "Cannot create a true fork because the name is already taken."
            print_error "GitHub's Fork API requires the fork to use the same name as the source repository."
            return 1
        fi
    fi
    
    # Try to create a true fork using the fork_repos.sh script
    print_info "Creating true fork of ${source_repo}..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if bash "${SCRIPT_DIR}/fork_repos.sh" "$source_repo" "$token"; then
        print_success "Successfully created true fork!"
        return 0
    else
        print_error "Failed to create true fork."
        return 1
    fi
}

main "$@"
