#!/usr/bin/env bash

# Paths MUST be relative to the directory where you run this script
# (which is /home/joseph-montanez/Documents/Phrost2/Engine/PhrostEngineV2)
export LINUX_DEPS_ROOT="../deps"

export SDL3_INCLUDE="$LINUX_DEPS_ROOT/SDL/include"
export SDL3_LIB="$LINUX_DEPS_ROOT/SDL/build"

export SDL3_IMAGE_INCLUDE="$LINUX_DEPS_ROOT/SDL_image/include"
export SDL3_IMAGE_LIB="$LINUX_DEPS_ROOT/SDL_image/build"

export SDL3_MIXER_INCLUDE="$LINUX_DEPS_ROOT/SDL_mixer/include"
export SDL3_MIXER_LIB="$LINUX_DEPS_ROOT/SDL_mixer/build"

export SDL3_TTF_INCLUDE="$LINUX_DEPS_ROOT/SDL_ttf/include"
export SDL3_TTF_LIB="$LINUX_DEPS_ROOT/SDL_ttf/build"


# This build command should now work with the relative paths
PHP_SRC_ROOT=../deps/source/php-src swift build -c release -vv \
    -Xcc -D_GNU_SOURCE \
    -Xcc -fno-builtin \
    -Xcc -I../deps/source/php-src \
    -Xcc -I../deps/source/php-src/main \
    -Xcc -I../deps/source/php-src/Zend \
    -Xcc -I../deps/source/php-src/TSRM \
    -Xcc "-I$SDL3_INCLUDE" \
    -Xcc "-I$SDL3_IMAGE_INCLUDE" \
    -Xcc "-I$SDL3_TTF_INCLUDE" \
     -Xlinker -L../deps/source/php-src/libs
    
