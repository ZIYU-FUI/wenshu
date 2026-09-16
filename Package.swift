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
            ],
            // Apple HIG canonical i18n root fix (boss 2026-09-16 OOB
            // '不要什么都先想着最简单, 不要为以后留坑. 要想着从根本解决问题':
            // the repeated i18n regression (= sidebar / inspector
            // labels flipping to English on zh-Hans users) was never
            // a WenshuI18n bug. The actual root cause per Apple HIG
            // + TN2418 + polpiella.dev ("Adding an Info.plist file
            // to a Swift executable"): when a Swift executable runs
            // as a bare Mach-O (= `swift build` output, `swift run`,
            // `open .build/.../WenshuApp`), `Bundle.main` resolves
            // to the binary path and has NO `CFBundleLocalizations`
            // field. Foundation then falls back to
            // `CFBundleDevelopmentRegion = en` and every
            // NSLocalizedString returns English regardless of the
            // user's `zh-Hans-CN` system language. The .app wrapper
            // hides this for production builds because build-app.sh
            // copies Info.plist into Contents/, but every dev iteration
            // (= every `swift build` + `open .build/.../WenshuApp`)
            // hits the same regression.
            //
            // Apple HIG-canonical fix: embed the project's
            // Info.plist directly into the Mach-O via the
            // `__TEXT,__info_plist` section. This is the exact
            // pattern Apple recommends for Swift CLI tools and
            // executable SPM targets that need a Bundle.main with
            // CFBundleLocalizations / CFBundleDevelopmentRegion.
            // Per developer.apple.com/forums/thread/734540:
            //
            //   > it is possible to give a command-line tool a
            //   > bundle ID, bundle name, and so on. The trick is
            //   > to embed the Info.plist into a special section
            //   > in your tool. See the CREATE_INFOPLIST_SECTION_IN_BINARY
            //   > build setting.
            //
            // After this change:
            //   - Bundle.main.object(forInfoDictionaryKey:
            //     "CFBundleLocalizations") returns ["en", "zh-Hans"]
            //   - Bundle.main.preferredLocalizations returns
            //     ["zh-Hans"] for zh-Hans-CN users
            //   - NSLocalizedString resolves to zh-Hans values
            //     regardless of whether wenshu is launched as
            //     a bare Mach-O or as a packaged .app bundle.
            //
            // The .app bundle build-app.sh still copies the same
            // Info.plist into Contents/Info.plist for Finder /
            // LaunchServices metadata (= canonical .app layout);
            // the linkerSettings below is the binary-side mirror
            // that makes dev builds behave identically.
            //
            // SPM field-order requirement: PackageDescription's
            // Target builder validates parameter order; =
            // linkerSettings must follow resources (= the previous
            // wrong order fails with 'argument resources must
            // precede argument linkerSettings').
            //
            // Full Q34 spec + dual-axis audit reports at
            // .scratch/2026-09-16-i18n-bare-mach-o-info-plist/
            // (= spec.md + 3 ticket files documenting the chain
            // of commits that landed this fix).
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
