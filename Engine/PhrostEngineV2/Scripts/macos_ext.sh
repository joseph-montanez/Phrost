#!/usr/bin/env bash

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")

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

# --- Add this section to print paths ---
echo "========================================="
echo "Checking paths from: $(pwd)"
echo "========================================="

echo "SDL3_INCLUDE"
echo "  Literal: $SDL3_INCLUDE"
echo "  Real:    $(realpath "$SDL3_INCLUDE")"
echo

echo "SDL3_LIB"
echo "  Literal: $SDL3_LIB"
echo "  Real:    $(realpath "$SDL3_LIB")"
echo

echo "SDL3_IMAGE_INCLUDE"
echo "  Literal: $SDL3_IMAGE_INCLUDE"
echo "  Real:    $(realpath "$SDL3_IMAGE_INCLUDE")"
echo

echo "SDL3_IMAGE_LIB"
echo "  Literal: $SDL3_IMAGE_LIB"
echo "  Real:    $(realpath "$SDL3_IMAGE_LIB")"
echo

echo "SDL3_MIXER_INCLUDE"
echo "  Literal: $SDL3_MIXER_INCLUDE"
echo "  Real:    $(realpath "$SDL3_MIXER_INCLUDE")"
echo

echo "SDL3_MIXER_LIB"
echo "  Literal: $SDL3_MIXER_LIB"
echo "  Real:    $(realpath "$SDL3_MIXER_LIB")"
echo

echo "SDL3_TTF_INCLUDE"
echo "  Literal: $SDL3_TTF_INCLUDE"
echo "  Real:    $(realpath "$SDL3_TTF_INCLUDE")"
echo

echo "SDL3_TTF_LIB"
echo "  Literal: $SDL3_TTF_LIB"
echo "  Real:    $(realpath "$SDL3_TTF_LIB")"
echo
echo "========================================="
echo "Continuing with build..."
# -------------------------------------------

swift build -vv \
    --configuration release \
    -Xcc -U__SSE2__ \
    -Xcc -I$PHP_SRC_ROOT \
    -Xcc -I$PHP_SRC_ROOT/main \
    -Xcc -I$PHP_SRC_ROOT/Zend \
    -Xcc -I$PHP_SRC_ROOT/TSRM \
    -Xcc -I${SDL3_INCLUDE} \
    -Xcc -I${SDL3_TTF_INCLUDE} \
    -Xcc -I${SDL3_MIXER_INCLUDE} \
    -Xcc -I${SDL3_IMAGE_INCLUDE}

export PHROST_RELEASE_DIR=$SCRIPT_DIR/../../../Release
export PHROST_RUNTIME_DIR=$SCRIPT_DIR/../../../Runtime
export PHROST_ASSETS_DIR="$PHROST_RELEASE_DIR/assets"

# Create the release
mkdir -p $PHROST_RELEASE_DIR
mkdir -p $PHROST_RELEASE_DIR/runtime

# Copy static PHP
cp $PHP_BIN $PHROST_RELEASE_DIR/runtime/

# Setup PHP Composer
$PHROST_RELEASE_DIR/runtime/php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
$PHROST_RELEASE_DIR/runtime/php -r "if (hash_file('sha384', 'composer-setup.php') === 'c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
$PHROST_RELEASE_DIR/runtime/php composer-setup.php
$PHROST_RELEASE_DIR/runtime/php -r "unlink('composer-setup.php');"

# Copy Phrost runtime
cp $SCRIPT_DIR/../.build/release/PhrostBinary $PHROST_RELEASE_DIR/
cp $SCRIPT_DIR/../.build/release/PhrostIPC $PHROST_RELEASE_DIR/

# --- NEW: Copy the settings.json file ---
echo "-> Copying runtime configuration..."
cp "$PHROST_RUNTIME_DIR/php/settings.json" "$PHROST_RELEASE_DIR/settings.json"

# Check if the assets directory does NOT exist
if [ ! -d "$PHROST_ASSETS_DIR" ]; then
	echo "-> Assets directory not found. Creating and copying from runtime..."

    # 1. Create the directory with sample files
	cp -Ra $PHROST_RUNTIME_DIR/assets $PHROST_RELEASE_DIR/

    # 2. Copy the *contents* of the php directory into the new assets directory
    # Using /." is a safe and robust way to copy all files and folders
    # (including hidden ones) from inside the 'php' dir.
	cp -r "$PHROST_RUNTIME_DIR/php/." "$PHROST_ASSETS_DIR/"

	echo "-> Assets copied."
else
	echo "-> Assets directory already exists. Skipping."
fi

# && php84 -dmemory_limit=-1 -dextension=/Users/josephmontanez/Documents/dev/Phrost2/Engine/PhrostEngineV2/.build/arm64-apple-macosx/release/libPhrostEngine.dylib assets/main.php

# Install runtime packages
mv $SCRIPT_DIR/../composer.phar $PHROST_ASSETS_DIR/src/
cd $PHROST_RELEASE_DIR/assets/src
ls -la
$PHROST_RELEASE_DIR/runtime/php composer.phar install
cd $SCRIPT_DIR/..
