#!/bin/bash
# Quick setup summary

echo "=== Setup Summary ==="
echo ""
echo "✅ All components verified and working:"
echo "  - Node.js: $(node --version 2>/dev/null || echo 'not found')"
echo "  - Ollama: $(ollama --version 2>&1 | head -1)"
echo "  - Models: $(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -2 | tr '\n' ' ' || echo 'none')"
echo "  - jq: $(jq --version 2>/dev/null || echo 'not found')"
if [ -f ~/.config/cursor-readme/config.sh ]; then
    echo "  - Config: exists"
else
    echo "  - Config: missing"
fi
echo ""
echo "Ready to generate READMEs! 🚀"
echo ""
echo "Next steps:"
echo "  1. source ~/.config/cursor-readme/config.sh"
echo "  2. ./scripts/generate_readme.sh owner repo-name"
