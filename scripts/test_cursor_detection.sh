#!/bin/bash
# Quick test to verify Cursor IDE detection

echo "=== Testing Cursor IDE Detection ==="
echo ""

# Test the improved detection
cd "$(dirname "$0")/.." || exit 1

echo "1. Testing check_cursor_ide.sh:"
echo "-----------------------------------"
bash scripts/check_cursor_ide.sh 2>&1 | grep -A 3 "1. Checking" || echo "Check script not found"

echo ""
echo "2. Testing complete_setup.sh Cursor IDE check:"
echo "-----------------------------------"
bash scripts/complete_setup.sh 2>&1 | grep -A 5 "\[5/8" || echo "Setup script not found"

echo ""
echo "3. Direct process check:"
echo "-----------------------------------"
CURSOR_PROCESS=$(pgrep -f -i cursor 2>/dev/null | head -1 || echo "")
if [ -n "$CURSOR_PROCESS" ]; then
    echo "✓ Cursor IDE process found (PID: $CURSOR_PROCESS)"
    ps -p "$CURSOR_PROCESS" -o comm=,pid= 2>/dev/null | head -1
else
    echo "⚠ No Cursor IDE process found via pgrep"
fi

echo ""
echo "=== Detection Test Complete ==="
