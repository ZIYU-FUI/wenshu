// swift-tools-version: 6.4
//
// Package.swift · Wenshu (Wenshu) · v0.00.0 project baseline (2026-08-14 owner decision "bootstrap from 0.00.0")
//
// Source of truth: @AGENTS.md + @CLAUDE.md + @wenshu-pour/architecture/CONTEXT.md (= owner 11 decisions)
//
// Architecture: Swift/SwiftUI single-process macOS desktop app (= Apple ecosystem exclusive, v1 only macOS).
// v0.00.0 bootstrap = app entry point that opens a window; features follow via /to-tickets.

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
        // v0.25.1 (= ticket 005 chat-zone icons): third-party SPM dep brought back
        // specifically for the chat zone icons (= bring-shrubbery/lucide-swift
        // 1.25.0). Owner 2026-08-26 OOB approved Lucide ('the bot icon and user
        // icon, we replace with Lucide .bot / .inbox / .botMessageSquare /
        // .userRound'); per AGENTS.md §11 + ticket 003 baseline-unlock rule
        // (= every third-party SDK requires owner-grill approval before
        // adding). Owner approved Lucide for this single chat-zone use.
        // No WenshuIcon abstraction layer (= ticket 002 over-engineered and
        // broke button functionality; reverted in tickets 002/003/004
        // followup). This re-introduction is single-purpose: just the chat
        // zone icon swap, nothing else.
        .package(url: "https://github.com/bring-shrubbery/lucide-swift.git", exact: "1.25.0"),
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            dependencies: [
                .product(name: "Lucide", package: "lucide-swift"),
            ],
            path: "Sources/WenshuApp",
            exclude: [
                // Info.plist + AppIcon are bundled by Scripts/build-app.sh into
                // Wenshu.app/Contents/Info.plist + Contents/Resources/AppIcon*
                // (= standard Cocoa .app bundle, AppKit reads CFBundleIconFile from there).
                // Bare `swift run` still works for dev: AppKit falls back to its
                // process-tile placeholder when no .app bundle exists.
                "Resources/Info.plist",
                "Resources/AppIcon.icon"
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