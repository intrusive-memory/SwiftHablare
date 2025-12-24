#!/bin/bash

# Install git hooks for SwiftHablare development
# This configures git to use the hooks in .githooks/ directory

set -e

echo "📦 Installing SwiftHablare git hooks..."
echo ""

# Configure git to use .githooks directory
git config core.hooksPath .githooks

echo "✅ Git hooks installed successfully!"
echo ""
echo "📋 Active hooks:"
echo "   - pre-commit: Runs local audio tests (LocalAudioTests.xctestplan)"
echo ""
echo "💡 To bypass the pre-commit hook (not recommended):"
echo "   git commit --no-verify"
echo ""
echo "💡 To uninstall hooks:"
echo "   git config --unset core.hooksPath"
echo ""
