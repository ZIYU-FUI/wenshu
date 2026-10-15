// swift-tools-version: 6.4
// data layer. Package structure (= Apple Backyard Birds target
// decomposition; = AGENTS.md §6.4).
//
// Per AGENTS.md §6.4 (= Shared/<Name>/ as local SwiftPM package)
// and ADR-0016 this plan.
//
// A7 (= 2026-10-15): added a WenshuDataTests target so the
// data-layer test files (= the 34 files that were originally
// in Tests/WenshuAppTests/WenshuData/) can be tested in
// isolation (= no @testable import of WenshuApp needed).
// Per Apple Backyard Birds convention, the data layer has
// its own test target so tests can verify the model +
// repository layer without the application runtime.
import PackageDescription

let package = Package(
    name: "WenshuData",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "WenshuData", targets: ["WenshuData"])
    ],
    targets: [
        .target(name: "WenshuData", path: "Sources/WenshuData"),
        .testTarget(
            name: "WenshuDataTests",
            dependencies: ["WenshuData"],
            path: "Tests/WenshuDataTests"
        )
    ]
)
