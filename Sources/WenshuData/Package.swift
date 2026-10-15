// swift-tools-version: 6.4
// v3.1 governance A1g.4.1: local SwiftPM package hosting the wenshu
// data layer. Package structure (= Apple Backyard Birds target
// decomposition; = AGENTS.md §6.4). The .swift sources are moved
// here in A1g.4.2; = this file is the first commit (= package
// skeleton + root Package.swift wire-up). The build of this
// package compiles with zero .swift sources (= the .target points
// at a Sources/WenshuData/ directory with no .swift files yet).
//
// Per AGENTS.md §6.4 (= Shared/<Name>/ as local SwiftPM package)
// and ADR-0016 A1g.4 plan (= 6 sub-tickets, each = 1 commit).
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
