# Stop the script if any command fails
$ErrorActionPreference = "Stop"
$STARTING_LOCATION = Get-Location

# --- Get Script Directory ---
$SCRIPT_DIR = $PSScriptRoot
Write-Host "Script running from: $SCRIPT_DIR"
Write-Host "Will return to: $STARTING_LOCATION"

# --- Environment Vars ---
# Note: Path adjusted to match your repo structure
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

# --- Path Debugging ---

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

if (-not $?) {
    Write-Error "Swift build failed! Stopping script."
    exit 1
}

Write-Host "### Swift Build Successful. ###"
Write-Host ""

# --- Post-Build Deployment ---
Write-Host "### 2. Starting Post-Build Deployment... ###"

$PROJECT_ROOT = (Join-Path $SCRIPT_DIR "..\..\.." | Resolve-Path)
$PHROST_RELEASE_DIR = Join-Path $PROJECT_ROOT "Release"
$PHROST_RUNTIME_DIR = Join-Path $PROJECT_ROOT "Runtime"
$PHROST_GAME_DIR = Join-Path $PHROST_RELEASE_DIR "game"
$PHROST_ENGINE_DIR = Join-Path $PHROST_RELEASE_DIR "engine"
$BUILD_SOURCE_DIR = (Join-Path $SCRIPT_DIR "..\.build\release")

Write-Host "Release Dir:  $PHROST_RELEASE_DIR"
Write-Host "Engine Dir:   $PHROST_ENGINE_DIR"

# --- Create Release Dirs ---
Write-Host "Creating directories..."
New-Item -ItemType Directory -Path $PHROST_RELEASE_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $PHROST_ENGINE_DIR -Force | Out-Null

# --- Copy PHP SDK Directory as 'runtime' ---
Write-Host "Copying entire PHP SDK directory to '$PHROST_RELEASE_DIR\runtime'..."
Copy-Item -Path $PHP_BASE_DIR -Destination (Join-Path $PHROST_RELEASE_DIR "runtime") -Recurse -Force

$PHP_RELEASE_EXE = Join-Path $PHROST_RELEASE_DIR "runtime\php.exe"

if (-not (Test-Path -Path $PHP_RELEASE_EXE -PathType Leaf)) {
    Write-Error "Failed to copy PHP SDK. '$PHP_RELEASE_EXE' not found!"
    exit 1
}
Write-Host "PHP executable located at: $PHP_RELEASE_EXE"


# --- *** NEW SECTION: Configure php.ini (Fixes HTTPS Wrapper Error) *** ---
Write-Host "Copying and configuring php.ini..."

$PHP_INI_SOURCE = (Join-Path $PHP_BASE_DIR "php.ini-development")
$PHP_INI_DEST = (Join-Path $PHROST_RELEASE_DIR "runtime\php.ini")

if (-not (Test-Path -Path $PHP_INI_SOURCE -PathType Leaf)) {
    Write-Error "php.ini-development not found at '$PHP_INI_SOURCE'!"
    # Fallback: Try looking for php.ini-production or just php.ini
    if (Test-Path (Join-Path $PHP_BASE_DIR "php.ini-production")) {
         $PHP_INI_SOURCE = (Join-Path $PHP_BASE_DIR "php.ini-production")
    }
}

# If still missing, we might be in trouble, but let's try to proceed or fail hard
Copy-Item -Path $PHP_INI_SOURCE -Destination $PHP_INI_DEST -Force

$iniContent = Get-Content -Path $PHP_INI_DEST -Raw

try {
    # Enabling OpenSSL is CRITICAL for Composer (https wrapper)
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

    # Note: We are enabling opcache extension, but JIT will be unavailable on Arm64.
    # This is fine; PHP will simply run without JIT.
} catch {
    Write-Error "Failed during php.ini string replacement."
    exit 1
}

[System.IO.File]::WriteAllText($PHP_INI_DEST, $iniContent)
Write-Host "php.ini configuration complete."
# --- *** END NEW SECTION *** ---


# --- Setup PHP Composer ---
Write-Host "Setting up Composer..."
Set-Location $PHROST_RELEASE_DIR

# This should now work because openssl is enabled in php.ini
& $PHP_RELEASE_EXE -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

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

# --- Copy Phrost Runtime ---
Write-Host "Copying Phrost binaries..."
Copy-Item -Path (Join-Path $BUILD_SOURCE_DIR "Phrost.exe") -Destination $PHROST_RELEASE_DIR
Copy-Item -Path (Join-Path $BUILD_SOURCE_DIR "PhrostIPC.exe") -Destination $PHROST_ENGINE_DIR

# --- Copy Dependency DLLs ---
Write-Host "Copying dependency DLLs..."
try {
    $SDL_BIN_DIR = (Join-Path $env:SDL3_LIB "..\bin") | Resolve-Path
    $CHIPMUNK_BIN_DIR = (Join-Path $env:CHIPMUNK2D_LIB "..\bin") | Resolve-Path

    Write-Host "Copying SDL DLLs from $SDL_BIN_DIR to $PHROST_ENGINE_DIR"
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3.dll") -Destination $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3_image.dll") -Destination $PHROST_ENGINE_DIR
    Copy-Item -Path (Join-Path $SDL_BIN_DIR "SDL3_ttf.dll") -Destination $PHROST_ENGINE_DIR

    Write-Host "Copying Chipmunk DLL from $CHIPMUNK_BIN_DIR to $PHROST_ENGINE_DIR"
    Copy-Item -Path (Join-Path $CHIPMUNK_BIN_DIR "chipmunk.dll") -Destination $PHROST_ENGINE_DIR
} catch {
    Write-Error "Failed to copy dependency DLLs."
    exit 1
}

# --- Copy Assets ---
Write-Host "Creating/clearing game directory at $PHROST_GAME_DIR..."
New-Item -ItemType Directory -Path $PHROST_GAME_DIR -Force | Out-Null

Write-Host "-> Copying 'assets' and 'php' files..."
Copy-Item -Path (Join-Path $PHROST_RUNTIME_DIR "assets") -Destination $PHROST_GAME_DIR -Recurse -Force
Copy-Item -Path (Join-Path $PHROST_RUNTIME_DIR "php\*") -Destination $PHROST_GAME_DIR -Recurse -Force

# --- Move settings.json to Root ---
$SOURCE_SETTINGS_PATH = Join-Path $PHROST_GAME_DIR "settings.json"
if (Test-Path -Path $SOURCE_SETTINGS_PATH) {
    Move-Item -Path $SOURCE_SETTINGS_PATH -Destination $PHROST_RELEASE_DIR -Force
    Write-Host "-> settings.json moved successfully."
}

# --- Install Runtime Packages ---
Write-Host "### 3. Installing Composer Packages... ###"
$COMPOSER_PHAR_SRC = (Join-Path $PHROST_RELEASE_DIR "composer.phar")
$COMPOSER_PHAR_DEST_DIR = $PHROST_GAME_DIR

New-Item -ItemType Directory -Path $COMPOSER_PHAR_DEST_DIR -Force | Out-Null
Move-Item -Path $COMPOSER_PHAR_SRC -Destination $COMPOSER_PHAR_DEST_DIR -Force
Set-Location $COMPOSER_PHAR_DEST_DIR

Write-Host "Running composer install..."
& $PHP_RELEASE_EXE "composer.phar" "install"

Write-Host ""
Write-Host "### All steps completed successfully. ###"
Write-Host "Returning to starting directory: $STARTING_LOCATION"
Set-Location $STARTING_LOCATION
