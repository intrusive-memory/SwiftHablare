// swift-tools-version: 6.2

import PackageDescription
import Foundation

// MARK: - Package Dependencies
//
// Uses SwiftCompartido from GitHub to ensure compatibility when consumed as a remote package
//

let package = Package(
    name: "SwiftHablare",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SwiftHablare",
            targets: ["SwiftHablare"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftFijos.git", branch: "main"),
        .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", branch: "development")
    ],
    targets: [
        .target(
            name: "SwiftHablare",
            dependencies: [
                .product(name: "SwiftCompartido", package: "SwiftCompartido")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftHablareTests",
            dependencies: [
                "SwiftHablare",
                .product(name: "SwiftFijos", package: "SwiftFijos"),
                .product(name: "SwiftCompartido", package: "SwiftCompartido")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
