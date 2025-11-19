cmake_minimum_required(VERSION 3.20)
project(PhrostHost C)

# --- 1. Architecture Detection & Paths ---
get_filename_component(ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../.." ABSOLUTE)
set(DEPS_DIR "${ROOT_DIR}/Engine/deps")

# [Bundle] Set Minimum OS Version (Matches Makefile LSMinimumSystemVersion)
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum OS X deployment version" FORCE)

# --- 2. Source Files & Executable Creation ---
# (Moved UP so the target exists for the platform checks below)
set(SOURCES
    main.c
    php_embed.c
    php_thread.c
    ../plugin/event_packer.c
)

# Create the target immediately
add_executable(PhrostHost MACOSX_BUNDLE ${SOURCES} "pthread_shim.h")

# [Bundle] Configure the Info.plist and Output Name
if(APPLE)
    set_target_properties(PhrostHost PROPERTIES
        OUTPUT_NAME "Phrost"  # Matches Makefile APP_NAME
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.phrost.engine"
        MACOSX_BUNDLE_BUNDLE_NAME "Phrost"
        MACOSX_BUNDLE_INFO_STRING "Phrost Game Engine"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
        MACOSX_BUNDLE_BUNDLE_VERSION "1"
        MACOSX_BUNDLE_COPYRIGHT "Copyright © 2025"
    )
endif()

# --- 3. Platform Specific Setup ---
if(APPLE)
    message(STATUS "BUILDING FOR: macOS")

    # --- Swift & PHP Paths (macOS) ---
    set(SWIFT_BUILD_DIR "${ROOT_DIR}/Engine/PhrostEngineV2/.build/arm64-apple-macosx/release")

    # --- Point to your local static buildroot ---
    set(PHP_BASE_DIR "${ROOT_DIR}/Engine/deps/buildroot")
    set(PHP_INC_DIR  "${PHP_BASE_DIR}/include/php")
    set(PHP_LIB_DIR  "${PHP_BASE_DIR}/lib")

    # --- Game Library Paths ---
    set(SDL_BASE_PATH     "${ROOT_DIR}/Engine/deps")
    set(SDL_LIB_PATH      "${SDL_BASE_PATH}/SDL/build/Release")
    set(SDL_IMG_LIB_PATH  "${SDL_BASE_PATH}/SDL_image/build/Release")
    set(SDL_TTF_LIB_PATH  "${SDL_BASE_PATH}/SDL_ttf/build/Release")

    set(CHIPMUNK_LIB_PATH "${ROOT_DIR}/Engine/SwiftChipmunk2D/Chipmunk2D.xcframework/macos-arm64_x86_64")
    set(CHIPMUNK_LIB_NAME "Chipmunk-Mac")

    # Mac Defines (Safe now because PhrostHost exists)
    target_compile_definitions(PhrostHost PRIVATE ZEND_DEBUG=0)

elseif(WIN32)
    message(STATUS "BUILDING FOR: Windows")

    # --- Swift & PHP Paths (Windows) ---
    set(SWIFT_SDK_BASE "C:/Users/Joseph/AppData/Local/Programs/Swift/Platforms/6.2.1/Windows.platform/Developer/SDKs/Windows.sdk/usr/lib/swift/windows")

    if(MSVC_C_ARCHITECTURE_ID MATCHES "ARM64" OR CMAKE_GENERATOR_PLATFORM MATCHES "ARM64")
        message(STATUS "  > Architecture: ARM64")
        set(SWIFT_ARCH_SLUG "aarch64-unknown-windows-msvc")
        set(PHP_BASE_DIR "${DEPS_DIR}/php-8.4.10-nts-Win32-vs17-arm64")
        set(SWIFT_RUNTIME_DIR "${SWIFT_SDK_BASE}/aarch64")
        set(SDL_ROOT      "${DEPS_DIR}/SDL3-arm64")
        set(CHIPMUNK_ROOT "${DEPS_DIR}/vcpkg/packages/chipmunk_arm64-windows")
    else()
        message(STATUS "  > Architecture: x64")
        set(SWIFT_ARCH_SLUG "x86_64-unknown-windows-msvc")
        set(PHP_BASE_DIR "${DEPS_DIR}/php-8.4.14-nts-Win32-vs17-x64")
        set(SWIFT_RUNTIME_DIR "${SWIFT_SDK_BASE}/x86_64")
        set(SDL_ROOT      "${DEPS_DIR}/SDL3-x64")
        set(CHIPMUNK_ROOT "${DEPS_DIR}/vcpkg/packages/chipmunk_x64-windows")
    endif()

    set(SWIFT_BUILD_ROOT "${ROOT_DIR}/Engine/PhrostEngineV2/.build/${SWIFT_ARCH_SLUG}")

    set(PHP_LIB_DIR  "${PHP_BASE_DIR}/sdk/lib")
    set(PHP_INC_DIR  "${PHP_BASE_DIR}/sdk/include")

    # --- Game Library Paths (Windows) ---
    set(SDL_ROOT      "${DEPS_DIR}/SDL3-arm64")
    set(CHIPMUNK_ROOT "${DEPS_DIR}/vcpkg/packages/chipmunk_arm64-windows")

    set(SDL_LIB_PATH      "${SDL_ROOT}/lib")
    set(SDL_IMG_LIB_PATH  "${SDL_ROOT}/lib")
    set(SDL_TTF_LIB_PATH  "${SDL_ROOT}/lib")
    set(CHIPMUNK_LIB_PATH "${CHIPMUNK_ROOT}/lib")
    set(CHIPMUNK_LIB_NAME "chipmunk")

    set(SDL_INC_PATH      "${SDL_ROOT}/include")
    set(CHIPMUNK_INC_PATH "${CHIPMUNK_ROOT}/include")

    # Windows Defines
    target_compile_definitions(PhrostHost PRIVATE ZEND_WIN32 PHP_WIN32 _WINDOWS _CRT_SECURE_NO_WARNINGS)
else()
    message(FATAL_ERROR "Unsupported Platform")
endif()

# --- 4. Include Directories ---
target_include_directories(PhrostHost PRIVATE
    .
    ../plugin
    "${PHP_INC_DIR}"
    "${PHP_INC_DIR}/main"
    "${PHP_INC_DIR}/TSRM"
    "${PHP_INC_DIR}/Zend"
)

if(WIN32)
    target_include_directories(PhrostHost PRIVATE "${SDL_INC_PATH}" "${CHIPMUNK_INC_PATH}")
endif()

# --- 5. Linking ---
if(WIN32)
    target_link_directories(PhrostHost PRIVATE "${SWIFT_RUNTIME_DIR}")
endif()

# Find PHP
if(APPLE)
    # On Mac, looking for libphp.a in your custom dir
    find_library(PHP_LIB NAMES php HINTS "${PHP_LIB_DIR}" NO_DEFAULT_PATH)

    # Find Static Dependencies (Required for static PHP) [cite: 18]
    find_library(LIB_XML2   NAMES xml2   HINTS "${PHP_LIB_DIR}" NO_DEFAULT_PATH)
    find_library(LIB_CURL   NAMES curl   HINTS "${PHP_LIB_DIR}" NO_DEFAULT_PATH)
    find_library(LIB_SSL    NAMES ssl    HINTS "${PHP_LIB_DIR}" NO_DEFAULT_PATH)
    find_library(LIB_CRYPTO NAMES crypto HINTS "${PHP_LIB_DIR}" NO_DEFAULT_PATH)
    find_library(LIB_ICONV  NAMES iconv  HINTS "${PHP_LIB_DIR}" NO_DEFAULT_PATH)
    find_library(LIB_Z      NAMES z      HINTS "${PHP_LIB_DIR}" NO_DEFAULT_PATH)
else()
    find_library(PHP_LIB NAMES php8 HINTS "${PHP_LIB_DIR}")
endif()

# --- FFind Engine Library ---
find_library(ENGINE_LIB NAMES PhrostShared HINTS "${SWIFT_BUILD_DIR}")

if(NOT ENGINE_LIB)
    # Fallback: Try finding the exact file if library lookup fails
    find_file(ENGINE_LIB_FILE libPhrostShared.a PATHS "${SWIFT_BUILD_DIR}" NO_DEFAULT_PATH)
    if(ENGINE_LIB_FILE)
        set(ENGINE_LIB ${ENGINE_LIB_FILE})
    else()
        message(FATAL_ERROR "Could not find libPhrostShared.a in ${SWIFT_BUILD_DIR}")
    endif()
endif()

# Find Game Dependencies
find_library(SDL3_LIB       NAMES SDL3       HINTS "${SDL_LIB_PATH}")
find_library(SDL3_IMG_LIB   NAMES SDL3_image HINTS "${SDL_IMG_LIB_PATH}")
find_library(SDL3_TTF_LIB   NAMES SDL3_ttf   HINTS "${SDL_TTF_LIB_PATH}")
find_library(CHIPMUNK_LIB   NAMES ${CHIPMUNK_LIB_NAME} chipmunk HINTS "${CHIPMUNK_LIB_PATH}")

# --- Find Engine Library (Dynamic Debug/Release Support) ---

# 1. Find Release Version
find_library(ENGINE_LIB_RELEASE 
    NAMES PhrostShared libPhrostShared 
    HINTS "${SWIFT_BUILD_ROOT}/release" 
    NO_DEFAULT_PATH
)

# 2. Find Debug Version
find_library(ENGINE_LIB_DEBUG 
    NAMES PhrostShared libPhrostShared 
    HINTS "${SWIFT_BUILD_ROOT}/debug" 
    NO_DEFAULT_PATH
)

if(ENGINE_LIB_RELEASE AND NOT ENGINE_LIB_DEBUG)
    message(STATUS "  [Swift] Debug lib not found. Using Release lib for all configs.")
    set(ENGINE_LIB_DEBUG ${ENGINE_LIB_RELEASE})
elseif(ENGINE_LIB_DEBUG AND NOT ENGINE_LIB_RELEASE)
    message(STATUS "  [Swift] Release lib not found. Using Debug lib for all configs.")
    set(ENGINE_LIB_RELEASE ${ENGINE_LIB_DEBUG})
endif()

if(NOT ENGINE_LIB_RELEASE AND NOT ENGINE_LIB_DEBUG)
    message(FATAL_ERROR "Could not find PhrostShared in ${SWIFT_BUILD_ROOT}/release OR /debug")
endif()


target_link_libraries(PhrostHost PRIVATE
    ${PHP_LIB}
    # Use 'debug' for Debug builds and 'optimized' (Release) for everything else
    debug     "${ENGINE_LIB_DEBUG}"
    optimized "${ENGINE_LIB_RELEASE}"
    ${SDL3_LIB}
    ${SDL3_IMG_LIB}
    ${SDL3_TTF_LIB}
    ${CHIPMUNK_LIB}
)

# System Libs
if(WIN32)
    target_link_libraries(PhrostHost PRIVATE
        # Swift Libs
        swiftCore swiftWinSDK swiftCRT
        # PHP Libs
        Bcrypt Userenv Ntdll Dnsapi Version Setupapi Imm32 Winmm
    )
elseif(APPLE)
    target_link_libraries(PhrostHost PRIVATE
        ${LIB_XML2} ${LIB_CURL} ${LIB_SSL} ${LIB_CRYPTO} ${LIB_ICONV} ${LIB_Z}
        "-framework CoreFoundation"
        "-framework Cocoa"
        "-framework IOKit"
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework Metal"
        "-framework QuartzCore"
        "-framework AVFoundation"
        "-framework SystemConfiguration"
        "-lresolv"
    )
endif()

# --- 6. Post-Build (Windows Only) ---
if(APPLE)
    add_custom_command(TARGET PhrostHost POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/game"
        "$<TARGET_FILE_DIR:PhrostHost>/game"
        COMMENT "Copying game assets to Bundle..."
    )
endif()

if(WIN32)
    set(SDL_BIN      "${SDL_ROOT}/bin")
    set(CHIPMUNK_BIN "${CHIPMUNK_ROOT}/bin")

    add_custom_command(TARGET PhrostHost POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${PHP_BASE_DIR}/php8.dll" "$<TARGET_FILE_DIR:PhrostHost>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${SDL_BIN}/SDL3.dll"       "$<TARGET_FILE_DIR:PhrostHost>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${SDL_BIN}/SDL3_image.dll" "$<TARGET_FILE_DIR:PhrostHost>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${SDL_BIN}/SDL3_ttf.dll"   "$<TARGET_FILE_DIR:PhrostHost>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CHIPMUNK_BIN}/chipmunk.dll" "$<TARGET_FILE_DIR:PhrostHost>"
        COMMENT "Copying Runtime DLLs..."
    )
endif()

# --- 7. Advanced Deployment ---
set(RUNTIME_ASSETS_SRC "${ROOT_DIR}/Runtime")

add_custom_command(TARGET PhrostHost POST_BUILD
    COMMAND ${CMAKE_COMMAND}
        -D "TARGET_DIR=$<TARGET_FILE_DIR:PhrostHost>"
        -D "PHP_SDK_DIR=${PHP_BASE_DIR}"
        -D "PROJECT_ROOT=${ROOT_DIR}"
        -D "ASSETS_DIR=${RUNTIME_ASSETS_SRC}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/Deploy.cmake"
    COMMENT " [Deploy] Running Advanced Deployment..."
)
