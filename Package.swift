// swift-tools-version: 6.4
//
// Package.swift · 文枢 (Wenshu) · v0.01.0 WO-001
// Project root: /Volumes/ANAN/Engineering/wenshu/
//
// Per AGENTS.md §13 baseline (2026-08-06 你拍板):
// - Swift/SwiftUI self-hosted desktop app (single-process)
// - CoreData (added in WO-002), LLM client (added in WO-003)
// - minimax cn LLM only (Anthropic-compatible) — NOT wired in this phase
//
// WO-001 only wires the Swift toolchain + macOS empty-window startup.
// No external dependencies. No CoreData. No LLM. No .ws files.

import PackageDescription

// MARK: - Info.plist
//
// Canonical Info.plist lives at Sources/WenshuApp/Resources/Info.plist
// (kept under the target so the linker flag below resolves it during
// build, and so it shows up in `git log` reviews alongside the Swift code).
//
// Key picks:
// - LSUIElement=false          → app shows in Dock (not a background-only helper)
// - CFBundleDisplayName=文枢   → user-facing app name (Chinese, as 拍板)
// - LSMinimumSystemVersion=27.0 → matches `.macOS(.v27)` platform target
// - NSPrincipalClass=NSApplication → required for Cocoa lifecycle in SwiftUI
//
// How the Info.plist reaches the binary:
// SwiftPM-built macOS executables are NOT proper .app bundles. To still
// be recognized by AppKit as an application (Dock icon, Force Quit,
// activation policy = .regular, etc.), we embed the Info.plist into
// the Mach-O __TEXT,__info_plist section via the standard linker flag
// below. When we eventually migrate to wenshu.xcodeproj in v0.01.x,
// we keep this same Info.plist as the canonical source.
//
// WO-001 platform note: AGENTS.md §13 says Apple 全家桶专属 but does
// not pin a deployment target. The task spec for WO-001 names `.v27`
// as "this machine's SDK"; verified via `xcrun --show-sdk-version` =
// 27.0 (Xcode-beta, macOS 27.0). Per CC rule: if real compatibility
// issues surface later, NOTE here and escalate to PM — do NOT silently
// downgrade.

let package = Package(
    name: "Wenshu",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .executable(name: "WenshuApp", targets: ["WenshuApp"])
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            path: "Sources/WenshuApp",
            // WO-001 has no external deps by design. CoreData, LLM, etc.
            // are added in later WOs. See CLAUDE.md §2 "不用" list.
            exclude: [
                // Info.plist is consumed by the linker flag below, not by
                // SwiftPM's resource bundling (which forbids "Info.plist"
                // as a top-level resource). Keep the file on disk so the
                // linker flag resolves, but tell SwiftPM to ignore it.
                "Resources/Info.plist"
            ],
            linkerSettings: [
                // Embed Info.plist into the executable's __TEXT,__info_plist
                // section. This is what makes the bare SwiftPM binary be
                // recognized as a Cocoa application bundle by AppKit.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/WenshuApp/Resources/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "WenshuAppTests",
            dependencies: ["WenshuApp"],
            path: "Tests/WenshuAppTests"
        )
    ]
)
