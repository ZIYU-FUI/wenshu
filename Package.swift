// swift-tools-version: 6.4
//
// Package.swift · 文枢 (Wenshu) · v0.01.0 WO-001 → v0.03.0 V0-fix-6
// Project root: /Volumes/ANAN/Engineering/wenshu/
//
// Per AGENTS.md §13 baseline (2026-08-06 你拍板):
// - Swift/SwiftUI self-hosted desktop app (single-process)
// - CoreData (added in WO-002), LLM client (added in WO-003)
// - minimax cn LLM only (Anthropic-compatible) — NOT wired in this phase
//
// WO-001 only wires the Swift toolchain + macOS empty-window startup.
// No external dependencies. No CoreData. No LLM. No .ws files.
//
// V0-fix-6: 加 resources: [.copy("Assets.xcassets")] — 标准 .appiconset
// 接入 (Apple HIG + Xcode 16 推荐姿势). SwiftPM .copy 不让 actool 跑,
// 纯命令行 build 时 .appiconset 不会被编进 .car; 实际 LOGO 注入走
// AppDelegate 的 applicationIconImage 兜底 (Sources/WenshuApp/Resources/
// Brand/AppIcon.icns). 等 wenshu.xcodeproj (v0.01.x 起) 上线后, 标准
// .appiconset 由 Xcode actool 编译接管, .copy 资源仍兼容.

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
// - CFBundleIconFile=AppIcon   → macOS legacy fallback (V0-fix-6, .icns 资源名)
// - CFBundleIconName=AppIcon   → .appiconset 资源名 (V0-fix-6, actool 编 .car 用)
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
                "Resources/Info.plist",
                // V0-fix-12: designer 落档的 9 份 DESIGN-*.md 与视图源码同目录
                // (设计意图贴着实现放, 便于 CC 改视图时直接读). 它们是文档不是
                // 运行时资源, SwiftPM 见到就报 "unhandled file" warning.
                // exclude 掉 = warning 归零且不进 bundle.
                "Views/Chat/DESIGN-LT-N2.md",
                "Views/DESIGN-SYSTEM-INIT.md",
                "Views/DESIGN-V0-fix-1.md",
                "Views/DESIGN-V0-fix-10.md",
                "Views/DESIGN-V0-fix-11.md",
                "Views/DESIGN-V0-fix-2.md",
                "Views/DESIGN-V0-fix-4.md",
                "Views/Editor/DESIGN-LT-N3.md",
                "Views/Project/DESIGN-LT-N1.md"
            ],
            // V0-fix-6: 标准 .appiconset 接入 — Assets.xcassets/ 整目录
            // .copy 到 .build/.../WenshuApp_WenshuApp.bundle/, 保留
            // .appiconset/Contents.json + 8 PNG 完整结构. SwiftPM 纯
            // 命令行 build 不跑 actool, .appiconset 不会自动编 .car;
            // 实际 LOGO 走 AppDelegate applicationIconImage 兜底.
            // 等 wenshu.xcodeproj (v0.01.x) 上线, Xcode actool 接管.
            resources: [
                .copy("Assets.xcassets"),
                // AppIcon.icns — AppDelegate applicationIconImage 兜底
                // 资源. 标准 .appiconset 走 actool 编 .car, 纯 swift build
                // 不跑 actool, 兜底必须. 等 wenshu.xcodeproj (v0.01.x) 上
                // 线后, 这条 .copy 可摘除.
                .copy("Resources/Brand/AppIcon.icns")
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
