// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftHablare",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .macCatalyst(.v26)
    ],
    products: [
        .library(
            name: "SwiftHablare",
            targets: ["SwiftHablare"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftFijos.git", from: "1.0.0"),
        .package(path: "../SwiftCompartido")
    ],
    targets: [
        .target(
            name: "SwiftHablare",
            dependencies: [
                .product(name: "SwiftCompartido", package: "SwiftCompartido")
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
                .enableExperimentalFeature("StrictConcurrency=minimal")
            ]
        ),
    ]
)
