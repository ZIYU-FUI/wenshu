// swift-tools-version: 6.4
// data layer. Package structure (= Apple Backyard Birds target
// decomposition; = AGENTS.md §6.4). The .swift sources are moved
// here in this work. The build of this
// package compiles with zero .swift sources (= the .target points
// at a Sources/WenshuData/ directory with no .swift files yet).
//
// Per AGENTS.md §6.4 (= Shared/<Name>/ as local SwiftPM package)
// and ADR-0016 this plan.
import PackageDescription

let package = Package(
    name: "WenshuData",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "WenshuData", targets: ["WenshuData"])
    ],
    targets: [
        .target(name: "WenshuData", path: "Sources/WenshuData")
    ]
)
