#!/bin/bash
#
# Push README.md file to GitHub repository using the GitHub API
# without cloning the repository locally.
#
# Usage:
#   ./push_readme.sh owner repo_name [readme_file] [branch] [commit_message]
#   ./push_readme.sh owner --org [readme_dir] [branch] [commit_message]
#

set -euo pipefail

# Default GitHub token (can be overridden with GITHUB_TOKEN env var)
DEFAULT_TOKEN="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"
GITHUB_TOKEN="${GITHUB_TOKEN:-$DEFAULT_TOKEN}"
GITHUB_API="https://api.github.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
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
        -H "User-Agent: README-Pusher/1.0"
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

# Get file SHA (needed for updates)
get_file_sha() {
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

    echo "$response" | jq -r '.sha // empty'
}

# Push file to repository using GitHub API
push_file_to_repo() {
    local owner="$1"
    local repo="$2"
    local path="$3"
    local file_path="$4"
    local branch="$5"
    local message="${6:-Update ${path}}"

    log_info "Pushing ${path} to ${owner}/${repo} (branch: ${branch})"

    # Check if file exists
    if [ ! -f "$file_path" ]; then
        log_error "File not found: ${file_path}"
        return 1
    fi

    # Read file content
    local content
    content=$(cat "$file_path")

    # Base64 encode content
    local encoded_content
    encoded_content=$(echo -n "$content" | base64 | tr -d '\n')

    # Get existing file SHA if it exists
    local sha
    sha=$(get_file_sha "$owner" "$repo" "$path" "$branch" 2>/dev/null || echo "")

    # Prepare JSON payload
    local payload
    if [ -n "$sha" ]; then
        # Update existing file
        payload=$(jq -n \
            --arg message "$message" \
            --arg content "$encoded_content" \
            --arg branch "$branch" \
            --arg sha "$sha" \
            '{
                message: $message,
                content: $content,
                branch: $branch,
                sha: $sha
            }')
        log_info "Updating existing file (SHA: ${sha:0:7}...)"
    else
        # Create new file
        payload=$(jq -n \
            --arg message "$message" \
            --arg content "$encoded_content" \
            --arg branch "$branch" \
            '{
                message: $message,
                content: $content,
                branch: $branch
            }')
        log_info "Creating new file"
    fi

    # Make API request
    local response
    response=$(api_request "PUT" "repos/${owner}/${repo}/contents/${path}" "$payload")

    if echo "$response" | jq -e '.content' >/dev/null 2>&1; then
        local commit_sha
        commit_sha=$(echo "$response" | jq -r '.commit.sha // empty')
        log_success "Successfully pushed ${path} (commit: ${commit_sha:0:7})"
        return 0
    else
        log_error "Failed to push file"
        echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error"
        return 1
    fi
}

# Process single repository
process_repo() {
    local owner="$1"
    local repo="$2"
    local readme_file="${3:-README.md}"
    local branch="${4:-}"
    local commit_message="${5:-docs: Update README.md}"

    if [ -z "$branch" ]; then
        branch=$(get_default_branch "$owner" "$repo")
    fi

    log_info "Processing repository: ${owner}/${repo} (branch: ${branch})"

    # Push README to repository
    if push_file_to_repo \
        "$owner" \
        "$repo" \
        "README.md" \
        "$readme_file" \
        "$branch" \
        "$commit_message"; then
        log_success "README.md pushed for ${owner}/${repo}"
        return 0
    else
        log_error "Failed to push README.md for ${owner}/${repo}"
        return 1
    fi
}

# Process all repositories in organization
process_org() {
    local owner="$1"
    local readme_dir="${2:-.}"
    local branch="${3:-}"
    local commit_message="${4:-docs: Update README.md}"
    local page=1
    local per_page=100

    log_info "Pushing READMEs for all repositories in organization: ${owner}"

    if [ ! -d "$readme_dir" ]; then
        log_error "Directory not found: ${readme_dir}"
        exit 1
    fi

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
                local readme_file="${readme_dir}/${repo_name}/README.md"
                if [ -f "$readme_file" ]; then
                    process_repo "$owner" "$repo_name" "$readme_file" "$branch" "$commit_message" || true
                else
                    log_warning "README.md not found: ${readme_file}, skipping"
                fi
                # Small delay to avoid rate limits
                sleep 1
            fi
        done

        if [ "$repo_count" -lt "$per_page" ]; then
            break
        fi

        page=$((page + 1))
    done

    log_success "Finished pushing READMEs for organization: ${owner}"
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 owner repo_name [readme_file] [branch] [commit_message]"
        echo "       $0 owner --org [readme_dir] [branch] [commit_message]"
        echo ""
        echo "Examples:"
        echo "  $0 universal-verification-methodology .github"
        echo "  $0 universal-verification-methodology .github README.md main"
        echo "  $0 universal-verification-methodology .github README.md main 'docs: Update README'"
        echo "  $0 universal-verification-methodology --org ./readmes"
        echo "  $0 universal-verification-methodology --org ./readmes main 'docs: Update README'"
        exit 1
    fi

    local owner="$1"
    local repo_or_flag="$2"
    local arg3="${3:-}"
    local arg4="${4:-}"
    local arg5="${5:-}"

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
        local readme_dir="${arg3:-.}"
        local branch="${arg4:-}"
        local commit_message="${arg5:-docs: Update README.md}"
        process_org "$owner" "$readme_dir" "$branch" "$commit_message"
    else
        local repo="$repo_or_flag"
        local readme_file="${arg3:-README.md}"
        local branch="${arg4:-}"
        local commit_message="${arg5:-docs: Update README.md}"
        process_repo "$owner" "$repo" "$readme_file" "$branch" "$commit_message"
    fi
}

# Run main function
main "$@"
