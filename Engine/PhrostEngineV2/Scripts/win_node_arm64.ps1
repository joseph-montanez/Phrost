# Stop the script if any command fails
$ErrorActionPreference = "Stop"
$STARTING_LOCATION = Get-Location

# --- Get Script Directory ---
$SCRIPT_DIR = $PSScriptRoot
Write-Host "Script running from: $SCRIPT_DIR"
Write-Host "Will return to: $STARTING_LOCATION"

# --- Environment Vars ---
$env:CLIENT_TYPE = "node"

# --- Node.js Paths ---
# Path adjusted to match your provided structure: Engine\deps\node-v25.2.1-win-arm64
$env:NODE_ROOT = (Join-Path $SCRIPT_DIR "..\..\deps\node-arm64" | Resolve-Path)
$NODE_BIN = Join-Path $env:NODE_ROOT "node.exe"
$NPM_BIN = Join-Path $env:NODE_ROOT "npm.cmd" # Usually npm is a cmd shim on Windows in the node dir

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

# --- Path Debugging ---
Write-Host "========================================="
Write-Host "Checking paths from: $(Get-Location)"
Write-Host "========================================="
Write-Host "NODE_ROOT"
Write-Host "  Real:    $env:NODE_ROOT"
Write-Host ""
Write-Host "CHIPMUNK2D_INCLUDE"
Write-Host "  Real:    $($env:CHIPMUNK2D_INCLUDE)"
Write-Host ""
Write-Host "SDL3_INCLUDE"
Write-Host "  Real:    $($env:SDL3_INCLUDE)"
Write-Host "========================================="
Write-Host "Continuing with build..."
Write-Host ""

# --- Build ---
Write-Host "### 1. Starting Swift Build (Node Target)... ###"

# Removed PHP-specific defines (ZEND_WIN32, etc.)
swift build -c release --static-swift-stdlib `
    -Xcc -UHAVE_BUILTIN_CONSTANT_P `
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
$BUILD_SOURCE_DIR = (Join-Path $SCRIPT_DIR "..\.build\aarch64-unknown-windows-msvc\release")

Write-Host "Release Dir:  $PHROST_RELEASE_DIR"
Write-Host "Engine Dir:   $PHROST_ENGINE_DIR"

# --- Create Release Dirs ---
Write-Host "Creating directories..."
New-Item -ItemType Directory -Path $PHROST_RELEASE_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $PHROST_ENGINE_DIR -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $PHROST_RELEASE_DIR "runtime") -Force | Out-Null

# --- Copy Node.js ---
Write-Host "Copying Node.js executable..."
Copy-Item -Path $NODE_BIN -Destination (Join-Path $PHROST_RELEASE_DIR "runtime\node.exe") -Force
$NODE_RELEASE_EXE = Join-Path $PHROST_RELEASE_DIR "runtime\node.exe"

if (-not (Test-Path -Path $NODE_RELEASE_EXE -PathType Leaf)) {
    Write-Error "Failed to copy Node.exe. '$NODE_RELEASE_EXE' not found!"
    exit 1
}

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

Write-Host "-> Copying 'assets' and 'js' files..."
Copy-Item -Path (Join-Path $PHROST_RUNTIME_DIR "assets") -Destination $PHROST_GAME_DIR -Recurse -Force

# Copy JS files (assuming they are in Runtime/js based on conversion)
# If they are in a different folder, adjust "js\*" below.
if (Test-Path (Join-Path $PHROST_RUNTIME_DIR "javascript")) {
    Copy-Item -Path (Join-Path $PHROST_RUNTIME_DIR "javascript\*") -Destination $PHROST_GAME_DIR -Recurse -Force
} else {
    Write-Warning "Runtime/javascript directory not found. Make sure generated JS files are placed there."
}

# --- Move settings.json to Root ---
$SOURCE_SETTINGS_PATH = Join-Path $PHROST_GAME_DIR "settings.json"
if (Test-Path -Path $SOURCE_SETTINGS_PATH) {
    Move-Item -Path $SOURCE_SETTINGS_PATH -Destination $PHROST_RELEASE_DIR -Force
    Write-Host "-> settings.json moved successfully."
}

# --- Install Runtime Packages (NPM) ---
Write-Host "### 3. Installing NPM Packages... ###"

Set-Location $PHROST_GAME_DIR

if (Test-Path "package.json") {
    Write-Host "Running npm install..."
    # We use the npm from the SDK source just to be safe, or global npm
    # If npm.cmd exists in the SDK node root, use it:
    if (Test-Path $NPM_BIN) {
        & $NPM_BIN install
    } else {
        Write-Warning "NPM binary not found in SDK root, trying system npm..."
        npm install
    }
} else {
    Write-Host "No package.json found in game dir, skipping npm install."
}

Write-Host ""
Write-Host "### All steps completed successfully. ###"
Write-Host "Returning to starting directory: $STARTING_LOCATION"
Set-Location $STARTING_LOCATION
