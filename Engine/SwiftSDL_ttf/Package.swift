import Foundation  // Required for ProcessInfo
// swift-tools-version: 6.2.0
import PackageDescription

// --- Read Environment Variables ---
let env = ProcessInfo.processInfo.environment
let sdlIncludePath = env["SDL3_INCLUDE"]
let sdlLibraryPath = env["SDL3_LIB"]
let sdlTtfIncludePath = env["SDL3_TTF_INCLUDE"]  // Specific variable for TTF
let sdlTtfLibraryPath = env["SDL3_TTF_LIB"]  // Specific variable for TTF

// --- Diagnostic Print ---
print("--- SwiftSDL_ttf Manifest Diagnostic ---")
print("SDL3_INCLUDE env var is: \(sdlIncludePath ?? "NOT SET")")
print("SDL3_LIB env var is: \(sdlLibraryPath ?? "NOT SET")")
print("SDL3_TTF_INCLUDE env var is: \(sdlTtfIncludePath ?? "NOT SET")")
print("SDL3_TTF_LIB env var is: \(sdlTtfLibraryPath ?? "NOT SET")")
print("--------------------------------------")

// --- Prepare Settings ---
var csdl3TtfCSettings: [CSetting] = []
var swiftSettings: [SwiftSetting] = []  // Needed to pass include paths to Swift importer
var linkerSettings: [LinkerSetting] = []

// --- Platform Specific Settings ---
#if os(macOS) || os(iOS) || os(tvOS)
    // --- Core SDL3 Paths ---
    if let includePath = sdlIncludePath {
        csdl3TtfCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    } else {
        print("Warning: SDL3_INCLUDE environment variable not set.")
        // fatalError("SDL3_INCLUDE environment variable must be set.")
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    } else {
        print("Warning: SDL3_LIB environment variable not set.")
        // fatalError("SDL3_LIB environment variable must be set.")
    }
    linkerSettings.append(.linkedLibrary("SDL3"))

    // --- SDL_ttf Specific Paths ---
    if let includePath = sdlTtfIncludePath {
        csdl3TtfCSettings.append(.unsafeFlags(["-I", includePath]))
        // Add SDL_ttf include path for Swift too
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    } else {
        print("Warning: SDL3_TTF_INCLUDE environment variable not set.")
        // fatalError("SDL3_TTF_INCLUDE environment variable must be set.")
    }
    if let libPath = sdlTtfLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    } else {
        print("Warning: SDL3_TTF_LIB environment variable not set.")
        // fatalError("SDL3_TTF_LIB environment variable must be set.")
    }
    linkerSettings.append(.linkedLibrary("SDL3_ttf"))  // Link static libSDL3_ttf.a

    // --- System Frameworks ---
    // Start with SDL3's dependencies
    linkerSettings.append(contentsOf: [
        // SDL3 Core Dependencies (ensure these are also in SwiftSDL's CSDL3 target)
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
        .linkedFramework("QuartzCore"),
        .linkedFramework("CoreServices"),
        // SDL_ttf Specific Dependencies
        .linkedFramework("CoreText"),
        .linkedFramework("AppKit"),
        .linkedFramework("Security"),
    ])
    linkerSettings.append(.unsafeFlags(["-L/opt/homebrew/lib"]))
    linkerSettings.append(contentsOf: [
        .linkedLibrary("freetype"),
        .linkedLibrary("harfbuzz"),
    ])

#elseif os(Windows)
    // Reuse variable names, ensure SDL3_TTF_INCLUDE/LIB are set in env
    // --- Core SDL3 Paths ---
    if let includePath = sdlIncludePath {
        csdl3TtfCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I", "-Xcc", "\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))

    // --- SDL_ttf Specific Paths ---
    if let includePath = sdlTtfIncludePath {
        csdl3TtfCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I", "-Xcc", "\(includePath)"]))
    }
    if let libPath = sdlTtfLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3_ttf"))  // Adjust if name differs

#elseif os(Linux)
    // Rely on pkg-config or environment variables
    if let includePath = sdlIncludePath {
        csdl3TtfCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    if let includePath = sdlTtfIncludePath {
        csdl3TtfCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    }
    if let libPath = sdlTtfLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))
    linkerSettings.append(.linkedLibrary("SDL3_ttf"))
// .pkgConfig("sdl3") // Could be fallbacks
// .pkgConfig("sdl3_ttf")
// .pkgConfig("freetype2") // Often needed on Linux
#endif

let package = Package(
    name: "SwiftSDL_ttf",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "SwiftSDL_ttf", targets: ["SwiftSDL_ttf"]),
        // You might not need to export CSDL3_ttf directly anymore
        .library(name: "CSDL3_ttf", targets: ["CSDL3_ttf"]),
    ],
    dependencies: [
        .package(path: "../SwiftSDL"),  // Depends on your SwiftSDL package
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // REMOVED: .binaryTarget for SDL3_ttf

        // C-interop target using environment variables
        .target(
            name: "CSDL3_ttf",
            dependencies: [
                .product(name: "CSDL3", package: "SwiftSDL")  // Depend on SwiftSDL's C target
            ],
            path: "Dependencies/CSDL3_ttf",  // Your shim/module map location
            publicHeadersPath: ".",
            cSettings: csdl3TtfCSettings,
            swiftSettings: swiftSettings,  // Pass include paths to Swift side
            linkerSettings: linkerSettings
        ),

        // REMOVED: CSDL_ttf target

        .target(
            name: "SwiftSDL_ttf",
            dependencies: [
                .product(name: "SwiftSDL", package: "SwiftSDL"),  // Depends on the main SwiftSDL library
                .target(name: "CSDL3_ttf"),  // Use the configured C target for all platforms
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
            // Linker settings moved to CSDL3_ttf target
        ),

        // TestBench target remains commented out
    ]
)
