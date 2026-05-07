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
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/intrusive-memory/SwiftFijos.git", .upToNextMajor(from: "1.4.1")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftCompartido.git", .upToNextMajor(from: "7.0.4")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftProyecto.git", .upToNextMajor(from: "3.5.0")),
  ],
  targets: [
    .target(
      name: "SwiftHablare",
      dependencies: [
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
        .product(name: "SwiftProyecto", package: "SwiftProyecto"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftHablareTests",
      dependencies: [
        "SwiftHablare",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ]
)
