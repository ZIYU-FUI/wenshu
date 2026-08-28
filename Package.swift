// swift-tools-version: 6.4
//
// Package.swift · Wenshu (Wenshu) · v0.00.0 project baseline (2026-08-14 owner decision "bootstrap from 0.00.0")
//
// Source of truth: @AGENTS.md + @CLAUDE.md + @wenshu-pour/architecture/CONTEXT.md (= owner 11 decisions)
//
// Architecture: Swift/SwiftUI single-process macOS desktop app (= Apple ecosystem exclusive, v1 only macOS).
// v0.00.0 bootstrap = app entry point that opens a window; features follow via /to-tickets.
//
// 2026-08-28 OOB: 老板 ratified "all libraries can be introduced immediately".
// Versions in this file are pinned against actual `git ls-remote --tags` listed
// on 2026-08-28 (NOT guesses). See AGENTS.md §11.1 for star counts, licenses,
// acceptance criteria, and decision history.

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
        // v0.25.1 chat-zone icons
        .package(url: "https://github.com/bring-shrubbery/lucide-swift.git", exact: "1.25.0"),

        // RUNTIME — UserDefaults + shortcut wrappers
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.2.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.10.0"),

        // RUNTIME — async image pipeline
        // Nuke major 13 ships NukeUI as a product in the main repo
        // (= kean merged NukeUI into Nuke at the 11.0 release in 2022-07-20;
        // the standalone `kean/NukeUI` repo is frozen at Nuke 10.5 line and
        // cannot resolve against `Nuke from: "13.2.0"` — see
        // .scratch/2026-08-28-third-party-integration-fix/issues/01-*.md).
        // Verified via `git ls-remote --tags` 2026-08-28.
        .package(url: "https://github.com/kean/Nuke", from: "13.2.0"),

        // RUNTIME — ZIP archive
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.20"),

        // RUNTIME — SQLite + FTS5
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),

        // RUNTIME — CommonMark / GFM parser
        // swift-markdown tags weren't returned by `git ls-remote` (it uses GitHub Releases,
        // not git tags). Pin to a permissive lower bound; SPM will pick latest.
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.4.0"),

        // RUNTIME — SSE stream client
        .package(url: "https://github.com/mattt/EventSource", from: "1.5.1"),

        // RUNTIME — SwiftUI rich-text
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.5.0"),

        // DEV — hot-reload (declared unconditionally for SPM; see per-file
        // `#if DEBUG import Inject #endif` for the actual gate)
        .package(url: "https://github.com/krzysztofzablocki/Inject", from: "1.6.0"),

        // TEST — SwiftUI view hierarchy inspection (testTarget only, no runtime)
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.3")
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            dependencies: [
                .product(name: "Lucide", package: "lucide-swift"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Nuke", package: "Nuke"),
                // NukeUI is a product of the main Nuke repo since Nuke 11.0
                // (= same row above; see comment on the .package line).
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "EventSource", package: "EventSource"),
                .product(name: "Textual", package: "textual"),
                .product(name: "Inject", package: "Inject"),
            ],
            path: "Sources/WenshuApp",
            exclude: [
                "Resources/Info.plist",
                "Resources/AppIcon.icon"
            ]
        ),
        .testTarget(
            name: "WenshuAppTests",
            dependencies: [
                "WenshuApp",
                .product(name: "ViewInspector", package: "ViewInspector"),
            ],
            path: "Tests/WenshuAppTests"
        )
    ]
)
