cmake_minimum_required(VERSION 3.20)
project(PhrostHost C)

# --- 1. Architecture Detection & Paths ---
get_filename_component(ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../.." ABSOLUTE)
set(DEPS_DIR "${ROOT_DIR}/Engine/deps")

# Define the path to your Swift Engine Build (Static Lib)
set(SWIFT_BUILD_DIR "${ROOT_DIR}/Engine/PhrostEngineV2/.build/aarch64-unknown-windows-msvc/release")

# --- GAME LIBRARY PATHS ---
set(SDL_ROOT      "${DEPS_DIR}/SDL3-arm64")
set(CHIPMUNK_ROOT "${DEPS_DIR}/vcpkg/packages/chipmunk_arm64-windows")

# --- SWIFT RUNTIME PATHS (NEW) ---
# We define the base path to your Swift installation
set(SWIFT_SDK_BASE "C:/Users/Joseph/AppData/Local/Programs/Swift/Platforms/6.2.1/Windows.platform/Developer/SDKs/Windows.sdk/usr/lib/swift/windows")

if(MSVC_C_ARCHITECTURE_ID MATCHES "ARM64" OR CMAKE_GENERATOR_PLATFORM MATCHES "ARM64")
    message(STATUS "BUILDING FOR: Windows ARM64")
    set(PHP_BASE_DIR "${DEPS_DIR}/php-8.4.10-nts-Win32-vs17-arm64")
    set(PHP_LIB_DIR  "${PHP_BASE_DIR}/SDK/lib")
    set(PHP_INC_DIR  "${PHP_BASE_DIR}/SDK/include")

    # Set Swift Runtime for ARM64
    set(SWIFT_RUNTIME_DIR "${SWIFT_SDK_BASE}/aarch64")
else()
    message(STATUS "BUILDING FOR: Windows x64")
    set(PHP_BASE_DIR "${DEPS_DIR}/php-8.4.14-nts-Win32-vs17-x64")
    set(PHP_LIB_DIR  "${PHP_BASE_DIR}/sdk/lib")
    set(PHP_INC_DIR  "${PHP_BASE_DIR}/sdk/include")

    # Set Swift Runtime for x64
    set(SWIFT_RUNTIME_DIR "${SWIFT_SDK_BASE}/x86_64")
endif()

# --- 2. Source Files ---
set(SOURCES
    main.c
    php_embed.c
    php_thread.c
    ../plugin/event_packer.c
)

add_executable(PhrostHost ${SOURCES} "pthread_shim.h")

# --- 3. Include Directories ---
target_include_directories(PhrostHost PRIVATE
    .
    ../plugin
    "${PHP_INC_DIR}"
    "${PHP_INC_DIR}/main"
    "${PHP_INC_DIR}/TSRM"
    "${PHP_INC_DIR}/Zend"
    "${SDL_ROOT}/include"
    "${CHIPMUNK_ROOT}/include"
)

# --- 4. Compiler Flags ---
if(MSVC)
    target_compile_definitions(PhrostHost PRIVATE ZEND_WIN32 PHP_WIN32 _WINDOWS _CRT_SECURE_NO_WARNINGS)
endif()

# --- 5. Linking ---
# Add the Swift Runtime directory to the Linker Search Path
target_link_directories(PhrostHost PRIVATE "${SWIFT_RUNTIME_DIR}")

find_library(PHP_LIB NAMES php8 HINTS "${PHP_LIB_DIR}")
find_library(ENGINE_LIB NAMES libPhrostShared HINTS "${SWIFT_BUILD_DIR}")

if(NOT ENGINE_LIB)
    message(FATAL_ERROR "Could not find libPhrostShared.a in ${SWIFT_BUILD_DIR}")
endif()

# Find Game Dependencies
find_library(SDL3_LIB       NAMES SDL3       HINTS "${SDL_ROOT}/lib")
find_library(SDL3_IMG_LIB   NAMES SDL3_image HINTS "${SDL_ROOT}/lib")
find_library(SDL3_TTF_LIB   NAMES SDL3_ttf   HINTS "${SDL_ROOT}/lib")
find_library(CHIPMUNK_LIB   NAMES chipmunk   HINTS "${CHIPMUNK_ROOT}/lib")

target_link_libraries(PhrostHost PRIVATE
    ${PHP_LIB}
    ${ENGINE_LIB}
    # Game Libs
    ${SDL3_LIB}
    ${SDL3_IMG_LIB}
    ${SDL3_TTF_LIB}
    ${CHIPMUNK_LIB}
    # Swift Runtime Libs
    swiftCore
    swiftWinSDK
    swiftCRT
    # System Libs
    Bcrypt
    Userenv
    Ntdll
    Dnsapi
    Version
    Setupapi
    Imm32
    Winmm
)

# --- 6. Post-Build: Copy DLLs ---
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

# --- 7. ADVANCED DEPLOYMENT ---
# We pass variables to the external script using -D

# Define where the Runtime assets live (Source code side)
set(RUNTIME_ASSETS_SRC "${ROOT_DIR}/Runtime")

add_custom_command(TARGET PhrostHost POST_BUILD
    COMMAND ${CMAKE_COMMAND}
        -D "TARGET_DIR=$<TARGET_FILE_DIR:PhrostHost>"
        -D "PHP_SDK_DIR=${PHP_BASE_DIR}"
        -D "PROJECT_ROOT=${ROOT_DIR}"
        -D "ASSETS_DIR=${RUNTIME_ASSETS_SRC}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/Deploy.cmake"

    COMMENT " [Deploy] Running Advanced Deployment (Assets, PHP Config, Composer)..."
)
