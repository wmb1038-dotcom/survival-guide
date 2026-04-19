#!/bin/bash

# Configuration
EXTERNAL_PATH="/Volumes/20TB_HDD/offline-library"
PROJECT_LIB_PATH="$(pwd)/Library"
MANIFEST_FILE="$(pwd)/MANIFEST.md"

echo "📂 Initializing Survival Library Setup..."

# 1. Create Symlink
if [ -d "$EXTERNAL_PATH" ]; then
    echo "✅ External drive detected at $EXTERNAL_PATH"
    
    # Remove existing symlink or folder if it exists
    if [ -L "$PROJECT_LIB_PATH" ] || [ -e "$PROJECT_LIB_PATH" ]; then
        rm -rf "$PROJECT_LIB_PATH"
    fi
    
    ln -s "$EXTERNAL_PATH" "$PROJECT_LIB_PATH"
    echo "🔗 Symlink created: $PROJECT_LIB_PATH -> $EXTERNAL_PATH"
else
    echo "⚠️ Warning: External drive not found at $EXTERNAL_PATH."
    echo "   Symlink will be broken until the drive is plugged in."
    ln -s "$EXTERNAL_PATH" "$PROJECT_LIB_PATH"
fi

# 2. Generate Manifest for Offline Browsing
echo "📝 Generating Offline Manifest (Directories Only)..."

echo "# Survival Library Manifest" > "$MANIFEST_FILE"
echo "Generated on: $(date)" >> "$MANIFEST_FILE"
echo "Source: $EXTERNAL_PATH" >> "$MANIFEST_FILE"
echo "" >> "$MANIFEST_FILE"
echo "---" >> "$MANIFEST_FILE"
echo "" >> "$MANIFEST_FILE"

if [ -d "$EXTERNAL_PATH" ]; then
    # Find all directories, strip the base path, and format as a tree/list
    find "$EXTERNAL_PATH" -type d | sed "s|$EXTERNAL_PATH||" | sort >> "$MANIFEST_FILE"
    echo "✅ Manifest generated: $MANIFEST_FILE"
else
    echo "❌ Cannot generate manifest: Drive is not plugged in."
    echo "   Please plug in the drive and run this script again to update the manifest." >> "$MANIFEST_FILE"
fi

echo "🚀 Setup complete."
