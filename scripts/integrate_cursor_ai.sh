#!/bin/bash
# Integration script to process Cursor IDE AI-generated content and merge with README generation
# Usage: ./scripts/integrate_cursor_ai.sh owner repo-name cursor-generated-content.txt [output_file]

set -euo pipefail

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

# Check arguments
if [ $# -lt 3 ]; then
    log_error "Usage: $0 owner repo-name cursor-generated-content.txt [output_file]"
    echo ""
    echo "Examples:"
    echo "  $0 universal-verification-methodology cocotb cursor-ai-content.txt"
    echo "  $0 universal-verification-methodology cocotb cursor-ai-content.txt README.md"
    exit 1
fi

OWNER="$1"
REPO="$2"
CURSOR_CONTENT_FILE="$3"
OUTPUT_FILE="${4:-README.md}"

# Check if Cursor content file exists
if [ ! -f "$CURSOR_CONTENT_FILE" ]; then
    log_error "Cursor-generated content file not found: $CURSOR_CONTENT_FILE"
    exit 1
fi

log_info "Processing Cursor IDE AI-generated content..."
log_info "Repository: ${OWNER}/${REPO}"
log_info "Cursor content file: ${CURSOR_CONTENT_FILE}"
log_info "Output file: ${OUTPUT_FILE}"

# Read Cursor-generated content
CURSOR_CONTENT=$(cat "$CURSOR_CONTENT_FILE")

# Parse Cursor-generated content
parse_cursor_content() {
    local content="$1"
    
    # Extract DESCRIPTION section
    local description=$(echo "$content" | sed -n '/^DESCRIPTION:/,/^FEATURES:/p' | sed '1d;$d' | grep -v "^FEATURES:" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract FEATURES section
    local features=$(echo "$content" | sed -n '/^FEATURES:/,/^USAGE_EXAMPLE:\|^EXPLANATION:\|^USE_CASE:/p' | sed '1d;$d' | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//' | sed 's/^-[[:space:]]*/- /' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract USAGE_EXAMPLE section (code block)
    local usage_example=""
    local usage_section=$(echo "$content" | sed -n '/^USAGE_EXAMPLE:/,/^EXPLANATION:\|^COMMON_USE_CASES:/p' | sed '1d;$d')
    
    if echo "$usage_section" | grep -q '```'; then
        # Extract code between ``` markers
        local in_block=false
        usage_example=""
        while IFS= read -r line; do
            if echo "$line" | grep -q '^```'; then
                if [ "$in_block" = false ]; then
                    in_block=true
                    continue
                else
                    break
                fi
            elif [ "$in_block" = true ]; then
                if [ -z "$usage_example" ]; then
                    usage_example="$line"
                else
                    usage_example="${usage_example}
${line}"
                fi
            fi
        done < <(printf '%s\n' "$usage_section")
    fi
    
    # Extract EXPLANATION section
    local explanation=$(echo "$content" | sed -n '/^EXPLANATION:/,/^COMMON_USE_CASES:/p' | sed '1d;$d' | grep -v "^COMMON_USE_CASES:" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract COMMON_USE_CASES section
    local use_cases=$(echo "$content" | sed -n '/^COMMON_USE_CASES:/,$p' | sed '1d' | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//' | head -n 5)
    
    # Return structured format (same as parse_ai_usage_response)
    echo "DESCRIPTION:${description}"
    if [ -n "$features" ]; then
        echo "$features" | while IFS= read -r line; do
            if [ -n "$line" ] && ! echo "$line" | grep -qE "^\[|^Feature [0-9]+:"; then
                if [[ ! "$line" =~ ^- ]]; then
                    line="- ${line}"
                fi
                echo "FEATURE:${line}"
            fi
        done
    fi
    echo "USAGE_EXAMPLE:${usage_example}"
    echo "EXPLANATION:${explanation}"
    if [ -n "$use_cases" ]; then
        echo "$use_cases" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                echo "USE_CASE:${line}"
            fi
        done
    fi
}

# Check if generate_readme.sh exists
if [ ! -f "scripts/generate_readme.sh" ]; then
    log_error "generate_readme.sh not found. Please run this script from the project root."
    exit 1
fi

# Set environment variables to use Cursor-generated content
export AI_ENABLED=true
export AI_PROVIDER="cursor-manual"  # Special provider for manual integration
export CURSOR_MANUAL_CONTENT="$CURSOR_CONTENT"

# Parse Cursor content
log_info "Parsing Cursor-generated content..."
PARSED_CONTENT=$(parse_cursor_content "$CURSOR_CONTENT")

# Extract components
DESCRIPTION=$(echo "$PARSED_CONTENT" | grep "^DESCRIPTION:" | sed 's/^DESCRIPTION://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
FEATURES=$(echo "$PARSED_CONTENT" | grep "^FEATURE:" | sed 's/^FEATURE://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
USAGE_EXAMPLE=$(echo "$PARSED_CONTENT" | sed -n '/^USAGE_EXAMPLE:/,/^EXPLANATION:/p' | sed '1s/^USAGE_EXAMPLE://' | sed '$d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPLANATION=$(echo "$PARSED_CONTENT" | grep "^EXPLANATION:" | sed 's/^EXPLANATION://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
USE_CASES=$(echo "$PARSED_CONTENT" | grep "^USE_CASE:" | sed 's/^USE_CASE://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

log_info "Extracted:"
log_info "  Description: $(echo "$DESCRIPTION" | cut -c1-60)..."
log_info "  Features: $(echo "$FEATURES" | wc -l) items"
log_info "  Usage example: $(if [ -n "$USAGE_EXAMPLE" ]; then echo "$USAGE_EXAMPLE" | head -n1 | cut -c1-40; else echo "none"; fi)..."

# Export parsed content for use by generate_readme.sh
export CURSOR_AI_DESCRIPTION="$DESCRIPTION"
export CURSOR_AI_FEATURES="$FEATURES"
export CURSOR_AI_USAGE_EXAMPLE="$USAGE_EXAMPLE"
export CURSOR_AI_EXPLANATION="$EXPLANATION"
export CURSOR_AI_USE_CASES="$USE_CASES"

# Temporarily modify generate_readme.sh to use manual content
# Instead, we'll create a wrapper that injects the content
log_info "Generating README with Cursor-generated content..."

# Create a temporary script that uses the parsed content
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
# Temporary script to inject Cursor-generated content into README generation

# Source the actual generate_readme.sh
source scripts/generate_readme.sh

# Override ai_analyze_repo to return Cursor-generated content
ai_analyze_repo() {
    local owner="$1"
    local repo="$2"
    local description="$3"
    local language="$4"
    local topics="$5"
    local languages="$6"
    
    # Return Cursor-generated content in the expected format
    echo "DESCRIPTION:${CURSOR_AI_DESCRIPTION}"
    if [ -n "${CURSOR_AI_FEATURES}" ]; then
        echo "$CURSOR_AI_FEATURES" | while IFS= read -r line; do
            echo "FEATURE:${line}"
        done
    fi
    echo "USE_CASE:${CURSOR_AI_EXPLANATION:-Use case extracted from Cursor IDE AI-generated content.}"
}

# Override ai_generate_usage to return Cursor-generated usage
ai_generate_usage() {
    local owner="$1"
    local repo="$2"
    local language="$3"
    local example_files="$4"
    
    echo "USAGE_EXAMPLE:${CURSOR_AI_USAGE_EXAMPLE}"
    echo "EXPLANATION:${CURSOR_AI_EXPLANATION}"
    if [ -n "${CURSOR_AI_USE_CASES}" ]; then
        echo "$CURSOR_AI_USE_CASES" | while IFS= read -r line; do
            echo "COMMON_USE_CASES:${line}"
        done
    fi
}

# Now call the main function from generate_readme.sh
main "$@"
SCRIPT_EOF

chmod +x "$TEMP_SCRIPT"

# Actually, a simpler approach: modify the environment and call generate_readme.sh directly
# But we need to patch the functions. Let me use a different approach:

# Use generate_readme.sh but with environment variables that will be used
# We'll need to modify generate_readme.sh to check for CURSOR_MANUAL_* variables

log_info "Calling generate_readme.sh with Cursor-generated content..."

# For now, let's create a simpler integration: manually merge the content
# Call generate_readme.sh to get the base README structure
BASE_README=$(bash scripts/generate_readme.sh "$OWNER" "$REPO" 2>&1)

# Extract sections from base README and replace with Cursor content
# This is complex, so let's use a simpler approach:

log_warning "Direct integration requires modifying generate_readme.sh"
log_info "Alternative approach: Generating README template, then you can manually merge Cursor content"
log_info ""

# Generate base README without AI
log_info "Generating base README structure..."
AI_ENABLED=false bash scripts/generate_readme.sh "$OWNER" "$REPO" > "${OUTPUT_FILE}.base" 2>/dev/null

log_info "Cursor-generated content parsed successfully!"
log_info ""
log_info "Next steps:"
log_info "  1. Review the parsed content above"
log_info "  2. Open ${OUTPUT_FILE}.base"
log_info "  3. Replace the template sections with Cursor-generated content:"
log_info "     - Replace Overview section with: ${DESCRIPTION:0:60}..."
log_info "     - Replace Features section with the extracted features"
log_info "     - Add Usage section with the extracted code example"
log_info ""
log_info "Or use the parsed content directly by modifying generate_readme.sh"
log_info "to check for CURSOR_MANUAL_* environment variables."

# Save parsed content to a file for easy reference
PARSED_FILE="${OUTPUT_FILE}.parsed"
echo "# Parsed Cursor AI Content" > "$PARSED_FILE"
echo "" >> "$PARSED_FILE"
echo "## Description" >> "$PARSED_FILE"
echo "$DESCRIPTION" >> "$PARSED_FILE"
echo "" >> "$PARSED_FILE"
echo "## Features" >> "$PARSED_FILE"
echo "$FEATURES" >> "$PARSED_FILE"
echo "" >> "$PARSED_FILE"
echo "## Usage Example" >> "$PARSED_FILE"
echo '```python' >> "$PARSED_FILE"
echo "$USAGE_EXAMPLE" >> "$PARSED_FILE"
echo '```' >> "$PARSED_FILE"
echo "" >> "$PARSED_FILE"
echo "## Explanation" >> "$PARSED_FILE"
echo "$EXPLANATION" >> "$PARSED_FILE"
echo "" >> "$PARSED_FILE"
echo "## Common Use Cases" >> "$PARSED_FILE"
echo "$USE_CASES" >> "$PARSED_FILE"

log_success "Parsed content saved to: ${PARSED_FILE}"
log_success "Base README saved to: ${OUTPUT_FILE}.base"
log_success ""
log_success "You can now:"
log_success "  1. Copy content from ${PARSED_FILE}"
log_success "  2. Paste into ${OUTPUT_FILE}.base"
log_success "  3. Save as ${OUTPUT_FILE}"

# Clean up
rm -f "$TEMP_SCRIPT"

exit 0
