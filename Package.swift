// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Hotenka",
  products: [
    .library(
      name: "Hotenka",
      targets: ["Hotenka"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Hotenka",
      dependencies: []
    ),
    .testTarget(
      name: "HotenkaTests",
      dependencies: ["Hotenka"]
    ),
  ]
)
