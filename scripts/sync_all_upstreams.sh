#!/bin/bash
#
# Sync upstream changes for all forked repositories in an organization
#
# This script:
# 1. Fetches all repositories from the specified organization
# 2. Filters for repositories that are forks
# 3. Gets the upstream (parent) repository information for each fork
# 4. Calls sync_upstream.sh to sync each fork with its upstream
#
# Usage:
#   ./sync_all_upstreams.sh [organization] [github_token]
#
# Example:
#   ./sync_all_upstreams.sh universal-verification-methodology
#   ./sync_all_upstreams.sh universal-verification-methodology ghp_xxxxx

set -euo pipefail

# Configuration
TARGET_ORG="${1:-universal-verification-methodology}"
DEFAULT_TOKEN="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"
GITHUB_TOKEN="${GITHUB_TOKEN:-$DEFAULT_TOKEN}"
GITHUB_API="https://api.github.com"
LOG_FILE="sync_all_upstreams_log.txt"
FAILED_REPOS_FILE="failed_syncs.txt"

# Get sync_upstream.sh directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_UPSTREAM_SCRIPT="${SCRIPT_DIR}/sync_upstream.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions (output to stderr so they don't interfere with function return values)
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

# Initialize log files
echo "=== Sync all upstreams started at $(date) ===" > "$LOG_FILE"
> "$FAILED_REPOS_FILE"

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
        -H "User-Agent: Sync-All-Upstreams/1.0"
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
    elif [ "$http_code" -eq 401 ]; then
        log_warning "Authentication failed (HTTP 401). Token may be invalid or expired."
        echo "{}"
    elif [ "$http_code" -eq 403 ]; then
        log_warning "Forbidden (HTTP 403). You may not have access to this resource."
        echo "{}"
    elif [ "$http_code" -eq 429 ]; then
        log_error "Rate limit exceeded. Please wait before retrying."
        exit 1
    else
        log_warning "API request failed: HTTP $http_code"
        echo "{}"
    fi
}

# Check rate limit
check_rate_limit() {
    local response
    response=$(api_request "GET" "rate_limit")
    local remaining
    remaining=$(echo "$response" | jq -r '.rate.remaining // 0' 2>/dev/null || echo "0")
    local limit
    limit=$(echo "$response" | jq -r '.rate.limit // 5000' 2>/dev/null || echo "5000")
    
    if [ "$remaining" -lt 10 ]; then
        log_warning "Low rate limit remaining: $remaining/$limit. Waiting 60 seconds..."
        sleep 60
    else
        log_info "Rate limit: $remaining/$limit remaining"
    fi
}

# Get all repositories from organization
get_org_repos() {
    local org="$1"
    local page=1
    local per_page=100
    local all_repos=""
    
    log_info "Fetching all repositories from organization: ${org}"
    
    while true; do
        local repos
        repos=$(api_request "GET" "orgs/${org}/repos?per_page=${per_page}&page=${page}&type=all")
        
        if [ "$repos" = "[]" ] || [ "$repos" = "{}" ] || [ -z "$repos" ]; then
            break
        fi
        
        # Check if response is valid JSON array
        if ! echo "$repos" | jq -e '. | type == "array"' >/dev/null 2>&1; then
            log_error "Invalid response from GitHub API"
            break
        fi
        
        local repo_count
        repo_count=$(echo "$repos" | jq '. | length' 2>/dev/null || echo "0")
        
        if [ "$repo_count" -eq 0 ]; then
            break
        fi
        
        log_info "Processing page ${page} (${repo_count} repositories)"
        
        # Process each repository - for forks, fetch full details to get parent info
        echo "$repos" | jq -r '.[] | select(.fork == true) | "\(.full_name)"' | while IFS= read -r full_name; do
            if [ -z "$full_name" ]; then
                continue
            fi
            
            # Fetch full repository details to get parent information
            local repo_details
            repo_details=$(api_request "GET" "repos/${full_name}")
            
            # Extract parent information from full repo details
            local parent_full
            parent_full=$(echo "$repo_details" | jq -r '.parent.full_name // empty' 2>/dev/null)
            
            if [ -n "$parent_full" ] && [ "$parent_full" != "null" ] && [ "$parent_full" != "" ]; then
                # Extract repo name from full_name (format: org/repo)
                local repo_name
                repo_name=$(echo "$full_name" | cut -d'/' -f2)
                
                # Extract parent owner and repo
                local parent_owner
                local parent_repo
                parent_owner=$(echo "$parent_full" | cut -d'/' -f1)
                parent_repo=$(echo "$parent_full" | cut -d'/' -f2)
                
                if [ -n "$parent_owner" ] && [ -n "$parent_repo" ]; then
                    echo "${org}|${repo_name}|${parent_owner}|${parent_repo}"
                fi
            fi
            
            # Small delay to avoid rate limits
            sleep 0.5
        done
        
        if [ "$repo_count" -lt "$per_page" ]; then
            break
        fi
        
        page=$((page + 1))
        
        # Check rate limit every page
        check_rate_limit
        sleep 1
    done
}

# Sync a single repository
sync_repo() {
    local fork_owner="$1"
    local fork_repo="$2"
    local upstream_owner="$3"
    local upstream_repo="$4"
    
    # Call sync_upstream.sh script (it will log the sync message itself)
    if [ -f "$SYNC_UPSTREAM_SCRIPT" ]; then
        # Run sync and show output in real-time (to stderr) while also logging to file
        if bash "$SYNC_UPSTREAM_SCRIPT" "$fork_owner" "$fork_repo" "$upstream_owner" "$upstream_repo" "$GITHUB_TOKEN" 2>&1 | tee -a "$LOG_FILE" >&2; then
            log_success "Successfully synced ${fork_owner}/${fork_repo}"
            return 0
        else
            log_error "Failed to sync ${fork_owner}/${fork_repo}"
            echo "${fork_owner}/${fork_repo}|${upstream_owner}/${upstream_repo}|Sync failed" >> "$FAILED_REPOS_FILE"
            return 1
        fi
    else
        log_error "sync_upstream.sh script not found at: $SYNC_UPSTREAM_SCRIPT"
        echo "${fork_owner}/${fork_repo}|${upstream_owner}/${upstream_repo}|Script not found" >> "$FAILED_REPOS_FILE"
        return 1
    fi
}

# Main function
main() {
    if [ $# -ge 1 ] && [[ "$1" =~ ^gh[opu]_ ]]; then
        # First argument is token, use default org
        GITHUB_TOKEN="$1"
    elif [ $# -ge 2 ] && [[ "$2" =~ ^gh[opu]_ ]]; then
        # Second argument is token
        TARGET_ORG="$1"
        GITHUB_TOKEN="$2"
    elif [ $# -ge 1 ]; then
        # First argument is org
        TARGET_ORG="$1"
    fi
    
    # Override token if provided as argument
    if [ -n "${GITHUB_TOKEN:-}" ] && [[ "$GITHUB_TOKEN" =~ ^gh[opu]_ ]]; then
        # Token provided
        :
    else
        GITHUB_TOKEN="${GITHUB_TOKEN:-$DEFAULT_TOKEN}"
    fi
    
    log_info "Starting sync operation for all forked repositories..."
    log_info "Target organization: ${TARGET_ORG} (https://github.com/${TARGET_ORG})"
    log_info "Sync script: ${SYNC_UPSTREAM_SCRIPT}"
    
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
    
    # Check if sync_upstream.sh exists
    if [ ! -f "$SYNC_UPSTREAM_SCRIPT" ]; then
        log_error "sync_upstream.sh script not found at: $SYNC_UPSTREAM_SCRIPT"
        exit 1
    fi
    
    # Check if sync_upstream.sh is executable
    if [ ! -x "$SYNC_UPSTREAM_SCRIPT" ]; then
        log_warning "sync_upstream.sh is not executable, making it executable..."
        chmod +x "$SYNC_UPSTREAM_SCRIPT"
    fi
    
    # Get all forked repositories and save to temp file (to avoid subshell issues)
    # Note: log_info outputs to stderr (>&2), so only data goes to stdout -> temp_file
    local temp_file
    temp_file=$(mktemp)
    get_org_repos "$TARGET_ORG" > "$temp_file"
    
    # Count forked repos (only count lines with 3 pipe separators: org|repo|upstream_owner|upstream_repo)
    local total_count
    total_count=$(grep -cE '^[^|]+\|[^|]+\|[^|]+\|[^|]+$' "$temp_file" 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [ "$total_count" -eq 0 ] || [ ! -s "$temp_file" ]; then
        log_warning "No forked repositories found in ${TARGET_ORG}"
        log_info "Debug: Temp file has $(wc -l < "$temp_file" 2>/dev/null | tr -d ' \n' || echo "0") lines"
        if [ -s "$temp_file" ]; then
            log_info "Debug: Temp file content (first 10 lines):"
            head -10 "$temp_file" 2>/dev/null | while IFS= read -r line; do
                [ -n "$line" ] && log_info "  $line"
            done || true
        fi
        rm -f "$temp_file"
        exit 0
    fi
    
    log_info "Found ${total_count} forked repository(ies) to sync"
    
    # Process each forked repository
    local current=0
    local success=0
    local failed=0
    
    while IFS='|' read -r fork_owner fork_repo upstream_owner upstream_repo; do
        if [ -z "$fork_owner" ] || [ -z "$fork_repo" ] || [ -z "$upstream_owner" ] || [ -z "$upstream_repo" ]; then
            continue
        fi
        
        current=$((current + 1))
        log_info "[${current}/${total_count}] Processing: ${fork_owner}/${fork_repo}"
        
        # Sync the repository
        if sync_repo "$fork_owner" "$fork_repo" "$upstream_owner" "$upstream_repo"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        
        # Check rate limit every 5 repositories
        if [ $((current % 5)) -eq 0 ]; then
            check_rate_limit
        fi
        
        # Small delay to avoid hitting rate limits
        sleep 2
    done < "$temp_file"
    
    # Clean up temp file
    rm -f "$temp_file"
    
    log_info "=== Sync Summary ==="
    log_success "Successfully synced: $success"
    log_error "Failed: $failed"
    log_info "Total processed: $current"
    log_info "Check $LOG_FILE for detailed logs"
    
    # Check if any failed
    if [ -f "$FAILED_REPOS_FILE" ] && [ -s "$FAILED_REPOS_FILE" ] && grep -q '[^[:space:]]' "$FAILED_REPOS_FILE" 2>/dev/null; then
        log_warning "Some repositories failed to sync. Check $FAILED_REPOS_FILE"
    fi
}

# Run main function
main "$@"
