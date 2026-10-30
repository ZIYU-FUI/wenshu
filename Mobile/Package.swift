// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "WenshuMobile",
    // iOS and iPadOS are the product targets (AGENTS.md 2.3). The floor is
    // iOS 18 so any current toolchain builds it; the foldable-native
    // APIs (iOS 27.1) are reached through @available with a size-class
    // fallback below them (ADR-0030). The macOS entry exists so the kit
    // builds and its tests run on a CI host; no macOS product ships from
    // this repository.
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "WenshuMobileKit", targets: ["WenshuMobileKit"]),
        .executable(name: "WenshuMobileApp", targets: ["WenshuMobileApp"]),
    ],
    targets: [
        .target(
            name: "WenshuMobileKit",
            path: "Sources/WenshuMobileKit"
        ),
        .executableTarget(
            name: "WenshuMobileApp",
            dependencies: ["WenshuMobileKit"],
            path: "Sources/WenshuMobileApp"
        ),
        .testTarget(
            name: "WenshuMobileTests",
            dependencies: ["WenshuMobileKit", "WenshuMobileApp"],
            path: "Tests/WenshuMobileTests"
        ),
    ]
)
