// swift-tools-version: 6.4
// agent layer. Local SwiftPM package so the agent runtime has an
// independent version boundary, an independently runnable test target, and
// a dependency edge the compiler enforces (a writing tool can reach this
// package's public surface and nothing else).
//
// Layering (= AGENTS.md §6.4, Shared/<Name>/ as a local package):
//
//     WenshuApp  ->  WenshuTool<Name>  ->  WenshuAgent  ->  WenshuData
//
// This package sits below every writing tool and holds no SwiftUI, no
// SwiftData, and no domain models. A tool package that needs persistence
// depends on WenshuData directly; a tool package that needs the agent
// depends on this one for the tool protocol only.
import PackageDescription

let package = Package(
    name: "WenshuAgent",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "WenshuAgent", targets: ["WenshuAgent"])
    ],
    targets: [
        .target(name: "WenshuAgent", path: "Sources/WenshuAgent")
    ]
)
