// swift-tools-version: 6.4
//
// Package.swift · Wenshu (Wenshu) · v0.00.0 project baseline (2026-08-14 owner decision "bootstrap from 0.00.0")
//
// Source of truth: @AGENTS.md + @CLAUDE.md + @wenshu-pour/architecture/CONTEXT.md (= owner 11 decisions)
//
// Architecture: Swift/SwiftUI single-process macOS desktop app (= Apple ecosystem exclusive, v1 only macOS).
// v0.00.0 bootstrap = app entry point that opens a window; features follow via /to-tickets.
//
// Third-party pins are limited to what a call site names. Removing a pin
// requires the same grep cross-check that retired the earlier batch:
// a package with zero `import` sites stays out of this file, and its
// transitive tail (swift-markdown -> cmark-gfm, swift-snapshot-testing ->
// swift-syntax / swift-custom-dump / swift-issue-reporting) goes with it.
// Reintroducing one requires a ticket naming the first consumer's import path.

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
        // Lock to the 0.13.x line (= directive-by-extension seam + LaTeX display mode +
        // code-block stale-cache crash fix + per-marker thematic break). 0.14.0 adds
        // the directive glyph + autocomplete surface (= a wider API delta; = planned
        // upgrade ticket once 0.14.1 lands). Range "0.13.0"..<"0.14.0" keeps the
        // pre-1.0 SemVer rule anchored at 0.13.0 (= SPM does NOT climb to 0.14.x).
        .package(url: "https://github.com/nodes-app/swift-markdown-engine", "0.13.0"..<"0.14.0"),

        // RUNTIME — UI enhancement: code-fence syntax highlight. Highlighter itself
        // is reached through MarkdownEngineCodeBlocks.HighlighterSwiftBridge; the
        // product is not linked into WenshuApp because no call site names a
        // Highlighter type directly. The pin stays because it holds the version
        // floor above swift-markdown-engine's own `from: "3.0.0"`.
        .package(url: "https://github.com/smittytone/HighlighterSwift", from: "3.1.0"),

        // RUNTIME — SSE stream client (= AnthropicStreaming + AnthropicStreamingWireup import EventSource)
        .package(url: "https://github.com/mattt/EventSource", from: "1.5.1"),

        // TEST — SwiftUI view hierarchy inspection (testTarget only, no runtime)
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.3"),

        // v3.1 governance A1g.4.1: local WenshuData package (= data layer; = extracted per ADR-0016).
        .package(name: "WenshuData", path: "Sources/WenshuData"),

        // Local WenshuAgent package (= agent layer; = extracted per AGENTS.md 6.4).
        // Independent of WenshuData so the agent runtime keeps its own version
        // boundary and test target. Layering: WenshuApp -> WenshuTool<Name> ->
        // WenshuAgent -> WenshuData. A writing tool reaches this package's
        // public surface only; it cannot reach WenshuApp.
        .package(name: "WenshuAgent", path: "Sources/WenshuAgent")
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            dependencies: [
                // Canonical icon rendering goes through Image(systemName: ...)
                // on Apple SF Symbols 6 (built into m

                // v3.1 governance A1g.4.2-4.4: WenshuData product wired
                // up here (= the 38 files have been moved into the
                // WenshuData target; = the boundary has been verified
                // smoke-test clean; = the App target can now see all
                // public @Model + Container + Repository types).
                .product(name: "WenshuData", package: "WenshuData"),
                .product(name: "WenshuAgent", package: "WenshuAgent"),

                // RUNTIME — Apple SF Symbols 6 (= built into macOS 27; = zero SPM
                // dependency; = see top-level note in the dependencies array).
                // v0.39 ticket 001: chapter editor.
                .product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine"),
                // LaTeX rendering via SwiftMathBridge (= enable 2026-10-11 boss拍).
                // Same Package, separate product. Hosts SwiftMath 1.7.3 transitively
                // (= Package.resolved already pins it).
                .product(name: "MarkdownEngineLatex", package: "swift-markdown-engine"),
                .product(name: "EventSource", package: "EventSource"),
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
                "Features/Agent/Store/AgentLifecycleTrackerDesign.md",
                "Shared/UI/ComponentDocs/ComponentIndex.md",
                // Per-region view wrapper design docs (= humans + LLMs,
                // not Swift compiler; = no runtime Bundle access).
                "Shared/UI/ComponentDocs/SFRegions.md",
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
                .product(name: "WenshuData", package: "WenshuData"),
                .product(name: "ViewInspector", package: "viewinspector"),
                // 2026-10-11 LaTeX regression gate (= factory wires SwiftMathBridge).
                .product(name: "MarkdownEngineLatex", package: "swift-markdown-engine"),
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
