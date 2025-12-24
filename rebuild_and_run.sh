#!/bin/bash

# Script to kill, rebuild, and run BrainDump

set -e

PROJECT_DIR="/Users/shreyansh/BrainDump"
SCHEME="BrainDump"

echo "🔴 Killing any running BrainDump instances..."
killall -9 BrainDump 2>/dev/null || echo "No running instances found"

echo ""
echo "🧹 Cleaning build folder..."
cd "$PROJECT_DIR"
xcodebuild clean -project BrainDump.xcodeproj -scheme "$SCHEME" -configuration Debug

echo ""
echo "🔨 Building BrainDump..."
xcodebuild build -project BrainDump.xcodeproj -scheme "$SCHEME" -configuration Debug

echo ""
echo "🚀 Launching BrainDump..."
# Find the built app and open it
BUILD_DIR=$(xcodebuild -project BrainDump.xcodeproj -scheme "$SCHEME" -configuration Debug -showBuildSettings 2>/dev/null | grep -m 1 "BUILT_PRODUCTS_DIR" | sed 's/.*= *//')
APP_PATH="$BUILD_DIR/BrainDump.app"

if [ -d "$APP_PATH" ]; then
    open "$APP_PATH"
    echo "✅ BrainDump launched successfully!"
else
    echo "❌ Could not find built app at: $APP_PATH"
    echo "Trying alternative method..."
    open -a BrainDump
fi

echo ""
echo "✨ Done! Check the app menu bar for the BrainDump icon."


