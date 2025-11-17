#!/bin/bash
#
# Phrost Engine - Unsigned Package Script
#
# This script does the following:
# 1.  Builds the Swift executables.
# 2.  Packages them into a styled, compressed DMG with a custom icon and background.
#
# This script does NOT sign or notarize the DMG.
# Your users will need to manually grant permission in
# "System Settings > Privacy & Security" to run the executables.
#
# REQUIREMENTS:
# - Place this script in your project's root directory.
# - In the same directory, you MUST have:
#   1. dmg_background.png (Your DMG's background image)
#   2. PhrostVolume.icns (Your custom .icns file for the DMG volume)

# Stop the script immediately if any command fails
set -eo pipefail

# --- 1. CONFIGURATION (Edit these variables) ---
echo_blue() { echo -e "\033[1;34m$1\033[0m"; }
echo_green() { echo -e "\033[1;32m$1\033[0m"; }
echo_red() { echo -e "\033[1;31m$1\033[0m"; }

# --- Build Paths & Environment ---
# (Using your provided paths)
export SDL3_INCLUDE="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL/include"
export SDL3_LIB="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL/build/Release"
export SDL3_IMAGE_INCLUDE="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_image/include"
export SDL3_IMAGE_LIB="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_image/build/Release"
export SDL3_MIXER_INCLUDE="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_mixer/include"
export SDL3_MIXER_LIB="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_mixer/build/Release"
export SDL3_TTF_INCLUDE="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_ttf/include"
export SDL3_TTF_LIB="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_ttf/build/Release"
export CLIENT_TYPE=php
export PHP_SRC_ROOT="/Users/josephmontanez/Documents/dev/SwiftPHP/PHP.xcframework/ios-arm64/Headers"

# --- Binaries & Assets ---
BUILD_CONFIG="release"
BUILD_ARCH="arm64-apple-macosx"
BUILD_DIR=".build/$BUILD_ARCH/$BUILD_CONFIG"

BINARY_NAME="PhrostBinary"
IPC_BINARY_NAME="PhrostIPC"

BINARY_PATH="$BUILD_DIR/$BINARY_NAME"
IPC_BINARY_PATH="$BUILD_DIR/$IPC_BINARY_NAME"

DMG_BACKGROUND_IMG="dmg_background.png"
DMG_ICON_FILE="PhrostVolume.icns"

# --- DMG Configuration ---
VOL_NAME="Phrost Engine"
FINAL_DMG_NAME="PhrostEngine-unsigned.dmg"
TEMP_DMG="PhrostEngine_temp.dmg"
STAGING_DIR="dmg_staging"


# --- 2. PRE-FLIGHT CHECKS ---
echo_blue "--- 2. Running Pre-flight Checks ---"
if [ ! -f "$DMG_BACKGROUND_IMG" ]; then echo_red "Missing background image: $DMG_BACKGROUND_IMG"; exit 1; fi
if [ ! -f "$DMG_ICON_FILE" ]; then echo_red "Missing volume icon: $DMG_ICON_FILE"; exit 1; fi
echo_green "All assets found."

# --- 3. BUILD BINARIES ---
echo_blue "--- 3. Building Binaries (using your command) ---"
# Using the exact build command from your history
swift build -vv \
    --configuration $BUILD_CONFIG \
    -Xcc -U__SSE2__ \
    -Xcc -I$PHP_SRC_ROOT \
    -Xcc -I$PHP_SRC_ROOT/main \
    -Xcc -I$PHP_SRC_ROOT/Zend \
    -Xcc -I$PHP_SRC_ROOT/TSRM \
    -Xcc "-I${SDL3_INCLUDE}" \
    -Xcc "-I${SDL3_TTF_INCLUDE}" \
    -Xcc "-I${SDL3_MIXER_INCLUDE}" \
    -Xcc "-I${SDL3_IMAGE_INCLUDE}"

# Verify binaries were built
if [ ! -f "$BINARY_PATH" ]; then echo_red "Build failed. Missing binary: $BINARY_PATH"; exit 1; fi
if [ ! -f "$IPC_BINARY_PATH" ]; then echo_red "Build failed. Missing binary: $IPC_BINARY_PATH"; exit 1; fi
echo_green "Build complete."

# --- 4. CREATE STAGING DIRECTORY ---
echo_blue "--- 4. Creating Staging Directory ---"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy binaries
cp "$BINARY_PATH" "$STAGING_DIR/"
cp "$IPC_BINARY_PATH" "$STAGING_DIR/"

# Add Applications symlink
ln -s /Applications "$STAGING_DIR/Applications"

# Add background image
mkdir "$STAGING_DIR/.background"
cp "$DMG_BACKGROUND_IMG" "$STAGING_DIR/.background/"

# Add volume icon
# The .VolumeIcon.icns is a special hidden file Finder looks for.
cp "$DMG_ICON_FILE" "$STAGING_DIR/.VolumeIcon.icns"

echo_green "Staging directory is ready."

# --- 5. CREATE TEMPORARY WRITABLE DMG ---
echo_blue "--- 5. Creating Temporary Writable DMG ---"
rm -f "$TEMP_DMG"
hdiutil create \
    -format UDRW \
    -fs HFS+ \
    -srcfolder "$STAGING_DIR" \
    -volname "$VOL_NAME" \
    "$TEMP_DMG"
echo_green "Temporary DMG created."

# --- 6. STYLE THE DMG ---
echo_blue "--- 6. Styling DMG (requires Finder) ---"
MOUNT_POINT="/Volumes/$VOL_NAME"
hdiutil attach "$TEMP_DMG" -readwrite -noverify -mountpoint "$MOUNT_POINT"

# Run AppleScript to style the Finder window
osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open

    -- Set window properties
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {400, 100, 1040, 580} -- {left, top, right, bottom}

    -- Set view options
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96

    -- Set background image
    set background picture of theViewOptions to file ".background:$DMG_BACKGROUND_IMG"

    -- Position the items
    set position of item "$BINARY_NAME" to {180, 240}
    set position of item "$IPC_BINARY_NAME" to {330, 240}
s    set position of item "Applications" to {500, 240}

    -- Hide asset folders
    set visible of file ".background" to false
    set visible of file ".VolumeIcon.icns" to false

    -- Update, close, and re-open to apply changes
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

# Unmount the DMG
hdiutil detach "$MOUNT_POINT"
echo_green "DMG styling applied."

# --- 7. CONVERT TO FINAL COMPRESSED DMG ---
echo_blue "--- 7. Converting to Final Compressed DMG ---"
rm -f "$FINAL_DMG_NAME"
hdiutil convert \
    "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG_NAME"
echo_green "Final DMG created: $FINAL_DMG_NAME"

# --- 8. CLEANUP ---
echo_blue "--- 8. Cleaning Up ---"
rm -rf "$STAGING_DIR"
rm -f "$TEMP_DMG"
echo_green "Removed temporary files."

echo_green "\n🎉 SUCCESS! 🎉"
echo_green "Your distribution DMG is ready: $FINAL_DMG_NAME"
echo_green "\nIMPORTANT: This DMG is NOT signed or notarized."
echo_green "Tell your users they must right-click the binary and select 'Open' to run it."
