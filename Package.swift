// swift-tools-version: 6.2

import PackageDescription
import Foundation

// MARK: - Local Development Support
//
// Automatically uses local SwiftCompartido if available, otherwise fetches from GitHub.
//
// For local development:
//   1. Clone SwiftCompartido alongside this repo: ../SwiftCompartido
//   2. Build will automatically use your local version
//   3. Changes to SwiftCompartido are reflected immediately
//
// For CI/production:
//   - Automatically uses latest from GitHub main branch
//

let localCompartidoPath = "../SwiftCompartido"
let useLocalCompartido = FileManager.default.fileExists(atPath: localCompartidoPath)

let compartidoDependency: Package.Dependency = useLocalCompartido
    ? .package(path: localCompartidoPath)
    : .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", branch: "main")

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
        compartidoDependency
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
