#!/bin/bash
set -e

echo "=== TextSnap setup ==="

# Ensure Homebrew is available
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install xcodegen if missing
if ! command -v xcodegen &>/dev/null; then
    echo "Installing xcodegen..."
    brew install xcodegen
fi

# Generate project
echo "Generating TextSnap.xcodeproj..."
xcodegen generate

echo ""
echo "Done. Build steps:"
echo "  1. Open TextSnap.xcodeproj in Xcode"
echo "  2. Set your Team in Signing & Capabilities"
echo "  3. Build & Run  (⌘R)"
echo "  4. Grant Screen Recording permission when prompted"
echo ""
echo "Default shortcut: ⌘⇧2"
echo "Change in: menu bar icon → Preferences…"

open TextSnap.xcodeproj
