// swift-tools-version: 6.4
//
// Package.swift · Wenshu (Wenshu) · v0.00.0 project baseline (2026-08-14 owner decision "bootstrap from 0.00.0")
//
// Source of truth: @AGENTS.md + @CLAUDE.md + @wenshu-pour/architecture/CONTEXT.md (= owner 11 decisions)
//
// Architecture: Swift/SwiftUI single-process macOS desktop app (= Apple ecosystem exclusive, v1 only macOS).
// v0.00.0 bootstrap = app entry point that opens a window; features follow via /to-tickets.
//
// 2026-09-05 update (DEAD-PIN-CLEANUP-001): 10 third-party libraries with zero source consumers
// removed after grep cross-check (= sindresorhus/Defaults, sindresorhus/KeyboardShortcuts,
// kean/Nuke + kean/NukeUI, weichsel/ZIPFoundation, witekbobrowski/EPUBKit, davecom/SwiftGraph,
// li3zhen1/Grape [ForceSimulation], orchestract/MenuBarExtraAccess, gonzalezreal/Textual,
// apple/swift-log). Per AGENTS.md §11.1 4-criteria gate all 10 remain ratified; this cleanup
// does not re-litigate the ratification, only removes the SPM resolution cost. The remaining
// pins each have >= 1 source consumer (= Highlighter is transitive via MarkdownEngineCodeBlocks'
// HighlighterSwiftBridge type used by WenshuEditorServicesFactory; EventSource has 2 import sites
// in AnthropicStreaming + AnthropicStreamingWireup; the rest are either explicit in Package.swift
// comment or required by the v0.39 editor adoption). See `git log -1 -- Package.swift` for the
// audit commit. Reintroducing any removed pin requires a v0.X ticket with the first consumer's
// import path documented.

import PackageDescription

let package = Package(
    name: "Wenshu",
    // v0.38 ticket P2 (= Apple-standard i18n per boss OOB "走苹果 api,
    // 英用默认语言先是中英文"): defaultLocalization declares the
    // baseline language that the build system expects to find in
    // Resources/<defaultLocalization>.lproj/. Apple canonical default
    // = user's OS language; for the project baseline (= source of
    // truth + XLIFF export) we ship en. Per boss OOB, "英用默认" =
    // English is the default; zh-Hans is the alternate. SPM rejects
    // bundles with .lproj resources unless this is set.
    defaultLocalization: "en",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .executable(name: "WenshuApp", targets: ["WenshuApp"])
    ],
    dependencies: [
        // Canonical icon layer = Apple SF Symbols 6 (= built into
        // macOS 27 = zero SPM dependency). Boss 2026-09-15 OOB
        // 'remove Lucide, use SF Symbols 6 (3rd gen) with palette
        // rendering': ajaxjiang96/lucide-swift (= the v0.34 fork)
        // and bring-shrubbery/lucide-swift (= the v0.28 baseline)
        // were both removed. All callsites migrated from
        // LucideIcon(...) / LucideThinIcon(...) / raw Lucide(...) /
        // Lucide enum string properties to Image(systemName: ...) at
        // .regular weight with .symbolRenderingMode(.palette) /
        // (.hierarchical).

        // RUNTIME — CommonMark / GFM parser
        // swift-markdown tags weren't returned by `git ls-remote` (it uses GitHub Releases,
        // not git tags). Pin to a permissive lower bound; SPM will pick latest.
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.4.0"),

        // RUNTIME — chapter editor (v0.39 ticket 001, boss 2026-09-04 OOB '尝试接入')
        // Adopted per .scratch/2026-09-04-editor-migration/spec.md §2.1. nodes-app/swift-markdown-engine
        // = 971★ / Apache-2.0 / 3 contributors / Munich+Zurich / 0.12.0 latest 2026-08-10
        // (= macOS 14+ only, TextKit 2, half-year 5 minor releases). Per AGENTS.md §11.1
        // 4-criteria gate (= 100★ + 12mo + Apache-2.0 + macOS-first) all met. SPM product
        // = `MarkdownEngineCodeBlocks` (transitively pulls HighlighterSwift which wenshu pins
        // separately because the MarkdownEngineCodeBlocks product re-exports Highlighter types
        // via HighlighterSwiftBridge, which is referenced at runtime by WenshuEditorServicesFactory).
        // Consumer wiring lands with v0.39 ticket 001 (= WenshuMarkdownEditor wrapper + 2 service
        // adapters in `Sources/WenshuApp/Editor/`).
        .package(url: "https://github.com/nodes-app/swift-markdown-engine", from: "0.12.0"),

        // RUNTIME — UI enhancement: code-fence syntax highlight (transitive via
        // MarkdownEngineCodeBlocks.HighlighterSwiftBridge which constructs a Highlighter instance
        // at runtime; see Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift lines 64 + 86).
        // Adopted per 2026-08-28-six-module-audit M2 (P1, 105 stars, 185 languages,
        // 89 themes, pure-Swift no JS). Thin 5-star margin above the 100-star gate
        // is acceptable per boss拍 A. SPM product name is `Highlighter` (not
        // `HighlighterSwift`) per upstream Package.swift.
        .package(url: "https://github.com/smittytone/HighlighterSwift", from: "3.1.0"),

        // RUNTIME — SSE stream client (= AnthropicStreaming + AnthropicStreamingWireup import EventSource)
        .package(url: "https://github.com/mattt/EventSource", from: "1.5.1"),

        // DEV — hot-reload (declared unconditionally for SPM; see per-file
        // `#if DEBUG import Inject #endif` for the actual gate)
        .package(url: "https://github.com/krzysztofzablocki/Inject", from: "1.6.0"),

        // TEST — SwiftUI view hierarchy inspection (testTarget only, no runtime)
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.3"),

        // TEST — SwiftUI pixel snapshot tests (batch 1 issue 05; testTarget only)
        // Adopted per 2026-08-28-six-module-audit M1 (drag-lost regression suite).
        // Pairs with ViewInspector: structure assertions vs pixel snapshots.
        // Per the README, must be wired into testTarget ONLY (not runtime target).
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.4")
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            dependencies: [
                // Canonical icon rendering goes through Image(systemName: ...)
                // on Apple SF Symbols 6 (built into macOS 27; = zero SPM
                // dependency; = see top-level note in the dependencies array).
                .product(name: "Markdown", package: "swift-markdown"),
                // v0.39 ticket 001: chapter editor.
                .product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine"),
                // Highlighter product (= the SPM product name is `Highlighter` even though
                // the repo URL is HighlighterSwift; see upstream Package.swift). Required at
                // runtime because MarkdownEngineCodeBlocks.HighlighterSwiftBridge instantiates
                // a Highlighter in its init (Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift
                // lines 64 + 86 wire HighlighterSwiftBridge into MarkdownEditorConfiguration).
                .product(name: "Highlighter", package: "HighlighterSwift"),
                .product(name: "EventSource", package: "EventSource"),
                .product(name: "Inject", package: "Inject"),
            ],
            path: "Sources/WenshuApp",
            exclude: [
                "Resources/Info.plist",
                "Resources/AppIcon.icon",
                // v0.46 fix: 'wenshu' found 2 unhandled .md files in
                // source tree. Both are design docs (= AgentLifecycleTrackerDesign.md
                // + ComponentIndex.md) consumed by humans + LLMs, not by
                // the Swift compiler. Excluded from the resource bundle
                // (= no #fileLiteral resource access at runtime).
                "Core/Agent/Conversation/AgentLifecycleTrackerDesign.md",
                "UI/ComponentIndex.md",
                // Per-region view wrapper design docs (= humans + LLMs,
                // not Swift compiler; = no runtime Bundle access).
                "UI/SFRegions.md",
                // Localizable.strings inside each .lproj/. The single
                // source of truth is Localizable.xcstrings; SPM 6.4
                // compiles it into per-locale Localizable.strings
                // inside Wenshu_WenshuApp.bundle at swift-build time
                // (= Apple's String Catalog native support). Excluding
                // these from the SPM target prevents the 'Multiple
                // commands produce ...' duplicate-output error when
                // SPM processes both the source .lproj/Localizable.strings
                // AND the .xcstrings-derived equivalent. The .lproj/
                // directory itself is still processed (= InfoPlist.strings
                // for localized CFBundleDisplayName etc. ships as a
                // normal SPM resource).
                "Resources/en.lproj/Localizable.strings",
                "Resources/zh-Hans.lproj/Localizable.strings",
            ],
            // Per (see OOB.md #2026-10-06): single source of truth is
            // Localizable.xcstrings (= Apple Xcode 15+ String Catalog
            // format; = JSON; = git-tracked; = edited in Xcode's String
            // Catalog editor). SPM .process("Resources") ships the
            // .xcstrings file verbatim; the build pipeline (= Tools/build-wenshu.sh
            // + Scripts/build-app.sh) then runs `xcstringstool compile`
            // to produce the per-locale .lproj/Localizable.strings
            // files that NSLocalizedString actually consumes at runtime.
            resources: [
                .process("Resources")
            ],
            // Apple HIG canonical: executable SPM targets that
            // ship an Info.plist must embed it into the Mach-O via
            // the `__TEXT,__info_plist` section so Bundle.main
            // resolves CFBundleLocalizations /
            // CFBundleDevelopmentRegion (= the bare-Mach-O
            // `swift run` path = same as the packaged .app path).
            // SPM field-order requirement: linkerSettings must
            // follow resources (= PackageDescription validates
            // parameter order).
            linkerSettings: [
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
            dependencies: [
                "WenshuApp",
                .product(name: "ViewInspector", package: "viewinspector"),
                // batch 1 issue 05: visual regression test support for ticket 028-011
                // (= drag-lost regression suite). Pairs with ViewInspector: structure
                // assertions vs pixel snapshots. README warns NOT to add to runtime target.
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/WenshuAppTests",
            // v0.46 fix: 'wenshu' found 13 unhandled files in
            // Tests/WenshuAppTests/Agent/PortedFromHermes/ (= golden
            // JSON snapshots for hermes port tests + the generate_golden.py
            // / x_e2e_dual_track.py scripts that build the snapshots).
            // These are read at test time via direct file URLs (= not
            // bundled through SPM's resource pipeline) so excluding
            // them here is correct. Without this, SPM emits a
            // 'unhandled files' warning every build.
            exclude: [
                "Agent/PortedFromHermes/golden",
                "Agent/PortedFromHermes/scripts",
            ],
            // v0.71 P1 batch 3 + 2026-10-06 update: per the Localizable.xcstrings
            // migration (= see OOB.md #2026-10-06), the test target
            // no longer needs to ship Localizable.xcstrings as an
            // SPM resource. Instead, tests read the catalog directly
            // from the source tree via the path
            // 'Sources/WenshuApp/Resources/Localizable.xcstrings'
            // (= the readStrings / runPlutil helpers use
            // String(contentsOf:) on that path; = works regardless
            // of whether SPM ships the file to the test bundle).
            // Removing the .copy("/.process") declaration prevents
            // SPM from emitting 'duplicate output file' warnings
            // (= the production target already ships the file).
            // The .lproj children are produced at build time by
            // `xcstringstool compile` (= Tools/build-wenshu.sh +
            // Scripts/build-app.sh).
        )
    ]
)
