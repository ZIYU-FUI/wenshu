// swift-tools-version: 6.4
//
// Package.swift · Wenshu (Wenshu) · v0.00.0 project baseline (2026-08-14 owner decision "bootstrap from 0.00.0")
//
// Source of truth: @AGENTS.md + @CLAUDE.md + @wenshu-pour/architecture/CONTEXT.md (= owner 11 decisions)
//
// Architecture: Swift/SwiftUI single-process macOS desktop app (= Apple ecosystem exclusive, v1 only macOS).
// v0.00.0 bootstrap = app entry point that opens a window; features follow via /to-tickets.
//
// Info.plist embedded via __TEXT,__info_plist linker section so AppKit recognizes the bare
// SwiftPM binary as a Cocoa application bundle (= Dock icon + Force Quit registration).

import PackageDescription

let package = Package(
    name: "Wenshu",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .executable(name: "WenshuApp", targets: ["WenshuApp"])
    ],
    dependencies: [
        // v0.00.0 bootstrap: no third-party deps. Add later via /to-tickets (LLM provider etc.)
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            path: "Sources/WenshuApp",
            exclude: [
                // Info.plist is consumed by the linker flag below, not by
                // SwiftPM's resource bundling. Keep on disk so linker resolves.
                "Resources/Info.plist"
            ],
            linkerSettings: [
                // Embed Info.plist into __TEXT,__info_plist so AppKit recognizes the
                // SwiftPM binary as a Cocoa app (= Dock icon + Force Quit registration).
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/WenshuApp/Resources/Info.plist"
                ])
            ]
        ),
        // v0.02.0: Swift Testing test target. v0.01.0 landed 7-zone scaffold;
        // v0.02.0 lands the bookshelf module (= storage protocol + FileSystem
        // implementation + view) and needs Swift Testing to enforce the storage
        // contract (= any future MetadataQuery / CoreData / CloudKit
        // implementation must pass the same contract tests).
        //
        // Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
        // 东西'. The contract tests are the architectural enforcement: they
        // describe the public behavior of LibraryStoring so the protocol
        // surface is locked before any UI code touches it.
        .testTarget(
            name: "WenshuAppTests",
            dependencies: ["WenshuApp"],
            path: "Tests/WenshuAppTests"
        )
    ]
)