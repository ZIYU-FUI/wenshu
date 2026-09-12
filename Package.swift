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
        // v0.25.1 chat-zone icons
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'Lucide 最细的多少?
        // 现在放大了, 线条好粗': switch to ajaxjiang96/lucide-swift
        // (= a Lucide fork that exposes `strokeWidth` as a
        // parameter; = the upstream bring-shrubbery/lucide-swift
        // 1.25.0 bakes strokes into filled outlines and exposes
        // a deprecated `lineWidth()` no-op; = the only way to
        // render truly thin lines is to use a fork with
        // stroked-path rendering).
        //
        // AGENTS.md §11.1 note: this fork has 0 stars (= below
        // the 100-star threshold). Boss 2026-09-12 explicitly
        // approved the swap despite the policy gap (= boss
        // directive is "线条好粗" + accept policy gap to fix it).
        // TODO future ticket: revisit if the fork gains adoption
        // OR revert to bring-shrubbery if a strokeWidth parameter
        // lands upstream.
        .package(url: "https://github.com/ajaxjiang96/lucide-swift.git", from: "0.3.0"),

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
                // v1.0.0-m1-shell boss 2026-09-12 OOB 'Lucide 最细的多少?
                // 现在放大了, 线条好粗': ajaxjiang96 fork exposes
                // its types via the `LucideSwift` product name (=
                // NOT `Lucide` like the upstream bring-shrubbery
                // fork). Type aliases for `Lucide` (the upstream
                // name) exist via re-export so most callers compile
                // unchanged, but explicit LucideIcon(...) init
                // we'll use strokeWidth on (= 1 PT) requires the
                // LucideSwift product to be imported directly.
                .product(name: "LucideSwift", package: "lucide-swift"),
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
                "Resources/AppIcon.icon"
            ],
            // v0.38 ticket P2 (= Apple-standard i18n per boss OOB):
            // .process("Resources") ships en.lproj/Localizable.strings +
            // zh-Hans.lproj/Localizable.strings (= Apple canonical
            // NSLocalizedString table) + entitlements (= macOS app sandbox
            // signing artifact; .process copies verbatim). The
            // Info.plist + AppIcon.icon are excluded above because they
            // are NOT regular resources (= Info.plist is the macOS bundle
            // descriptor, AppIcon.icon is an icns container that the
            // build script extracts separately).
            resources: [
                .process("Resources")
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
            // v0.71 P1 batch 3: expose Localizable.strings to the
            // test target's Bundle.module (= the I18nParityTests
            // suite needs Bundle.module.url(forResource: "Localizable",
            // withExtension: "strings") to verify en ↔ zh-Hans parity
            // + source-code coverage). Without this, Bundle.module
            // doesn't exist (= SPM only generates it when the target
            // has resources). Symlink the WenshuApp Resources dir
            // (= Localizable.strings is the only file the i18n tests
            // actually read; = no need to process .lproj via SPM's
            // localization pipeline = .copy preserves the .lproj
            // directory structure).
            resources: [
                // Localizable.strings lives in each .lproj (= the
                // canonical Apple localization layout; = Swift's
                // NSLocalizedString looks it up via the user's
                // preferred language + the .lproj directory).
                .copy("Resources/en.lproj"),
                .copy("Resources/zh-Hans.lproj"),
            ]
        )
    ]
)
