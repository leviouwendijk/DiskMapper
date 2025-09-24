// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DiskMapper",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", branch: "main"),
        .package(url: "https://github.com/leviouwendijk/plate.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "DiskMapperCore",
            path: "Sources/disk-mapper-core"
        ),
        .executableTarget(
            name: "DiskMapper",
            dependencies: [
                .product(name: "plate", package: "plate"),
                "DiskMapperCore",
            ],
            path: "Sources/diskmapper-application"
        ),

        .executableTarget(
            name: "diskmap",
            dependencies: [
                "DiskMapperCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "plate", package: "plate"),
            ],
            path: "Sources/diskmap-cli"
        ),
    ]
)
