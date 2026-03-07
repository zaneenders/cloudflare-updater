// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "cloudflare-updater",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "CloudFlareUpdater", targets: ["CloudFlareUpdater"]),
    .executable(name: "CreateCNAMERecord", targets: ["CreateCNAMERecord"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      from: "1.3.0"),
    .package(
      url: "https://github.com/swift-server/async-http-client.git",
      from: "1.25.1"),
    .package(
      url: "https://github.com/apple/swift-nio.git",
      from: "2.77.0"),
    .package(
      url: "https://github.com/swiftlang/swift-subprocess.git",
      from: "0.1.0"),
  ],
  targets: [
    .executableTarget(
      name: "CloudFlareUpdater",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
        .product(name: "Subprocess", package: "swift-subprocess"),
      ]
    ),
    .executableTarget(
      name: "CreateCNAMERecord",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
        .product(name: "Subprocess", package: "swift-subprocess"),
      ]
    )
  ]
)
