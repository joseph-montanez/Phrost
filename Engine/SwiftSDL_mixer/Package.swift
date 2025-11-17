import Foundation  // Required for ProcessInfo
// swift-tools-version: 6.2.0
import PackageDescription

// --- Read Environment Variables ---
let env = ProcessInfo.processInfo.environment
let sdlIncludePath = env["SDL3_INCLUDE"]
let sdlLibraryPath = env["SDL3_LIB"]
let sdlMixerIncludePath = env["SDL3_MIXER_INCLUDE"]  // Specific variable for Mixer
let sdlMixerLibraryPath = env["SDL3_MIXER_LIB"]  // Specific variable for Mixer

// --- Diagnostic Print ---
print("--- SwiftSDL_mixer Manifest Diagnostic ---")
print("SDL3_INCLUDE env var is: \(sdlIncludePath ?? "NOT SET")")
print("SDL3_LIB env var is: \(sdlLibraryPath ?? "NOT SET")")
print("SDL3_MIXER_INCLUDE env var is: \(sdlMixerIncludePath ?? "NOT SET")")
print("SDL3_MIXER_LIB env var is: \(sdlMixerLibraryPath ?? "NOT SET")")
print("----------------------------------------")

// --- Prepare Settings ---
var csdl3MixerCSettings: [CSetting] = []
var swiftSettings: [SwiftSetting] = []  // Needed to pass include paths to Swift importer
var linkerSettings: [LinkerSetting] = []

// --- Platform Specific Settings ---
#if os(macOS) || os(iOS) || os(tvOS)
    // --- Core SDL3 Paths ---
    if let includePath = sdlIncludePath {
        csdl3MixerCSettings.append(.unsafeFlags(["-I", includePath]))
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

    // --- SDL_mixer Specific Paths ---
    if let includePath = sdlMixerIncludePath {
        csdl3MixerCSettings.append(.unsafeFlags(["-I", includePath]))
        // Add SDL_mixer include path for Swift too
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    } else {
        print("Warning: SDL3_MIXER_INCLUDE environment variable not set.")
        // fatalError("SDL3_MIXER_INCLUDE environment variable must be set.")
    }
    if let libPath = sdlMixerLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    } else {
        print("Warning: SDL3_MIXER_LIB environment variable not set.")
        // fatalError("SDL3_MIXER_LIB environment variable must be set.")
    }
    linkerSettings.append(.linkedLibrary("SDL3_mixer"))  // Link static libSDL3_mixer.a

    // --- System Frameworks ---
    // Start with SDL3's dependencies
    linkerSettings.append(contentsOf: [
        .linkedFramework("AudioToolbox"),  // Essential for audio on Apple platforms
        .linkedFramework("AVFoundation"),
        .linkedFramework("CoreAudio"),  // Essential for audio on Apple platforms
        .linkedFramework("CoreGraphics"),
        .linkedFramework("CoreHaptics"),
        .linkedFramework("CoreMotion"),
        .linkedFramework("Foundation"),
        .linkedFramework("GameController"),
        .linkedFramework("IOKit"),
        .linkedFramework("Metal"),
    ])
    // Add frameworks needed specifically by SDL_mixer (often just audio ones already included)
    // linkerSettings.append(contentsOf: [
    //     // Add others if needed based on enabled mixer features
    // ])

    // Platform-specific UI frameworks (Usually needed by SDL3 itself)
    #if os(macOS)
        linkerSettings.append(contentsOf: [
            .linkedFramework("AppKit"),
            .linkedFramework("Security"),
        ])
    #else
        linkerSettings.append(contentsOf: [
            .linkedFramework("UIKit"),
            .linkedFramework("OpenGLES"),
        ])
    #endif

// Add libraries needed by enabled external decoders/synthesizers (e.g., ogg, vorbis, flac, mpg123)
// You MUST link these if SDL_mixer was built *against* them.
// Examples (adjust based on your SDL_mixer build config):
// linkerSettings.append(.linkedLibrary("ogg"))    // If using system libogg
// linkerSettings.append(.linkedLibrary("vorbisfile")) // If using system libvorbis
// linkerSettings.append(.linkedLibrary("FLAC"))   // If using system libFLAC
// linkerSettings.append(.linkedLibrary("mpg123")) // If using system libmpg123
// Ensure the -L paths for these libraries (e.g., from Homebrew) are also added if needed.
// If you used Homebrew: linkerSettings.append(.unsafeFlags(["-L/opt/homebrew/lib"]))

#elseif os(Windows)
    // Reuse variable names, ensure SDL3_MIXER_INCLUDE/LIB are set in env
    // --- Core SDL3 Paths ---
    if let includePath = sdlIncludePath {
        csdl3MixerCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I", "-Xcc", "\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))

    // --- SDL_mixer Specific Paths ---
    if let includePath = sdlMixerIncludePath {
        csdl3MixerCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I", "-Xcc", "\(includePath)"]))
    }
    if let libPath = sdlMixerLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3_mixer"))  // Adjust if name differs

#elseif os(Linux)
    // Rely on pkg-config or environment variables
    if let includePath = sdlIncludePath {
        csdl3MixerCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    if let includePath = sdlMixerIncludePath {
        csdl3MixerCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    }
    if let libPath = sdlMixerLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))
    linkerSettings.append(.linkedLibrary("SDL3_mixer"))
// .pkgConfig("sdl3") // Could be fallbacks
// .pkgConfig("sdl3_mixer")
// Link other deps like vorbisfile, ogg, flac, mpg123 etc. via pkgConfig or -l flags
#endif

let package = Package(
    name: "SwiftSDL_mixer",  // Corrected package name
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "SwiftSDL_mixer", targets: ["SwiftSDL_mixer"])
        // Exporting CSDL3_mixer is likely unnecessary unless another package needs *only* the C bindings
        // .library(name: "CSDL3_mixer", targets: ["CSDL3_mixer"]),
    ],
    dependencies: [
        .package(path: "../SwiftSDL"),  // Depends on your SwiftSDL package
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // REMOVED: .binaryTarget for SDL3_mixer

        // C-interop target using environment variables
        .target(
            name: "CSDL3_mixer",
            dependencies: [
                .product(name: "CSDL3", package: "SwiftSDL")  // Depend on SwiftSDL's C target
            ],
            path: "Dependencies/CSDL3_mixer",  // Your shim/module map location
            publicHeadersPath: ".",
            cSettings: csdl3MixerCSettings,
            swiftSettings: swiftSettings,  // Pass include paths to Swift side
            linkerSettings: linkerSettings
        ),

        // REMOVED: CSDL_Mixer target

        .target(
            name: "SwiftSDL_mixer",
            dependencies: [
                .product(name: "SwiftSDL", package: "SwiftSDL"),  // Depends on the main SwiftSDL library
                .target(name: "CSDL3_mixer"),  // Use the configured C target for all platforms
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
            // Linker settings moved to CSDL3_mixer target
        ),

        // TestBench target remains commented out
    ]
)
