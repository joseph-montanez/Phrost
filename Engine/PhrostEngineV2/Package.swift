// swift-tools-version: 6.2
import CompilerPluginSupport
import Foundation
import PackageDescription

let env = ProcessInfo.processInfo.environment

// --- SwiftSDL Local Package Paths ---
let swiftChipmunk2DPath = env["SWIFTCHIPMUNK2D_PATH"] ?? "../SwiftChipmunk2D"
let swiftMiniAudioPath = env["SWIFTMINIAUDIO_PATH"] ?? "../miniaudio-swift"
let swiftSDLPath = env["SWIFTSDL_PATH"] ?? "../SwiftSDL"
let swiftSDLImagePath = env["SWIFTSDL_IMAGE_PATH"] ?? "../SwiftSDL_image"
let swiftSDLTtfPath = env["SWIFTSDL_TTF_PATH"] ?? "../SwiftSDL_ttf"

// --- Client Type Configuration ---
let clientType = (env["CLIENT_TYPE"] ?? "php").lowercased()
var clientDefines: [SwiftSetting] = []

print("--- Building PhrostBinary for \(clientType.uppercased()) ---")

switch clientType {
case "php":
    clientDefines.append(.define("USE_PHP"))
case "python":
    clientDefines.append(.define("USE_PYTHON"))
case "lua":
    clientDefines.append(.define("USE_LUA"))
case "luajit":
    clientDefines.append(.define("USE_LUAJIT"))
case "node":
    clientDefines.append(.define("USE_NODE"))
case "bun":
    clientDefines.append(.define("USE_BUN"))
case "deno":
    clientDefines.append(.define("USE_DENO"))
default:
    print("--- WARNING: Unknown CLIENT_TYPE '\(clientType)'. Defaulting to PHP. ---")
    clientDefines.append(.define("USE_PHP"))
}

// --- Flag to determine if we build PHP extension ---
// We only build PHP components if the client type is explicitly PHP.
let buildPHPExtension = (clientType == "php")

// --- PHP Paths (Only relevant if building PHP) ---
#if os(macOS)
    let includePHPXCFramework = false
    let phpSrc = env["PHP_SRC_ROOT"] ?? "../deps/buildroot/include/php"
    let phpLib = ""
    let excludeFiles: [String] = []
#elseif os(Windows)
    let includePHPXCFramework = false
    let phpSrc = env["PHP_SRC_ROOT"] ?? "D:/dev/php-src"
    let phpLib = env["PHP_LIB_ROOT"] ?? "D:/dev/php-src/libs"
    let excludeFiles: [String] = []
#else
    let includePHPXCFramework = false
    let phpSrc = env["PHP_SRC_ROOT"] ?? "../deps/source/php-src"
    let phpLib = ""
    let excludeFiles: [String] = []
#endif

var sdlIncludeFlags: [String] = []
var sdlLinkerFlags: [LinkerSetting] = []

#if os(Windows) || os(linux)
    if let includePath = env["CHIPMUNK2D_INCLUDE"] {
        sdlIncludeFlags.append(contentsOf: ["-Xcc", "-I", "-Xcc", includePath])
    }
    if let libPath = env["CHIPMUNK2D_LIB"] {
        sdlLinkerFlags.append(.unsafeFlags(["-L\(libPath)"]))
    }
    sdlLinkerFlags.append(.linkedLibrary("chipmunk"))

    if let includePath = env["SDL3_INCLUDE"] {
        sdlIncludeFlags.append(contentsOf: ["-Xcc", "-I", "-Xcc", includePath])
    }
    if let libPath = env["SDL3_LIB"] {
        sdlLinkerFlags.append(.unsafeFlags(["-L\(libPath)"]))
    }
    sdlLinkerFlags.append(.linkedLibrary("SDL3"))

    // --- SDL_image Specific Paths ---
    if let includePath = env["SDL3_IMAGE_INCLUDE"] {
        sdlIncludeFlags.append(contentsOf: ["-Xcc", "-I", "-Xcc", includePath])
    }
    if let libPath = env["SDL3_IMAGE_LIB"] {
        sdlLinkerFlags.append(.unsafeFlags(["-L\(libPath)"]))
    }
    sdlLinkerFlags.append(.linkedLibrary("SDL3_image"))

    // --- SDL_ttf Specific Paths ---
    if let includePath = env["SDL3_TTF_INCLUDE"] {
        sdlIncludeFlags.append(contentsOf: ["-Xcc", "-I", "-Xcc", includePath])
    }
    if let libPath = env["SDL3_TTF_LIB"] {
        sdlLinkerFlags.append(.unsafeFlags(["-L\(libPath)"]))
    }
    sdlLinkerFlags.append(.linkedLibrary("SDL3_ttf"))
#endif

// --- Target Definitions ---

var targets: [Target] = [
    .target(
        name: "PhrostEngineCore",
        dependencies: [
            .product(name: "Chipmunk2D", package: "SwiftChipmunk2D"),
            .product(name: "SwiftSDL", package: "SwiftSDL"),
            .product(name: "SwiftSDL_image", package: "SwiftSDL_image"),
            .product(name: "SwiftSDL_ttf", package: "SwiftSDL_ttf"),
            .product(name: "CMiniaudio", package: "Miniaudio"),
            .product(name: "ImGui", package: "SwiftImGui"),
        ],
        path: "Sources/PhrostEngineCore",
        swiftSettings: [
            .unsafeFlags(sdlIncludeFlags, .when(platforms: [.windows, .linux]))
        ],
        linkerSettings: sdlLinkerFlags
    ),

    .target(
        name: "PhrostEngineLib",
        dependencies: [
            "PhrostEngineCore",
            "SwiftSDL",
        ]
    ),

    .executableTarget(
        name: "PhrostIPC",
        dependencies: [
            "PhrostEngineCore"
        ],
        path: "Sources/PhrostIPC",
        swiftSettings: [
            .unsafeFlags(sdlIncludeFlags, .when(platforms: [.windows, .linux]))
        ],
        linkerSettings: [
            .linkedLibrary("Kernel32", .when(platforms: [.windows]))
        ] + sdlLinkerFlags
    ),

    .executableTarget(
        name: "PhrostBinary",
        dependencies: [],
        path: "Sources/PhrostBinary",
        swiftSettings: clientDefines,
        linkerSettings: []
    ),
]

// --- PHP Specific Targets (Conditionally Added) ---
if buildPHPExtension {
    targets.append(contentsOf: [
        .target(
            name: "PHPCore",
            dependencies: [ "CSwiftPHP" ],
            path: "Sources/PHPCore",
            cSettings: [
                .unsafeFlags(["-UHAVE_BUILTIN_CONSTANT_P"], .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .define("ZEND_WIN32", .when(platforms: [.windows])),
                .define("PHP_WIN32", .when(platforms: [.windows])),
                .define("WIN32", .when(platforms: [.windows])),
                .define("_WIN32", .when(platforms: [.windows])),
                .define("_WINDOWS", .when(platforms: [.windows])),
                .define("NTS_SWIFT", .when(platforms: [.windows, .macOS])),
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-UHAVE_BUILTIN_CONSTANT_P"], .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .define("NTS_SWIFT", .when(platforms: [.windows, .macOS])),
                .unsafeFlags(
                    [
                        "-Xcc", "-include", "-Xcc", "intrin.h",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/main",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/Zend",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/TSRM",
                    ], .when(platforms: [.windows])),
            ]
        ),
        .target(
            name: "CSwiftPHP",
            dependencies: [],
            path: "Sources/CSwiftPHP",
            publicHeadersPath: ".",
            cSettings: [
                .unsafeFlags(["-UHAVE_BUILTIN_CONSTANT_P"], .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .define("ZEND_WIN32", .when(platforms: [.windows])),
                .define("PHP_WIN32", .when(platforms: [.windows])),
                .define("WIN32", .when(platforms: [.windows])),
                .define("_WIN32", .when(platforms: [.windows])),
                .define("_WINDOWS", .when(platforms: [.windows])),
                .define("NTS_SWIFT", .when(platforms: [.windows, .macOS, .iOS])),
                .unsafeFlags(
                    [
                        "-I", phpSrc,
                        "-I", "\(phpSrc)/main",
                        "-I", "\(phpSrc)/Zend",
                        "-I", "\(phpSrc)/TSRM",
                        "-I", "\(phpSrc)/win32",
                        "-fno-builtin",
                        "-include", "intrin.h",
                    ], .when(platforms: [.windows])),
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-UHAVE_BUILTIN_CONSTANT_P"], .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .define("NTS_SWIFT", .when(platforms: [.windows, .macOS, .iOS])),
                .define("ZEND_WIN32", .when(platforms: [.windows])),
                .define("PHP_WIN32", .when(platforms: [.windows])),
                .define("WIN32", .when(platforms: [.windows])),
                .unsafeFlags(
                    [
                        "-Xcc", "-include", "-Xcc", "intrin.h",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/main",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/Zend",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/TSRM",
                    ], .when(platforms: [.windows])),
            ]
        ),
        .target(
            name: "SwiftPHPExtension",
            dependencies: [
                "PHPCore",
                "CSwiftPHP",
                "PhrostEngineCore",
            ],
            path: "Sources/SwiftPHPExtension",
            exclude: excludeFiles,
            cSettings: [
                .unsafeFlags(["-UHAVE_BUILTIN_CONSTANT_P"], .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .define("ZEND_WIN32", .when(platforms: [.windows])),
                .define("PHP_WIN32", .when(platforms: [.windows])),
                .define("WIN32", .when(platforms: [.windows])),
                .define("_WIN32", .when(platforms: [.windows])),
                .define("_WINDOWS", .when(platforms: [.windows])),
                .define("NTS_SWIFT", .when(platforms: [.windows, .macOS, .iOS])),
                .unsafeFlags(
                    [
                        "-I", phpSrc,
                        "-I", "\(phpSrc)/main",
                        "-I", "\(phpSrc)/Zend",
                        "-I", "\(phpSrc)/TSRM",
                        "-I", "\(phpSrc)/win32",
                    ], .when(platforms: [.windows])),
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-UHAVE_BUILTIN_CONSTANT_P"], .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .define("NTS_SWIFT", .when(platforms: [.windows, .macOS, .iOS])),
                .define("ZEND_WIN32", .when(platforms: [.windows])),
                .define("PHP_WIN32", .when(platforms: [.windows])),
                .define("WIN32", .when(platforms: [.windows])),
                .unsafeFlags(
                    [
                        "-Xcc", "-include", "-Xcc", "intrin.h",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/main",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/Zend",
                        "-Xcc", "-I", "-Xcc", "\(phpSrc)/TSRM",
                    ], .when(platforms: [.windows])),
            ],
            linkerSettings: [
                .unsafeFlags(
                    [
                        "-L\(phpLib)",
                        "\(phpLib)/php8.lib",
                    ], .when(platforms: [.windows])),
            ]
        )
    ])
}

if includePHPXCFramework && buildPHPExtension {
    targets.append(.binaryTarget(name: "PHP", path: "PHP.xcframework"))
}

// --- Products Definition ---
var products: [Product] = [
    .library(name: "PhrostShared", type: .dynamic, targets: ["PhrostEngineLib"]),
    .executable(name: "PhrostIPC", targets: ["PhrostIPC"]),
    .executable(name: "Phrost", targets: ["PhrostBinary"]),
]

// Only add the PHP extension library product if building for PHP
if buildPHPExtension {
    products.append(.library(name: "php_phrostengine", type: .dynamic, targets: ["SwiftPHPExtension"]))
}

let package = Package(
    name: "SwiftPHP",
    platforms: [.macOS(.v14), .iOS(.v13)],
    products: products,
    dependencies: [
        .package(name: "Miniaudio", path: swiftMiniAudioPath),
        .package(name: "SwiftChipmunk2D", path: swiftChipmunk2DPath),
        .package(name: "SwiftSDL", path: swiftSDLPath),
        .package(name: "SwiftSDL_image", path: swiftSDLImagePath),
        .package(name: "SwiftSDL_ttf", path: swiftSDLTtfPath),
        .package(url: "https://github.com/ctreffs/SwiftImGui.git", from: "1.86.0"),
    ],
    targets: targets
)
