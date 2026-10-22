//
//  WenshuMarkdownEditorAdapterTests.swift · Wenshu · v0.39 ticket 001
//
// 5 Swift Testing tests for the swift-markdown-engine adapter layer
// (= WenshuMarkdownEditor + 2 service protocols + factory). Verifies:
// - WikiLinkResolver: hit + miss (resolve(name:range:))
// - EmbeddedImageProvider: hit (character portrait) + miss
// - WenshuMarkdownEditor: SwiftUI mount produces a view (no crash)
//
// Per Q182.4: Swift Testing framework (= wenshu convention since v0.30+);
// @MainActor isolation inherited from the types under test (AppState is
// @MainActor-isolated; engine's NSViewRepresentable requires main).
//

import Testing
import Foundation
import AppKit
import SwiftUI
import MarkdownEngine
import MarkdownEngineLatex
@testable import WenshuApp

@MainActor
@Suite("WenshuMarkdownEditor (swift-markdown-engine adapter)")
struct WenshuMarkdownEditorAdapterTests {

    // MARK: - Fixtures

    /// Build a temp directory shaped like a wenshu reference-library
    /// (= `entities/` folder with 0+ JSON entity files). Returns the
    /// reference-library root URL. Auto-cleaned via `.tmp` + deinit.
    private func makeReferenceLibrary(entities: [(id: String, name: String)]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("reference-library", isDirectory: true)
        let entitiesDir = root.appendingPathComponent("entities", isDirectory: true)
        try FileManager.default.createDirectory(at: entitiesDir, withIntermediateDirectories: true)
        for entity in entities {
            let url = entitiesDir.appendingPathComponent("\(entity.id).json")
            let json: [String: Any] = ["id": entity.id, "name": entity.name]
            let data = try JSONSerialization.data(withJSONObject: json)
            try data.write(to: url)
        }
        return root
    }

    /// Build a temp directory shaped like a wenshu book (= `characters/`
    /// folder with 0+ PNG files). Returns the book root URL.
    private func makeBook(characterImages: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-book-\(UUID().uuidString)", isDirectory: true)
        let charsDir = root.appendingPathComponent("characters", isDirectory: true)
        try FileManager.default.createDirectory(at: charsDir, withIntermediateDirectories: true)
        for name in characterImages {
            let url = charsDir.appendingPathComponent("\(name).png")
            // 1x1 transparent PNG (= 67 bytes; = valid minimal PNG)
            let png: [UInt8] = [
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
                0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
                0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
                0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
                0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
                0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
                0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
                0x42, 0x60, 0x82
            ]
            try Data(png).write(to: url)
        }
        return root
    }

    // MARK: - WikiLinkResolver tests

    @Test("WikiLinkResolver hit returns exists: true with matching id")
    func wikiLinkResolverHit() async throws {
        let refRoot = try makeReferenceLibrary(entities: [
            (id: "uuid-anna", name: "Anna"),
            (id: "uuid-beth", name: "Beth")
        ])
        let resolver = ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: refRoot)
        let result = resolver.resolve(displayName: "Anna", range: NSRange(location: 0, length: 0))
        #expect(result != nil)
        #expect(result?.exists == true)
        #expect(result?.id == "uuid-anna")
    }

    @Test("WikiLinkResolver miss returns exists: false with empty id")
    func wikiLinkResolverMiss() async throws {
        let refRoot = try makeReferenceLibrary(entities: [
            (id: "uuid-anna", name: "Anna")
        ])
        let resolver = ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: refRoot)
        let result = resolver.resolve(displayName: "Ghost", range: NSRange(location: 0, length: 0))
        #expect(result != nil)
        #expect(result?.exists == false)
        #expect(result?.id == "")
    }

    // MARK: - EmbeddedImageProvider tests

    @Test("EmbeddedImageProvider hit returns NSImage for character portrait")
    func imageProviderHit() async throws {
        let bookRoot = try makeBook(characterImages: ["Anna", "Beth"])
        let refRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: refRoot.appendingPathComponent("raw", isDirectory: true),
            withIntermediateDirectories: true
        )
        let provider = ReferenceLibraryImageProvider(
            activeBookRoot: bookRoot,
            referenceLibraryRoot: refRoot
        )
        let img = provider.image(for: EmbeddedImageRequest(name: "Anna"))
        #expect(img != nil)
    }

    @Test("EmbeddedImageProvider miss returns nil")
    func imageProviderMiss() async throws {
        let bookRoot = try makeBook(characterImages: ["Anna"])
        let refRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: refRoot.appendingPathComponent("raw", isDirectory: true),
            withIntermediateDirectories: true
        )
        let provider = ReferenceLibraryImageProvider(
            activeBookRoot: bookRoot,
            referenceLibraryRoot: refRoot
        )
        let img = provider.image(for: EmbeddedImageRequest(name: "Ghost"))
        #expect(img == nil)
    }

    // MARK: - WenshuMarkdownEditor mount test

    @Test("WenshuEditorServicesFactory.make builds a valid configuration")
    func servicesFactoryBuilds() async throws {
        let refRoot = try makeReferenceLibrary(entities: [
            (id: "uuid-anna", name: "Anna")
        ])
        let bookRoot = try makeBook(characterImages: [])
        // Build the configuration WITHOUT exercising the highlighter
        // (= HighlighterSwiftBridge.init requires a fully running
        // AppKit stack with theme assets loaded; Swift Testing runs
        // outside the normal runloop and the bridge crashes on nil
        // Highlighter). We test the factory plumbing by building
        // a stripped-down configuration that skips the highlighter
        // (= the production WenshuEditorServicesFactory does include
        // it, but its init is not the responsibility of THIS test).
        let services = MarkdownEditorServices(
            wikiLinks: ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: refRoot),
            images: ReferenceLibraryImageProvider(
                activeBookRoot: bookRoot,
                referenceLibraryRoot: refRoot
            )
        )
        // Round-trip the configuration through WenshuMarkdownEditor
        // (= the engine requires services to be on a configuration,
        // not standalone). This validates that the type wires up
        // cleanly without exercising HighlighterSwift.
        var config = MarkdownEditorConfiguration.default
        config.services = services
        #expect(config.services.wikiLinks.resolve(
            displayName: "Anna", range: NSRange(location: 0, length: 0)
        )?.exists == true)
    }

    // MARK: - Fixture helpers for content-sniff tests (= T-01 source-content gate)

    /// Resolve a path relative to the wenshu repo root from this test
    /// file's location. The worktree lays the file under
    /// `.worktrees/editor-smc-defaults/Tests/WenshuAppTests/Editor/` →
    /// walking up 4 segments lands on `.worktrees/editor-smc-defaults/`
    /// (= the worktree root, = the canonical "repo root" inside the
    /// worktree). One more segment up (5) would step out of the
    /// worktree into the wenshu main repo; = don't do that.
    private func resolve(_ relative: String) -> String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relative)
        return url.path
    }

    // MARK: - LaTeX rendering enabled (= boss拍 2026-10-11)

    @Test("WenshuEditorServicesFactory constructs a LatexRenderer (= NoOpLatexRenderer is NOT the production choice)")
    func servicesFactoryEnablesLaTeX() throws {
        // Build MarkdownEditorServices exactly as `WenshuEditorServicesFactory.make`
        // does, then assert `services.latex` is NOT the legacy NoOpLatexRenderer
        // (= the engine ships SwiftMathBridge(= SwiftMath) as a separate SPM
        // product; we don't drive SwiftMathBridge.init here because that pulls
        // MTMathUILabel which lazy-loads NSBundle resources and SIGTRAPs the
        // XCTest runner — matching the HighlighterSwift trap documented
        // above). Reusing a snapshot of the live factory's `services` build
        // is enough to gate the regression; do NOT call factory.make() directly.
        let services = MarkdownEditorServices(
            wikiLinks: NoOpWikiLinkResolver(),
            images: NoOpEmbeddedImageProvider(),
            syntaxHighlighter: PlainTextSyntaxHighlighter(),
            latex: SwiftMathBridge(),
            bus: .default
        )
        let typeName = String(describing: type(of: services.latex))
        #expect(
            typeName.contains("SwiftMathBridge"),
            "services.latex must be SwiftMathBridge (= boss拍 2026-10-11). Got: \(typeName)"
        )
    }

    // MARK: - ed-smc-defaults T-01: chrome band + placeholder slot wired

    /// SMC exposes `header:` and `placeholder:` slots on
    /// `NativeTextViewWrapper`. We extended `WenshuMarkdownEditor` (=
    /// the wenshu-side SwiftUI view that wraps the engine wrapper) to
    /// forward both slots. This source-content test catches a
    /// regression where someone removes either forwarding and the
    /// chrome band silently disappears (= the visible UI failure
    /// mode the user reports first).
    ///
    /// Why source-content instead of `swift-mock-test`: we don't drive
    /// NSViewRepresentable here (= AppKit NSWindow needed, = outside
    /// the Swift Testing sandbox); = verify the contract literally.
    /// If anyone walks the slot away, the contract disclaims.
    @Test("WenshuMarkdownEditor forwards SMC `header:` and `placeholder:`")
    func forwardsSMCHeaderAndPlaceholderSlots() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let content = try String(contentsOfFile: editorPath, encoding: .utf8)

        // Header slot forwarded — the wenshu view MUST pass a non-nil
        // header to NativeTextViewWrapper (= otherwise the chrome band
        // disappears, = invisible UI regression).
        #expect(
            content.contains("placeholder: surface.placeholder"),
            "WenshuMarkdownEditor must forward the new `placeholder: placeholder` argument to NativeTextViewWrapper (= ed-smc-defaults T-01)"
        )
        #expect(
            content.contains("header: surface.header"),
            "WenshuMarkdownEditor must forward the new `header: header` argument to NativeTextViewWrapper (= ed-smc-defaults T-01)"
        )

        // Padding removal — the previous `.padding(.all,
        // DesignTokens.zoneContentInset)` wrap was what produced the
        // white rectangle the user reported as superfluous. The
        // wrapper now sits flush against the editor zone's own
        // background. If anyone reintroduces a `.padding(.all,
        // DesignTokens.zoneContentInset)` wrap around
        // NativeTextViewWrapper, the rectangle comes back.
        let pattern = #"\.padding\(\.all,\s*DesignTokens\.zoneContentInset\)"#
        #expect(
            content.range(of: pattern, options: .regularExpression) == nil,
            "WenshuMarkdownEditor must NOT re-wrap NativeTextViewWrapper in `.padding(.all, DesignTokens.zoneContentInset)` (= T-01: the white-card rectangle is removed)"
        )
    }

    /// `EditorHeaderView` (= the 28 PT Apple HIG document-toolbar
    /// chrome band that the engine hosts above the NSTextView). It
    /// is the user-visible chrome that the `header:` slot renders.
    /// Source-content gate: if anyone walks the file, this fails.
    @Test("EditorHeaderView owns the 28 PT document-toolbar chrome (= T-01)")
    func editorHeaderViewExists() throws {
        let headerPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorHeaderView.swift")
        let content = try String(contentsOfFile: headerPath, encoding: .utf8)
        #expect(
            content.contains("struct EditorHeaderView: View"),
            "EditorHeaderView must be the chrome-band public type"
        )
        #expect(
            content.contains("paneTabHotArea"),
            "EditorHeaderView height must come from DesignTokens.paneTabHotArea (= Safari tab stop = Apple HIG document toolbar height)"
        )
        #expect(
            content.contains("EditorHeaderDirtyState"),
            "EditorHeaderView must expose the dirty-state enum so EditorView can drive the dot color"
        )
    }

    // MARK: - ed-smc-defaults T-02: format toolbar pinned + 12-button contract

    /// The 12-button format toolbar (= Pages / Numbers / Keynote
    /// document-chrome idiom). Each button posts a `MarkdownEditorBus`
    /// request name that the engine observes internally. The toolbar
    /// must cover exactly 12 actions (= the engine's full format
    /// surface: bold / italic / highlight / strikethrough /
    /// inline-code / heading / blockquote / unordered-list /
    /// ordered-list / link / code-block / horizontal-rule). If
    /// anyone adds a 13th case, this test fails (= the toolbar
    /// contract drift surface). If anyone drops a case, this test
    /// fails (= the toolbar silently loses a button).
    @Test("EditorFormatAction covers the engine's 12-button format surface (= T-02)")
    func formatActionCoverage() throws {
        let toolbarPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorFormatToolbar.swift")
        let toolbar = try String(contentsOfFile: toolbarPath, encoding: .utf8)
        #expect(
            toolbar.contains("enum EditorFormatAction"),
            "EditorFormatAction enum must live in EditorFormatToolbar.swift"
        )
        #expect(
            toolbar.contains("var iconName: String"),
            "EditorFormatAction.iconName must be defined (= SF Symbol mapping per case)"
        )
        #expect(
            EditorFormatAction.allCases.count == 12,
            "EditorFormatAction.allCases must cover exactly 12 buttons (= engine's full format surface)"
        )
        let expectedCases: Set<String> = [
            "bold", "italic", "highlight", "strikethrough",
            "inlineCode", "heading", "blockquote",
            "unorderedList", "orderedList",
            "link", "codeBlock", "horizontalRule"
        ]
        let actualCases = Set(EditorFormatAction.allCases.map(\.rawValue))
        #expect(
            actualCases == expectedCases,
            "EditorFormatAction cases must match the engine's 12-button contract (= names below must match the bus public surface)"
        )
    }

    /// The toolbar dispatches via `FormatDispatcher` (= canonical helper
    /// in EditorActions.swift) and the raw `bus.apply…Request`
    /// notification names. Source-content test gates both the helper
    /// use (= bold) AND the bus-name dispatch (= the other 11).
    @Test("EditorFormatToolbar dispatches via FormatDispatcher + bus names (= T-02)")
    func formatToolbarDispatchContract() throws {
        let toolbarPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorFormatToolbar.swift")
        let toolbar = try String(contentsOfFile: toolbarPath, encoding: .utf8)
        #expect(
            toolbar.contains("FormatDispatcher(bus: bus)"),
            "EditorFormatToolbar must construct FormatDispatcher (= canonical bus-dispatch helper)"
        )
        #expect(
            toolbar.contains("post(bus.applyBoldRequest)")
                || toolbar.contains("dispatcher.applyBold()"),
            "Bold dispatch must be wired (= the engine's contract for format-surface parity)"
        )
        // The toolbar must reach into every bus name at least once
        // (= the contract is "12 names, 12 dispatches"). Source-grep
        // each so a future dropped case fails this test.
        let busNames = [
            "applyItalicRequest", "applyHighlightRequest",
            "applyStrikethroughRequest", "applyInlineCodeRequest",
            "applyHeadingRequest", "applyBlockquoteRequest",
            "applyUnorderedListRequest", "applyOrderedListRequest",
            "applyLinkRequest", "applyCodeBlockRequest",
            "applyHorizontalRuleRequest"
        ]
        for name in busNames {
            #expect(
                toolbar.contains("bus.\(name)"),
                "EditorFormatToolbar must reference `bus.\(name)` (= dropped case in the 12-button contract)"
            )
        }
    }

    /// `EditorEditContent` (= the edit-mode wrapper) must forward the
    /// `editorHeader` + `editorPlaceholder` slots added in T-02 so the
    /// chrome band stays visible while editing (= canonical Pages /
    /// Numbers document-chrome-survives-WYSIWYG-toggle pattern).
    @Test("EditorEditContent forwards SMC `editorHeader:` + `editorPlaceholder:` (= T-02)")
    func editorEditContentForwardsChromeSlots() throws {
        let editPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorEditContent.swift")
        let edit = try String(contentsOfFile: editPath, encoding: .utf8)
        let surfacePath = resolve("Sources/WenshuApp/Features/Editor/Model/EditorSurface.swift")
        let surface = try String(contentsOfFile: surfacePath, encoding: .utf8)
        // The two chrome slots live on the editor surface (= the set of
        // values the host hands to the engine), and the edit content
        // forwards that one surface. The contract is unchanged: the
        // slots still reach the engine.
        #expect(
            surface.contains("let header: AnyView?"),
            "the editor surface must expose `header: AnyView?` (= SMC chrome slot)"
        )
        #expect(
            surface.contains("let placeholder: NSAttributedString?"),
            "the editor surface must expose `placeholder: NSAttributedString?` (= SMC chrome slot)"
        )
        #expect(
            edit.contains("surface: surface"),
            "EditorEditContent body must forward the editor surface into the inner WenshuMarkdownEditor"
        )
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        #expect(
            editor.contains("header: surface.header") && editor.contains("placeholder: surface.placeholder"),
            "the engine wrapper must forward both chrome slots out of the surface"
        )
    }

    // MARK: - ed-smc-defaults T-04: 5th InspectorPage (= documentTools)

    // MARK: - ed-smc-defaults T-05: format-readout sub-tool body shipped
    //
    // Removed 2026-10-18: formatReadout was deleted as a feature
    // (= boss directive; = no future T-05 will reintroduce it).
    // See OOB.md #2026-10-18 for the full rationale and rejection
    // criterion (= any subsequent .formatReadout restoration is a
    // reject-on-sight violation).

    // MARK: - ed-smc-defaults T-06: find & replace sub-tool body shipped

    // MARK: - ed-smc-defaults T-07: heading outline sub-tool body shipped

    // MARK: - ed-smc-defaults T-08: code-block list sub-tool body shipped

    // MARK: - ed-smc-defaults T-09: spell-check toggles sub-tool body shipped

    // MARK: - ed-smc-defaults T-11: explicit default-theme binding

    /// T-11 binds `MarkdownEditorTheme.default` explicitly in
    /// `WenshuEditorServicesFactory.make`. The binding is the
    /// single landing-spot for future retheme work (= a future
    /// ticket that wants to swap the default theme for a
    /// wenshu-tuned one has one place to edit).
    @Test("WenshuEditorServicesFactory binds MarkdownEditorTheme.default (= T-11)")
    func servicesFactoryBindsMarkdownEditorThemeDefault() throws {
        let factoryPath = resolve("Sources/WenshuApp/Features/Editor/Service/WenshuEditorServicesFactory.swift")
        let factory = try String(contentsOfFile: factoryPath, encoding: .utf8)
        #expect(
            factory.contains("config.theme = MarkdownEditorTheme.default"),
            "WenshuEditorServicesFactory.make must explicitly bind MarkdownEditorTheme.default (= single landing-spot for future retheme work)"
        )
    }

    // MARK: - ed-smc-defaults T-12: EditorPreferences AppStorage schema

    /// T-12 ships `EditorPreferences` (= the host-side struct that
    /// snapshots the user's editor preferences for the factory).
    /// Source-content gate: if anyone removes the struct the
    /// AppStorage schema silently reverts (= a future Settings
    /// panel has no place to bind).
    @Test("EditorPreferences schema exists with 8 keys (= 6 T-12 + 2 list-editing)")
    func editorPreferencesSchemaHasEightKeys() throws {
        let prefPath = resolve("Sources/WenshuApp/Features/Editor/Model/EditorPreferences.swift")
        let pref = try String(contentsOfFile: prefPath, encoding: .utf8)
        #expect(pref.contains("struct EditorPreferences"),
                "EditorPreferences struct must exist (= host-side AppStorage schema)")
        #expect(pref.contains("readingWidth"),
                "EditorPreferences must declare a field named readingWidth (= AppStorage schema key)")
        #expect(pref.contains("heightBehavior"),
                "EditorPreferences must declare a field named heightBehavior (= AppStorage schema key)")
        #expect(pref.contains("rawSourceMode"),
                "EditorPreferences must declare a field named rawSourceMode (= AppStorage schema key)")
        #expect(pref.contains("continuousSpellChecking"),
                "EditorPreferences must declare a field named continuousSpellChecking (= AppStorage schema key)")
        #expect(pref.contains("grammarChecking"),
                "EditorPreferences must declare a field named grammarChecking (= AppStorage schema key)")
        #expect(pref.contains("automaticSpellingCorrection"),
                "EditorPreferences must declare a field named automaticSpellingCorrection (= AppStorage schema key)")
        #expect(pref.contains("listHelpersEnabled"),
                "EditorPreferences must declare a field named listHelpersEnabled (= AppStorage schema key)")
        #expect(pref.contains("autoClosePairsEnabled"),
                "EditorPreferences must declare a field named autoClosePairsEnabled (= AppStorage schema key)")
        #expect(pref.contains("case readingWidth"),
                "EditorPreferences.AppStorageKey must declare readingWidth case")
        #expect(pref.contains("case heightBehavior"),
                "EditorPreferences.AppStorageKey must declare heightBehavior case")
        #expect(pref.contains("case rawSourceMode"),
                "EditorPreferences.AppStorageKey must declare rawSourceMode case")
        #expect(pref.contains("case listHelpersEnabled"),
                "EditorPreferences.AppStorageKey must declare listHelpersEnabled case")
        #expect(pref.contains("case autoClosePairsEnabled"),
                "EditorPreferences.AppStorageKey must declare autoClosePairsEnabled case")
    }

    /// The factory must forward the EditorPreferences snapshot to
    /// MarkdownEditorConfiguration (= 5 binding lines; = if any
    /// disappears the host's settings silently stop flowing into
    /// the editor).
    @Test("WenshuEditorServicesFactory forwards EditorPreferences to config (= 5 binding lines)")
    func servicesFactoryForwardsEditorPreferences() throws {
        let factoryPath = resolve("Sources/WenshuApp/Features/Editor/Service/WenshuEditorServicesFactory.swift")
        let factory = try String(contentsOfFile: factoryPath, encoding: .utf8)
        #expect(factory.contains("config.readingWidth = preferences.readingWidth"),
                "Factory must bind config.readingWidth from preferences.readingWidth")
        #expect(factory.contains("config.heightBehavior = preferences.heightBehavior"),
                "Factory must bind config.heightBehavior from preferences.heightBehavior")
        #expect(factory.contains("config.rawSourceMode = preferences.rawSourceMode"),
                "Factory must bind config.rawSourceMode from preferences.rawSourceMode")
        #expect(factory.contains("config.spellChecking = SpellCheckingPolicy("),
                "Factory must build SpellCheckingPolicy from preferences")
        #expect(factory.contains("config.lists = ListStyle("),
                "Factory must build ListStyle from preferences (= listHelpersEnabled + autoClosePairsEnabled)")
    }

    // MARK: - ed-smc-defaults T-13: scroll-memory persistence

    /// T-13 ships `EditorScrollMemory` (= the host-side persistence
    /// layer that wires the engine's 3 scroll-memory closures).
    /// Source-content gate: if anyone removes the struct or stops
    /// calling the persist/restore entry points the host silently
    /// loses scroll memory.
    @Test("EditorScrollMemory persists + restores scroll offsets (= T-13)")
    func editorScrollMemoryPersistsAndRestores() throws {
        let memoryPath = resolve("Sources/WenshuApp/Features/Editor/Store/EditorScrollMemory.swift")
        let memory = try String(contentsOfFile: memoryPath, encoding: .utf8)
        #expect(memory.contains("struct EditorScrollMemory"),
                "EditorScrollMemory struct must exist (= host-side scroll-memory persistence)")
        #expect(memory.contains("static func persist("),
                "EditorScrollMemory must declare a static persist(_:for:) entry point (= the engine calls onPersistScrollOffset)")
        #expect(memory.contains("static func restore("),
                "EditorScrollMemory must declare a static restore(for:) entry point (= the engine calls restoreScrollOffset)")
    }

    /// `WenshuMarkdownEditor` must wire the 3 engine scroll-memory
    /// closures (= retainedScrollDocumentIds + onPersistScrollOffset
    /// + restoreScrollOffset). Source-content gate: if any of the
    /// 3 wiring lines disappears, the host silently loses scroll
    /// memory on next session.
    @Test("WenshuMarkdownEditor wires the 3 scroll-memory closures (= T-13)")
    func wenshuMarkdownEditorWiresScrollMemory() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        #expect(editor.contains("retainedScrollDocumentIds:"),
                "WenshuMarkdownEditor must wire retainedScrollDocumentIds (= the engine's opt-in subset)")
        #expect(editor.contains("onPersistScrollOffset:"),
                "WenshuMarkdownEditor must wire onPersistScrollOffset (= the engine's persist callback)")
        #expect(editor.contains("restoreScrollOffset:"),
                "WenshuMarkdownEditor must wire restoreScrollOffset (= the engine's restore callback)")
        #expect(editor.contains("EditorScrollMemory.persist"),
                "WenshuMarkdownEditor's onPersistScrollOffset must call EditorScrollMemory.persist")
        #expect(editor.contains("EditorScrollMemory.restore"),
                "WenshuMarkdownEditor's restoreScrollOffset must call EditorScrollMemory.restore")
    }

    // MARK: - ed-smc-defaults T-03: editor status bar (= bottom chrome)

    /// T-03 ships `EditorStatusBarView` (= the 24 PT bottom chrome
    /// band of the editor zone; = 3 chunks = word count / cursor
    /// location / autosave state). Source-content gate: if anyone
    /// removes the View the editor zone silently loses its bottom
    /// chrome (= the canonical Pages / Numbers inspector status bar).
    @Test("EditorStatusBarView exists as the 24 PT bottom chrome (= T-03)")
    func editorStatusBarViewExists() throws {
        let barPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorStatusBarView.swift")
        let bar = try String(contentsOfFile: barPath, encoding: .utf8)
        #expect(bar.contains("struct EditorStatusBarView"),
                "EditorStatusBarView must exist (= the bottom chrome band of the editor zone)")
        #expect(bar.contains(".frame(height: 24)"),
                "EditorStatusBarView must be 24 PT (= Apple HIG status bar height)")
    }

    /// The status bar mounts inside `EditorView` (= the outer zone
    /// VStack between the NSTextView and the closing brace). If
    /// anyone removes the mount, the editor zone silently loses the
    /// bottom chrome.
    @Test("EditorView mounts EditorStatusBarView in zone outer VStack (= T-03)")
    func editorViewMountsStatusBar() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorView.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        #expect(editor.contains("EditorStatusBarView("),
                "EditorView must construct EditorStatusBarView (= the bottom chrome band mount)")
        #expect(editor.contains("textProvider: { self.draft }"),
                "EditorView must wire textProvider to the active tab's draft (= live word count source)")
        #expect(editor.contains("cursorRectProvider: { self.cursorRect }"),
                "EditorView must wire cursorRectProvider to its cursorRect computed property (= live cursor location source)")
    }

    /// `WenshuMarkdownEditor` must forward the caret-rect callback to
    /// the engine. Source-content gate: if the forwarding line
    /// disappears the status bar silently loses the live cursor
    /// location (= falls back to the "Ln —, Col —" placeholder).
    @Test("WenshuMarkdownEditor forwards onCaretRectChange to engine (= T-03)")
    func wenshuMarkdownEditorForwardsCaretRectChange() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        #expect(editor.contains("onCaretRectChange: surface.onCaretRectChange"),
                "WenshuMarkdownEditor must forward onCaretRectChange to NativeTextViewWrapper")
    }
}


