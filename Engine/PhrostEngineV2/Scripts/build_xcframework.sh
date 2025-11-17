#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -eu

# --- Pre-flight Checks and Environment Setup ---

echo "Setting up build environment..."

# Ensure Homebrew is in the PATH.
if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew not found. Please install Homebrew first."
  exit 1
fi
export PATH="$(brew --prefix)/bin:$PATH"

# Ensure build tools are installed.
echo "Ensuring Homebrew's Bison and re2c are installed..."
brew install bison re2c

# Get the explicit path to Homebrew's bison.
HOMEBREW_BISON=$(brew --prefix bison)/bin/bison

# Verify Bison version.
BISON_VERSION=$($HOMEBREW_BISON --version | head -n 1 | awk '{print $4}')
REQUIRED_VERSION="3.0.0"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$BISON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
  echo "Error: Bison version $BISON_VERSION is too old. Please update to at least version $REQUIRED_VERSION."
  exit 1
fi
echo "Using Bison version $BISON_VERSION."

# --- Variables ---
PHP_VERSION="php-8.4.12"
BUILD_DIR="build/php-src"
XCFRAMEWORK_DIR="build/PHP.xcframework"
IOS_HEADERS_DIR="build/php-src-ios-headers"
MACOS_HEADERS_DIR="build/php-src-macos-headers"
IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
MACOS_SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

# --- Main Script ---

mkdir -p "build"

# Clone or reset PHP source
if [ ! -d "$BUILD_DIR" ]; then
  echo "Cloning PHP $PHP_VERSION..."
  git clone https://github.com/php/php-src.git "$BUILD_DIR"
  (cd "$BUILD_DIR" && git checkout "tags/$PHP_VERSION" --force)
else
  echo "Resetting PHP source directory..."
  (cd "$BUILD_DIR" && git fetch --all --tags && git reset --hard "tags/$PHP_VERSION")
fi

pushd "$BUILD_DIR"

# Run buildconf
echo "Running buildconf..."
./buildconf --force

# --- macOS Build ---
echo "Building PHP for macOS (arm64)..."
make clean || true
BISON="$HOMEBREW_BISON" YACC="$HOMEBREW_BISON" ./configure --host=arm64-apple-darwin \
  --with-iconv="$MACOS_SDK_PATH/usr" \
  --with-sqlite3="$MACOS_SDK_PATH/usr" \
  --disable-opcache \
  --enable-embed=static \
  --disable-phar \
  --without-libxml \
  --disable-dom \
  --disable-xml \
  --disable-simplexml \
  --disable-xmlreader \
  --disable-xmlwriter \
  --enable-cli \
  --disable-cgi \
  --disable-opcache-jit \
  --without-pcre-jit

make BISON="$HOMEBREW_BISON" YACC="$HOMEBREW_BISON" -j$(sysctl -n hw.ncpu)

echo "Preparing macOS headers..."
mkdir -p "../../$MACOS_HEADERS_DIR"
find . -name '*.h' | cpio -pdm "../../$MACOS_HEADERS_DIR"
cp main/php_config.h "../../$MACOS_HEADERS_DIR/main/"
cp Zend/zend_config.h "../../$MACOS_HEADERS_DIR/Zend/"

echo "Creating structured module map for macOS..."
cat > "../../$MACOS_HEADERS_DIR/module.modulemap" <<EOF
module PHP {
    header "main/php.h"
    // --- FIXED: Removed SAPI-specific header to make the framework neutral ---
    // header "sapi/embed/php_embed.h"
    export *

    explicit module Main {
        header "main/php_ini.h"
        export *
    }

    explicit module Zend {
        header "Zend/zend_API.h"
        header "Zend/zend_exceptions.h"
        export *
    }

    explicit module TSRM {
        header "TSRM/TSRM.h"
        export *
    }

    link "php"
    link framework "CoreServices"
    link framework "Foundation"
}
EOF

MACOS_LIB_PATH="../libphp-macos.a"
cp libs/libphp.a "$MACOS_LIB_PATH"

# --- iOS Build ---
echo "Building PHP for iOS (arm64)..."
make clean || true
BISON="$HOMEBREW_BISON" YACC="$HOMEBREW_BISON" ./configure --host=arm-apple-darwin \
  CC="$(xcrun --sdk iphoneos --find clang) -isysroot $IOS_SDK_PATH -arch arm64 -mios-version-min=13.0" \
  CFLAGS="-isysroot $IOS_SDK_PATH -arch arm64 -mios-version-min=13.0" \
  LDFLAGS="-isysroot $IOS_SDK_PATH -arch arm64 -mios-version-min=13.0" \
  --without-iconv \
  --disable-opcache \
  --enable-embed=static \
  --disable-phar \
  --without-libxml \
  --without-sqlite3 \
  --without-pdo-sqlite \
  --disable-dom \
  --disable-xml \
  --disable-simplexml \
  --disable-xmlreader \
  --disable-xmlwriter \
  --disable-fileinfo \
  --disable-cli \
  --disable-cgi \
  --disable-opcache-jit \
  --without-pcre-jit \

echo "Patching config for iOS build..."
sed -i '' 's/#define PHP_CAN_SUPPORT_PROC_OPEN 1/#undef PHP_CAN_SUPPORT_PROC_OPEN/g' main/php_config.h
sed -i '' 's/#define HAVE_POSIX_SPAWN_FILE_ACTIONS_ADDCHDIR_NP 1/#undef HAVE_POSIX_SPAWN_FILE_ACTIONS_ADDCHDIR_NP/g' main/php_config.h

make BISON="$HOMEBREW_BISON" YACC="$HOMEBREW_BISON" -j$(sysctl -n hw.ncpu)

echo "Preparing iOS headers..."
mkdir -p "../../$IOS_HEADERS_DIR"
find . -name '*.h' | cpio -pdm "../../$IOS_HEADERS_DIR"
cp main/php_config.h "../../$IOS_HEADERS_DIR/main/"
cp Zend/zend_config.h "../../$IOS_HEADERS_DIR/Zend/"

echo "Creating structured module map for iOS..."
cat > "../../$IOS_HEADERS_DIR/module.modulemap" <<EOF
module PHP {
    header "main/php.h"
    // --- FIXED: Removed SAPI-specific header to make the framework neutral ---
    // header "sapi/embed/php_embed.h"
    export *

    explicit module Main {
        header "main/php_ini.h"
        export *
    }

    explicit module Zend {
        header "Zend/zend_API.h"
        header "Zend/zend_exceptions.h"
        export *
    }

    explicit module TSRM {
        header "TSRM/TSRM.h"
        export *
    }

    link framework "CoreServices"
    link framework "Foundation"
}
EOF

IOS_LIB_PATH="../libphp-ios.a"
cp libs/libphp.a "$IOS_LIB_PATH"

popd

# --- Create XCFramework ---
echo "Creating XCFramework..."
rm -rf "$XCFRAMEWORK_DIR"
xcodebuild -create-xcframework \
  -library "$BUILD_DIR/$MACOS_LIB_PATH" \
  -headers "$MACOS_HEADERS_DIR" \
  -library "$BUILD_DIR/$IOS_LIB_PATH" \
  -headers "$IOS_HEADERS_DIR" \
  -output "$XCFRAMEWORK_DIR"

echo "✅ PHP XCFramework created successfully at $XCFRAMEWORK_DIR"

rm -rf PHP.xcframework
mv "$XCFRAMEWORK_DIR" PHP.xcframework

