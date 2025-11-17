// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Miniaudio",
    products: [
        .library(
            name: "CMiniaudio",
            targets: ["CMiniaudio"]),
    ],
    targets: [
        .executableTarget(
            name: "AudioGallery",
            dependencies: [
                "CMiniaudio"
            ]),
        .target(
            name: "CMiniaudio"),
    ]
)
