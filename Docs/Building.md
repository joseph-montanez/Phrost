### Building


## Compile Game Engine For Windows

This is not required to use the game engine. Everything is provided in the release for the specific language you want to use. If you want to customize the game engine, you can compile it yourself. Follow the instructions.

Download the redist - https://aka.ms/vs/17/release/vc_redist.x64.exe

**Visual Studio Community 2022**

Download the Visual Studio Community 2022 installer from the Microsoft website. Once downloaded, run it and select the Desktop development with C++ workload.

**Install Swift 6.2**

Project is designed with Swift 6.2 strict concurrency. https://www.swift.org/install/windows/

**Enable Developer Mode**

This is the permanent fix. It allows your user account to create symbolic links without needing to run as Administrator every time.

1. Open Windows Settings.

2. Go to Privacy & security (or Update & Security on Windows 10) > For developers.

3. Toggle Developer Mode to On.

Confirm the prompt.


**Download SDL3 Headers and Libraries**

    mkdir .\Engine\deps
    cd .\Engine\deps
    curl -o SDL3-x64.zip "https://github.com/mmozeiko/build-sdl3/releases/download/2025-11-23/SDL3-x64-2025-11-23.zip"
    curl -o SDL3-arm64.zip "https://github.com/mmozeiko/build-sdl3/releases/download/2025-11-23/SDL3-arm64-2025-11-23.zip"
    tar -xf SDL3-x64.zip
    tar -xf SDL3-arm64.zip
    del SDL3-x64.zip
    del SDL3-arm64.zip
    cd ..\..\

**Download Chipmunk2D Headers and Libraries**

    winget install --id Git.Git -e --source winget

    cd .\Engine\deps
    git clone https://github.com/microsoft/vcpkg.git
    cd vcpkg
    .\bootstrap-vcpkg.bat
    .\vcpkg.exe install chipmunk:x64-windows
    .\vcpkg.exe install chipmunk:arm64-windows
    cd ..\..\..\

**Download PHP SDK**

    cd .\Engine\deps
    curl -o php-x64.zip "https://windows.php.net/downloads/releases/php-8.5.0-nts-Win32-vs17-x64.zip"
    curl -o php-x64-sdk.zip "https://windows.php.net/downloads/releases/php-devel-pack-8.5.0-nts-Win32-vs17-x64.zip"
    curl -o php-arm64.7z "https://github.com/hyh19962008/php-windows-arm64/releases/download/8.4.10/php-8.4.10-nts-Win32-vs17-arm64-experimental.7z"
    mkdir php-8.5.0-nts-Win32-vs17-x64
    mkdir php-8.5.0-nts-Win32-vs17-x64\sdk
    mkdir php-8.4.10-nts-Win32-vs17-arm64
    tar -xf php-x64.zip -C php-8.5.0-nts-Win32-vs17-x64
    tar -xf php-x64-sdk.zip -C php-8.5.0-nts-Win32-vs17-x64\sdk
    tar -xf php-arm64.7z -C php-8.4.10-nts-Win32-vs17-arm64
    move .\php-8.5.0-nts-Win32-vs17-x64\sdk\php-8.5.0-devel-vs17-x64\* .\php-8.5.0-nts-Win32-vs17-x64\sdk\
    rmdir .\php-8.5.0-nts-Win32-vs17-x64\sdk\php-8.5.0-devel-vs17-x64
    del php-x64.zip
    del php-x64-sdk.zip
    del php-arm64.7z
    cd ..\..\

**Build PhrostEngineV2**

You may need to allow powershell execution `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

    cd .\Engine\PhrostEngineV2
    # Edit Scripts\win_ext_arm64.ps1 and Scripts\win_ext_x64.ps1 paths
    ./Scripts/win_ext_arm64.ps1
    ./Scripts/win_ext_x64.ps1

## Compile Game Engine For macOS

    xcode-select --install

    mkdir Engine/deps
    cd Engine/deps

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

    cp ../craft.yml ./
    curl -fsSL -o spc https://dl.static-php.dev/static-php-cli/spc-bin/nightly/spc-macos-aarch64 # OR FOR INTEL (curl -fsSL -o spc https://dl.static-php.dev/static-php-cli/spc-bin/nightly/spc-macos-x86_64)
    chmod +x ./spc
    ./spc craft
    cd ../
    
    cd PhrostEngineV2
    chmod +x ./Scripts/macos_ext.sh
    ./Scripts/macos_ext.sh

**Code Signing**

If you want to distribute your game, you will need to sign it with a valid Apple Developer certificate.

    cd .\Engine\PhrostEngineV2
    codesign --force --sign "Developer ID Application: Your Name (TEAMID)" .build/release/PhrostBinary


## Compiling Game Engine for Ubuntu 24.04 LTS

** Install Swift **

    sudo apt-get install curl

    curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz && \
    tar zxf swiftly-$(uname -m).tar.gz && \
    ./swiftly init --quiet-shell-followup && \
    . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" && \
    hash -r

    sudo apt-get -y install binutils git gnupg2 libcurl4-openssl-dev libgcc-13-dev libpython3-dev libstdc++-13-dev libxml2-dev libncurses-dev libz3-dev pkg-config zlib1g-dev

** Building SDL3 **

    # Ubuntu 24.04 LTS
    sudo apt install build-essential git cmake pkg-config \
    libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxss-dev \
    libwayland-dev libxkbcommon-dev libdecor-0-dev wayland-protocols \
    libpipewire-0.3-dev libpulse-dev libasound2-dev \
    libibus-1.0-dev libgl1-mesa-dev libvulkan-dev libudev-dev \
    libjpeg-turbo8-dev libpng-dev libwebp-dev libtiff5-dev \
    libfreetype-dev libharfbuzz-dev libxi-dev


    # Debian 12
    sudo apt install build-essential git cmake pkg-config \
    libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxss-dev \
    libwayland-dev libxkbcommon-dev libdecor-0-dev wayland-protocols \
    libpipewire-0.3-dev libpulse-dev libasound2-dev \
    libibus-1.0-dev libgl1-mesa-dev libvulkan-dev libudev-dev \
    libjpeg62-turbo-dev libpng-dev libwebp-dev libtiff5-dev \
    libfreetype-dev libharfbuzz-dev libxi-dev libxtst-dev


    mkdir Engine/deps
    cd Engine/deps

    git clone https://github.com/libsdl-org/SDL.git
    cd SDL
    git submodule update --init --recursive
    mkdir build
    cd build
    cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    make -j10
    cd ../../

    export SDL3_DIR_PATH="$(pwd)/SDL/build"

    git clone https://github.com/libsdl-org/SDL_image.git
    cd SDL_image
    git submodule update --init --recursive
    mkdir build
    cd build
    cmake .. -DBUILD_SHARED_LIBS=OFF -DSDL3_DIR=$SDL3_DIR_PATH -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    make -j10
    cd ../../

    git clone https://github.com/libsdl-org/SDL_ttf.git
    cd SDL_ttf
    git submodule update --init --recursive
    mkdir build
    cd build
    cmake .. -DBUILD_SHARED_LIBS=OFF -DSDL3_DIR=$SDL3_DIR_PATH -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    make -j10
    cd ../../

** Chipmunk2D Physics Engine **

  sudo apt-get install libchipmunk-dev

** Static PHP **

    cp ../craft.yml ./

    # For Linux x86_64
    curl -fsSL -o spc https://dl.static-php.dev/static-php-cli/spc-bin/nightly/spc-linux-x86_64
    # For Linux aarch64
    curl -fsSL -o spc https://dl.static-php.dev/static-php-cli/spc-bin/nightly/spc-linux-aarch64

    # Add execute perm
    chmod +x ./spc

    ./spc craft
