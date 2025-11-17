# Function to detect architecture
function Get-PlatformArchitecture {
    $arch = (Get-CimInstance -Class Win32_Processor).AddressWidth
    if ($arch -eq 64) {
        $processorArchitecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
        if ($processorArchitecture -like "*ARM*") {
            return "arm64-windows"
        } else {
            return "x64-windows"
        }
    } else {
        return "x86-windows"
    }
}

# Detect the platform architecture and set the folder name
$platformFolder = Get-PlatformArchitecture
Write-Host "`nDetected platform: $platformFolder"

# Set default encoding to UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Define paths
$vcpkgPath = "$PSScriptRoot\vcpkg"

# Check if vcpkg is already cloned
if (!(Test-Path -Path $vcpkgPath)) {
    Write-Host "Cloning vcpkg..."
    git clone https://github.com/Microsoft/vcpkg.git
    & "$vcpkgPath\bootstrap-vcpkg.bat"
    & "$vcpkgPath\vcpkg" integrate powershell
} else {
    Write-Host "vcpkg already exists. Skipping clone and bootstrap."
}

# Install pkgconf if not already installed
if (!(Test-Path -Path "$vcpkgPath\installed\$platformFolder\tools\pkgconf")) {
    Write-Host "Installing pkgconf..."
    & "$vcpkgPath\vcpkg.exe" install pkgconf --triplet $platformFolder --no-print-usage
} else {
    Write-Host "pkgconf is already installed. Skipping installation."
}
$pkgconfPath = "$vcpkgPath\installed\$platformFolder\tools\pkgconf"
$env:Path += ';' + $pkgconfPath
$env:PKG_CONFIG_PATH = "$vcpkgPath\installed\$platformFolder\lib\pkgconfig"

Write-Host "`nEnvironment Variables:"
Write-Host "PATH = $env:Path"
Write-Host "PKG_CONFIG_PATH = $env:PKG_CONFIG_PATH"

# Install required library (Chipmunk2D) via vcpkg
$requiredLib = "chipmunk"
if (!(Test-Path -Path "$vcpkgPath\installed\$platformFolder\lib\pkgconfig\$requiredLib.pc")) {
    Write-Host "`nInstalling $requiredLib..."
    & "$vcpkgPath\vcpkg.exe" install $requiredLib --recurse --triplet $platformFolder --no-print-usage
} else {
    Write-Host "$requiredLib is already installed. Skipping installation."
}

# Verify Chipmunk2D is installed correctly
$chipmunkHeaderPath = "$vcpkgPath\installed\$platformFolder\include\chipmunk\chipmunk.h"
if (!(Test-Path -Path $chipmunkHeaderPath)) {
    Write-Error "Chipmunk2D header not found at $chipmunkHeaderPath"
    exit 1
} else {
    Write-Host "`nChipmunk2D header found: $chipmunkHeaderPath"
}

# Generate Chipmunk2D windows header only if it doesn't exist
$windowsHeaderPath = "Sources\CChipmunk2D\windows_generated.h"
$windowsHeaderDir = [System.IO.Path]::GetDirectoryName($windowsHeaderPath)

# Ensure the directory exists
if (!(Test-Path -Path $windowsHeaderDir)) {
    Write-Host "`nCreating directory: $windowsHeaderDir"
    New-Item -ItemType Directory -Path $windowsHeaderDir | Out-Null
}

if (!(Test-Path -Path $windowsHeaderPath)) {
    Write-Host "`nGenerating Chipmunk2D windows header..."
    
    # Hardcode the include directory for Chipmunk2D
    $chipmunkIncludedir = "$vcpkgPath\installed\$platformFolder\include\chipmunk"
    Write-Host "Chipmunk2D include directory: $chipmunkIncludedir"

    '#include "' + $chipmunkIncludedir + '\chipmunk.h"' | Out-File -FilePath $windowsHeaderPath -Append -Encoding utf8
} else {
    Write-Host "Chipmunk2D windows header already exists. Skipping generation."
}

# Set environment variables for Chipmunk2D if not already set
if ($env:INCLUDE -notlike "*$vcpkgPath\installed\$platformFolder\include*") {
    Write-Host "`nSetting up environment variables for Chipmunk2D..."
    $env:INCLUDE = "$vcpkgPath\installed\$platformFolder\include;" + $env:INCLUDE
    $env:LIB = "$vcpkgPath\installed\$platformFolder\lib;" + $env:LIB
    $env:Path += ";$vcpkgPath\installed\$platformFolder\bin"

    Write-Host "`nEnvironment variables set for Chipmunk2D."
} else {
    Write-Host "Environment variables for Chipmunk2D are already set. Skipping."
}

Write-Host "`nBuilding Swift package..."

# Build Swift project without cleaning if .build folder exists
if (!(Test-Path -Path ".\.build")) {
    Write-Host "`nNo existing build found. Building from scratch..."
    swift build --configuration debug -v
    swift build --configuration release -v
} else {
    Write-Host "`nIncremental build..."
    swift build --configuration debug -v
    swift build --configuration release -v
}

# Copy Chipmunk2D libraries if not already copied
$chipmunkLibPath = "$vcpkgPath\installed\$platformFolder\bin\chipmunk.dll"
$chipmunkLibLibPath = "$vcpkgPath\installed\$platformFolder\lib\chipmunk.lib"

# Ensure DLLs and LIBs exist
if (!(Test-Path $chipmunkLibPath)) {
    Write-Error "Chipmunk.dll not found at $chipmunkLibPath"
    exit 1
}
if (!(Test-Path $chipmunkLibLibPath)) {
    Write-Error "Chipmunk.lib not found at $chipmunkLibLibPath"
    exit 1
}

# Set LIB environment variable for linker if not already set
if ($env:LIB -notlike "*$chipmunkLibLibPath*") {
    $env:LIB += ";$chipmunkLibLibPath"
    Write-Host "LIB environment variable: $env:LIB"
} else {
    Write-Host "LIB environment variable already includes Chipmunk2D lib path. Skipping."
}

$configurations = @("debug", "release")
$arch = "x86_64-unknown-windows-msvc"  # Adjust this if your architecture is different

foreach ($config in $configurations) {
    $buildPath = ".build\$arch\$config"
    Write-Host "`nProcessing build configuration: $config"
    Write-Host "Build path: $buildPath"
    if (Test-Path -Path $buildPath) {
        if (!(Test-Path -Path "$buildPath\chipmunk.dll")) {
            Write-Host "Copying chipmunk.dll to $buildPath"
            Copy-Item $chipmunkLibPath -Destination $buildPath -Force
        } else {
            Write-Host "chipmunk.dll already exists in $buildPath. Skipping copy."
        }
    } else {
        Write-Host "Build path $buildPath does not exist, skipping..."
    }
}
