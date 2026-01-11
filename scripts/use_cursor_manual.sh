#!/bin/bash
# Helper script to use Cursor IDE manually generated content with generate_readme.sh
# Usage: ./scripts/use_cursor_manual.sh owner repo-name [cursor-content.txt]
# If cursor-content.txt is provided, it will parse and export as environment variables
# If not provided, it will prompt you to paste the content

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }

if [ $# -lt 2 ]; then
    log_error "Usage: $0 owner repo-name [cursor-content.txt]"
    echo ""
    echo "Examples:"
    echo "  $0 universal-verification-methodology cocotb cursor-content.txt"
    echo "  $0 universal-verification-methodology cocotb"
    echo ""
    echo "If cursor-content.txt is not provided, you'll be prompted to paste the content."
    exit 1
fi

OWNER="$1"
REPO="$2"
CURSOR_FILE="${3:-}"

# Function to parse Cursor-generated content
parse_cursor_content() {
    local content="$1"
    
    # Extract DESCRIPTION section
    local description=$(echo "$content" | sed -n '/^DESCRIPTION:/,/^FEATURES:/p' | sed '1d;$d' | grep -v "^FEATURES:" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract FEATURES section
    local features=$(echo "$content" | sed -n '/^FEATURES:/,/^USAGE_EXAMPLE:\|^USE_CASE:/p' | sed '1d;$d' | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//' | sed 's/^-[[:space:]]*/- /')
    
    # Extract USAGE_EXAMPLE section (code block)
    local usage_code=""
    local usage_section=$(echo "$content" | sed -n '/^USAGE_EXAMPLE:/,/^EXPLANATION:/p' | sed '1d;$d')
    
    if echo "$usage_section" | grep -q '```'; then
        # Extract code between ``` markers
        local in_block=false
        usage_code=""
        while IFS= read -r line; do
            if echo "$line" | grep -q '^```'; then
                if [ "$in_block" = false ]; then
                    in_block=true
                    continue
                else
                    break
                fi
            elif [ "$in_block" = true ]; then
                if [ -z "$usage_code" ]; then
                    usage_code="$line"
                else
                    usage_code="${usage_code}
${line}"
                fi
            fi
        done < <(printf '%s\n' "$usage_section")
    fi
    
    # Extract EXPLANATION section
    local explanation=$(echo "$content" | sed -n '/^EXPLANATION:/,/^COMMON_USE_CASES:/p' | sed '1d;$d' | grep -v "^COMMON_USE_CASES:" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract COMMON_USE_CASES section
    local use_cases=$(echo "$content" | sed -n '/^COMMON_USE_CASES:/,$p' | sed '1d' | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//' | head -n 5)
    
    # Export as environment variables
    export CURSOR_MANUAL_DESCRIPTION="$description"
    export CURSOR_MANUAL_FEATURES="$features"
    export CURSOR_MANUAL_USAGE="$usage_code"
    export CURSOR_MANUAL_EXPLANATION="$explanation"
    export CURSOR_MANUAL_USE_CASES="$use_cases"
    
    # Enable AI so the generate_readme.sh will use manual content
    export AI_ENABLED=true
}

# Get Cursor content
if [ -n "$CURSOR_FILE" ]; then
    if [ ! -f "$CURSOR_FILE" ]; then
        log_error "File not found: $CURSOR_FILE"
        exit 1
    fi
    log_info "Reading Cursor-generated content from: $CURSOR_FILE"
    CURSOR_CONTENT=$(cat "$CURSOR_FILE")
else
    log_info "No content file provided. Please paste your Cursor IDE generated content."
    log_info "Paste the content below (including DESCRIPTION, FEATURES, USAGE_EXAMPLE, etc.)"
    log_info "Press Ctrl+D (or Ctrl+Z on Windows) when done:"
    echo ""
    CURSOR_CONTENT=$(cat)
fi

# Parse and export content
log_info "Parsing Cursor-generated content..."
parse_cursor_content "$CURSOR_CONTENT"

log_success "Content parsed successfully!"
log_info ""
log_info "Extracted:"
if [ -n "$CURSOR_MANUAL_DESCRIPTION" ]; then
    log_info "  Description: $(echo "$CURSOR_MANUAL_DESCRIPTION" | cut -c1-60)..."
fi
if [ -n "$CURSOR_MANUAL_FEATURES" ]; then
    local feature_count=$(echo "$CURSOR_MANUAL_FEATURES" | grep -c "^-" || echo "0")
    log_info "  Features: ${feature_count} items"
fi
if [ -n "$CURSOR_MANUAL_USAGE" ]; then
    log_info "  Usage example: $(echo "$CURSOR_MANUAL_USAGE" | head -n1 | cut -c1-40)..."
fi
if [ -n "$CURSOR_MANUAL_EXPLANATION" ]; then
    log_info "  Explanation: $(echo "$CURSOR_MANUAL_EXPLANATION" | cut -c1-60)..."
fi

log_info ""
log_info "Generating README with Cursor-generated content..."

# Call generate_readme.sh (it will detect CURSOR_MANUAL_* variables)
bash scripts/generate_readme.sh "$OWNER" "$REPO" "$(pwd)/README-${REPO}.md"

log_success "README generated with Cursor IDE content!"
log_info "Output: README-${REPO}.md"

exit 0
