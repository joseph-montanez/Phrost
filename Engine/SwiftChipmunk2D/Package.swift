// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "SwiftChipmunk2D",
    platforms: [
        .macOS(.v11),
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "Chipmunk2D",
            targets: ["SwiftChipmunk2D"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftChipmunk2D",
            dependencies: [
                .target(name: "CChipmunk2D", condition: .when(platforms: [.linux, .windows])),
                .target(name: "Chipmunk2DBinary", condition: .when(platforms: [.macOS, .iOS]))
            ],
            path: "Sources/Chipmunk2D",
            sources: ["Chipmunk2D.swift"],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
        .binaryTarget(
            name: "Chipmunk2DBinary", // Binary target for macOS/iOS
            path: "./Chipmunk2D.xcframework"
        ),
        .systemLibrary(
            name: "CChipmunk2D",
            pkgConfig: "chipmunk2d",
            providers: [
                .apt(["libchipmunk-dev"]) // For Linux
            ]
        ),
    ]
)
