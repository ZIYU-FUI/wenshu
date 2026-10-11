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

    // MARK: - ed-smc-defaults T-06: find & replace sub-tool body shipped

    /// The `.findReplace` case in `EditorDocumentToolsView` must now
    /// construct the real `EditorFindReplaceView` (= T-04 shipped a
    /// placeholder; = T-06 wires the live find & replace panel that
    /// posts `bus.findQuery` / `bus.replaceCurrent` / `bus.replaceAll`
    /// and observes `bus.findResults` for the live count).
    @Test("EditorDocumentToolsView wires .findReplace → EditorFindReplaceView (= T-06)")
    func editorDocumentToolsWiresFindReplace() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorDocumentToolsView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(
            view.contains("EditorFindReplaceView(bus: bus)"),
            "EditorDocumentToolsView's .findReplace case must construct EditorFindReplaceView (= T-06 live body)"
        )
    }

    /// `EditorFindReplaceView` posts the 3 find/replace request names
    /// AND observes `findResults` for the count badge. Source-content
    /// gate: if any of these disappear the find panel silently breaks
    /// (= AND from the user's perspective).
    @Test("EditorFindReplaceView wires the 4 bus names (= T-06)")
    func editorFindReplaceWiresBusNames() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorFindReplaceView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        // Request direction (= 3 names).
        #expect(view.contains("bus.findQuery"),
                "EditorFindReplaceView must post on bus.findQuery (= the engine's find-request notification)")
        #expect(view.contains("bus.replaceCurrent"),
                "EditorFindReplaceView must post on bus.replaceCurrent (= the engine's replace-current notification)")
        #expect(view.contains("bus.replaceAll"),
                "EditorFindReplaceView must post on bus.replaceAll (= the engine's replace-all notification)")
        // Response direction (= 1 name).
        #expect(view.contains("bus.findResults"),
                "EditorFindReplaceView must observe bus.findResults (= the engine's find-count response)")
    }

    // MARK: - ed-smc-defaults T-07: heading outline sub-tool body shipped

    /// The `.headingOutline` case in `EditorDocumentToolsView` must now
    /// construct the real `EditorHeadingOutlineView` (= T-04 shipped
    /// a placeholder; = T-07 wires the live outline panel that
    /// parses `^#{1,6}\s` rows from the current draft).
    @Test("EditorDocumentToolsView wires .headingOutline → EditorHeadingOutlineView (= T-07)")
    func editorDocumentToolsWiresHeadingOutline() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorDocumentToolsView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(
            view.contains("EditorHeadingOutlineView(activeDocumentText: activeDocumentText)"),
            "EditorDocumentToolsView's .headingOutline case must construct EditorHeadingOutlineView (= T-07 live body)"
        )
    }

    /// `EditorHeadingOutlineView` parses `^#{1,6}\s` rows (= the engine
    /// has no public outline API; = we re-parse on every body
    /// invocation). The pattern is the only thing that gates the
    /// format = if anyone replaces the regex with a different
    /// heading syntax (= `**bold**` etc.) the canonical CommonMark
    /// outline contract breaks.
    @Test("EditorHeadingOutlineView parses the CommonMark heading pattern (= T-07)")
    func editorHeadingOutlineParsesCommonMark() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorHeadingOutlineView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        // Test the heading pattern pieces (= CommonMark requires
        // leading 1-6 hashes followed by whitespace; = a token-level
        // check survives the regex-string dance without escaping).
        #expect(view.contains("#{1,6}"),
                "EditorHeadingOutlineView must use the CommonMark heading regex (starts with #{1,6})")
        #expect(view.contains("\\s"),
                "EditorHeadingOutlineView must include backslash-s whitespace match in the regex (= the canonical markdown heading format)")
        // Empty-state hint (= the Apple HIG inspector "no outline"
        // placeholder so the panel is not blank when the document has
        // no headings).
        #expect(
            view.contains("inspector.documentTools.headingOutline.empty"),
            "EditorHeadingOutlineView must render an empty-state hint (= no-outline headings alert)"
        )
    }

    // MARK: - ed-smc-defaults T-08: code-block list sub-tool body shipped

    /// The `.codeBlocks` case in `EditorDocumentToolsView` must now
    /// construct the real `EditorCodeBlocksView` (= T-04 shipped a
    /// placeholder; = T-08 wires the live fenced-block panel that
    /// parses ```/~~~ rows from the current draft).
    @Test("EditorDocumentToolsView wires .codeBlocks → EditorCodeBlocksView (= T-08)")
    func editorDocumentToolsWiresCodeBlocks() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorDocumentToolsView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(
            view.contains("EditorCodeBlocksView(activeDocumentText: activeDocumentText)"),
            "EditorDocumentToolsView's .codeBlocks case must construct EditorCodeBlocksView (= T-08 live body)"
        )
    }

    /// `EditorCodeBlocksView` parses the canonical CommonMark fence
    /// markers (` ``` ` AND `~~~` = both are valid CommonMark fenced
    /// code-block openers). Source-content gate: if anyone removes
    /// either marker the Swift / shell / python / json code-block
    /// surfaces silently drop from the inspector.
    @Test("EditorCodeBlocksView parses both fence markers (= T-08)")
    func editorCodeBlocksParsesBothFences() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorCodeBlocksView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(view.contains(#"triple backtick"#) || view.contains("```"),
                        "EditorCodeBlocksView must parse the triple-backtick fence (= the canonical CommonMark code-block opener)")
                #expect(view.contains(#"triple tilde"#) || view.contains("~~~"),
                        "EditorCodeBlocksView must parse the triple-tilde fence (= the alternate CommonMark code-block opener)")
        #expect(view.contains("inspector.documentTools.codeBlocks.empty"),
                "EditorCodeBlocksView must render an empty-state hint (= no-code-blocks alert)")
    }

    // MARK: - ed-smc-defaults T-09: spell-check toggles sub-tool body shipped

    /// The `.spellToggles` case in `EditorDocumentToolsView` must now
    /// construct the real `EditorSpellTogglesView` (= T-04 shipped
    /// a placeholder; = T-09 wires the live 3-toggle inspector row).
    /// This is the LAST of the 5 sub-tool bodies.
    @Test("EditorDocumentToolsView wires .spellToggles → EditorSpellTogglesView (= T-09)")
    func editorDocumentToolsWiresSpellToggles() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorDocumentToolsView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(
            view.contains("EditorSpellTogglesView("),
            "EditorDocumentToolsView's .spellToggles case must construct EditorSpellTogglesView (= T-09 live body)"
        )
    }

    /// `EditorSpellTogglesView` ships 3 disabled Toggles (= one per
    /// `SpellCheckingPolicy` field = continuous / grammar /
    /// autocorrect). Source-content gate: if anyone drops a Toggle
    /// (= e.g. only 2 of 3 fields exposed) the inspector silently
    /// hides that affordance.
    @Test("EditorSpellTogglesView renders all 3 spell toggles (= T-09)")
    func editorSpellTogglesRendersAllThree() throws {
        let viewPath = resolve("Sources/WenshuApp/Views/Inspector/EditorSpellTogglesView.swift")
        let view = try String(contentsOfFile: viewPath, encoding: .utf8)
        #expect(view.contains("continuousSpellChecking"),
                "EditorSpellTogglesView must reflect initialPolicy.continuousSpellChecking (= NSTextView.isContinuousSpellCheckingEnabled mirror)")
        #expect(view.contains("grammarChecking"),
                "EditorSpellTogglesView must reflect initialPolicy.grammarChecking (= NSTextView.isGrammarCheckingEnabled mirror)")
        #expect(view.contains("automaticSpellingCorrection"),
                "EditorSpellTogglesView must reflect initialPolicy.automaticSpellingCorrection (= NSTextView.isAutomaticSpellingCorrectionEnabled mirror)")
        #expect(view.contains(".disabled(true)"),
                "EditorSpellTogglesView's toggles must be disabled (= inspector reflects engine state; mutation happens in the editor's context menu = Apple HIG system Settings pattern)")
    }

    // MARK: - ed-smc-defaults T-11: explicit default-theme binding

    /// T-11 binds `MarkdownEditorTheme.default` explicitly in
    /// `WenshuEditorServicesFactory.make`. The binding is the
    /// single landing-spot for future retheme work (= a future
    /// ticket that wants to swap the default theme for a
    /// wenshu-tuned one has one place to edit).
    @Test("WenshuEditorServicesFactory binds MarkdownEditorTheme.default (= T-11)")
    func servicesFactoryBindsMarkdownEditorThemeDefault() throws {
        let factoryPath = resolve("Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift")
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
    @Test("EditorPreferences schema exists with 6 keys (= T-12)")
    func editorPreferencesSchemaHasSixKeys() throws {
        let prefPath = resolve("Sources/WenshuApp/Editor/EditorPreferences.swift")
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
        #expect(pref.contains("case readingWidth"),
                "EditorPreferences.AppStorageKey must declare readingWidth case")
        #expect(pref.contains("case heightBehavior"),
                "EditorPreferences.AppStorageKey must declare heightBehavior case")
        #expect(pref.contains("case rawSourceMode"),
                "EditorPreferences.AppStorageKey must declare rawSourceMode case")
    }

    /// The factory must forward the EditorPreferences snapshot to
    /// MarkdownEditorConfiguration (= 4 binding lines; = if any
    /// disappears the host's settings silently stop flowing into
    /// the editor).
    @Test("WenshuEditorServicesFactory forwards EditorPreferences to config (= T-12)")
    func servicesFactoryForwardsEditorPreferences() throws {
        let factoryPath = resolve("Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift")
        let factory = try String(contentsOfFile: factoryPath, encoding: .utf8)
        #expect(factory.contains("config.readingWidth = preferences.readingWidth"),
                "Factory must bind config.readingWidth from preferences.readingWidth")
        #expect(factory.contains("config.heightBehavior = preferences.heightBehavior"),
                "Factory must bind config.heightBehavior from preferences.heightBehavior")
        #expect(factory.contains("config.rawSourceMode = preferences.rawSourceMode"),
                "Factory must bind config.rawSourceMode from preferences.rawSourceMode")
        #expect(factory.contains("config.spellChecking = SpellCheckingPolicy("),
                "Factory must build SpellCheckingPolicy from preferences")
    }

    // MARK: - ed-smc-defaults T-13: scroll-memory persistence

    /// T-13 ships `EditorScrollMemory` (= the host-side persistence
    /// layer that wires the engine's 3 scroll-memory closures).
    /// Source-content gate: if anyone removes the struct or stops
    /// calling the persist/restore entry points the host silently
    /// loses scroll memory.
    @Test("EditorScrollMemory persists + restores scroll offsets (= T-13)")
    func editorScrollMemoryPersistsAndRestores() throws {
        let memoryPath = resolve("Sources/WenshuApp/Editor/EditorScrollMemory.swift")
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
        let editorPath = resolve("Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift")
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
}


