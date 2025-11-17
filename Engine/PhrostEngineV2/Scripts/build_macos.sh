#!/usr/bin/env bash

set -eu

mkdir -p "build"

# Variables
PHP_VERSION="php-8.4.13"
BUILD_DIR="build/php-src"
XCFRAMEWORK_DIR="build/PHP.xcframework"
IOS_HEADERS_DIR="build/php-src-ios"
MACOS_HEADERS_DIR="build/php-src-macos"
IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
MACOS_SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

# Clone PHP if not already cloned, or reset if exists
if [ ! -d "$BUILD_DIR" ]; then
  echo "Cloning PHP $PHP_VERSION..."
  git clone https://github.com/php/php-src.git "$BUILD_DIR"
  pushd "$BUILD_DIR"
  git checkout "tags/$PHP_VERSION" --force
  popd
else
  echo "Resetting PHP source directory to original state..."
  pushd "$BUILD_DIR"
  git fetch --all --tags
  git reset --hard "tags/$PHP_VERSION"
  popd
fi

pushd "$BUILD_DIR"



# Run buildconf
echo "Running buildconf..."
./buildconf --force

# Check if bison is installed, and install it if necessary
if ! command -v bison &>/dev/null; then
  echo "Bison not found. Installing bison using Homebrew..."
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Please install Homebrew first."
    exit 1
  else
    brew install bison
  fi
fi

# Get the path of Homebrew-installed bison
BISON_PATH=$(brew --prefix bison)/bin

# Verify that we have the correct version of bison
BISON_VERSION=$($BISON_PATH/bison --version | head -n 1 | awk '{print $4}')
REQUIRED_VERSION="3.0.0"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$BISON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION"; then
  echo "Bison version $BISON_VERSION is too old. Please update to at least version $REQUIRED_VERSION."
  exit 1
fi

echo "Bison version $BISON_VERSION found."

# Export BISON and YACC to make sure configure and make use the correct bison
export BISON="$BISON_PATH/bison"
export YACC="$BISON_PATH/bison"

# macOS build
echo "Building PHP for macOS..."
make clean || true
PATH="$BISON_PATH:$PATH" ./configure --host=arm-apple-darwin \
  --with-iconv="$MACOS_SDK_PATH/usr" \
  --with-sqlite3="$MACOS_SDK_PATH/usr" \
  --enable-debug \
  --disable-opcache \
  --enable-embed=static \
  --disable-phar \
  --without-libxml \
  --disable-dom \
  --disable-xml \
  --disable-simplexml \
  --disable-xmlreader \
  --disable-xmlwriter \
  --disable-cgi \
  --enable-zts

make BISON="$BISON_PATH/bison" YACC="$BISON_PATH/bison" -j$(sysctl -n hw.ncpu)

popd
