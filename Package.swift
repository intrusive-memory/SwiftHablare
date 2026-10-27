// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SwiftHablare",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(
      name: "SwiftHablare",
      targets: ["SwiftHablare"]
    ),
    .library(
      name: "SwiftHablareTesting",
      targets: ["SwiftHablareTesting"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/intrusive-memory/SwiftFijos.git",
      .upToNextMajor(from: "1.4.1")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftCompartido.git",
      .upToNextMajor(from: "7.4.0")),
    .package(
      url: "https://github.com/intrusive-memory/vox-format.git",
      .upToNextMajor(from: "0.4.1")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftAcervo.git",
      .upToNextMajor(from: "0.25.0")),
  ],
  targets: [
    .target(
      name: "SwiftHablare",
      dependencies: [
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
        .product(name: "VoxFormat", package: "vox-format"),
        .product(name: "SwiftAcervo", package: "SwiftAcervo"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "SwiftHablareTesting",
      dependencies: ["SwiftHablare"],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftHablareTests",
      dependencies: [
        "SwiftHablare",
        "SwiftHablareTesting",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ]
)
