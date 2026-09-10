// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-fx-rates",
    platforms: [
        .macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "FXRates", targets: ["FXRates"]),
    ],
    targets: [
        .target(name: "FXRates"),
        .testTarget(name: "FXRatesTests", dependencies: ["FXRates"]),
    ]
)
