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
        // v0.27 boss 8/27 OOB: "从今天开始，任何功能，先查有没有三方库可以用".
        // wenshu splitter drag (LayoutShellView NativeSplitter) didn't work
        // because SwiftUI .gesture(.local) is unreliable on macOS 14+ when
        // nested in HStack with .transition(= zone hide/show animation).
        // Boss approved `stevengharris/SplitView` (= AGENTS.md §11.1 first
        // approved third-party exception) as the splitter replacement.
        //
        // Per AGENTS.md §11.1 acceptance criteria (= SplitView meets all 4):
        // - GitHub stars: 216 (>= 100 ✓)
        // - Last commit: v3.5 within 12 months (active ✓)
        // - License: MIT (commercial-friendly ✓)
        // - macOS-first (✓; = NSSplitView SwiftUI wrapper designed for macOS
        //   first; supports iOS/macOS/Catalyst but primary target is macOS).
        //
        // This commit adds the dep first; wenshu code does not yet import
        // SplitView (= followup commit will rewrite LayoutShellView to use
        // SplitView's HSplit / VSplit / Split views). v3.5 chosen = latest
        // release on the v3 series (= no breaking changes from v3.x prior).
        .package(url: "https://github.com/stevengharris/SplitView.git", exact: "3.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            dependencies: [
                .product(name: "Lucide", package: "lucide-swift"),
                .product(name: "SplitView", package: "SplitView"),
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