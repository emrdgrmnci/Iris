#!/bin/bash

# Clean script for Iris.app
# Removes all build artifacts

set -e  # Exit on error

echo "🧹 Cleaning build artifacts..."

# Check if project exists
if [ ! -d "Iris/Iris.xcodeproj" ]; then
    echo "⚠️  Warning: Iris.xcodeproj not found"
    echo "Nothing to clean"
    exit 0
fi

# Navigate to project directory
cd Iris

# Clean using xcodebuild
if command -v xcodebuild &> /dev/null; then
    echo "Cleaning with xcodebuild..."
    xcodebuild \
        -project Iris.xcodeproj \
        -scheme Iris \
        -configuration Release \
        clean
fi

# Remove build directory
if [ -d "build" ]; then
    echo "Removing build directory..."
    rm -rf build/
fi

# Remove DerivedData (if it exists in project)
if [ -d "DerivedData" ]; then
    echo "Removing DerivedData..."
    rm -rf DerivedData/
fi

echo "✅ Clean complete!"
