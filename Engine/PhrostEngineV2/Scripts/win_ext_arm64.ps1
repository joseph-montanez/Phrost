# Stop the script if any command fails
$ErrorActionPreference = "Stop"
$STARTING_LOCATION = Get-Location


# --- Get Script Directory ---
# $PSScriptRoot is the PowerShell equivalent of `dirname $(realpath BASH_SOURCE[0])`
$SCRIPT_DIR = $PSScriptRoot
Write-Host "Script running from: $SCRIPT_DIR"
Write-Host "Will return to: $STARTING_LOCATION"

# --- Environment Vars ---
$env:PHP_SRC_ROOT = (Join-Path $SCRIPT_DIR "..\..\deps\php-8.4.10-nts-Win32-vs17-arm64\SDK\include" | Resolve-Path)
$env:PHP_LIB_ROOT = (Join-Path $SCRIPT_DIR "..\..\deps\php-8.4.10-nts-Win32-vs17-arm64\SDK\lib" | Resolve-Path)
$env:CLIENT_TYPE = "php"

# --- Chipmunk2D ---
$env:CHIPMUNK2D_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\vcpkg\packages\chipmunk_arm64-windows\include" | Resolve-Path)
$env:CHIPMUNK2D_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\vcpkg\packages\chipmunk_arm64-windows\lib" | Resolve-Path)

# --- Core SDL3 ---
$env:SDL3_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-arm64\include" | Resolve-Path)
$env:SDL3_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-arm64\lib" | Resolve-Path)

# --- SDL_image ---
$env:SDL3_IMAGE_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-arm64\include" | Resolve-Path)
$env:SDL3_IMAGE_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-arm64\lib" | Resolve-Path)

# --- SDL_ttf ---
$env:SDL3_TTF_INCLUDE = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-arm64\include" | Resolve-Path)
$env:SDL3_TTF_LIB = (Join-Path $SCRIPT_DIR "..\..\deps\SDL3-arm64\lib" | Resolve-Path)

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
Write-Host "### 1. Starting Swift Build... ###"

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
    --triple aarch64-unknown-windows-msvc

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
$PHROST_GAME_DIR = Join-Path $PHROST_RELEASE_DIR "game"
$BUILD_SOURCE_DIR = (Join-Path $SCRIPT_DIR "..\.build\release")

# --- MODIFIED: Define the new engine directory ---
$PHROST_ENGINE_DIR = Join-Path $PHROST_RELEASE_DIR "engine"
# ---

Write-Host "Release Dir:  $PHROST_RELEASE_DIR"
Write-Host "Engine Dir:   $PHROST_ENGINE_DIR"
Write-Host "Runtime Dir:  $PHROST_RUNTIME_DIR"
Write-Host "Assets Dir:   $PHROST_GAME_DIR"
Write-Host "Build Source: $BUILD_SOURCE_DIR"

# --- Create Release Dirs ---
# -Force is like `mkdir -p`
Write-Host "Creating directories..."
New-Item -ItemType Directory -Path $PHROST_RELEASE_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $PHROST_ENGINE_DIR -Force | Out-Null # --- MODIFIED ---

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
# --- MODIFIED: Split binaries to correct locations ---
Copy-Item -Path (Join-Path $BUILD_SOURCE_DIR "Phrost.exe") -Destination $PHROST_RELEASE_DIR
Copy-Item -Path (Join-Path $BUILD_SOURCE_DIR "PhrostIPC.exe") -Destination $PHROST_ENGINE_DIR
# ---

# --- Copy Dependency DLLs ---
Write-Host "Copying dependency DLLs..."

try {
    $SDL_BIN_DIR = (Join-Path $env:SDL3_LIB "..\bin") | Resolve-Path
    $CHIPMUNK_BIN_DIR = (Join-Path $env:CHIPMUNK2D_LIB "..\bin") | Resolve-Path

    Write-Host "Copying SDL DLLs from $SDL_BIN_DIR to $PHROST_ENGINE_DIR"
    # --- MODIFIED: Changed destination to $PHROST_ENGINE_DIR for all DLLs ---
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3.dll") -Destination $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3_image.dll") -Destination $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3_ttf.dll") -Destination $PHROST_ENGINE_DIR

    Write-Host "Copying Chipmunk DLL from $CHIPMUNK_BIN_DIR to $PHROST_ENGINE_DIR"
    Copy-Item -Path (Join-Path $CHIPMUNK_BIN_DIR "chipmunk.dll") -Destination $PHROST_ENGINE_DIR
    # ---
} catch {
    Write-Error "Failed to copy dependency DLLs. Check your env:SDL3_LIB and env:CHIPMUNK2D_LIB paths."
    Write-Error $_
    exit 1
}

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

# --- Install Runtime Packages ---
Write-Host "### 3. Installing Composer Packages... ###"

# *** FIX: Point to the composer.phar that was just downloaded to $PHROST_RELEASE_DIR ***
$COMPOSER_PHAR_SRC = (Join-Path $PHROST_RELEASE_DIR "composer.phar")
$COMPOSER_PHAR_DEST_DIR = $PHROST_GAME_DIR

# Ensure dest dir exists
New-Item -ItemType Directory -Path $COMPOSER_PHAR_DEST_DIR -Force | Out-Null

Write-Host "Moving composer.phar from '$COMPOSER_PHAR_SRC' to '$COMPOSER_PHAR_DEST_DIR'"
Move-Item -Path $COMPOSER_PHAR_SRC -Destination $COMPOSER_PHAR_DEST_DIR -Force

# Set location to the src dir
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
