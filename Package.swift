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
//
// v0.05.0 t_d4e02b80 ICON v2: **lucide-swift SPM 延后** — 原计划加
// ajaxjiang96/lucide-swift dep, 但实测上游 Package.swift 含 .package
// (path: "PatchedDependencies/SVGPath") 本地子包依赖, SwiftPM 6.4 三种
// requirement 类型 (.revision / .branch / .exact) 全部拒绝 ("required
// using a revision-based requirement and it depends on local package
// 'svgpath'" / "depends on an unstable-version package 'svgpath'")。
// v0.05.0 视图层不消费 LucideSwift (Image(systemName:) 兜底), IconLibrary
// .Action.lucideName 仅 metadata 字段 — **没有 runtime 依赖**, 故 SPM dep
// 直接延后至 v0.05.x 真启用 Lucide 渲染时再接入 (届时走 vendored
// SVGPath 本地包或 fork upstream)。 第 3 方 LICENSE 文件保留 (.copy 进
// bundle), 仍满足分发前置 (App Store notarization / Redistributable
// notice) — README.md 是源码仓库说明, 不进 bundle。

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
    // v0.05.0 t_d4e02b80 ICON v2: lucide-swift SPM dep 延后 (见顶 comment
    // § v0.05.0)。 v0.05.0 阶段无外部依赖 — IconLibrary.Action.lucideName
    // 仅 metadata, 无 runtime 消费。
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            // WO-001 has no external deps by design. CoreData, LLM, etc.
            // are added in later WOs. See CLAUDE.md §2 "不用" list.
            //
            // v0.05.0 t_d4e02b80: LucideSwift SPM dep 延后 (上游 Package.swift
            // 本地子包约束), 视图层不消费 LucideSwift (systemImage: 兜底),
            // 仅 metadata 字段 (IconLibrary.Action.lucideName) 预留 v0.05.x
            // 切换路径。
            dependencies: [
            ],
            path: "Sources/WenshuApp",
            exclude: [
                // Info.plist is consumed by the linker flag below, not by
                // SwiftPM's resource bundling (which forbids "Info.plist"
                // as a top-level resource). Keep the file on disk so the
                // linker flag resolves, but tell SwiftPM to ignore it.
                "Resources/Info.plist",
                // AIF 大管家 8/12 14:15 修正: 备 .icns 3 variant (light/mono) 给后续 dark 切换/调试用, SPM 见到会报 unhandled warning, exclude 掉
                "Resources/Brand/light/AppIcon.icns",
                "Resources/Brand/mono/AppIcon.icns",
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
                "Views/Project/DESIGN-LT-N1.md",
                // v0.05.0 t_d4e02b80: 3rd-party LICENSE README 仅落档源码仓库
                // 说明用, 不进 app bundle (LICENSE 纯文本进 bundle —
                // 见 resources: [.copy("Resources/ThirdPartyLicenses/...")])
                "Resources/ThirdPartyLicenses/README.md"
            ],
            // V0-fix-6: 标准 .appiconset 接入 — Assets.xcassets/ 整目录
            // .copy 到 .build/.../WenshuApp_WenshuApp.bundle/, 保留
            // .appiconset/Contents.json + 8 PNG 完整结构. SwiftPM 纯
            // 命令行 build 不跑 actool, .appiconset 不会自动编 .car;
            // 实际 LOGO 走 AppDelegate applicationIconImage 兜底.
            // 等 wenshu.xcodeproj (v0.01.x) 上线, Xcode actool 接管.
            //
            // v0.05.0 t_d4e02b80: 3rd-party LICENSE 文本进 bundle 满足
            // 分发前置 (App Store / DMG notarization)。 README.md
            // exclude 掉 (不进 bundle, 仅源码仓库说明用)。
            resources: [
                .copy("Assets.xcassets"),
                // AppIcon.icns — AppDelegate applicationIconImage 兜底
                // 资源. 标准 .appiconset 走 actool 编 .car, 纯 swift build
                // 不跑 actool, 兜底必须. 等 wenshu.xcodeproj (v0.01.x) 上
                // 线后, 这条 .copy 可摘除.
                .copy("Resources/Brand/AppIcon.icns"),
                // v0.05.0 t_d4e02b80: lucide-swift + lucide-icons ISC 文本
                // 进 bundle 满足分发前置. 见 ThirdPartyLicenses/README.md §
                // "Acknowledgements" 段。
                .copy("Resources/ThirdPartyLicenses/lucide-swift-LICENSE"),
                .copy("Resources/ThirdPartyLicenses/lucide-icons-LICENSE")
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
