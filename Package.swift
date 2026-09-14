// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ExifVeil",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "ExifVeilCore", targets: ["ExifVeilCore"])
    ],
    targets: [
        .target(
            name: "ExifVeilCore",
            path: "Sources/ExifVeilCore"
        ),
        .testTarget(
            name: "ExifVeilCoreTests",
            dependencies: ["ExifVeilCore"],
            path: "Tests/ExifVeilCoreTests"
        )
    ]
)

