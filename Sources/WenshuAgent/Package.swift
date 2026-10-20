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
    dependencies: [
        .package(name: "WenshuData", path: "../WenshuData"),
        // SSE client for the streaming connectors. Declared here rather than
        // left to the host: a package whose dependencies only resolve through
        // its consumer is not a package, it is a source folder. This surfaced
        // the moment the package got its own test target, which links
        // WenshuAgent without going through WenshuApp.
        .package(url: "https://github.com/mattt/EventSource", from: "1.5.1")
    ],
    targets: [
        .target(
            name: "WenshuAgent",
            dependencies: [
                .product(name: "WenshuData", package: "WenshuData"),
                .product(name: "EventSource", package: "EventSource")
            ],
            path: "Sources/WenshuAgent"
        ),
        // Tests live in the package so the package can be checked on its own.
        // The alternative (= everything under the root Tests/) costs a full app
        // build to verify one guard, and makes the package impossible to
        // validate as an upgradeable unit (= the reason it is a package).
        .testTarget(
            name: "WenshuAgentTests",
            dependencies: [
                "WenshuAgent",
                .product(name: "WenshuData", package: "WenshuData")
            ],
            path: "Tests/WenshuAgentTests"
        )
    ]
)
