#!/usr/bin/env bash

set -eu

# Variables
PHP_VERSION="php-8.4.12"
BUILD_DIR="build/php-src"

# Create the build directory
mkdir -p "build"

# Install necessary dependencies
echo "Installing PHP build dependencies..."
sudo apt-get install -y build-essential autoconf libtool re2c libxml2-dev libsqlite3-dev bison

# Clone or update the PHP source
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

# Enter the PHP source directory
pushd "$BUILD_DIR"

# Run buildconf
echo "Running buildconf..."
./buildconf --force

# Configure and build PHP
echo "Configuring PHP with ZTS enabled and embedding..."
make clean || true
./configure \
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
  --disable-cli \
  --disable-cgi \
  --enable-zts \
  --with-sqlite3=/usr

# Build PHP
echo "Building PHP..."
make -j$(nproc)

echo "PHP $PHP_VERSION build completed successfully with ZTS and embedding enabled."
popd