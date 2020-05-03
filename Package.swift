// swift-tools-version:5.1

import PackageDescription

let package = Package(
      name: "BirdbrainBLE",
      platforms: [
         .iOS(.v10), .macOS(.v10_13)
      ],
      products: [
         .library(
               name: "BirdbrainBLE",
               targets: ["BirdbrainBLE"]),
      ],
      dependencies: [
      ],
      targets: [
         .target(
               name: "BirdbrainBLE",
               dependencies: []),
         .testTarget(
               name: "BirdbrainBLETests",
               dependencies: ["BirdbrainBLE"]),
      ]
)
