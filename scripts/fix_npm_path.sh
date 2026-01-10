#!/bin/bash
# Fix npm PATH to use nvm's npm instead of system npm

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm use 18

# Get the correct npm path
NVM_NPM=$(which npm 2>/dev/null || echo "$NVM_DIR/versions/node/$(node -v)/bin/npm")

# Update PATH in bashrc
if [ -f "$HOME/.bashrc" ]; then
    # Remove old PATH modifications if any
    sed -i '/# NVM PATH/d' "$HOME/.bashrc"
    sed -i '/export PATH.*nvm/d' "$HOME/.bashrc"
    
    # Add correct PATH
    if ! grep -q "NVM_DIR.*nvm.sh" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm use 18 2>/dev/null || true
EOF
    fi
fi

echo "✓ PATH updated. Restart your terminal or run: source ~/.bashrc"
