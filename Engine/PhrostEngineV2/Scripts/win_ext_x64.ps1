# Stop the script if any command fails
$ErrorActionPreference = "Stop"
$STARTING_LOCATION = Get-Location

# --- Get Script Directory ---
# $PSScriptRoot is the PowerShell equivalent of `dirname $(realpath BASH_SOURCE[0])`
$SCRIPT_DIR = $PSScriptRoot
Write-Host "Script running from: $SCRIPT_DIR"
Write-Host "Will return to: $STARTING_LOCATION"

# --- Environment Vars ---
$env:PHP_SRC_ROOT = (Join-Path $SCRIPT_DIR "..\..\deps\php-8.4.14-nts-Win32-vs17-x64\sdk\include" | Resolve-Path)
$env:PHP_LIB_ROOT = (Join-Path $SCRIPT_DIR "..\..\deps\php-8.4.14-nts-Win32-vs17-x64\sdk\lib" | Resolve-Path)
$env:CLIENT_TYPE = "php"

# --- Chipmunk2D ---
$env:CHIPMUNK2D_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\vcpkg\packages\chipmunk_x64-windows\include" | Resolve-Path)
$env:CHIPMUNK2D_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\vcpkg\packages\chipmunk_x64-windows\lib" | Resolve-Path)

# --- Core SDL3 ---
# *** FIXED: This path pointed to arm64 in your script, corrected to x64 ***
$env:SDL3_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-x64\include" | Resolve-Path)
$env:SDL3_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-x64\lib" | Resolve-Path)

# --- SDL_image ---
$env:SDL3_IMAGE_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-x64\include" | Resolve-Path)
$env:SDL3_IMAGE_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-x64\lib" | Resolve-Path)

# --- SDL_ttf ---
$env:SDL3_TTF_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-x64\include" | Resolve-Path)
$env:SDL3_TTF_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-x64\lib" | Resolve-Path)

# --- Derive PHP.EXE path from your SDK root ---
$PHP_BASE_DIR = (Join-Path $env:PHP_SRC_ROOT "..\.." | Resolve-Path)
$PHP_BIN = Join-Path $PHP_BASE_DIR "php.exe"

# --- Path Debugging (Ported from Bash) ---
Write-Host "========================================="
Write-Host "Checking paths from: $(Get-Location)"
Write-Host "========================================="

Write-Host "PHP_SRC_ROOT"
Write-Host "  Literal: $env:PHP_SRC_ROOT"
Write-Host "  Real:    $(Resolve-Path $env:PHP_SRC_ROOT)"
Write-Host ""
Write-Host "PHP_BIN"
Write-Host "  Literal: $PHP_BIN"
Write-Host "  Real:    $(Resolve-Path $PHP_BIN)"
Write-Host ""
Write-Host "CHIPMUNK2D_INCLUDE"
Write-Host "  Literal: $env:CHIPMUNK2D_INCLUDE"
Write-Host "  Real:    $(Resolve-Path $env:CHIPMUNK2D_INCLUDE)"
Write-Host ""
Write-Host "SDL3_INCLUDE"
Write-Host "  Literal: $env:SDL3_INCLUDE"
Write-Host "  Real:    $(Resolve-Path $env:SDL3_INCLUDE)"
Write-Host ""
Write-Host "SDL3_IMAGE_INCLUDE"
Write-Host "  Literal: $env:SDL3_IMAGE_INCLUDE"
Write-Host "  Real:    $(Resolve-Path $env:SDL3_IMAGE_INCLUDE)"
Write-Host ""
Write-Host "SDL3_TTF_INCLUDE"
Write-Host "  Literal: $env:SDL3_TTF_INCLUDE"
Write-Host "  Real:    $(Resolve-Path $env:SDL3_TTF_INCLUDE)"
Write-Host ""
Write-Host "========================================="
Write-Host "Continuing with build..."
Write-Host ""

# --- Build ---
Write-Host "### 1. Starting Swift Build (x64)... ###"

# Note: Backtick ` is the line continuation character in PowerShell
swift build -c release --static-swift-stdlib `
    -Xcc -UHAVE_BUILTIN_CONSTANT_P `
    -Xcc -DZEND_WIN32=1 `
    -Xcc -DPHP_WIN32=1 `
    -Xcc -DWIN32=1 `
    -Xcc -D_WINDOWS=1 `
    -Xcc -D_WIN32=1 `
    -Xcc -DNDEBUG `
    -Xcc "-I$($env:CHIPMUNK2D_INCLUDE)" `
    -Xcc "-I$($env:SDL3_INCLUDE)" `
    --triple x86_64-unknown-windows-msvc

# Check if the last command (swift build) was successful
if (-not $?) {
    Write-Error "Swift build failed! Stopping script."
    # Exit the script with an error code
    exit 1
}

Write-Host "### Swift Build Successful. ###"
Write-Host ""

# --- Post-Build Deployment ---
Write-Host "### 2. Starting Post-Build Deployment... ###"

# --- Define Paths (Ported from Bash) ---
# Assumes this script is in .../Phrost/Engine/PhrostEngineV2/scripts
$PROJECT_ROOT = (Join-Path $SCRIPT_DIR "..\..\.." | Resolve-Path)
$PHROST_RELEASE_DIR = Join-Path $PROJECT_ROOT "Release"
$PHROST_RUNTIME_DIR = Join-Path $PROJECT_ROOT "Runtime"
# *** MODIFIED: Using $PHROST_GAME_DIR from your arm64 script ***
$PHROST_GAME_DIR = Join-Path $PHROST_RELEASE_DIR "game"
$PHROST_ENGINE_DIR = Join-Path $PHROST_RELEASE_DIR "engine"

# *** UPDATED: Point to the x64 build artifact directory ***
$BUILD_SOURCE_DIR = (Join-Path $SCRIPT_DIR "..\.build\x86_64-unknown-windows-msvc\release")

Write-Host "Release Dir:  $PHROST_RELEASE_DIR"
Write-Host "Engine Dir:   $PHROST_ENGINE_DIR"
Write-Host "Runtime Dir:  $PHROST_RUNTIME_DIR"
# *** MODIFIED: Changed label to 'Game Dir' ***
Write-Host "Game Dir:     $PHROST_GAME_DIR"
Write-Host "Build Source: $BUILD_SOURCE_DIR"

# Check if build source exists
if (-not (Test-Path -Path $BUILD_SOURCE_DIR -PathType Container)) {
    Write-Error "Build source directory not found: $BUILD_SOURCE_DIR"
    Write-Error "Did the build *actually* produce artifacts in the expected 'x86_64-unknown-windows-msvc' folder?"
    exit 1
}

# --- Create Release Dirs ---
# -Force is like `mkdir -p`
Write-Host "Creating directories..."
New-Item -ItemType Directory -Path $PHROST_RELEASE_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $PHROST_ENGINE_DIR -Force | Out-Null
# The 'runtime' directory is no longer created here, it will be the copied PHP SDK folder

# --- Copy PHP SDK Directory as 'runtime' ---
Write-Host "Copying entire PHP SDK directory to '$PHROST_RELEASE_DIR\runtime'..."
Copy-Item -Path $PHP_BASE_DIR -Destination (Join-Path $PHROST_RELEASE_DIR "runtime") -Recurse -Force

# Define the path to the php.exe inside the newly copied runtime folder
$PHP_RELEASE_EXE = Join-Path $PHROST_RELEASE_DIR "runtime\php.exe"

# Verify php.exe exists at the new path
if (-not (Test-Path -Path $PHP_RELEASE_EXE -PathType Leaf)) {
    Write-Error "Failed to copy PHP SDK. '$PHP_RELEASE_EXE' not found at expected location!"
    Write-Error "Source path was: $PHP_BASE_DIR"
    exit 1
}
Write-Host "PHP executable located at: $PHP_RELEASE_EXE"


# --- *** NEW SECTION: Configure php.ini *** ---
Write-Host "Copying and configuring php.ini..."

$PHP_INI_SOURCE = (Join-Path $PHP_BASE_DIR "php.ini-development")
$PHP_INI_DEST = (Join-Path $PHROST_RELEASE_DIR "runtime\php.ini")

if (-not (Test-Path -Path $PHP_INI_SOURCE -PathType Leaf)) {
    Write-Error "php.ini-development not found at '$PHP_INI_SOURCE'!"
    exit 1
}

Copy-Item -Path $PHP_INI_SOURCE -Destination $PHP_INI_DEST -Force

# Read the entire file
# -Raw reads it as a single string, which is much faster for replaces
$iniContent = Get-Content -Path $PHP_INI_DEST -Raw

# Use -replace with regex. ';\s*(...)' finds the semicolon, optional whitespace,
# and captures the part we want to keep ($1). We then replace the whole match
# with just the captured group, effectively uncommenting it.

try {
    $iniContent = $iniContent -replace ';\s*(extension_dir\s*=\s*"ext")'    , '$1' `
                                -replace ';\s*(extension=bz2)'              , '$1' `
                                -replace ';\s*(extension=curl)'             , '$1' `
                                -replace ';\s*(extension=ffi)'              , '$1' `
                                -replace ';\s*(extension=ftp)'              , '$1' `
                                -replace ';\s*(extension=fileinfo)'         , '$1' `
                                -replace ';\s*(extension=gd)'               , '$1' `
                                -replace ';\s*(extension=gettext)'          , '$1' `
                                -replace ';\s*(extension=intl)'             , '$1' `
                                -replace ';\s*(extension=mbstring)'         , '$1' `
                                -replace ';\s*(extension=exif\s+;.*)'       , '$1' `
                                -replace ';\s*(extension=openssl)'          , '$1' `
                                -replace ';\s*(extension=pdo_sqlite)'       , '$1' `
                                -replace ';\s*(extension=shmop)'            , '$1' `
                                -replace ';\s*(extension=sockets)'          , '$1' `
                                -replace ';\s*(extension=sodium)'           , '$1' `
                                -replace ';\s*(extension=sqlite3)'          , '$1' `
                                -replace ';\s*(extension=zip)'              , '$1' `
                                -replace ';\s*(zend_extension=opcache)'     , '$1'
} catch {
    Write-Error "Failed during php.ini string replacement."
    Write-Error $_
    exit 1
}

# Write the modified content back
# Using [System.IO.File] is more reliable and avoids extra newlines
try {
    [System.IO.File]::WriteAllText($PHP_INI_DEST, $iniContent)
} catch {
    Write-Error "Failed to write modified content to '$PHP_INI_DEST'."
    Write-Error $_
    exit 1
}
Write-Host "php.ini configuration complete."
# --- *** END NEW SECTION *** ---


# --- Setup PHP Composer ---
Write-Host "Setting up Composer..."
# Set location to download composer-setup.php
Set-Location $PHROST_RELEASE_DIR

# & is the "call" operator to run an executable from a variable
& $PHP_RELEASE_EXE -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

# Get hash. Note: PHP on Windows might add \r\n, so we trim.
$HASH = (& $PHP_RELEASE_EXE -r "echo hash_file('sha384', 'composer-setup.php');").Trim()
$EXPECTED_HASH = "c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47"

if ($HASH -ne $EXPECTED_HASH) {
    Write-Host "Installer corrupt! Hash was: $HASH"
    Remove-Item "composer-setup.php"
    throw "Composer installer hash mismatch!"
}

Write-Host "Installer verified."
& $PHP_RELEASE_EXE composer-setup.php
& $PHP_RELEASE_EXE -r "unlink('composer-setup.php');"
# This step creates 'composer.phar' in the current directory ($PHROST_RELEASE_DIR)

# --- Copy Phrost Runtime ---
Write-Host "Copying Phrost binaries..."
# Phrost.exe (Launcher) goes in the root Release folder
Copy-Item -Path (Join-Path $BUILD_SOURCE_DIR "Phrost.exe") -Destination $PHROST_RELEASE_DIR

# PhrostIPC.exe goes into the 'engine' sub-folder
Copy-Item -Path (Join-Path $BUILD_SOURCE_DIR "PhrostIPC.exe") -Destination $PHROST_ENGINE_DIR

# PhrostEngine.dll goes into the 'engine' sub-folder
Write-Host "Copying PhrostEngine.dll (if present) to engine dir..."
Copy-Item -Path (Join-Path $BUILD_SOURCE_DIR "PhrostEngine.dll") -Destination $PHROST_ENGINE_DIR -ErrorAction SilentlyContinue


# --- Copy Dependency DLLs ---
Write-Host "Copying dependency DLLs (x64) to engine dir..."

try {
    # These paths are now the x64 paths defined at the top of the script
    $SDL_BIN_DIR = (Join-Path $env:SDL3_LIB "..\bin") | Resolve-Path
    $CHIPMUNK_BIN_DIR = (Join-Path $env:CHIPMUNK2D_LIB "..\bin") | Resolve-Path

    Write-Host "Copying SDL DLLs from $SDL_BIN_DIR"
    # Destination is $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3.dll") -Destination $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3_image.dll") -Destination $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3_ttf.dll") -Destination $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3_mixer.dll") -Destination $PHROST_ENGINE_DIR -ErrorAction SilentlyContinue

    Write-Host "Copying Chipmunk DLL from $CHIPMUNK_BIN_DIR"
    # Destination is $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $CHIPMUNK_BIN_DIR "chipmunk.dll") -Destination $PHROST_ENGINE_DIR
} catch {
    Write-Error "Failed to copy dependency DLLs. Check your env:SDL3_LIB and env:CHIPMUNK2D_LIB paths."
    Write-Error $_
    exit 1
}

# --- *** MODIFIED: This entire block is from your arm64 script *** ---
# --- Copy Assets ---
Write-Host "Creating/clearing game directory at $PHROST_GAME_DIR..."
# Ensure the game directory always exists
New-Item -ItemType Directory -Path $PHROST_GAME_DIR -Force | Out-Null

Write-Host "-> Copying 'assets' folder into 'game' folder..."
# Copy the 'assets' folder *into* the 'game' folder (This creates 'game\assets')
Copy-Item -Path (Join-Path $PHROST_RUNTIME_DIR "assets") -Destination $PHROST_GAME_DIR -Recurse -Force

Write-Host "-> Copying 'php' files into 'game' folder..."
# Copy the *contents* of the 'php' folder into the 'game' folder
Copy-Item -Path (Join-Path $PHROST_RUNTIME_DIR "php\*") -Destination $PHROST_GAME_DIR -Recurse -Force

Write-Host "-> Assets and PHP files copied."

# --- Move settings.json to Root (now runs every time) ---
Write-Host "Moving settings.json to release root..."
$SOURCE_SETTINGS_PATH = Join-Path $PHROST_GAME_DIR "settings.json"

# Check if the file exists in the 'game' folder before trying to move it
if (Test-Path -Path $SOURCE_SETTINGS_PATH) {
    Move-Item -Path $SOURCE_SETTINGS_PATH -Destination $PHROST_RELEASE_DIR -Force
    Write-Host "-> settings.json moved successfully."
} else {
    Write-Host "-> settings.json was not found in '$PHROST_GAME_DIR'."
}
# --- *** END MODIFIED BLOCK *** ---

# --- Install Runtime Packages ---
Write-Host "### 3. Installing Composer Packages... ###"

# Point to the composer.phar that was just downloaded to $PHROST_RELEASE_DIR
$COMPOSER_PHAR_SRC = (Join-Path $PHROST_RELEASE_DIR "composer.phar")
# *** MODIFIED: Destination is now the game directory ***
$COMPOSER_PHAR_DEST_DIR = $PHROST_GAME_DIR

# Ensure dest dir exists
New-Item -ItemType Directory -Path $COMPOSER_PHAR_DEST_DIR -Force | Out-Null

Write-Host "Moving composer.phar from '$COMPOSER_PHAR_SRC' to '$COMPOSER_PHAR_DEST_DIR'"
Move-Item -Path $COMPOSER_PHAR_SRC -Destination $COMPOSER_PHAR_DEST_DIR -Force

# *** MODIFIED: Set location to the game directory ***
Set-Location $COMPOSER_PHAR_DEST_DIR

Write-Host "Current directory: $(Get-Location)"
Get-ChildItem

# Run composer install
Write-Host "Running composer install..."
& $PHP_RELEASE_EXE "composer.phar" "install"

# --- Return to starting directory ---
Write-Host ""
Write-Host "### All steps completed successfully. ###"
Write-Host "Returning to starting directory: $STARTING_LOCATION"
Set-Location $STARTING_LOCATION
