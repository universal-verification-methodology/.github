#!/bin/bash

# Script to search for GitHub repositories and identify ones that don't exist
# in the universal-verification-methodology organization (i.e., repos that need to be forked)
#
# This script:
# 1. Fetches all existing repositories from universal-verification-methodology organization
# 2. Searches GitHub for repositories matching the search query
# 3. Compares and lists repositories that are NOT present in the organization
# 4. Outputs detailed results sorted by stars (descending) with comprehensive metadata
# 5. Uses parallel processing (up to 10 concurrent jobs) to speed up API calls
# 6. Optionally filters repositories to only include those with README.md
#
# Usage: ./search_repos.sh <search_query> [github_token] [--readme-only]
# Note: GitHub token is optional but recommended (higher rate limits).
#       Set GITHUB_TOKEN environment variable or pass as second argument.
#       Use --readme-only flag to filter repositories that have README.md
#
# Example: ./search_repos.sh "language:systemverilog uvm"
# Example: ./search_repos.sh "language:systemverilog uvm" ghp_xxxxxxxxxxxxx
# Example: ./search_repos.sh "language:systemverilog uvm" ghp_xxxxxxxxxxxxx --readme-only
#
# Output Format (pipe-separated):
#   full_name|description|stars|forks|default_branch|has_readme|language|size|updated_at|created_at|license|archived|topics
#
# Field Descriptions:
#   - full_name: Repository owner/repo (e.g., username/repo-name)
#   - description: Repository description (N/A if none)
#   - stars: Number of stars
#   - forks: Number of forks
#   - default_branch: Default branch name (usually 'main' or 'master')
#   - has_readme: true/false - whether repository has README.md
#   - language: Primary programming language (N/A if unknown)
#   - size: Repository size (KB or MB)
#   - updated_at: Last update date (YYYY-MM-DD)
#   - created_at: Creation date (YYYY-MM-DD)
#   - license: License name (N/A if none)
#   - archived: true/false - whether repository is archived
#   - topics: Comma-separated list of topics/tags (N/A - requires additional API call)

set -euo pipefail

# Configuration
TARGET_ORG="universal-verification-methodology"
GITHUB_API_BASE="https://api.github.com"
RESULTS_FILE="repos_to_fork.txt"
EXISTING_REPOS_FILE="existing_repos.txt"
MAX_PARALLEL_JOBS=10  # Number of concurrent API calls (adjust based on rate limits)
FILTER_README_ONLY=false  # Set to true to only include repos with README.md

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <search_query> [github_token] [--readme-only]"
    print_info "Example: $0 'language:systemverilog uvm'"
    print_info "Example: $0 'language:systemverilog uvm' ghp_xxxxxxxxxxxxx --readme-only"
    print_info "Note: GitHub token is optional but recommended (higher rate limits)."
    print_info "      Set GITHUB_TOKEN environment variable or pass as second argument."
    print_info "      Use --readme-only flag to filter repositories that have README.md"
    exit 1
fi

SEARCH_QUERY="$1"
# GitHub token (can be provided via environment variable or command-line argument)
# Default token is provided for convenience, but can be overridden
# Check for --readme-only flag
FILTER_README_ONLY=false
GITHUB_TOKEN=""

# Parse arguments: token can be 2nd arg, --readme-only can be anywhere
for arg in "$@"; do
    if [ "$arg" = "--readme-only" ]; then
        FILTER_README_ONLY=true
    elif [ "$arg" != "$1" ] && [ "$arg" != "--readme-only" ] && [ -z "$GITHUB_TOKEN" ]; then
        # First non-query, non-flag argument is assumed to be the token
        GITHUB_TOKEN="$arg"
    fi
done

# If no token provided as argument, try environment variable, then use default
if [ -z "$GITHUB_TOKEN" ]; then
    GITHUB_TOKEN="${GITHUB_TOKEN:-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}"
fi

if [ "$FILTER_README_ONLY" = "true" ]; then
    print_info "Filtering enabled: Only repositories with README.md will be included"
fi

if [ -z "$GITHUB_TOKEN" ]; then
    print_warn "GitHub token not provided. Some API calls may be rate-limited."
    print_info "Set GITHUB_TOKEN environment variable or pass as second argument."
    AUTH_HEADER=""
else
    AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
fi

# Function to make GitHub API requests
github_api_request() {
    local url="$1"
    local response
    
    if [ -n "$AUTH_HEADER" ]; then
        response=$(curl -s -H "$AUTH_HEADER" -H "Accept: application/vnd.github.v3+json" "$url")
    else
        response=$(curl -s -H "Accept: application/vnd.github.v3+json" "$url")
    fi
    
    echo "$response"
}

# Function to check rate limit
check_rate_limit() {
    local response
    if [ -n "$AUTH_HEADER" ]; then
        response=$(curl -s -H "$AUTH_HEADER" -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API_BASE}/rate_limit")
    else
        response=$(curl -s -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API_BASE}/rate_limit")
    fi
    
    local remaining=$(echo "$response" | grep -o '"remaining":[0-9]*' | cut -d':' -f2)
    local reset_time=$(echo "$response" | grep -o '"reset":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$remaining" ] && [ "$remaining" -lt 10 ]; then
        print_warn "Rate limit remaining: $remaining"
        if [ -n "$reset_time" ]; then
            local reset_date=$(date -d "@$reset_time" 2>/dev/null || date -r "$reset_time" 2>/dev/null || echo "unknown")
            print_warn "Rate limit resets at: $reset_date"
        fi
    fi
}

# Function to get all repositories from target organization
get_org_repos() {
    print_info "Fetching existing repositories from ${TARGET_ORG}..."
    local page=1
    local per_page=100
    local all_repos=""
    
    while true; do
        local url="${GITHUB_API_BASE}/orgs/${TARGET_ORG}/repos?page=${page}&per_page=${per_page}&type=all"
        local response=$(github_api_request "$url")
        
        # Check for API errors first
        if echo "$response" | grep -q '"message"'; then
            local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            print_error "GitHub API error: $error_msg"
            print_warn "Failed to fetch repositories from ${TARGET_ORG}. Continuing with empty list."
            # Create empty file if error occurs and break
            touch "$EXISTING_REPOS_FILE"
            break
        fi
        
        # Check if response is a JSON array (starts with [)
        local first_char=$(echo "$response" | head -c 1 | tr -d '[:space:]')
        if [ "$first_char" != "[" ]; then
            if [ "$page" -eq 1 ]; then
                print_warn "Unexpected response format (expected JSON array)"
                print_info "Response preview: $(echo "$response" | head -c 200)"
            fi
            break
        fi
        
        # Check if it's an empty array
        local trimmed_response=$(echo "$response" | tr -d '[:space:]')
        if [ "$trimmed_response" = "[]" ]; then
            if [ "$page" -eq 1 ]; then
                print_warn "No repositories found in ${TARGET_ORG}"
            fi
            break
        fi
        
        # Extract repository full names (owner/repo)
        # Use sed to extract full_name values more reliably
        local repos=$(echo "$response" | grep -o '"full_name":"[^"]*"' 2>/dev/null | sed 's/"full_name":"\([^"]*\)"/\1/' || true)
        
        if [ -z "$repos" ]; then
            if [ "$page" -eq 1 ]; then
                print_warn "Could not extract repository names from response"
                print_info "Trying alternative extraction method..."
                # Try alternative: use jq if available, or try different grep pattern
                repos=$(echo "$response" | grep -oE '"full_name"\s*:\s*"[^"]*"' 2>/dev/null | sed -E 's/.*"full_name"\s*:\s*"([^"]*)".*/\1/' || true)
            fi
            if [ -z "$repos" ]; then
                break
            fi
        fi
        
        # Add repos to the list
        while IFS= read -r repo; do
            if [ -n "$repo" ]; then
                all_repos="${all_repos}${repo}"$'\n'
            fi
        done <<< "$repos"
        
        # Count how many repos we got
        local repo_count=$(echo "$repos" | grep -v '^$' | wc -l)
        repo_count=$(echo "$repo_count" | tr -d '[:space:]')
        
        # If we got fewer than per_page, this is the last page
        if [ -z "$repo_count" ] || [ "$repo_count" -lt "$per_page" ]; then
            break
        fi
        
        page=$((page + 1))
        
        # Small delay to avoid rate limiting
        sleep 0.5
    done
    
    # Write results to file (even if empty)
    if [ -n "$all_repos" ]; then
        # Filter out empty lines and write to file
        echo "$all_repos" | grep -v '^$' | grep -v '^[[:space:]]*$' | sort -u > "$EXISTING_REPOS_FILE" || touch "$EXISTING_REPOS_FILE"
    else
        touch "$EXISTING_REPOS_FILE"
    fi
    
    # Count non-empty lines - ensure we get a clean integer
    local count=0
    if [ -f "$EXISTING_REPOS_FILE" ] && [ -s "$EXISTING_REPOS_FILE" ]; then
        count=$(grep -v '^$' "$EXISTING_REPOS_FILE" | grep -v '^[[:space:]]*$' | wc -l)
        count=$(echo "$count" | tr -d '[:space:]')
        # Ensure count is numeric
        if ! echo "$count" | grep -qE '^[0-9]+$'; then
            count=0
        fi
    fi
    
    if [ -n "$count" ] && [ "$count" -gt 0 ] 2>/dev/null; then
        print_info "Found $count existing repositories in ${TARGET_ORG}"
    else
        print_warn "No existing repositories found in ${TARGET_ORG} (file created but empty)"
    fi
}

# Function to check if repository has README file
check_readme_exists() {
    local repo="$1"
    local auth_header="$2"
    local api_base="$3"
    local default_branch="$4"
    
    # Check for common README file names
    local readme_names=("README.md" "README.rst" "README.txt" "README" "readme.md" "Readme.md")
    
    for readme_name in "${readme_names[@]}"; do
        local contents_url="${api_base}/repos/${repo}/contents/${readme_name}?ref=${default_branch}"
        local contents_response
        if [ -n "$auth_header" ]; then
            contents_response=$(curl -s -H "$auth_header" -H "Accept: application/vnd.github.v3+json" "$contents_url" 2>/dev/null || echo "")
        else
            contents_response=$(curl -s -H "Accept: application/vnd.github.v3+json" "$contents_url" 2>/dev/null || echo "")
        fi
        
        # If we get a valid response (not an error), README exists
        if [ -n "$contents_response" ] && ! echo "$contents_response" | grep -q '"message"'; then
            if echo "$contents_response" | grep -q '"name"'; then
                echo "true"
                return 0
            fi
        fi
    done
    
    echo "false"
}

# Function to extract JSON field value (handles null values)
extract_json_field() {
    local json="$1"
    local field="$2"
    local default="${3:-}"
    
    # Try to extract the field value
    local value=$(echo "$json" | grep -o "\"${field}\":[^,}]*" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed 's/,$//' || echo "")
    
    # Handle null values
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "$default"
    else
        # Escape pipe characters in the value to avoid breaking the output format
        echo "$value" | sed 's/|/\\|/g'
    fi
}

# Function to extract JSON array field (for topics)
extract_json_array() {
    local json="$1"
    local field="$2"
    
    # Extract array values and join with commas
    local values=$(echo "$json" | grep -o "\"${field}\":\[[^]]*\]" | sed "s/\"${field}\"://" | sed 's/\[//' | sed 's/\]//' | sed 's/"//g' | sed 's/,/, /g' || echo "")
    
    if [ -z "$values" ] || [ "$values" = "null" ] || [ "$values" = "[]" ]; then
        echo "N/A"
    else
        # Escape pipe characters
        echo "$values" | sed 's/|/\\|/g'
    fi
}

# Function to process a single repository (for parallel processing)
# This function is called in background jobs
process_repo_parallel() {
    local repo="$1"
    local existing_repos_file="$2"
    local results_file="$3"
    local target_org="$4"
    local auth_header="$5"
    local api_base="$6"
    local filter_readme="$7"
    
    if [ -z "$repo" ]; then
        return 0
    fi
    
    local repo_url="${api_base}/repos/${repo}"
    local repo_response
    if [ -n "$auth_header" ]; then
        repo_response=$(curl -s -H "$auth_header" -H "Accept: application/vnd.github.v3+json" "$repo_url")
    else
        repo_response=$(curl -s -H "Accept: application/vnd.github.v3+json" "$repo_url")
    fi
    
    # Check for errors in repo details
    if echo "$repo_response" | grep -q '"message"'; then
        return 1
    fi
    
    # Extract all fields with better null handling
    local description=$(extract_json_field "$repo_response" "description" "N/A")
    local stars=$(extract_json_field "$repo_response" "stargazers_count" "0")
    local forks=$(extract_json_field "$repo_response" "forks_count" "0")
    local default_branch=$(extract_json_field "$repo_response" "default_branch" "main")
    
    # Check for README file (GitHub API doesn't provide has_readme field directly)
    local has_readme=$(check_readme_exists "$repo" "$auth_header" "$api_base" "$default_branch")
    
    local language=$(extract_json_field "$repo_response" "language" "N/A")
    local size=$(extract_json_field "$repo_response" "size" "0")  # Size in KB
    local updated_at=$(extract_json_field "$repo_response" "updated_at" "N/A")
    local created_at=$(extract_json_field "$repo_response" "created_at" "N/A")
    local archived=$(extract_json_field "$repo_response" "archived" "false")
    
    # Extract license (nested object)
    local license_name=$(echo "$repo_response" | grep -o '"license":{[^}]*}' | grep -o '"name":"[^"]*"' | sed 's/"name":"\([^"]*\)"/\1/' || echo "")
    if [ -z "$license_name" ] || [ "$license_name" = "null" ]; then
        license_name="N/A"
    fi
    
    # Extract topics - Note: topics are not in the basic repo endpoint
    # Would require separate API call to /repos/{owner}/{repo}/topics
    # For performance, we'll set to N/A and can enhance later if needed
    local topics="N/A"
    
    # Try to get topics if we have auth (requires additional API call)
    # This is optional and can be slow, so we'll skip it for now
    # Uncomment below if you want to fetch topics (slower but more complete)
    # if [ -n "$auth_header" ]; then
    #     local topics_url="${api_base}/repos/${repo}/topics"
    #     local topics_response=$(curl -s -H "$auth_header" -H "Accept: application/vnd.github.mercy-preview+json" "$topics_url" 2>/dev/null || echo "")
    #     if [ -n "$topics_response" ] && ! echo "$topics_response" | grep -q '"message"'; then
    #         topics=$(extract_json_array "$topics_response" "names")
    #     fi
    # fi
    
    # Filter by README if requested
    if [ "$filter_readme" = "true" ] && [ "$has_readme" != "true" ]; then
        return 0  # Skip repos without README
    fi
    
    # Extract just the repo name (without owner)
    local repo_name=$(echo "$repo" | cut -d'/' -f2)
    local org_repo_name="${target_org}/${repo_name}"
    
    # Check if repo already exists in target org (compare full_name)
    if [ -f "$existing_repos_file" ] && [ -s "$existing_repos_file" ]; then
        if grep -qFx "${org_repo_name}" "$existing_repos_file" 2>/dev/null; then
            return 0  # Already exists, skip
        fi
    fi
    
    # Format dates to be more readable (YYYY-MM-DD)
    local updated_date=$(echo "$updated_at" | cut -d'T' -f1)
    local created_date=$(echo "$created_at" | cut -d'T' -f1)
    
    # Format size (convert KB to MB if > 1024 KB)
    local size_formatted="${size}KB"
    if [ -n "$size" ] && [ "$size" != "N/A" ] && [ "$size" != "0" ]; then
        # Check if size is numeric and > 1024
        if echo "$size" | grep -qE '^[0-9]+$' && [ "$size" -gt 1024 ] 2>/dev/null; then
            if command -v bc >/dev/null 2>&1; then
                local size_mb=$(echo "scale=2; $size / 1024" | bc 2>/dev/null || echo "")
                if [ -n "$size_mb" ]; then
                    size_formatted="${size_mb}MB"
                fi
            else
                # Fallback: simple division using awk
                local size_mb=$(awk "BEGIN {printf \"%.2f\", $size/1024}" 2>/dev/null || echo "")
                if [ -n "$size_mb" ]; then
                    size_formatted="${size_mb}MB"
                fi
            fi
        fi
    fi
    
    # Write to a unique temp file to avoid race conditions
    # Format: full_name|description|stars|forks|default_branch|has_readme|language|size|updated_at|created_at|license|archived|topics
    local temp_file="${results_file}.tmp.$$.$(shuf -i 100000-999999 -n 1)"
    echo "${repo}|${description}|${stars}|${forks}|${default_branch}|${has_readme}|${language}|${size_formatted}|${updated_date}|${created_date}|${license_name}|${archived}|${topics}" > "$temp_file"
    
    # Append to main temp file using file locking (if available) or atomic append
    if command -v flock >/dev/null 2>&1; then
        (
            flock -x 200
            cat "$temp_file" >> "${results_file}.tmp"
            rm -f "$temp_file"
        ) 200>"${results_file}.lock"
    else
        # Fallback: use atomic append (less safe but works without flock)
        cat "$temp_file" >> "${results_file}.tmp" 2>/dev/null
        rm -f "$temp_file"
    fi
    
    return 0
}

# Function to search GitHub repositories
search_repositories() {
    print_info "Searching GitHub for: $SEARCH_QUERY"
    print_info "Using parallel processing with up to $MAX_PARALLEL_JOBS concurrent jobs"
    local page=1
    local per_page=100
    local all_results=""
    local total_count=0
    
    # URL encode the search query properly
    # GitHub search API expects queries like: "uvm", "uvm in:name", "language:systemverilog uvm", etc.
    local encoded_query=$(echo "$SEARCH_QUERY" | sed 's/ /%20/g' | sed 's/:/%3A/g' | sed 's/+/%2B/g' | sed 's/&/%26/g' | sed 's/?/%3F/g' | sed 's/=/%3D/g')
    
    while true; do
        local url="${GITHUB_API_BASE}/search/repositories?q=${encoded_query}&page=${page}&per_page=${per_page}&sort=stars&order=desc"
        local response=$(github_api_request "$url")
        
        # Check for errors
        if echo "$response" | grep -q '"message"'; then
            local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            local error_docs=$(echo "$response" | grep -o '"documentation_url":"[^"]*"' | cut -d'"' -f4 || echo "")
            print_error "GitHub API error: $error_msg"
            if [ -n "$error_docs" ]; then
                print_info "Documentation: $error_docs"
            fi
            # Show response for debugging
            if [ "$page" -eq 1 ]; then
                print_info "API Response: $(echo "$response" | head -c 500)"
            fi
            break
        fi
        
        # Extract total count on first page
        if [ "$page" -eq 1 ]; then
            # Try multiple patterns to extract total_count
            total_count=$(echo "$response" | grep -oE '"total_count"\s*:\s*[0-9]+' | grep -oE '[0-9]+' | head -1)
            if [ -z "$total_count" ]; then
                # Try without whitespace
                total_count=$(echo "$response" | grep -o '"total_count":[0-9]*' | cut -d':' -f2 | tr -d '[:space:]')
            fi
            
            if [ -n "$total_count" ] && [ "$total_count" != "" ]; then
                if [ "$total_count" = "0" ]; then
                    print_warn "No repositories found matching search query: $SEARCH_QUERY"
                    print_info "Try a more specific query, e.g., 'language:systemverilog uvm' or 'uvm in:name'"
                    break
                else
                    print_info "Total repositories found: $total_count"
                fi
            else
                print_warn "Could not extract total_count from search response"
                print_info "Response preview: $(echo "$response" | head -c 300)"
            fi
        fi
        
        # Check if response is not empty
        if [ -z "$response" ]; then
            print_error "Empty response from GitHub API"
            break
        fi
        
        # Extract repository information from items array
        # Extract full_name from items array - handle JSON with or without whitespace
        # First try: with optional whitespace around colon
        local repos=$(echo "$response" | grep -oE '"full_name"\s*:\s*"[^"]*"' | sed -E 's/"full_name"\s*:\s*"([^"]*)"/\1/' || true)
        
        # If that didn't work, try without whitespace
        if [ -z "$repos" ]; then
            repos=$(echo "$response" | grep -o '"full_name":"[^"]*"' | sed 's/"full_name":"\([^"]*\)"/\1/' || true)
        fi
        
        # If still nothing, try a more permissive pattern
        if [ -z "$repos" ]; then
            repos=$(echo "$response" | grep -oE 'full_name["\s]*:["\s]*["]([^"]+)' | sed -E 's/.*"([^"]+)"$/\1/' || true)
        fi
        
        if [ -z "$repos" ]; then
            if [ "$page" -eq 1 ]; then
                print_warn "Could not extract repository names from search results"
                print_info "Response structure: $(echo "$response" | head -c 500)"
            fi
            break
        fi
        
        # Process repos in parallel batches
        local repo_list=()
        while IFS= read -r repo; do
            if [ -n "$repo" ]; then
                repo_list+=("$repo")
            fi
        done <<< "$repos"
        
        if [ ${#repo_list[@]} -eq 0 ]; then
            page=$((page + 1))
            continue
        fi
        
        # Process repos in parallel with job control
        local total_repos=${#repo_list[@]}
        local processed=0
        local i=0
        
            # Process in batches to control parallelism
        while [ $i -lt $total_repos ]; do
            local batch_end=$((i + MAX_PARALLEL_JOBS))
            if [ $batch_end -gt $total_repos ]; then
                batch_end=$total_repos
            fi
            
            # Start batch of parallel jobs
            local j=$i
            while [ $j -lt $batch_end ]; do
                local repo="${repo_list[$j]}"
                (
                    process_repo_parallel "$repo" "$EXISTING_REPOS_FILE" "$RESULTS_FILE" "$TARGET_ORG" "$AUTH_HEADER" "$GITHUB_API_BASE" "$FILTER_README_ONLY"
                ) &
                j=$((j + 1))
            done
            
            # Wait for this batch to complete
            wait
            
            processed=$((processed + (batch_end - i)))
            if [ "$page" -eq 1 ] && [ $((processed % 20)) -eq 0 ]; then
                print_info "Processed $processed/$total_repos repositories from page $page..."
            fi
            
            i=$batch_end
        done
        
        if [ "$page" -eq 1 ] && [ $total_repos -gt 0 ]; then
            print_info "Completed processing $total_repos repositories from page $page"
        fi
        
        page=$((page + 1))
        
        # Check if we got fewer results than per_page (last page)
        local repo_count=$(echo "$repos" | grep -v '^$' | wc -l)
        repo_count=$(echo "$repo_count" | tr -d '[:space:]')
        if [ -z "$repo_count" ] || [ "$repo_count" -lt "$per_page" ]; then
            break
        fi
        
        # Rate limit: GitHub allows 30 requests per minute for unauthenticated, 5000 for authenticated
        sleep 1
        
        # Limit to first 10 pages to avoid excessive API calls
        if [ "$page" -gt 10 ]; then
            print_warn "Limiting search to first 10 pages (1000 repositories)"
            break
        fi
    done
    
    # Clean up lock file if it exists
    rm -f "${RESULTS_FILE}.lock"
    rm -f "${RESULTS_FILE}.tmp."*  # Clean up any leftover temp files
    
    # Sort results by stars (descending) and format output
    if [ -f "${RESULTS_FILE}.tmp" ]; then
        # Add header row
        {
            echo "full_name|description|stars|forks|default_branch|has_readme|language|size|updated_at|created_at|license|archived|topics"
            # Replace empty stars field (||) with |0| for proper numeric sorting
            # Field 3 is stars, extract numeric value for sorting
            awk -F'|' 'BEGIN{OFS=FS} {
                if ($3 == "" || $3 == "N/A") $3 = "0"
                # Extract numeric value from stars (handle cases like "100" or "1.2K")
                gsub(/[^0-9]/, "", $3)
                if ($3 == "") $3 = "0"
                print
            }' "${RESULTS_FILE}.tmp" | \
            sort -t'|' -k3 -rn
        } > "$RESULTS_FILE"
        rm -f "${RESULTS_FILE}.tmp"
        
        local count=0
        if [ -f "$RESULTS_FILE" ] && [ -s "$RESULTS_FILE" ]; then
            # Count non-header lines
            count=$(tail -n +2 "$RESULTS_FILE" | wc -l)
            count=$(echo "$count" | tr -d '[:space:]')
            if ! echo "$count" | grep -qE '^[0-9]+$'; then
                count=0
            fi
        fi
        
        if [ -n "$count" ] && [ "$count" -gt 0 ] 2>/dev/null; then
            print_info "Found $count repositories NOT in ${TARGET_ORG} (to potentially fork)"
            
            # Display summary
            print_info "Top 10 repositories by stars:"
            tail -n +2 "$RESULTS_FILE" | head -10 | while IFS='|' read -r repo desc stars forks branch readme language size updated created license archived topics; do
                local readme_status="No README"
                if [ "$readme" = "true" ]; then
                    readme_status="✅ Has README"
                else
                    readme_status="❌ No README"
                fi
                local lang_display="${language}"
                if [ "$language" = "N/A" ]; then
                    lang_display="Unknown"
                fi
                echo "  - ${repo} (⭐ ${stars}, 🍴 ${forks}) [${lang_display}] - ${readme_status}"
            done
        else
            print_warn "No repositories found that are not already in ${TARGET_ORG}"
        fi
    else
        print_warn "No repositories found matching the search criteria"
    fi
}

# Main execution
main() {
    print_info "Starting repository search..."
    check_rate_limit
    
    # Get existing repositories from target organization
    # Continue even if this fails - we'll just skip duplicate checking
    get_org_repos || print_warn "Continuing search despite errors fetching existing repos..."
    
    # Search for new repositories
    search_repositories
    
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Summary:"
    print_info "  • $EXISTING_REPOS_FILE: Repositories ALREADY in ${TARGET_ORG} (already forked)"
    print_info "  • $RESULTS_FILE: Repositories from search that are NOT in ${TARGET_ORG} (need to fork)"
    print_info ""
    print_info "Output Format (pipe-separated):"
    print_info "  full_name|description|stars|forks|default_branch|has_readme|language|size|updated_at|created_at|license|archived|topics"
    print_info ""
    print_info "Field Descriptions:"
    print_info "  • full_name: Repository owner/repo (e.g., username/repo-name)"
    print_info "  • description: Repository description (N/A if none)"
    print_info "  • stars: Number of stars (⭐)"
    print_info "  • forks: Number of forks (🍴)"
    print_info "  • default_branch: Default branch name (usually 'main' or 'master')"
    print_info "  • has_readme: true/false - whether repository has README.md"
    print_info "  • language: Primary programming language (N/A if unknown)"
    print_info "  • size: Repository size (KB or MB)"
    print_info "  • updated_at: Last update date (YYYY-MM-DD)"
    print_info "  • created_at: Creation date (YYYY-MM-DD)"
    print_info "  • license: License name (N/A if none)"
    print_info "  • archived: true/false - whether repository is archived"
    print_info "  • topics: Comma-separated list of topics/tags (N/A if none)"
    print_info ""
    if [ "$FILTER_README_ONLY" = "true" ]; then
        print_info "  ⚠️  Filtered: Only repositories with README.md are included"
    fi
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
