// swift-tools-version: 6.4
// Package.swift · Wenshu Board · the card-board client.
//
// A sibling package of the macOS app, the way Mobile/ is. It shares the
// repository and the data layer with the desktop app and adds nothing to it:
// the desktop app's sources are not a dependency of this package.
//
// The shared layer is consumed as a local path package, so both sides
// resolve the same bytes by construction (one checkout, no pin to drift).
// The dependency path leaves this package root on purpose; SwiftPM allows a
// relative path dependency, and the constraint it places is on TARGET paths
// (a target may not escape its package root), which this package respects.
import PackageDescription

let package = Package(
    name: "WenshuBoard",
    // macOS-only, the same floor as the desktop app and as WenshuData.
    // The card board is a Mac surface: it opens the same .ws library, so it
    // needs the same platform, and it does not widen WenshuData's manifest.
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .library(name: "WenshuBoardKit", targets: ["WenshuBoardKit"]),
        .executable(name: "WenshuBoardApp", targets: ["WenshuBoardApp"])
    ],
    dependencies: [
        .package(name: "WenshuData", path: "../Sources/WenshuData")
    ],
    targets: [
        .target(
            name: "WenshuBoardKit",
            dependencies: [
                .product(name: "WenshuData", package: "WenshuData")
            ],
            path: "Sources/WenshuBoardKit"
        ),
        .executableTarget(
            name: "WenshuBoardApp",
            dependencies: ["WenshuBoardKit"],
            path: "Sources/WenshuBoardApp"
        ),
        .testTarget(
            name: "WenshuBoardTests",
            dependencies: ["WenshuBoardKit"],
            path: "Tests/WenshuBoardTests"
        )
    ]
)
