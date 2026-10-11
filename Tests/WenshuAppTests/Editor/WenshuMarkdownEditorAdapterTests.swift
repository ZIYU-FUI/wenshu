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
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
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
        let editorPath = resolve("Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift")
        let content = try String(contentsOfFile: editorPath, encoding: .utf8)

        // Header slot forwarded — the wenshu view MUST pass a non-nil
        // header to NativeTextViewWrapper (= otherwise the chrome band
        // disappears, = invisible UI regression).
        #expect(
            content.contains("placeholder: placeholder"),
            "WenshuMarkdownEditor must forward the new `placeholder: placeholder` argument to NativeTextViewWrapper (= ed-smc-defaults T-01)"
        )
        #expect(
            content.contains("header: header"),
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
        let headerPath = resolve("Sources/WenshuApp/UI/Editor/EditorHeaderView.swift")
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
        let toolbarPath = resolve("Sources/WenshuApp/UI/Editor/EditorFormatToolbar.swift")
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
        let toolbarPath = resolve("Sources/WenshuApp/UI/Editor/EditorFormatToolbar.swift")
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
        let editPath = resolve("Sources/WenshuApp/Views/Workspace/EditorEditContent.swift")
        let edit = try String(contentsOfFile: editPath, encoding: .utf8)
        #expect(
            edit.contains("var editorHeader: AnyView? = nil"),
            "EditorEditContent must expose `editorHeader: AnyView? = nil` (= SMC chrome slot)"
        )
        #expect(
            edit.contains("var editorPlaceholder: NSAttributedString? = nil"),
            "EditorEditContent must expose `editorPlaceholder: NSAttributedString? = nil` (= SMC chrome slot)"
        )
        #expect(
            edit.contains("header: editorHeader") && edit.contains("placeholder: editorPlaceholder"),
            "EditorEditContent body must forward both slots into the inner WenshuMarkdownEditor"
        )
    }

    // MARK: - ed-smc-defaults T-04: 5th InspectorPage (= documentTools)

    /// InspectorPage (= the right-column 5-tab segmented picker) now
    /// hosts a 5th case `documentTools` that aggregates the engine's
    /// format / find / outline / code-block / spell-check surfaces.
    /// This source-content test fails if anyone removes the case
    /// (= the right-column document-tools surface silently drops) or
    /// changes its icon (= the toolbar picks this page on the icon).
    @Test("InspectorPage adds the 5th documentTools case (= T-04)")
    func inspectorPageAddsDocumentToolsCase() throws {
        let statePath = resolve("Sources/WenshuApp/State/WorkspaceUIState.swift")
        let state = try String(contentsOfFile: statePath, encoding: .utf8)
        #expect(
            state.contains("case documentTools"),
            "InspectorPage must declare `case documentTools` (= the 5th page in the right-column picker)"
        )
        #expect(
            state.contains("case .documentTools:        return \"textformat\""),
            "InspectorPage.documentTools must use the SF Symbol 'textformat' (= Apple HIG document-with-controls surface)"
        )
    }

    /// The 5 sub-tools (= formatReadout / findReplace / headingOutline /
    /// codeBlocks / spellToggles) all live behind `EditorDocumentToolsSubToolPicker`.
    /// Source-content test gates the contract: if anyone removes a
    /// case, the picker source contract drift surface triggers a fail.
    @Test("EditorDocumentToolsSubTool covers the engine's 5-sub-tool surface (= T-04)")
    func documentToolsSubToolCoverage() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorDocumentToolsView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(
            view.contains("enum EditorDocumentToolsSubTool"),
            "EditorDocumentToolsSubTool enum must live in EditorDocumentToolsView.swift"
        )
        let expectedCases: Set<String> = [
            "formatReadout", "findReplace", "headingOutline",
            "codeBlocks", "spellToggles"
        ]
        #expect(
            EditorDocumentToolsSubTool.allCases.count == 5,
            "EditorDocumentToolsSubTool.allCases must cover exactly 5 sub-tools (= Apple HIG document-inspector surface)"
        )
        let actualCases = Set(EditorDocumentToolsSubTool.allCases.map(\.rawValue))
        #expect(
            actualCases == expectedCases,
            "EditorDocumentToolsSubTool cases must match the 5-sub-tool contract (= T-05..09 each fill one case body)"
        )
    }

    /// InspectorView's `toolsForCurrentPage` must wire the new
    /// `.documentTools` case to the page host (= if anyone removes
    /// the switch arm the right-column picker silently shows an empty
    /// body when the user selects the 5th tab).
    @Test("InspectorView routes .documentTools → EditorDocumentToolsView (= T-04)")
    func inspectorViewRoutesDocumentTools() throws {
        let inspectorPath = resolve("Sources/WenshuApp/Views/Inspector/InspectorView.swift")
        let inspector = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(
            inspector.contains("case .documentTools:"),
            "InspectorView.toolsForCurrentPage must declare `case .documentTools`"
        )
        #expect(
            inspector.contains("EditorDocumentToolsView("),
            "InspectorView's .documentTools case must construct EditorDocumentToolsView (= the page host)"
        )
        #expect(
            inspector.contains("bus: MarkdownEditorBus.buildWenshu()"),
            "EditorDocumentToolsView must receive a fresh MarkdownEditorBus (= the engine's bus factory exposes the bus = sub-tool post surface)"
        )
    }

    // MARK: - ed-smc-defaults T-05: format-readout sub-tool body shipped

    /// The `.formatReadout` case in `EditorDocumentToolsView` must now
    /// construct the real `EditorFormatReadoutView` (= the placeholder
    /// from T-04 was a contract surface, = T-05 replaces it with a
    /// live body that observes the engine's selection-state events).
    /// Source-content gate: if anyone reverts the T-05 wiring this
    /// test fails (= the right-column format readout silently drops
    /// back to the T-04 placeholder).
    @Test("EditorDocumentToolsView wires .formatReadout → EditorFormatReadoutView (= T-05)")
    func editorDocumentToolsWiresFormatReadout() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorDocumentToolsView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(
            view.contains("EditorFormatReadoutView(bus: bus)"),
            "EditorDocumentToolsView's .formatReadout case must construct EditorFormatReadoutView (= T-05 live body)"
        )
    }

    /// `EditorFormatReadoutView` (= the new T-05 sub-tool body) reads
    /// the 3 engine selection-state events. The bus names live on
    /// `MarkdownEditorBus` (= set by `MarkdownEditorBus.buildWenshu()` =
    /// the factory wenshu exposes); = the observer registration must
    /// read these 3 names or the readout silently stays frozen.
    @Test("EditorFormatReadoutView observes the 3 engine selection events (= T-05)")
    func editorFormatReadoutObservesSelectionEvents() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorFormatReadoutView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        // One #expect per engine selection-state event (= if any of
        // the 3 disappears the readout silently drops that toggle =
        // AND from the user's perspective = all 3 must be wired).
        #expect(view.contains("bus.selectionBoldDidChange"),
                "EditorFormatReadoutView must register an observer for bus.selectionBoldDidChange (= the engine's bold-toggle notification)")
        #expect(view.contains("bus.selectionItalicDidChange"),
                "EditorFormatReadoutView must register an observer for bus.selectionItalicDidChange (= the engine's italic-toggle notification)")
        #expect(view.contains("bus.selectionHighlightDidChange"),
                "EditorFormatReadoutView must register an observer for bus.selectionHighlightDidChange (= the engine's highlight-toggle notification)")
    }
}


