// swift-tools-version: 6.2

import Foundation
import PackageDescription

// In CI we always pin to released remotes. Locally, prefer a sibling checkout
// at ../<name> if present so in-flight changes can be exercised end-to-end
// without publishing a release. Falls back to the remote pin if the sibling
// directory is missing, so fresh clones still build.
let useLocalSiblings = ProcessInfo.processInfo.environment["CI"] != "true"

func sibling(_ name: String, remote: String, from version: Version) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, .upToNextMajor(from: version))
}

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
    .executable(
      name: "hablare",
      targets: ["hablare"]
    ),
  ],
  dependencies: [
    sibling(
      "SwiftFijos",
      remote: "https://github.com/intrusive-memory/SwiftFijos.git",
      from: "1.4.1"
    ),
    sibling(
      "SwiftCompartido",
      remote: "https://github.com/intrusive-memory/SwiftCompartido.git",
      from: "7.0.2"
    ),
    sibling(
      "SwiftProyecto",
      remote: "https://github.com/intrusive-memory/SwiftProyecto.git",
      from: "3.5.0"
    ),
    sibling(
      "SwiftOnce",
      remote: "https://github.com/intrusive-memory/SwiftOnce.git",
      from: "0.2.0"
    ),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
  ],
  targets: [
    .target(
      name: "SwiftHablare",
      dependencies: [
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
        .product(name: "SwiftProyecto", package: "SwiftProyecto"),
        .product(name: "SwiftOnce", package: "SwiftOnce"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .executableTarget(
      name: "hablare",
      dependencies: [
        "SwiftHablare",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .unsafeFlags(["-parse-as-library"]),
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
