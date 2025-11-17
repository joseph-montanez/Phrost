import Foundation  // Required for ProcessInfo
// swift-tools-version: 6.0.0
import PackageDescription

// --- Read Environment Variables ---
let env = ProcessInfo.processInfo.environment
let sdlIncludePath = env["SDL3_INCLUDE"]
let sdlLibraryPath = env["SDL3_LIB"]

// --- Diagnostic Print ---
print("--- SwiftSDL Manifest Diagnostic ---")
print("SDL3_INCLUDE env var is: \(sdlIncludePath ?? "NOT SET")")
print("SDL3_LIB env var is: \(sdlLibraryPath ?? "NOT SET")")
print("----------------------------------")

// --- Prepare Settings ---
var csdl3CSettings: [CSetting] = []
var swiftSettings: [SwiftSetting] = []
var linkerSettings: [LinkerSetting] = []

// --- Platform Specific Settings ---
#if os(macOS) || os(iOS) || os(tvOS)
    // Use environment variables for include and library paths
    if let includePath = sdlIncludePath {
        csdl3CSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))  // Pass include path to Swift via Clang importer
    } else {
        // Fallback or error if SDL3_INCLUDE is not set
        print(
            "Warning: SDL3_INCLUDE environment variable not set. Header search path might be missing."
        )
        // Optionally, add a default path or make it an error:
        // fatalError("SDL3_INCLUDE environment variable must be set.")
    }

    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))  // Add library search path
    } else {
        // Fallback or error if SDL3_LIB is not set
        print(
            "Warning: SDL3_LIB environment variable not set. Library search path might be missing.")
        // Optionally, add a default path or make it an error:
        // fatalError("SDL3_LIB environment variable must be set.")
    }

    linkerSettings.append(.linkedLibrary("SDL3"))  // Link the static library (libSDL3.a)

    // Add required system frameworks for SDL3 on Apple platforms
    linkerSettings.append(contentsOf: [
        .linkedFramework("AudioToolbox"),
        .linkedFramework("AVFoundation"),
        .linkedFramework("CoreAudio"),
        .linkedFramework("CoreGraphics"),
        .linkedFramework("CoreHaptics"),
        .linkedFramework("CoreMedia"),
        .linkedFramework("CoreMotion"),
        .linkedFramework("CoreVideo"),
        .linkedFramework("ForceFeedback"),
        .linkedFramework("Foundation"),
        .linkedFramework("GameController"),
        .linkedFramework("IOKit"),
        .linkedFramework("Metal"),
        .linkedFramework("UniformTypeIdentifiers"),
        .linkedFramework("AppKit"),
        .linkedFramework("Security"),
        .linkedFramework("Carbon"),
    ])

#elseif os(Windows)
    if let includePath = sdlIncludePath {  // Reuse env var name
        csdl3CSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I", "-Xcc", "\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {  // Reuse env var name
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))  // Adjust library name if different on Windows
#elseif os(Linux)
    // For Linux, rely on pkg-config by default or expect env vars if needed
    if let includePath = sdlIncludePath {
        csdl3CSettings.append(.headerSearchPath(includePath))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))
// .pkgConfig("sdl3") // Could still be a fallback
#endif

let package = Package(
    name: "SwiftSDL",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "SwiftSDL", targets: ["SwiftSDL"]),
        .library(name: "CSDL3", targets: ["CSDL3"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(
            url: "https://github.com/apple/swift-collections.git", .upToNextMinor(from: "1.1.4")),
    ],
    targets: [
        // CSDL3 now handles finding SDL3 on all platforms using env vars or defaults
        .target(
            name: "CSDL3",
            path: "Dependencies/CSDL3",
            publicHeadersPath: ".",
            cSettings: csdl3CSettings,
            swiftSettings: swiftSettings,  // Pass include path to Swift side
            linkerSettings: linkerSettings
        ),

        .target(
            name: "SwiftSDL",
            dependencies: [
                .target(name: "CSDL3"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
    ]
)
