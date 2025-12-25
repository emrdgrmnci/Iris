#!/bin/bash

# Run script for Iris.app
# Builds (if needed) and launches the application

set -e  # Exit on error

echo "🚀 Launching Iris.app..."

# Build first
./build.sh

# Find the built app (check both possible locations)
APP_PATH=""
if [ -d "Iris/build/Release/Iris.app" ]; then
    APP_PATH="Iris/build/Release/Iris.app"
else
    # Check DerivedData location
    DERIVED_DATA_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Iris.app" -path "*/Release/*" 2>/dev/null | head -1)
    if [ -n "$DERIVED_DATA_APP" ]; then
        APP_PATH="$DERIVED_DATA_APP"
    fi
fi

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Build failed or app not found"
    exit 1
fi

# Launch the app
echo "Opening Iris.app from $APP_PATH..."
open "$APP_PATH"

echo "✅ Iris.app launched!"
echo ""
echo "Look for the Iris icon in your menu bar (top right)"
echo "Click the icon to toggle the window visibility"
echo ""
echo "To quit: Click the menu bar icon and select 'Quit Iris'"
