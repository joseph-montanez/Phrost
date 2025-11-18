# --- Deploy.cmake ---
# This script handles the complex deployment logic previously done in PowerShell.

# 1. INPUT VARIABLES (Passed from Main CMake)
# TARGET_DIR: Directory where the executable resides (e.g., build/Release)
# PHP_SDK_DIR: Source directory of the PHP SDK
# PROJECT_ROOT: The root of the repository
# ASSETS_DIR: The source runtime/assets directory

message(STATUS "--- [Deploy] Starting Phrost Deployment ---")

# --- 2. SETUP PATHS ---
set(RELEASE_ROOT "${PROJECT_ROOT}/Release")
set(GAME_DIR     "${RELEASE_ROOT}/game")
set(ENGINE_DIR   "${RELEASE_ROOT}/engine")
set(RUNTIME_DEST "${RELEASE_ROOT}/runtime")

# Create directories
file(MAKE_DIRECTORY "${RELEASE_ROOT}")
file(MAKE_DIRECTORY "${GAME_DIR}")
file(MAKE_DIRECTORY "${ENGINE_DIR}")

# --- 3. DEPLOY PHP RUNTIME ---
message(STATUS "--- [Deploy] Copying PHP SDK from ${PHP_SDK_DIR}...")
# Copy the entire PHP SDK folder to Release/runtime
file(COPY "${PHP_SDK_DIR}/" DESTINATION "${RUNTIME_DEST}")

set(PHP_EXE "${RUNTIME_DEST}/php.exe")

# --- 4. CONFIGURE PHP.INI ---
message(STATUS "--- [Deploy] Configuring php.ini...")

# Find source ini (dev or prod)
if(EXISTS "${RUNTIME_DEST}/php.ini-development")
    set(PHP_INI_SRC "${RUNTIME_DEST}/php.ini-development")
elseif(EXISTS "${RUNTIME_DEST}/php.ini-production")
    set(PHP_INI_SRC "${RUNTIME_DEST}/php.ini-production")
else()
    message(FATAL_ERROR "Could not find php.ini-development or production in SDK!")
endif()

set(PHP_INI_DEST "${RUNTIME_DEST}/php.ini")
file(COPY "${PHP_INI_SRC}" DESTINATION "${RUNTIME_DEST}")
file(RENAME "${RUNTIME_DEST}/php.ini-development" "${PHP_INI_DEST}") # Ensure name is php.ini

# Read the file
file(READ "${PHP_INI_DEST}" INI_CONTENT)

# Enable Extensions (Regex Replace)
# We look for the line (commented or not) and force it to extension_dir = "ext"
if(INI_CONTENT MATCHES "extension_dir\\s*=")
    string(REGEX REPLACE ";?\\s*extension_dir\\s*=\\s*\"?[^\"]+\"?" "extension_dir = \"ext\"" INI_CONTENT "${INI_CONTENT}")
else()
    # If not found, append it to the end
    set(INI_CONTENT "${INI_CONTENT}\nextension_dir = \"ext\"\n")
endif()
# Matches "; extension=name" and replaces with "extension=name"
string(REGEX REPLACE ";\\s*(extension=[a-z_]+)" "\\1" INI_CONTENT "${INI_CONTENT}")

#Opcache not yet supported on ARM64
#string(REGEX REPLACE ";\\s*(zend_extension=opcache)" "\\1" INI_CONTENT "${INI_CONTENT}")

# Write it back
file(WRITE "${PHP_INI_DEST}" "${INI_CONTENT}")
message(STATUS "--- [Deploy] php.ini configured (Extensions Enabled).")

# --- 5. DEPLOY ASSETS ---
message(STATUS "--- [Deploy] Copying Game Assets...")

# Copy 'assets' folder
file(COPY "${ASSETS_DIR}/assets" DESTINATION "${GAME_DIR}")

# Copy 'php' source files
file(COPY "${ASSETS_DIR}/php" DESTINATION "${GAME_DIR}")

# Move settings.json if it exists inside game dir to root
if(EXISTS "${GAME_DIR}/settings.json")
    file(RENAME "${GAME_DIR}/settings.json" "${RELEASE_ROOT}/settings.json")
endif()

# --- 6. COMPOSER SETUP ---
message(STATUS "--- [Deploy] Setting up Composer...")

set(COMPOSER_SETUP "${RELEASE_ROOT}/composer-setup.php")
set(COMPOSER_PHAR  "${RELEASE_ROOT}/composer.phar")

# Download Installer
if(NOT EXISTS "${COMPOSER_PHAR}")
    file(DOWNLOAD "https://getcomposer.org/installer" "${COMPOSER_SETUP}" TLS_VERIFY ON)

    # Run Installer
    execute_process(
        COMMAND "${PHP_EXE}" "${COMPOSER_SETUP}"
        WORKING_DIRECTORY "${RELEASE_ROOT}"
        RESULT_VARIABLE COMPOSER_RET
    )

    if(NOT COMPOSER_RET EQUAL 0)
        message(FATAL_ERROR "Composer installation failed!")
    endif()

    file(REMOVE "${COMPOSER_SETUP}")
endif()

# --- 7. COMPOSER INSTALL ---
message(STATUS "--- [Deploy] Running 'composer install'...")

# Move composer.phar to game dir temporarily or run from root pointing to it?
# Your script moves it to game dir.
file(RENAME "${COMPOSER_PHAR}" "${GAME_DIR}/composer.phar")

execute_process(
    COMMAND "${PHP_EXE}" "composer.phar" "install"
    WORKING_DIRECTORY "${GAME_DIR}"
    RESULT_VARIABLE INSTALL_RET
)

if(NOT INSTALL_RET EQUAL 0)
    message(WARNING "Composer install returned error code: ${INSTALL_RET}")
endif()

message(STATUS "--- [Deploy] Deployment Complete. ---")
