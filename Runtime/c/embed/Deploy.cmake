# --- Deploy.cmake ---
# 1. INPUT VARIABLES
# TARGET_DIR: Directory where the executable resides
# PHP_SDK_DIR: Source directory of the PHP SDK
# PROJECT_ROOT: The root of the repository
# ASSETS_DIR: The source runtime/assets directory
# IS_WINDOWS: "TRUE" or "FALSE" (Passed from CMake)

message(STATUS "--- [Deploy] Starting Phrost Deployment ---")

# --- 2. SETUP PATHS ---
set(GAME_DIR     "${TARGET_DIR}/game")

# On macOS, TARGET_DIR is inside the bundle (Phrost.app/Contents/MacOS)
# We don't need a separate 'runtime' folder logic for the static build.
if(IS_WINDOWS)
    set(RELEASE_ROOT "${TARGET_DIR}")
    set(RUNTIME_DEST "${RELEASE_ROOT}/runtime")
    set(PHP_EXE      "${RUNTIME_DEST}/php.exe")
else()
    # On macOS, we use the system PHP or the one in buildroot just for Composer
    set(RELEASE_ROOT "${TARGET_DIR}")
    set(RUNTIME_DEST "${RELEASE_ROOT}") # No runtime subfolder needed
    set(PHP_EXE      "${PHP_SDK_DIR}/bin/php")
endif()

# --- 3. DEPLOY PHP RUNTIME (WINDOWS ONLY) ---
if(IS_WINDOWS)
    message(STATUS "--- [Deploy] Copying PHP SDK (Windows Dynamic Build)...")
    # Clean destination to prevent "File exists" errors
    file(REMOVE_RECURSE "${RUNTIME_DEST}")
    file(MAKE_DIRECTORY "${RUNTIME_DEST}")

    file(COPY "${PHP_SDK_DIR}/" DESTINATION "${RUNTIME_DEST}")

    # --- 4. CONFIGURE PHP.INI (WINDOWS ONLY) ---
    message(STATUS "--- [Deploy] Configuring php.ini...")
    if(EXISTS "${RUNTIME_DEST}/php.ini-development")
        set(PHP_INI_SRC "${RUNTIME_DEST}/php.ini-development")
    elseif(EXISTS "${RUNTIME_DEST}/php.ini-production")
        set(PHP_INI_SRC "${RUNTIME_DEST}/php.ini-production")
    else()
        message(WARNING "Could not find php.ini-development or production in SDK!")
    endif()

    if(PHP_INI_SRC)
        set(PHP_INI_DEST "${RUNTIME_DEST}/php.ini")
        file(COPY "${PHP_INI_SRC}" DESTINATION "${RUNTIME_DEST}")
        file(RENAME "${RUNTIME_DEST}/php.ini-development" "${PHP_INI_DEST}")

        file(READ "${PHP_INI_DEST}" INI_CONTENT)
        # Enable Extensions
        if(INI_CONTENT MATCHES "extension_dir\\s*=")
            string(REGEX REPLACE ";?\\s*extension_dir\\s*=\\s*\"?[^\"]+\"?" "extension_dir = \"ext\"" INI_CONTENT "${INI_CONTENT}")
        else()
            set(INI_CONTENT "${INI_CONTENT}\nextension_dir = \"ext\"\n")
        endif()
        # Uncomment extensions
        string(REGEX REPLACE ";\\s*(extension=[a-z_]+)" "\\1" INI_CONTENT "${INI_CONTENT}")
        file(WRITE "${PHP_INI_DEST}" "${INI_CONTENT}")
    endif()
else()
    message(STATUS "--- [Deploy] macOS Static Build detected. Skipping SDK Copy.")
endif()

# --- 5. DEPLOY ASSETS ---
message(STATUS "--- [Deploy] Copying Game Assets to ${GAME_DIR}...")

# Ensure Game Directory Exists
file(MAKE_DIRECTORY "${GAME_DIR}")

# Copy 'assets' folder
if(EXISTS "${ASSETS_DIR}/assets")
    file(COPY "${ASSETS_DIR}/assets" DESTINATION "${GAME_DIR}")
endif()

# Copy 'php' source files
if(EXISTS "${ASSETS_DIR}/php")
    file(COPY "${ASSETS_DIR}/php" DESTINATION "${GAME_DIR}")
endif()

# Move settings.json
if(EXISTS "${GAME_DIR}/settings.json")
    file(RENAME "${GAME_DIR}/settings.json" "${RELEASE_ROOT}/settings.json")
endif()

# --- 6. COMPOSER SETUP ---
message(STATUS "--- [Deploy] Setting up Composer...")
set(COMPOSER_SETUP "${RELEASE_ROOT}/composer-setup.php")
set(COMPOSER_PHAR  "${RELEASE_ROOT}/composer.phar")

if(NOT EXISTS "${COMPOSER_PHAR}")
    file(DOWNLOAD "https://getcomposer.org/installer" "${COMPOSER_SETUP}" TLS_VERIFY ON)

    execute_process(
        COMMAND "${PHP_EXE}" "${COMPOSER_SETUP}"
        WORKING_DIRECTORY "${RELEASE_ROOT}"
        RESULT_VARIABLE COMPOSER_RET
    )

    if(NOT COMPOSER_RET EQUAL 0)
        message(WARNING "Composer installation failed! (Ret: ${COMPOSER_RET})")
    else()
        file(REMOVE "${COMPOSER_SETUP}")
    endif()
endif()

# --- 7. COMPOSER INSTALL ---
if(EXISTS "${COMPOSER_PHAR}")
    message(STATUS "--- [Deploy] Running 'composer install'...")

    # On macOS, we might need to move composer.phar to game dir or run it referencing the file
    file(RENAME "${COMPOSER_PHAR}" "${GAME_DIR}/composer.phar")

    execute_process(
        COMMAND "${PHP_EXE}" "composer.phar" "install"
        WORKING_DIRECTORY "${GAME_DIR}"
        RESULT_VARIABLE INSTALL_RET
    )
endif()

message(STATUS "--- [Deploy] Deployment Complete. ---")
