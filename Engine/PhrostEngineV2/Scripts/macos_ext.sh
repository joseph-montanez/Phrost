#!/usr/bin/env bash

# Stop script on error
set -e

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")

# export CHIPMUNK2D__INCLUDE="$SCRIPT_DIR/../../deps/SDL/include"
# export CHIPMUNK2D__LIB="$SCRIPT_DIR/../../deps/SDL/build/Release"

export SDL3_INCLUDE="$SCRIPT_DIR/../../deps/SDL/include"
export SDL3_LIB="$SCRIPT_DIR/../../deps/SDL/build/Release"

export SDL3_IMAGE_INCLUDE="$SCRIPT_DIR/../../deps/SDL_image/include"
export SDL3_IMAGE_LIB="$SCRIPT_DIR/../../deps/SDL_image/build/Release"

export SDL3_MIXER_INCLUDE="$SCRIPT_DIR/../../deps/SDL_mixer/include"
export SDL3_MIXER_LIB="$SCRIPT_DIR/../../deps/SDL_mixer/build/Release"

export SDL3_TTF_INCLUDE="$SCRIPT_DIR/../../deps/SDL_ttf/include"
export SDL3_TTF_LIB="$SCRIPT_DIR/../../deps/SDL_ttf/build/Release"

export PHP_SRC_ROOT="$SCRIPT_DIR/../../deps/buildroot/include/php"
export PHP_BIN="$SCRIPT_DIR/../../deps/buildroot/bin/php"

export CLIENT_TYPE=php

# --- Debug Paths ---
echo "========================================="
echo "Checking paths from: $(pwd)"
echo "========================================="
echo "SDL3_INCLUDE:    $(realpath "$SDL3_INCLUDE")"
echo "SDL3_LIB:        $(realpath "$SDL3_LIB")"
echo "========================================="
echo "Continuing with build..."

# --- Swift Build ---
swift build --configuration release \
    -Xcc -U__SSE2__ \
    -Xcc -I$PHP_SRC_ROOT \
    -Xcc -I$PHP_SRC_ROOT/main \
    -Xcc -I$PHP_SRC_ROOT/Zend \
    -Xcc -I$PHP_SRC_ROOT/TSRM \
    -Xcc -I${SDL3_INCLUDE} \
    -Xcc -I${SDL3_TTF_INCLUDE} \
    -Xcc -I${SDL3_MIXER_INCLUDE} \
    -Xcc -I${SDL3_IMAGE_INCLUDE}

# --- Define Output Paths ---
# Matches Windows structure
export PHROST_RELEASE_DIR="$SCRIPT_DIR/../../../Release"
export PHROST_ENGINE_DIR="$PHROST_RELEASE_DIR/engine"
export PHROST_GAME_DIR="$PHROST_RELEASE_DIR/game"
export PHROST_RUNTIME_DIR="$SCRIPT_DIR/../../../Runtime"

echo "Release Dir: $PHROST_RELEASE_DIR"
echo "Engine Dir:  $PHROST_ENGINE_DIR"
echo "Game Dir:    $PHROST_GAME_DIR"

# --- Create Directories ---
mkdir -p "$PHROST_RELEASE_DIR"
mkdir -p "$PHROST_RELEASE_DIR/runtime"
mkdir -p "$PHROST_ENGINE_DIR"
mkdir -p "$PHROST_GAME_DIR"

# --- Copy PHP Runtime ---
echo "-> Copying PHP binary..."
cp "$PHP_BIN" "$PHROST_RELEASE_DIR/runtime/"

# --- Setup PHP Composer ---
echo "-> Setting up Composer..."
"$PHROST_RELEASE_DIR/runtime/php" -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
"$PHROST_RELEASE_DIR/runtime/php" -r "if (hash_file('sha384', 'composer-setup.php') === 'c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
"$PHROST_RELEASE_DIR/runtime/php" composer-setup.php
"$PHROST_RELEASE_DIR/runtime/php" -r "unlink('composer-setup.php');"

# --- Copy Phrost Binaries ---
echo "-> Copying Engine binaries..."

# 1. Phrost Main Executable (Goes to Root)
# FIX: The source file is named 'Phrost' (Product Name), not 'PhrostBinary' (Target Name)
if [ -f "$SCRIPT_DIR/../.build/release/Phrost" ]; then
    cp "$SCRIPT_DIR/../.build/release/Phrost" "$PHROST_RELEASE_DIR/Phrost"
else
    echo "ERROR: Phrost binary not found at $SCRIPT_DIR/../.build/release/Phrost"
    exit 1
fi

# 2. PhrostIPC (Goes to Engine folder)
if [ -f "$SCRIPT_DIR/../.build/release/PhrostIPC" ]; then
    cp "$SCRIPT_DIR/../.build/release/PhrostIPC" "$PHROST_ENGINE_DIR/"
else
    echo "ERROR: PhrostIPC binary not found at $SCRIPT_DIR/../.build/release/PhrostIPC"
    exit 1
fi

# --- Copy Settings ---
echo "-> Copying runtime configuration..."
# Windows script moves settings.json to root
if [ -f "$PHROST_RUNTIME_DIR/php/settings.json" ]; then
    cp "$PHROST_RUNTIME_DIR/php/settings.json" "$PHROST_RELEASE_DIR/settings.json"
fi

# --- Copy Assets & PHP Files ---
echo "-> Building Game Directory..."

# 1. Copy 'assets' folder into 'game' (creates game/assets)
if [ -d "$PHROST_RUNTIME_DIR/assets" ]; then
    cp -Ra "$PHROST_RUNTIME_DIR/assets" "$PHROST_GAME_DIR/"
fi

# 2. Copy contents of 'php' folder into 'game' root
# This matches Windows: Join-Path $PHROST_RUNTIME_DIR "php\*"
if [ -d "$PHROST_RUNTIME_DIR/php" ]; then
    cp -R "$PHROST_RUNTIME_DIR/php/." "$PHROST_GAME_DIR/"
fi

echo "-> Assets and PHP scripts copied to $PHROST_GAME_DIR"

# --- Install Composer Packages ---
echo "-> Installing Composer dependencies..."

# Move composer.phar to the game directory (where composer.json should be now)
if [ -f "composer.phar" ]; then
    mv "composer.phar" "$PHROST_GAME_DIR/"
fi

# Switch to game dir to run install
pushd "$PHROST_GAME_DIR" > /dev/null
    ../runtime/php composer.phar install
popd > /dev/null

echo "### Build and Deployment Complete ###"
