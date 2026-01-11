#!/bin/bash

# Script to sort repos_to_fork.txt by stars (highest first)
# Handles both old format (5 fields) and new format (13 fields)

INPUT_FILE="repos_to_fork.txt"
OUTPUT_FILE="repos_to_fork.txt"
TEMP_FILE="${OUTPUT_FILE}.sorted"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

if [ ! -f "$INPUT_FILE" ]; then
    print_warn "File $INPUT_FILE not found!"
    exit 1
fi

# Check if file has header row
first_line=$(head -n 1 "$INPUT_FILE")
has_header=false

if echo "$first_line" | grep -q "full_name"; then
    has_header=true
    print_info "Detected header row, will preserve it"
fi

# Count fields to determine format
field_count=$(echo "$first_line" | awk -F'|' '{print NF}')

if [ "$has_header" = "true" ]; then
    # New format (13 fields) - stars is field 3
    stars_field=3
    print_info "Detected new format (13 fields), sorting by field $stars_field (stars)"
    
    # Extract header and sort the rest
    {
        echo "$first_line"
        tail -n +2 "$INPUT_FILE" | awk -F'|' 'BEGIN{OFS=FS} {
            # Normalize stars field for sorting
            if ($3 == "" || $3 == "N/A" || $3 == "No description") $3 = "0"
            # Extract numeric value (remove any non-numeric characters)
            gsub(/[^0-9]/, "", $3)
            if ($3 == "") $3 = "0"
            print
        }' | sort -t'|' -k${stars_field} -rn
    } > "$TEMP_FILE"
    
elif [ "$field_count" -eq 5 ]; then
    # Old format (5 fields): full_name|description|stars|default_branch|has_readme
    stars_field=3
    print_info "Detected old format (5 fields), sorting by field $stars_field (stars)"
    
    awk -F'|' 'BEGIN{OFS=FS} {
        # Normalize stars field for sorting
        if ($3 == "" || $3 == "N/A" || $3 == "No description") $3 = "0"
        # Extract numeric value (remove any non-numeric characters)
        gsub(/[^0-9]/, "", $3)
        if ($3 == "") $3 = "0"
        print
    }' "$INPUT_FILE" | sort -t'|' -k${stars_field} -rn > "$TEMP_FILE"
    
else
    print_warn "Unknown format detected ($field_count fields). Attempting to sort by field 3..."
    
    awk -F'|' 'BEGIN{OFS=FS} {
        # Normalize stars field for sorting
        if ($3 == "" || $3 == "N/A") $3 = "0"
        # Extract numeric value
        gsub(/[^0-9]/, "", $3)
        if ($3 == "") $3 = "0"
        print
    }' "$INPUT_FILE" | sort -t'|' -k3 -rn > "$TEMP_FILE"
fi

# Replace original file
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Show summary
total_lines=$(wc -l < "$OUTPUT_FILE" | tr -d '[:space:]')
if [ "$has_header" = "true" ]; then
    data_lines=$((total_lines - 1))
    print_info "Sorted $data_lines repositories (plus header row)"
    
    # Show top 10 by stars
    print_info "Top 10 repositories by stars:"
    tail -n +2 "$OUTPUT_FILE" | head -10 | while IFS='|' read -r repo desc stars rest; do
        echo "  - ${repo}: ${stars} stars"
    done
else
    print_info "Sorted $total_lines repositories"
    
    # Show top 10 by stars
    print_info "Top 10 repositories by stars:"
    head -10 "$OUTPUT_FILE" | while IFS='|' read -r repo desc stars rest; do
        echo "  - ${repo}: ${stars} stars"
    done
fi

print_info "File sorted successfully: $OUTPUT_FILE"
