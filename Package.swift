// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "cloudflare-updater",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "CloudFlareUpdater", targets: ["CloudFlareUpdater"]),
    .executable(name: "CreateCNAMERecord", targets: ["CreateCNAMERecord"]),
    .executable(name: "SyncICloudMailDNS", targets: ["SyncICloudMailDNS"]),
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
  ],
  targets: [
    .target(
      name: "CloudflareLogging",
      dependencies: [
        .product(name: "_NIOFileSystem", package: "swift-nio")
      ]
    ),
    .target(
      name: "CloudflareDNS",
      dependencies: [
        "CloudflareLogging",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
      ]
    ),
    .executableTarget(
      name: "CreateCNAMERecord",
      dependencies: [
        "CloudflareDNS",
        "CloudflareLogging",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .executableTarget(
      name: "CloudFlareUpdater",
      dependencies: [
        "CloudflareDNS",
        "CloudflareLogging",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .executableTarget(
      name: "SyncICloudMailDNS",
      dependencies: [
        "CloudflareDNS",
        "CloudflareLogging",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
      ]
    ),
  ]
)
