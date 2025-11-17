# Phrost Engine

## Installation on Windows 11 x64/ARM64

As of this time, the current Windows SDK is broken and you need to follow the guide to install Swift on Windows successfully https://forums.swift.org/t/an-unofficial-guide-to-building-the-swift-toolchain-on-windows-x64-and-arm64/81751

### Windows 11 ARM64

PHP has no official support for Windows 11 on ARM, however progress is being made and you can use the guide below.

1. Download the experimental builds for PHP 8.4: https://github.com/hyh19962008/php-windows-arm64/releases/download/8.4.10/php-8.4.10-nts-Win32-vs17-arm64-experimental.7z. Source code and SDK are in the same 7zip file.

 - php-8.4.10-nts-Win32-vs17-arm64-experimental.7z

2. Download the release for all SDL3 https://github.com/mmozeiko/build-sdl3/releases and unzip into a folder. Also copy the .dll files into your PHP folder where php.exe is.

3. Edit `Scripts/win_ext.ps1` and change `$env:PHP_SRC_ROOT="D:/dev/php-src-php-8.4.10"` to where the PHP source code was unzipped to.

```powershell
# Change these to where you decompressed `php-8.4.10-nts-Win32-vs17-arm64-experimental`
$env:PHP_SRC_ROOT = "D:/dev/php-8.4.10-nts-Win32-vs17-arm64-experimental/SDK/include"
$env:PHP_LIB_ROOT = "D:/dev/php-8.4.10-nts-Win32-vs17-arm64-experimental/SDK/lib"
```

3. Run `Scripts/win_ext.ps1` to build your Native PHP extension.

### macOS

    cd deps

    git clone https://github.com/libsdl-org/SDL.git
    cd SDL
    mkdir build
    cd build
    cmake .. -G Xcode -DBUILD_SHARED_LIBS=OFF
    xcodebuild -configuration Release -parallelizeTargets -jobs 10
    cd ../../

    git clone https://github.com/libsdl-org/SDL_image.git
    cd SDL_image
    git submodule update --init --recursive
    mkdir build
    cd build
    cmake .. -G Xcode -DBUILD_SHARED_LIBS=OFF -DSDL3_DIR=../SDL/build
    xcodebuild -configuration Release -parallelizeTargets -jobs 10
    cd ../../

    git clone https://github.com/libsdl-org/SDL_ttf.git
    cd SDL_ttf
    git submodule update --init --recursive
    mkdir build
    cd build
    cmake .. -G Xcode -DBUILD_SHARED_LIBS=OFF -DSDL3_DIR=../SDL/build
    xcodebuild -configuration Release -parallelizeTargets -jobs 10
    cd ../../

    git clone https://github.com/libsdl-org/SDL_mixer.git
    cd SDL_mixer
    git submodule update --init --recursive
    mkdir build
    cd build
    cmake .. -G Xcode -DBUILD_SHARED_LIBS=OFF -DSDL3_DIR=../SDL/build -DSDLMIXER_VORBIS_VORBISFILE=OFF
    xcodebuild -configuration Release -parallelizeTargets -jobs 10
    cd ../../
