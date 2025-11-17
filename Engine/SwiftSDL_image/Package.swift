// swift-tools-version: 6.2.0
import Foundation  // Required for ProcessInfo
import PackageDescription

// --- Read Environment Variables ---
let env = ProcessInfo.processInfo.environment
let sdlIncludePath = env["SDL3_INCLUDE"]
let sdlLibraryPath = env["SDL3_LIB"]
let sdlImageIncludePath = env["SDL3_IMAGE_INCLUDE"]
let sdlImageLibraryPath = env["SDL3_IMAGE_LIB"]

// --- Diagnostic Print ---
print("--- SwiftSDL_image Manifest Diagnostic ---")
print("SDL3_INCLUDE env var is: \(sdlIncludePath ?? "NOT SET")")
print("SDL3_LIB env var is: \(sdlLibraryPath ?? "NOT SET")")
print("SDL3_IMAGE_INCLUDE env var is: \(sdlImageIncludePath ?? "NOT SET")")
print("SDL3_IMAGE_LIB env var is: \(sdlImageLibraryPath ?? "NOT SET")")
print("---------------------------------------")

// --- Prepare Settings ---
var csdl3ImageCSettings: [CSetting] = []
var swiftSettings: [SwiftSetting] = []  // Needed to pass include paths to Swift importer
var linkerSettings: [LinkerSetting] = []

// --- Platform Specific Settings ---
#if os(macOS) || os(iOS) || os(tvOS)
    // --- Core SDL3 Paths ---
    if let includePath = sdlIncludePath {
        csdl3ImageCSettings.append(.unsafeFlags(["-I", includePath]))
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

    // --- SDL_image Specific Paths ---
    if let includePath = sdlImageIncludePath {
        csdl3ImageCSettings.append(.unsafeFlags(["-I", includePath]))
        // Add SDL_image include path for Swift too
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    } else {
        print("Warning: SDL3_IMAGE_INCLUDE environment variable not set.")
        // fatalError("SDL3_IMAGE_INCLUDE environment variable must be set.")
    }
    if let libPath = sdlImageLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    } else {
        print("Warning: SDL3_IMAGE_LIB environment variable not set.")
        // fatalError("SDL3_IMAGE_LIB environment variable must be set.")
    }
    linkerSettings.append(.linkedLibrary("SDL3_image"))  // Link static libSDL3_image.a

    // --- System Frameworks ---
    // Start with SDL3's dependencies
    linkerSettings.append(contentsOf: [
        .linkedFramework("AudioToolbox"),
        .linkedFramework("AVFoundation"),
        .linkedFramework("CoreAudio"),
        .linkedFramework("CoreGraphics"),
        .linkedFramework("CoreHaptics"),
        .linkedFramework("CoreMotion"),
        .linkedFramework("Foundation"),
        .linkedFramework("GameController"),
        .linkedFramework("IOKit"),
        .linkedFramework("Metal"),
    ])
    // Add frameworks needed specifically by SDL_image
    linkerSettings.append(contentsOf: [
        .linkedFramework("ImageIO")  // For JPG, PNG, TIFF, etc. on Apple platforms
        // Potentially add WebKit if building with SVG support, etc.
    ])
    // Platform-specific UI frameworks
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
// Add any frameworks needed by third-party image libraries you enabled (e.g., libjpeg, libpng, webp)
// Example: linkerSettings.append(.linkedLibrary("jpeg")) // If linking against brew's libjpeg

#elseif os(Windows)
    // --- Core SDL3 Paths ---
    if let includePath = sdlIncludePath {
        csdl3ImageCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I", "-Xcc", "\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))

    // --- SDL_image Specific Paths ---
    if let includePath = sdlImageIncludePath {
        csdl3ImageCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I", "-Xcc", "\(includePath)"]))
    }
    if let libPath = sdlImageLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3_image"))  // Adjust if name differs

#elseif os(Linux)
    // Rely on pkg-config or environment variables
    if let includePath = sdlIncludePath {
        csdl3ImageCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    }
    if let libPath = sdlLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    if let includePath = sdlImageIncludePath {
        csdl3ImageCSettings.append(.unsafeFlags(["-I", includePath]))
        swiftSettings.append(.unsafeFlags(["-Xcc", "-I\(includePath)"]))
    }
    if let libPath = sdlImageLibraryPath {
        linkerSettings.append(.unsafeFlags(["-L\(libPath)"]))
    }
    linkerSettings.append(.linkedLibrary("SDL3"))
    linkerSettings.append(.linkedLibrary("SDL3_image"))
// .pkgConfig("sdl3") // Could be fallbacks
// .pkgConfig("sdl3_image")
#endif

let package = Package(
    name: "SwiftSDL_image",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "SwiftSDL_image", targets: ["SwiftSDL_image"]),
        // You might not need to export CSDL3_image directly anymore
        .library(name: "CSDL3_image", targets: ["CSDL3_image"]),
    ],
    dependencies: [
        .package(path: "../SwiftSDL"),  // Depends on your SwiftSDL package
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // REMOVED: .binaryTarget for SDL3_image

        // C-interop target using environment variables
        .target(
            name: "CSDL3_image",
            dependencies: [
                .product(name: "CSDL3", package: "SwiftSDL")  // Depend on SwiftSDL's C target
            ],
            path: "Dependencies/CSDL3_image",  // Your shim/module map location
            publicHeadersPath: ".",
            cSettings: csdl3ImageCSettings,
            swiftSettings: swiftSettings,  // Pass include paths to Swift side
            linkerSettings: linkerSettings
        ),

        // REMOVED: CSDL_image target

        .target(
            name: "SwiftSDL_image",
            dependencies: [
                .product(name: "SwiftSDL", package: "SwiftSDL"),  // Depends on the main SwiftSDL library
                .target(name: "CSDL3_image"),  // Use the configured C target for all platforms
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
            // Linker settings moved to CSDL3_image target
        ),

        // TestBench target remains commented out
    ]
)
