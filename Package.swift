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
        .package(url: "https://github.com/bring-shrubbery/lucide-swift.git", exact: "1.25.0"),

        // RUNTIME — UserDefaults typed wrapper (sindresorhus/Defaults 9.0.8)
        // Bumped from 8.2.0 -> 9.0.8 per 2026-08-28-six-module-audit M6 recommendation.
        // Zero source consumers (wenshu uses Apple Foundation UserDefaults + @AppStorage directly
        // across LayoutShellViewModel / WorkspaceStore / ZoneContentView / LibraryRootView etc.;
        // sindresorhus/Defaults remains as a pin for future feature work where typed Codable
        // UserDefaults become beneficial — see v0.28 chat history migration ticket as the first
        // candidate consumer).
        .package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.0"),
        // RUNTIME — global shortcut binding (bump batch 2 issue 09)
        // Bumped from 1.10.0 to 2.2.0 (= per 2026-08-28-six-module-audit
        // M6 + boss拍 'v1 → v2 breaking-change risk 由 ticket 评估').
        // Verified ZERO source consumers in wenshu (= the App.swift + view
        // files use Apple's native .keyboardShortcut(...) modifier only; the
        // KeyboardShortcuts lib is reserved for the v0.28+ Settings pane
        // Keyboard tab where users can rebind global shortcuts via System
        // Settings). v2 is API-compatible with v1 on the import side.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),

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

        // RUNTIME — chapter editor (v0.39 ticket 001, boss 2026-09-04 OOB '尝试接入')
        // Adopted per .scratch/2026-09-04-editor-migration/spec.md §2.1. nodes-app/swift-markdown-engine
        // = 971★ / Apache-2.0 / 3 contributors / Munich+Zurich / 0.12.0 latest 2026-08-10
        // (= macOS 14+ only, TextKit 2, half-year 5 minor releases). Per AGENTS.md §11.1
        // 4-criteria gate (= 100★ + 12mo + Apache-2.0 + macOS-first) all met. SPM product
        // = `MarkdownEngineCodeBlocks` (already pulls HighlighterSwift which wenshu has
        // pinned). Consumer wiring lands with v0.39 ticket 001 (= WenshuMarkdownEditor
        // wrapper + 2 service adapters in `Sources/WenshuApp/Editor/`).
        .package(url: "https://github.com/nodes-app/swift-markdown-engine", from: "0.12.0"),

        // RUNTIME — UI enhancement: code-fence syntax highlight (batch 2 issue 02)
        // Adopted per 2026-08-28-six-module-audit M2 (P1, 105 stars, 185 languages,
        // 89 themes, pure-Swift no JS). Thin 5-star margin above the 100-star gate
        // is acceptable per boss拍 A. Consumer wiring lands with the v0.28 M2
        // chapter-preview feature ticket (= separate from this adoption commit).
        .package(url: "https://github.com/smittytone/HighlighterSwift", from: "3.1.0"),

        // RUNTIME — EPUB 2/3 parser (batch 2 issue 03)
        // Adopted per 2026-08-28-six-module-audit M3 (= EPUB import ticket
        // trigger; feeds M5-15 LLM Wiki pipeline = extract core settings +
        // writing-style fingerprint into reference-library). Sole-maintainer
        // risk (316 stars, 5mo stale); thin EPUBImportService adapter wraps
        // the parser so a future swap is 1-file change.
        .package(url: "https://github.com/witekbobrowski/EPUBKit", from: "0.5.0"),

        // RUNTIME — graph algorithms (batch 2 issue 04)
        // Adopted per 2026-08-28-six-module-audit M4 (P1, 811 stars, 4.0.0,
        // pure data: BFS / DFS / Dijkstra / Prim / Kruskal). Used by M4
        // foreshadowing-graph algorithms (= 'which chapter recycles
        // foreshadowing from chapter 12' = Dijkstra cross-chapter shortest
        // path; recycling-graph = Prim minimum spanning tree). Consumer
        // wiring lands with the v0.28 M4 graph-algorithms feature ticket.
        .package(url: "https://github.com/davecom/SwiftGraph", from: "4.0.0"),

        // RUNTIME — force-directed graph layout (batch 2 issue 05, CONDITIONAL)
        // Adopted per 2026-08-28-six-module-audit M4 + boss拍 A (= accept
        // WARN, 15mo stale, 402 stars, MIT, macOS-first, Swift 6 ready,
        // zero data-race). NOTE: only the ForceSimulation product is adopted
        // (= pure data: physics spring simulation); the Grape SwiftUI view
        // product (= MiniMap + Toolbar + Panel = ADR-0008 view-architecture
        // risk surface) is REJECTED per the audit verdict. ~700 LOC
        // hand-rolled spring-force as in-house fallback per boss拍 A.
        .package(url: "https://github.com/li3zhen1/Grape", from: "1.1.0"),

        // RUNTIME — macOS platform integration (batch 2 issue 07)
        // Adopted per 2026-08-28-six-module-audit M6 (= 218 stars, MIT,
        // 1.3.0, 2025-02-25 last release per SPI; macOS 13+ required).
        // Provides programmatic show / hide / toggle control over SwiftUI
        // MenuBarExtra (= Apple SwiftUI MenuBarExtra API does NOT expose
        // these controls natively). Used by the v0.28+ menu shape ticket
        // (= adds a wenshu menu bar icon with scriptable show/hide on
        // chat events). Falls under 'macOS platform integration allowed'
        // per ADR-0008.
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.3.0"),

        // RUNTIME — SSE stream client
        .package(url: "https://github.com/mattt/EventSource", from: "1.5.1"),

        // RUNTIME — SwiftUI rich-text
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.5.0"),

        // DEV — hot-reload (declared unconditionally for SPM; see per-file
        // `#if DEBUG import Inject #endif` for the actual gate)
        .package(url: "https://github.com/krzysztofzablocki/Inject", from: "1.6.0"),

        // TEST — SwiftUI view hierarchy inspection (testTarget only, no runtime)
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.3"),

        // RUNTIME — Apple first-party Logger API (telemetry; batch 1 issue 04)
        // Adopted per 2026-08-28-six-module-audit M6. Zero source consumers yet;
        // first consumer lands with v0.28+ wenshu CLI / daemon ticket (= future
        // batch 2 work). Pin added now so the dep graph is ready when needed.
        // Forward-fix: pin to "1.15.0" (= actual SPM resolution per
        // Package.resolved; the prior "from: 1.5.4" semver floor resolved to
        // 1.15.0 which was a Q35 commit-message 描述 vs 真值 drift per the
        // Spec-axis sub-agent V1.3 finding).
        .package(url: "https://github.com/apple/swift-log", from: "1.15.0"),

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
                // v0.39 ticket 001: chapter editor.
                .product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine"),
                // batch 2 issue 02: Highlighter product (= the SPM product name
                // is `Highlighter` even though the repo URL is HighlighterSwift;
                // see https://raw.githubusercontent.com/smittytone/HighlighterSwift/3.1.0/Package.swift).
                // SwiftUI token list + SwiftUI CodeTextView (= Highlighter is the
                // JS-bridge wrapper for highlight.js; pure-Swift wrapper, no Swift
                // source files needed by wenshu). Consumer wiring lands with the
                // v0.28 M2 chapter-preview feature ticket.
                .product(name: "Highlighter", package: "HighlighterSwift"),

                // batch 2 issue 03: EPUBKit product (= EPUB 2/3 parser).
                // Sole-maintainer risk (5mo stale, 316 stars) per audit; thin
                // adapter protocol EPUBImportService wraps the parser so a future
                // swap to Readium or self-implemented parser (ZIPFoundation + AEXML)
                // is a 1-file change. NOTE: EPUBKit transitively depends on
                // marmelroy/Zip (= a second ZIP engine alongside wenshu's own
                // ZIPFoundation dep) — accepted per the 2026-08-28-six-module-
                // audit M3 risk note (= 'no functional conflict; doesn't affect
                // .ws export/import which uses wenshu's own ZIPFoundation dep').
                // Consumer wiring lands with the v0.28 M3 EPUB-import feature
                // ticket and feeds M5-15 LLM Wiki pipeline (= extract core
                // settings + writing-style fingerprint into reference-library).
                .product(name: "EPUBKit", package: "EPUBKit"),

                // batch 2 issue 04: SwiftGraph product (= graph algorithms).
                // Pure data (= BFS / DFS / Dijkstra / Prim / Kruskal); no view
                // surface, no ADR-0008 risk. Consumer wiring lands with the
                // v0.28 M4 graph-algorithms feature ticket (= ForeshadowingGraph
                // service that maps cross-chapter recycling paths).
                .product(name: "SwiftGraph", package: "SwiftGraph"),

                // batch 2 issue 05: ForceSimulation product from the Grape
                // package. NOTE: the Grape package also defines a SwiftUI view
                // product named 'Grape' (= MiniMap + Toolbar + Panel = ADR-0008
                // view-architecture risk surface); that product is REJECTED and
                // NOT imported here. Only ForceSimulation (= pure data: physics
                // spring simulation for force-directed graph layout) is adopted.
                .product(name: "ForceSimulation", package: "Grape"),

                // batch 2 issue 07: MenuBarExtraAccess product (= macOS
                // platform integration for SwiftUI MenuBarExtra show/hide/toggle
                // control). ADR-0008 carve-out: macOS platform integration IS
                // allowed (= the lib is a pure macOS platform adapter, not a
                // view-framework / pane / dock / split / drag library).
                .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess"),
                .product(name: "EventSource", package: "EventSource"),
                .product(name: "Textual", package: "textual"),
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
                .product(name: "ViewInspector", package: "ViewInspector"),
                // batch 1 issue 05: visual regression test support for ticket 028-011
                // (= drag-lost regression suite). Pairs with ViewInspector: structure
                // assertions vs pixel snapshots. README warns NOT to add to runtime target.
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/WenshuAppTests"
        )
    ]
)
