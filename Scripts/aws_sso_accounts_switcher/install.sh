#!/bin/bash
# install.sh - Quick setup script for AWS SSO Account Switcher

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$HOME/bin}"

echo "Installing AWS SSO Account Switcher..."

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy the main script
cp "$SCRIPT_DIR/aws_sso_switcher.sh" "$TARGET_DIR/"
chmod +x "$TARGET_DIR/aws_sso_switcher.sh"

# Copy the template
cp "$SCRIPT_DIR/aws_accounts.conf.template" "$TARGET_DIR/"

echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "1. Copy the template: cp '$TARGET_DIR/aws_accounts.conf.template' '$TARGET_DIR/aws_accounts.conf'"
echo "2. Edit the config: vim '$TARGET_DIR/aws_accounts.conf'"
echo "3. Add to your shell profile:"
echo "   echo 'alias sso=\"source $TARGET_DIR/aws_sso_switcher.sh\"' >> ~/.zshrc"
echo "4. Reload your shell: source ~/.zshrc"
echo ""
echo "Then run: sso"