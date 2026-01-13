#!/bin/bash
#
# Sync upstream changes from original repository to forked repository
# while preserving the custom README.md in the fork
#
# Usage:
#   ./sync_upstream.sh fork_owner fork_repo upstream_owner upstream_repo [github_token]
#   ./sync_upstream.sh fork_owner fork_repo upstream_owner/repo [github_token]
#
# Example:
#   ./sync_upstream.sh universal-verification-methodology core-v-verif openhwgroup core-v-verif
#   ./sync_upstream.sh universal-verification-methodology core-v-verif openhwgroup/core-v-verif

set -euo pipefail

# GitHub token must be provided via GITHUB_TOKEN environment variable or as an argument
# Never hardcode tokens in scripts for security reasons
GITHUB_API="https://api.github.com"
CLONE_DIR=".sync_clones"
PRESERVE_FILE="README.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions (output to stderr so they don't interfere with function return values)
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
        -H "User-Agent: Upstream-Sync/1.0"
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
        log_info "The script will attempt to continue using git operations (which may work for public repos)."
        echo "{}"
    elif [ "$http_code" -eq 403 ]; then
        log_warning "Forbidden (HTTP 403). You may not have access to this resource."
        echo "{}"
    elif [ "$http_code" -eq 429 ]; then
        log_error "Rate limit exceeded. Please wait before retrying."
        exit 1
    else
        log_warning "API request failed: HTTP $http_code"
        local error_msg
        error_msg=$(echo "$response" | jq -r '.message // empty' 2>/dev/null || echo "")
        if [ -n "$error_msg" ]; then
            log_warning "Error message: $error_msg"
        fi
        echo "{}"
    fi
}

# Get default branch of repository
get_default_branch() {
    local owner="$1"
    local repo="$2"
    local repo_info
    repo_info=$(api_request "GET" "repos/${owner}/${repo}")
    
    # Try to extract default branch from API response
    local branch
    branch=$(echo "$repo_info" | jq -r '.default_branch // empty' 2>/dev/null || echo "")
    
    # If API failed or branch is empty, return default
    if [ -z "$branch" ] || [ "$branch" = "null" ]; then
        echo "main"
    else
        echo "$branch"
    fi
}

# Get default branch using git (fallback when API fails)
get_default_branch_git() {
    local repo_dir="$1"
    local remote="${2:-origin}"
    
    # Check if directory exists before trying to cd
    if [ ! -d "$repo_dir" ]; then
        echo "main"
        return 0
    fi
    
    local original_dir
    original_dir=$(pwd)
    
    if ! cd "$repo_dir" 2>/dev/null; then
        echo "main"
        return 0
    fi
    
    # Try to get default branch from git
    local branch
    branch=$(git symbolic-ref "refs/remotes/${remote}/HEAD" 2>/dev/null | sed "s@^refs/remotes/${remote}/@@" 2>/dev/null)
    if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
        cd "$original_dir" || true
        echo "$branch"
        return 0
    fi
    
    # Fallback: try common branch names (check master first for older repos)
    for b in master main; do
        if git show-ref --verify --quiet "refs/remotes/${remote}/${b}" 2>/dev/null; then
            cd "$original_dir" || true
            echo "$b"
            return 0
        fi
    done
    
    # Last resort
    cd "$original_dir" || true
    echo "main"
}

# Clone or update repository
prepare_repo() {
    local fork_owner="$1"
    local fork_repo="$2"
    local fork_url
    local repo_dir="${CLONE_DIR}/${fork_owner}/${fork_repo}"
    
    # Build clone URL - use token if available, otherwise use public URL
    if [ -n "$GITHUB_TOKEN" ] && [ "$GITHUB_TOKEN" != "none" ]; then
        fork_url="https://${GITHUB_TOKEN}@github.com/${fork_owner}/${fork_repo}.git"
    else
        fork_url="https://github.com/${fork_owner}/${fork_repo}.git"
    fi
    
    if [ -d "$repo_dir" ]; then
        log_info "Repository already cloned, updating..."
        if cd "$repo_dir" 2>/dev/null; then
            # Fetch latest changes from origin
            git fetch origin >/dev/null 2>&1 || true
            
            # Get default branch using git (more reliable than API)
            local default_branch
            default_branch=$(get_default_branch_git "$repo_dir" "origin" 2>/dev/null)
            
            # Checkout default branch (suppress all output)
            git checkout -f "$default_branch" >/dev/null 2>&1 || \
                git checkout -f main >/dev/null 2>&1 || \
                git checkout -f master >/dev/null 2>&1 || true
            
            # Reset to origin to ensure clean state (suppress all output)
            local current_branch
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "$default_branch")
            git reset --hard "origin/${current_branch}" >/dev/null 2>&1 || true
        else
            log_warning "Repository directory exists but cannot access: $repo_dir"
            log_info "Removing and re-cloning..."
            rm -rf "$repo_dir"
        fi
    fi
    
    # Clone if directory doesn't exist or was removed
    if [ ! -d "$repo_dir" ]; then
        log_info "Cloning repository ${fork_owner}/${fork_repo}..."
        mkdir -p "$(dirname "$repo_dir")"
        if ! git clone "$fork_url" "$repo_dir" --depth 1; then
            log_error "Failed to clone repository"
            return 1
        fi
        cd "$repo_dir" || {
            log_error "Failed to cd into cloned repository"
            return 1
        }
    fi
    
    # Ensure we're in the repo directory (after cloning or updating)
    if [ -d "$repo_dir" ]; then
        if ! cd "$repo_dir" 2>/dev/null; then
            log_error "Failed to cd into repository: $repo_dir"
            return 1
        fi
    else
        log_error "Repository directory does not exist: $repo_dir"
        return 1
    fi
    
    echo "$repo_dir"
}

# Detect default branch from upstream remote
detect_upstream_branch() {
    local remote="${1:-upstream}"
    local branch
    
    # Try to get default branch from git symbolic-ref
    branch=$(git symbolic-ref "refs/remotes/${remote}/HEAD" 2>/dev/null | sed "s@^refs/remotes/${remote}/@@")
    if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
        echo "$branch"
        return 0
    fi
    
    # Fallback: try common branch names (check which exists)
    # Check common branch names in order of preference
    for b in master main production develop dev trunk; do
        if git show-ref --verify --quiet "refs/remotes/${remote}/${b}" 2>/dev/null; then
            echo "$b"
            return 0
        fi
    done
    
    # Last resort: list all available branches and pick the first one
    # (excluding HEAD)
    branch=$(git branch -r 2>/dev/null | grep "^  ${remote}/" | grep -v "HEAD" | sed "s|^  ${remote}/||" | head -1 | tr -d ' \n')
    if [ -n "$branch" ]; then
        echo "$branch"
        return 0
    fi
    
    # Absolute last resort
    echo "main"
}

# Add or update upstream remote
setup_upstream() {
    local upstream_owner="$1"
    local upstream_repo="$2"
    local upstream_url="https://github.com/${upstream_owner}/${upstream_repo}.git"
    
    # Verify we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository. Current directory: $(pwd)"
        return 1
    fi
    
    log_info "Setting up upstream remote: ${upstream_owner}/${upstream_repo}"
    
    # Remove existing upstream if it exists
    if git remote | grep -q "^upstream$"; then
        git remote remove upstream 2>/dev/null || true
    fi
    
    # Add upstream remote
    git remote add upstream "$upstream_url"
    git fetch upstream >/dev/null 2>&1
    
    # Try to get default branch from GitHub API first (more reliable)
    local api_branch
    api_branch=$(get_default_branch "$upstream_owner" "$upstream_repo" 2>/dev/null || echo "")
    
    # Verify the API branch actually exists in the remote (if API returned a valid branch)
    if [ -n "$api_branch" ] && [ "$api_branch" != "null" ] && git show-ref --verify --quiet "refs/remotes/upstream/${api_branch}" 2>/dev/null; then
        echo "$api_branch"
        return 0
    fi
    
    # If API failed or the branch doesn't exist, fall back to git detection
    # Detect and return the actual default branch (only output branch name to stdout)
    detect_upstream_branch "upstream"
}

# Sync upstream changes while preserving README.md
sync_with_upstream() {
    local fork_branch="$1"
    local upstream_branch="$2"
    local preserved_file="$3"
    
    log_info "Syncing upstream changes (preserving ${preserved_file})..."
    
    # Ensure we're on the fork branch
    # First try to checkout the existing branch
    if ! git checkout "$fork_branch" 2>/dev/null; then
        # Branch doesn't exist locally, create it from origin
        if git show-ref --verify --quiet "refs/remotes/origin/${fork_branch}" 2>/dev/null; then
            git checkout -b "$fork_branch" "origin/${fork_branch}" 2>/dev/null || true
        else
            # No remote branch, create new branch
            git checkout -b "$fork_branch" 2>/dev/null || true
        fi
    fi
    
    # Ensure branch is up to date with origin
    git fetch origin "$fork_branch" 2>/dev/null || true
    
    # Backup the README.md we want to keep
    local readme_backup=""
    if [ -f "$preserved_file" ]; then
        log_info "Backing up ${preserved_file}..."
        readme_backup=$(mktemp)
        cp "$preserved_file" "$readme_backup"
    fi
    
    # Clean up upstream_branch variable (remove any log messages that might have been captured)
    upstream_branch=$(echo "$upstream_branch" | tail -1 | tr -d '\n')
    
    # Verify upstream branch exists before fetching
    if ! git show-ref --verify --quiet "refs/remotes/upstream/${upstream_branch}" 2>/dev/null; then
        log_error "Upstream branch '${upstream_branch}' does not exist"
        log_info "Available upstream branches:"
        git branch -r | grep "^  upstream/" | sed 's|^  upstream/||' | head -10
        if [ -n "$readme_backup" ]; then
            rm -f "$readme_backup"
        fi
        return 1
    fi
    
    # Fetch latest upstream changes (already fetched in setup_upstream, but refresh)
    git fetch upstream "$upstream_branch" 2>/dev/null || true
    
    # Try to merge upstream changes
    log_info "Merging upstream/${upstream_branch}..."
    
    local merge_output
    merge_output=$(git merge "upstream/${upstream_branch}" --allow-unrelated-histories --no-edit --no-commit 2>&1)
    local merge_exit=$?
    
    if [ $merge_exit -eq 0 ]; then
        # Merge succeeded without conflicts
        log_success "Merge completed without conflicts"
    else
        # Check if the error is about unrelated histories (shouldn't happen with --allow-unrelated-histories)
        if echo "$merge_output" | grep -qi "refusing to merge unrelated histories"; then
            log_warning "Git detected unrelated histories. Retrying with --allow-unrelated-histories..."
            if git merge "upstream/${upstream_branch}" --allow-unrelated-histories --no-edit --no-commit 2>&1; then
                log_success "Merge completed after allowing unrelated histories"
            else
                log_error "Merge failed even with --allow-unrelated-histories"
                log_error "Merge output: $merge_output"
                git merge --abort 2>/dev/null || true
                if [ -n "$readme_backup" ]; then
                    rm -f "$readme_backup"
                fi
                return 1
            fi
        # Check if there are conflicts
        elif git status --short 2>/dev/null | grep -q "^UU\|^AA\|^DD"; then
            log_warning "Merge conflicts detected"
            
            # Restore our README.md if it exists in backup
            if [ -n "$readme_backup" ] && [ -f "$readme_backup" ]; then
                log_info "Restoring ${preserved_file} from backup..."
                cp "$readme_backup" "$preserved_file"
                git add "$preserved_file"
            fi
            
            # Resolve other conflicts by taking theirs (upstream)
            for conflicted_file in $(git diff --name-only --diff-filter=U | grep -v "^${preserved_file}$"); do
                if [ -f "$conflicted_file" ]; then
                    log_info "Resolving conflict in ${conflicted_file} (taking upstream version)..."
                    git checkout --theirs "$conflicted_file" 2>/dev/null || true
                    git add "$conflicted_file"
                fi
            done
            
            # Complete the merge
            git commit -m "chore: sync with upstream while preserving ${preserved_file}" || true
        else
            # Merge failed for other reasons, abort
            log_warning "Merge failed, aborting..."
            git merge --abort 2>/dev/null || true
            if [ -n "$readme_backup" ]; then
                rm -f "$readme_backup"
            fi
            return 1
        fi
    fi
    
    # If README.md was changed by merge, restore it
    if [ -n "$readme_backup" ] && [ -f "$readme_backup" ] && [ -f "$preserved_file" ]; then
        if ! cmp -s "$readme_backup" "$preserved_file"; then
            log_info "Restoring ${preserved_file} after merge..."
            cp "$readme_backup" "$preserved_file"
            git add "$preserved_file"
            
            # Amend commit if we just made one, or create new commit
            if git diff --cached --quiet; then
                # No changes to commit (file already matches)
                :
            else
                # Check if we're in the middle of a merge
                if [ -f ".git/MERGE_HEAD" ]; then
                    # Complete the merge with our README
                    git commit --no-edit || \
                        git commit -m "chore: sync with upstream while preserving ${preserved_file}" || true
                else
                    # Create new commit
                    git commit --amend --no-edit 2>/dev/null || \
                        git commit -m "chore: preserve ${preserved_file} after upstream sync" 2>/dev/null || true
                fi
            fi
        fi
        rm -f "$readme_backup"
    fi
    
    # Check if we're in the middle of a merge
    if [ -f ".git/MERGE_HEAD" ]; then
        # We have a merge in progress - check if we need to commit
        if git diff --cached --quiet 2>/dev/null; then
            # No staged changes, but we're in a merge - complete it
            git commit --no-edit -m "chore: sync with upstream while preserving ${preserved_file}" || \
                git commit -m "chore: sync with upstream while preserving ${preserved_file}" || true
        else
            # Staged changes, complete the merge
            git commit --no-edit -m "chore: sync with upstream while preserving ${preserved_file}" || \
                git commit -m "chore: sync with upstream while preserving ${preserved_file}" || true
        fi
    fi
    
    # Ensure we committed if there are staged changes but not in merge
    if ! git diff --cached --quiet 2>/dev/null && [ ! -f ".git/MERGE_HEAD" ]; then
        git commit -m "chore: preserve ${preserved_file} after upstream sync" 2>/dev/null || true
    fi
    
    # If we successfully merged but no commit was made, the merge might have been fast-forward
    # Check if we're ahead of origin
    local ahead_of_origin
    ahead_of_origin=$(git rev-list --count "origin/${fork_branch}..HEAD" 2>/dev/null || echo "0")
    
    if [ "$ahead_of_origin" -eq 0 ]; then
        # Check if we're actually behind upstream
        local behind_upstream
        behind_upstream=$(git rev-list --count "HEAD..upstream/${upstream_branch}" 2>/dev/null || echo "0")
        
        if [ "$behind_upstream" -gt 0 ]; then
            log_info "Fork is ${behind_upstream} commit(s) behind upstream. Attempting to sync..."
            # Try a simple merge without the unrelated histories check
            if git merge "upstream/${upstream_branch}" --no-edit --allow-unrelated-histories 2>&1; then
                log_success "Successfully merged ${behind_upstream} commit(s) from upstream"
            else
                log_warning "Could not automatically merge. You may need to merge manually."
            fi
        fi
    fi
}

# Configure git credential helper to store token
setup_git_credentials() {
    # Configure git to store credentials
    git config --local credential.helper store 2>/dev/null || true
    
    # If token is provided, configure credential helper with token
    if [ -n "$GITHUB_TOKEN" ] && [ "$GITHUB_TOKEN" != "none" ]; then
        # Set up credential helper to use token
        # Format: https://username:token@github.com
        local cred_file="${HOME}/.git-credentials"
        local cred_entry="https://${GITHUB_TOKEN}@github.com"
        
        # Add credential to helper file if not already present
        if [ ! -f "$cred_file" ] || ! grep -q "$cred_entry" "$cred_file" 2>/dev/null; then
            mkdir -p "$(dirname "$cred_file")"
            echo "$cred_entry" >> "$cred_file"
            chmod 600 "$cred_file" 2>/dev/null || true
        fi
        
        # Configure git to use credential helper
        git config --global credential.helper store 2>/dev/null || true
    fi
}

# Push changes back to fork
push_changes() {
    local branch="$1"
    local fork_owner="$2"
    local fork_repo="$3"
    
    log_info "Pushing changes to ${fork_owner}/${fork_repo}..."
    
    # Setup git credentials to avoid password prompts
    setup_git_credentials
    
    # Check if there are changes to push
    local ahead
    ahead=$(git rev-list --count "origin/${branch}..HEAD" 2>/dev/null || echo "0")
    
    if [ "$ahead" -gt 0 ]; then
        log_info "Pushing ${ahead} commit(s)..."
        
        # Configure git to use token without prompting
        local push_url
        local original_url
        original_url=$(git remote get-url origin 2>/dev/null || echo "")
        
        if [ -n "$GITHUB_TOKEN" ] && [ "$GITHUB_TOKEN" != "none" ]; then
            push_url="https://${GITHUB_TOKEN}@github.com/${fork_owner}/${fork_repo}.git"
            # Update remote URL to include token
            git remote set-url origin "$push_url" 2>/dev/null || true
        else
            push_url="https://github.com/${fork_owner}/${fork_repo}.git"
        fi
        
        # Push without prompting (disable all interactive prompts)
        # GIT_TERMINAL_PROMPT=0 prevents password prompts
        # GIT_ASKPASS=/bin/echo makes git use echo (no-op) for credentials
        export GIT_TERMINAL_PROMPT=0
        export GIT_ASKPASS=/bin/echo
        export GIT_SSH_COMMAND="ssh -o BatchMode=yes"
        
        if git push origin "$branch" >/dev/null 2>&1; then
            log_success "Successfully pushed changes to ${fork_owner}/${fork_repo}"
        else
            # If push failed, try with explicit URL
            log_warning "Standard push failed, trying alternative method..."
            if git push "$push_url" "$branch:${branch}" >/dev/null 2>&1; then
                log_success "Successfully pushed changes to ${fork_owner}/${fork_repo}"
            else
                log_error "Failed to push changes"
                log_info "This might be due to:"
                log_info "  1. Token expired or invalid"
                log_info "  2. Token doesn't have 'repo' scope"
                log_info "  3. Repository permissions issue"
                # Restore original URL
                if [ -n "$original_url" ]; then
                    git remote set-url origin "$original_url" 2>/dev/null || true
                fi
                return 1
            fi
        fi
        
        # Restore original URL if we changed it (remove token from URL)
        if [ -n "$original_url" ] && [ "$original_url" != "$push_url" ] && [ -n "$GITHUB_TOKEN" ]; then
            # Restore URL without token for security
            local clean_url="https://github.com/${fork_owner}/${fork_repo}.git"
            git remote set-url origin "$clean_url" 2>/dev/null || true
        fi
        
        # Unset environment variables
        unset GIT_TERMINAL_PROMPT
        unset GIT_ASKPASS
        unset GIT_SSH_COMMAND
    else
        log_info "No changes to push (already up to date)"
    fi
}

# Main sync function
sync_repository() {
    local fork_owner="$1"
    local fork_repo="$2"
    local upstream_owner="$3"
    local upstream_repo="$4"
    
    log_info "Syncing ${fork_owner}/${fork_repo} with upstream ${upstream_owner}/${upstream_repo}"
    
    # Check if jq is installed (needed for API calls)
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Please install jq first."
        log_info "On Ubuntu/Debian: sudo apt-get install jq"
        log_info "On macOS: brew install jq"
        exit 1
    fi
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed."
        exit 1
    fi
    
    # Prepare repository first (needed for git-based branch detection)
    local repo_dir
    local original_dir
    local prepare_output
    local prepare_exit
    original_dir=$(pwd)
    
    # Capture output and handle errors gracefully (avoid pipefail issue)
    set +e
    prepare_output=$(prepare_repo "$fork_owner" "$fork_repo" 2>&1)
    prepare_exit=$?
    set -e
    
    if [ $prepare_exit -ne 0 ]; then
        log_error "Failed to prepare repository ${fork_owner}/${fork_repo}"
        # Show the actual error message from prepare_repo
        echo "$prepare_output" | grep -E "\[ERROR\]|\[WARNING\]" >&2 || echo "$prepare_output" >&2
        return 1
    fi
    
    # Extract the directory path (last line of output)
    repo_dir=$(echo "$prepare_output" | tail -1)
    
    # Verify we're in the correct repository directory
    if [ ! -d "$repo_dir" ]; then
        log_error "Repository directory does not exist: $repo_dir"
        log_error "prepare_repo output: $prepare_output"
        return 1
    fi
    
    # Ensure we're in the repository directory
    if ! cd "$repo_dir" 2>/dev/null; then
        log_error "Failed to cd into repository: $repo_dir"
        return 1
    fi
    
    # Verify we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not a git repository: $repo_dir"
        cd "$original_dir" || true
        return 1
    fi
    
    # Verify we're in the correct repository (check remote URL)
    local current_remote_url
    local current_dir
    current_dir=$(pwd)
    current_remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    
    log_info "Operating in repository directory: $current_dir"
    log_info "Repository remote URL: ${current_remote_url:-Not found}"
    
    if [ -n "$current_remote_url" ]; then
        if ! echo "$current_remote_url" | grep -q "${fork_owner}/${fork_repo}"; then
            log_error "ERROR: Current repository remote URL doesn't match expected!"
            log_error "Expected: ${fork_owner}/${fork_repo}"
            log_error "Current remote URL: $current_remote_url"
            log_error "Current directory: $current_dir"
            log_error "This script should only operate on ${fork_owner}/${fork_repo}"
            cd "$original_dir" || true
            return 1
        else
            log_info "Verified: Operating on correct repository ${fork_owner}/${fork_repo}"
        fi
    else
        log_warning "Could not verify remote URL, but continuing..."
    fi
    
    # Setup upstream and detect actual default branch
    local upstream_branch
    upstream_branch=$(setup_upstream "$upstream_owner" "$upstream_repo")
    
    # Get fork branch - try API first, fallback to git
    local fork_branch
    fork_branch=$(get_default_branch "$fork_owner" "$fork_repo")
    
    # If API failed, use git to detect branch
    if [ "$fork_branch" = "main" ] && [ -d "$repo_dir" ]; then
        local git_branch
        git_branch=$(get_default_branch_git "$repo_dir" "origin")
        if [ "$git_branch" != "main" ] || git show-ref --verify --quiet "refs/remotes/origin/main"; then
            fork_branch="$git_branch"
        fi
    fi
    
    log_info "Fork branch: ${fork_branch}, Upstream branch: ${upstream_branch}"
    
    # Sync changes
    if sync_with_upstream "$fork_branch" "$upstream_branch" "$PRESERVE_FILE"; then
        # Push changes
        push_changes "$fork_branch" "$fork_owner" "$fork_repo"
        log_success "Sync completed for ${fork_owner}/${fork_repo}"
    else
        log_error "Sync failed for ${fork_owner}/${fork_repo}"
        cd "$original_dir"
        return 1
    fi
    
    cd "$original_dir"
}

# Main function
main() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 fork_owner fork_repo upstream_owner upstream_repo [github_token]"
        echo "       $0 fork_owner fork_repo upstream_owner/repo [github_token]"
        echo ""
        echo "Examples:"
        echo "  $0 universal-verification-methodology core-v-verif openhwgroup core-v-verif"
        echo "  $0 universal-verification-methodology core-v-verif openhwgroup/core-v-verif"
        echo "  $0 universal-verification-methodology core-v-verif openhwgroup core-v-verif ghp_xxxxx"
        exit 1
    fi
    
    local fork_owner="$1"
    local fork_repo="$2"
    local upstream_owner=""
    local upstream_repo=""
    local token="${5:-}"
    
    # Parse upstream argument
    if [[ "$3" =~ ^[^/]+/[^/]+$ ]]; then
        # Format: upstream_owner/repo
        upstream_owner=$(echo "$3" | cut -d'/' -f1)
        upstream_repo=$(echo "$3" | cut -d'/' -f2)
        if [ $# -ge 4 ] && [[ "$4" =~ ^gh[opu]_ ]]; then
            token="$4"
        fi
    else
        # Format: upstream_owner upstream_repo
        upstream_owner="$3"
        upstream_repo="$4"
        if [ $# -ge 5 ] && [[ "$5" =~ ^gh[opu]_ ]]; then
            token="$5"
        fi
    fi
    
    if [ -z "$upstream_owner" ] || [ -z "$upstream_repo" ]; then
        log_error "Invalid upstream repository format"
        exit 1
    fi
    
    # Override token if provided
    if [ -n "$token" ]; then
        GITHUB_TOKEN="$token"
    fi
    
    # Check if token is provided
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log_error "GitHub token is required!"
        echo "Please set GITHUB_TOKEN environment variable:" >&2
        echo "  export GITHUB_TOKEN=ghp_your_token_here" >&2
        echo "Or provide it as the last argument to the script" >&2
        echo "" >&2
        echo "Get a token from: https://github.com/settings/tokens" >&2
        exit 1
    fi
    
    sync_repository "$fork_owner" "$fork_repo" "$upstream_owner" "$upstream_repo"
}

# Run main function
main "$@"
