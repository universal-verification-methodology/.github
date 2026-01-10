#!/bin/bash

# Script to fork GitHub repositories to the universal-verification-methodology organization
#
# Usage: ./fork_repos.sh [repos_file] [github_token]
#
# Example: ./fork_repos.sh repos_to_fork.txt ghp_xxxxxxxxxxxxx

set -euo pipefail

# Configuration
TARGET_ORG="universal-verification-methodology"
GITHUB_API_BASE="https://api.github.com"
DEFAULT_REPOS_FILE="repos_to_fork.txt"
LOG_FILE="fork_log.txt"
FAILED_REPOS_FILE="failed_forks.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    REPOS_FILE="${DEFAULT_REPOS_FILE}"
else
    REPOS_FILE="$1"
fi

# GitHub token (can be provided via environment variable or command-line argument)
# Default token is provided for convenience, but can be overridden
GITHUB_TOKEN="${2:-${GITHUB_TOKEN:-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}}"

# Initialize log files
echo "=== Fork operation started at $(date) ===" > "$LOG_FILE"
> "$FAILED_REPOS_FILE"  # Create empty file (no blank line)

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

# Function to check if repository already exists in target organization
repo_exists_in_org() {
    local repo_name="$1"
    local org_repo="${TARGET_ORG}/${repo_name}"
    local url="${GITHUB_API_BASE}/repos/${org_repo}"
    
    local response=$(github_api_request "GET" "$url")
    
    if echo "$response" | grep -q '"name"'; then
        return 0  # Repository exists
    else
        return 1  # Repository does not exist
    fi
}

# Function to create a repository and import from source (used when name conflict detected)
create_and_import_repo() {
    local source_repo="$1"
    local target_name="$2"
    local owner="$3"
    local full_target="${TARGET_ORG}/${target_name}"
    
    # Step 1: Create empty repository
    print_info "Creating empty repository ${full_target}..."
    local create_url="${GITHUB_API_BASE}/orgs/${TARGET_ORG}/repos"
    local create_data="{\"name\":\"${target_name}\",\"private\":false}"
    local create_response=$(github_api_request "POST" "$create_url" "$create_data")
    
    if ! echo "$create_response" | grep -qE '"name"|"full_name"'; then
        local error_msg=$(echo "$create_response" | grep -oE '"message"\s*:\s*"[^"]*"' | sed -E 's/"message"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$create_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        print_error "Failed to create repository ${full_target}: ${error_msg:-Unknown error}"
        echo "${source_repo}|Failed to create repo: ${error_msg:-Unknown error}" >> "$FAILED_REPOS_FILE"
        return 1
    fi
    
    # Wait a moment for repository to be ready
    sleep 2
    
    # Step 2: Import from source repository
    print_info "Importing content from ${source_repo} to ${full_target}..."
    local import_url="${GITHUB_API_BASE}/repos/${full_target}/import"
    local import_data="{\"vcs_url\":\"https://github.com/${source_repo}\",\"vcs\":\"git\"}"
    local import_response=$(github_api_request "PUT" "$import_url" "$import_data")
    
    # Check import status
    if echo "$import_response" | grep -qE '"status"|"import"'; then
        print_success "Import initiated for ${full_target}"
        print_info "  Repository URL: https://github.com/${full_target}"
        print_info "  Note: Large repositories may take time to import. Check status at:"
        print_info "  https://github.com/${full_target}/settings/import"
        return 0
    else
        local error_msg=$(echo "$import_response" | grep -oE '"message"\s*:\s*"[^"]*"' | sed -E 's/"message"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$import_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        print_warn "Repository created but import may have issues: ${error_msg:-Check manually}"
        print_info "  Repository created at: https://github.com/${full_target}"
        print_info "  You may need to manually import or sync the content"
        return 0  # Repository was created, so partial success
    fi
}

# Function to rename a repository
rename_repository() {
    local current_name="$1"
    local new_name="$2"
    local url="${GITHUB_API_BASE}/repos/${current_name}"
    local data="{\"name\":\"${new_name}\"}"
    
    print_info "Renaming ${current_name} to ${new_name}..."
    local response=$(github_api_request "PATCH" "$url" "$data")
    
    if echo "$response" | grep -qE '"name"|"full_name"'; then
        local renamed_full=$(echo "$response" | grep -oE '"full_name"\s*:\s*"[^"]*"' | sed -E 's/"full_name"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$renamed_full" ]; then
            renamed_full=$(echo "$response" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        if [ -n "$renamed_full" ]; then
            print_success "Successfully renamed to ${renamed_full}"
            return 0
        fi
    fi
    
    local error_msg=$(echo "$response" | grep -oE '"message"\s*:\s*"[^"]*"' | sed -E 's/"message"\s*:\s*"([^"]*)"/\1/' | head -1)
    if [ -z "$error_msg" ]; then
        error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
    fi
    print_warn "Failed to rename repository: ${error_msg:-Unknown error}"
    return 1
}

# Function to fork a repository
fork_repository() {
    local full_repo_name="$1"
    local owner=$(echo "$full_repo_name" | cut -d'/' -f1)
    local repo_name=$(echo "$full_repo_name" | cut -d'/' -f2)
    local org_repo="${TARGET_ORG}/${repo_name}"
    local target_name="$repo_name"
    local needs_rename=false
    
    # Check if simple name already exists
    if repo_exists_in_org "$repo_name"; then
        print_warn "Repository ${org_repo} already exists. Using renamed format: ${owner}-${repo_name}"
        target_name="${owner}-${repo_name}"
        local renamed_repo="${TARGET_ORG}/${target_name}"
        
        # Check if the renamed version also exists
        if repo_exists_in_org "$target_name"; then
            print_warn "Repository ${renamed_repo} also exists. Skipping..."
            return 0
        fi
        
        # Since GitHub fork API doesn't support custom names, we need to create repo and import
        print_info "Creating repository ${renamed_repo} and importing from ${full_repo_name}..."
        create_and_import_repo "$full_repo_name" "$target_name" "$owner"
        return $?
    fi
    
    print_info "Forking ${full_repo_name} to ${TARGET_ORG}..."
    
    # GitHub API endpoint for forking
    local url="${GITHUB_API_BASE}/repos/${full_repo_name}/forks"
    
    # Fork to organization
    local data="{\"organization\":\"${TARGET_ORG}\"}"
    local response=$(github_api_request "POST" "$url" "$data")
    
    # Check response - more robust JSON parsing
    if echo "$response" | grep -qE '"name"|"full_name"'; then
        # Try multiple patterns to extract full_name
        local forked_name=$(echo "$response" | grep -oE '"full_name"\s*:\s*"[^"]*"' | sed -E 's/"full_name"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$forked_name" ]; then
            # Fallback to simpler pattern
            forked_name=$(echo "$response" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        
        # If we need to rename, do it now
        if [ "$needs_rename" = true ] && [ -n "$forked_name" ]; then
            # Wait a moment for GitHub to process the fork
            sleep 2
            if rename_repository "$forked_name" "$target_name"; then
                forked_name="${TARGET_ORG}/${target_name}"
            else
                print_warn "Fork succeeded but rename failed. Repository is at: ${forked_name}"
            fi
        fi
        
        if [ -n "$forked_name" ]; then
            print_success "Successfully forked ${full_repo_name} to ${forked_name}"
            print_info "  Repository URL: https://github.com/${forked_name}"
        else
            print_success "Successfully forked ${full_repo_name} (response received)"
            if [ "$needs_rename" = true ]; then
                print_info "  Expected location: https://github.com/${TARGET_ORG}/${target_name}"
            else
                print_info "  Expected location: https://github.com/${TARGET_ORG}/${repo_name}"
            fi
        fi
        return 0
    else
        local error_msg=$(echo "$response" | grep -oE '"message"\s*:\s*"[^"]*"' | sed -E 's/"message"\s*:\s*"([^"]*)"/\1/' | head -1)
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        if [ -z "$error_msg" ]; then
            error_msg="Unknown error (check API response)"
        fi
        
        # Check if error is due to name already existing
        if echo "$error_msg" | grep -qiE "already exists|name already taken|repository.*exists"; then
            if [ "$needs_rename" != true ]; then
                # Name conflict detected - try with renamed format
                print_warn "Name conflict detected. Repository ${org_repo} may already exist."
                print_info "Suggestion: The repository might already be forked. Check: https://github.com/${org_repo}"
            fi
        fi
        
        print_error "Failed to fork ${full_repo_name}: $error_msg"
        echo "${full_repo_name}|${error_msg}" >> "$FAILED_REPOS_FILE"
        return 1
    fi
}

# Function to check rate limit
check_rate_limit() {
    local response=$(github_api_request "GET" "${GITHUB_API_BASE}/rate_limit")
    # More robust JSON parsing - handle whitespace
    local remaining=$(echo "$response" | grep -oE '"remaining"\s*:\s*[0-9]+' | grep -oE '[0-9]+' | head -1)
    if [ -z "$remaining" ]; then
        remaining=$(echo "$response" | grep -o '"remaining":[0-9]*' | cut -d':' -f2 | tr -d '[:space:]')
    fi
    local limit=$(echo "$response" | grep -oE '"limit"\s*:\s*[0-9]+' | grep -oE '[0-9]+' | head -1)
    if [ -z "$limit" ]; then
        limit=$(echo "$response" | grep -o '"limit":[0-9]*' | cut -d':' -f2 | tr -d '[:space:]')
    fi
    
    if [ -n "$remaining" ] && [ -n "$limit" ]; then
        print_info "Rate limit: $remaining/$limit remaining"
    else
        print_warn "Could not parse rate limit information"
    fi
    
    if [ -n "$remaining" ] && [ "$remaining" -lt 10 ]; then
        print_warn "Low rate limit remaining. Waiting 60 seconds..."
        sleep 60
    fi
}

# Function to process repositories from file
process_repositories() {
    if [ ! -f "$REPOS_FILE" ]; then
        print_error "Repository file not found: $REPOS_FILE"
        exit 1
    fi
    
    local total=$(wc -l < "$REPOS_FILE" | tr -d ' ')
    local current=0
    local success=0
    local failed=0
    local skipped=0
    
    print_info "Processing $total repositories from $REPOS_FILE"
    
    while IFS='|' read -r repo desc stars branch readme || [ -n "$repo" ]; do
        # Skip empty lines and comments
        if [ -z "$repo" ] || [[ "$repo" =~ ^# ]]; then
            continue
        fi
        
        # Extract just the repo name if full format is used
        local full_repo_name="$repo"
        if [[ "$repo" =~ ^[^/]+/[^/]+$ ]]; then
            full_repo_name="$repo"
        else
            # Try to extract from pipe-separated format
            full_repo_name=$(echo "$repo" | cut -d'|' -f1)
        fi
        
        current=$((current + 1))
        print_info "[$current/$total] Processing: $full_repo_name"
        
        # Check rate limit every 10 repositories
        if [ $((current % 10)) -eq 0 ]; then
            check_rate_limit
        fi
        
        # Fork the repository
        if fork_repository "$full_repo_name"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        
        # Small delay to avoid hitting rate limits
        sleep 2
    done < "$REPOS_FILE"
    
    print_info "=== Fork Summary ==="
    print_success "Successfully forked: $success"
    print_warn "Skipped (already exists): $skipped"
    print_error "Failed: $failed"
    print_info "Total processed: $current"
}

# Function to fork a single repository (alternative usage)
fork_single_repo() {
    local repo_name="$1"
    check_rate_limit
    fork_repository "$repo_name"
}

# Main execution
main() {
    print_info "Starting fork operation..."
    print_info "Target organization: ${TARGET_ORG} (https://github.com/${TARGET_ORG})"
    print_info "Repository file: ${REPOS_FILE}"
    
    # Check if GitHub token is valid
    local token_check=$(github_api_request "GET" "${GITHUB_API_BASE}/user")
    if ! echo "$token_check" | grep -qE '"login"|"name"'; then
        print_error "Invalid GitHub token. Please check your token."
        exit 1
    fi
    
    # More robust JSON parsing for username
    local user=$(echo "$token_check" | grep -oE '"login"\s*:\s*"[^"]*"' | sed -E 's/"login"\s*:\s*"([^"]*)"/\1/' | head -1)
    if [ -z "$user" ]; then
        user=$(echo "$token_check" | grep -o '"login":"[^"]*"' | cut -d'"' -f4 | head -1)
    fi
    if [ -n "$user" ]; then
        print_info "Authenticated as: $user"
    else
        print_warn "Could not extract username from token check"
    fi
    
    # Check if user has permission to fork to organization
    local org_check=$(github_api_request "GET" "${GITHUB_API_BASE}/orgs/${TARGET_ORG}")
    if ! echo "$org_check" | grep -q '"login"'; then
        print_error "Organization ${TARGET_ORG} not found or not accessible."
        exit 1
    fi
    
    # Verify organization name from response
    local org_name=$(echo "$org_check" | grep -oE '"login"\s*:\s*"[^"]*"' | sed -E 's/"login"\s*:\s*"([^"]*)"/\1/' | head -1)
    if [ -z "$org_name" ]; then
        org_name=$(echo "$org_check" | grep -o '"login":"[^"]*"' | cut -d'"' -f4 | head -1)
    fi
    if [ -n "$org_name" ]; then
        print_info "Target organization verified: https://github.com/${org_name}"
    fi
    
    # Process repositories
    if [ $# -ge 1 ] && [ -f "$REPOS_FILE" ]; then
        process_repositories
    elif [ $# -ge 1 ] && [[ "$1" =~ ^[^/]+/[^/]+$ ]]; then
        # Single repository provided as argument
        fork_single_repo "$1"
    else
        print_error "Invalid arguments or repository file not found."
        print_info ""
        print_info "Usage: $0 [repos_file] [github_token]"
        print_info "   or: $0 <owner/repo> [github_token]"
        print_info ""
        if [ $# -ge 1 ] && [[ ! "$1" =~ / ]]; then
            print_warn "You provided '$1' which is not in the format 'owner/repo'."
            print_info "Examples of valid repository names:"
            print_info "  - maximecb/uvm"
            print_info "  - cocotb/cocotb"
            print_info "  - openhwgroup/core-v-verif"
            print_info ""
            print_info "To find repositories with '$1' in the name, use the search script first:"
            print_info "  ./scripts/search_repos.sh 'language:systemverilog $1'"
        fi
        exit 1
    fi
    
    print_info "Fork operation completed. Check $LOG_FILE for details."
    # Check if file exists and has non-empty, non-whitespace content
    if [ -f "$FAILED_REPOS_FILE" ] && [ -s "$FAILED_REPOS_FILE" ] && grep -q '[^[:space:]]' "$FAILED_REPOS_FILE" 2>/dev/null; then
        print_warn "Some repositories failed to fork. Check $FAILED_REPOS_FILE"
    fi
}

main "$@"
