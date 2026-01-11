#!/bin/bash
# Simple script to integrate Cursor IDE AI-generated content with README generation
# Usage: ./scripts/integrate_cursor_ai_simple.sh owner repo-name cursor-content.txt [output_file]

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

if [ $# -lt 3 ]; then
    log_error "Usage: $0 owner repo-name cursor-content.txt [output_file]"
    exit 1
fi

OWNER="$1"
REPO="$2"
CURSOR_FILE="$3"
OUTPUT="${4:-README.md}"

if [ ! -f "$CURSOR_FILE" ]; then
    log_error "File not found: $CURSOR_FILE"
    exit 1
fi

log_info "Integrating Cursor AI-generated content for ${OWNER}/${REPO}..."

# Parse Cursor content into structured format that generate_readme.sh expects
CURSOR_CONTENT=$(cat "$CURSOR_FILE")

# Extract sections
DESCRIPTION=$(echo "$CURSOR_CONTENT" | sed -n '/^DESCRIPTION:/,/^FEATURES:/p' | sed '1d;$d' | grep -v "^FEATURES:" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

FEATURES=$(echo "$CURSOR_CONTENT" | sed -n '/^FEATURES:/,/^USAGE_EXAMPLE:/p' | sed '1d;$d' | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//')

USAGE_SECTION=$(echo "$CURSOR_CONTENT" | sed -n '/^USAGE_EXAMPLE:/,/^EXPLANATION:/p' | sed '1d;$d')
USAGE_CODE=""
if echo "$USAGE_SECTION" | grep -q '```'; then
    USAGE_CODE=$(echo "$USAGE_SECTION" | sed -n '/```/,/```/p' | sed '1d;$d')
fi

EXPLANATION=$(echo "$CURSOR_CONTENT" | sed -n '/^EXPLANATION:/,/^COMMON_USE_CASES:/p' | sed '1d;$d' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

USE_CASES=$(echo "$CURSOR_CONTENT" | sed -n '/^COMMON_USE_CASES:/,$p' | sed '1d' | grep -E "^-|^[[:space:]]*-" | sed 's/^[[:space:]]*//' | head -n 5)

# Create a temporary AI response file in the format expected by generate_readme.sh
TEMP_AI_RESPONSE=$(mktemp)

cat > "$TEMP_AI_RESPONSE" << EOF
DESCRIPTION:
${DESCRIPTION}

FEATURES:
$(echo "$FEATURES" | sed 's/^[[:space:]]*/- /' | head -n 7)

USE_CASE:
This project is ideal for developers working on $(echo "$REPO" | sed 's/-verif//' | sed 's/core-v-//' | sed 's/-/ /g') verification and testbench development.
EOF

# Create temporary usage response file
TEMP_USAGE_RESPONSE=$(mktemp)

cat > "$TEMP_USAGE_RESPONSE" << EOF
USAGE_EXAMPLE:
\`\`\`python
${USAGE_CODE}
\`\`\`

EXPLANATION:
${EXPLANATION}

COMMON_USE_CASES:
${USE_CASES}
EOF

# Set environment variables to use Cursor content
export AI_ENABLED=true
export AI_PROVIDER="cursor-manual"
export CURSOR_MANUAL_DESCRIPTION="$DESCRIPTION"
export CURSOR_MANUAL_FEATURES="$FEATURES"
export CURSOR_MANUAL_USAGE="$USAGE_CODE"
export CURSOR_MANUAL_EXPLANATION="$EXPLANATION"
export CURSOR_MANUAL_USE_CASES="$USE_CASES"

# Modify generate_readme.sh functions temporarily by creating a wrapper
# Since we can't easily modify the script, let's create a simple merge approach
log_info "Generating README with Cursor-generated content..."

# Generate base README structure
log_info "Step 1: Generating base README structure (without AI)..."
BASE_README=$(AI_ENABLED=false bash scripts/generate_readme.sh "$OWNER" "$REPO" 2>/dev/null)

# Extract GitHub data sections we want to keep
REPO_NAME=$(echo "$REPO" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')

# Create final README by merging
log_info "Step 2: Merging Cursor-generated content..."

# For now, let's output the merged content
cat > "$OUTPUT" << EOF
# ${REPO_NAME}

$(echo "$BASE_README" | grep -A 20 "^![License]" | head -n 20)

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Overview

${DESCRIPTION}

$(echo "$BASE_README" | grep -A 1 "^This repository is part of" | head -n 2)

## Features

$(echo "$FEATURES" | sed 's/^[[:space:]]*/- /' | head -n 7)

$(echo "$BASE_README" | grep -A 10 "^## Requirements" | head -n 10)

## Installation

$(echo "$BASE_README" | grep -A 10 "^## Installation" | sed -n '2,$p' | head -n 10)

## Usage

### Basic Example

\`\`\`python
${USAGE_CODE}
\`\`\`

${EXPLANATION}

### Common Use Cases

$(echo "$USE_CASES" | sed 's/^[[:space:]]*/- /' | head -n 5)

$(echo "$BASE_README" | grep -A 50 "^## Project Structure" | head -n 50)

EOF

log_success "README generated: ${OUTPUT}"
log_info ""
log_info "Review the generated README and adjust as needed."
log_info "Cursor-generated content has been integrated into:"
log_info "  - Overview section"
log_info "  - Features section"
log_info "  - Usage section with code example"

# Cleanup
rm -f "$TEMP_AI_RESPONSE" "$TEMP_USAGE_RESPONSE"

exit 0
