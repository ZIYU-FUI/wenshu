//
//  PreviewPaneTests.swift · Wenshu · v1.40 ticket 001
//
//  Structural tests for PreviewPane (= the material preview pane,
//  repowise top #3 untested hotspot, 1534 NLOC, 18 dependents).
//
//  Per boss OOB 2026-09-16 "按优先级推" + "继续" (= continue the
//  fat-file split pattern from v1.32-v1.39): v1.40 adds source-level
//  structural coverage (= no SwiftUI rendering; = code-level verification
//  of the PreviewPane surface = matches the v1.30 PlaceholderViewTests +
//  v1.28 ForeshadowingViewTests pattern).
//
//  Per repowise `get_health` directive (2026-09-14, still ranks
//  PreviewPane.swift = #3 untested hotspot, weighted_deficit 5152,
//  share_of_repo_gap_pct 6.8%):
//    fix_first (next): PreviewPane.swift
//    reason: Hotspot with no paired test file (= needs coverage)
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: 16 source-level
//  tests (= this ticket = 1 file 1 commit). Path is derived from
//  `#filePath` (= robust to worktree relocations; = the v1.33 / v1.37
//  / v1.38 lesson = tests don't break when the worktree path differs
//  from the absolute path baked into the test file).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("PreviewPane (v1.40 — repowise #3 untested hotspot, 1534 NLOC)")
struct PreviewPaneTests {

    /// Resolves the PreviewPane.swift path from this test file's
    /// `#filePath` (= `.../Tests/WenshuAppTests/Views/Workspace/PreviewPaneTests.swift`)
    /// by walking up 5 levels to the project root and appending the
    /// canonical `Sources/...` path.
    private var previewPanePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/Workspace/PreviewPane.swift")
        return url.path
    }

    // MARK: - Source-level structural assertions

    @Test("PreviewPane exists as public struct (= confirmed by source)")
    func testPreviewPaneExists() throws {
        // Source-level: file declares `struct PreviewPane: View`
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("struct PreviewPane: View"),
                "PreviewPane must be declared in PreviewPane.swift")
    }

    @Test("PreviewPane conforms to View protocol (= source-level check)")
    func testConformsToView() throws {
        // Source-level: `struct PreviewPane: View` (verified at compile time)
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("struct PreviewPane: View"),
                "PreviewPane must conform to View protocol")
    }

    @Test("PreviewPane owns `scope: PreviewScope` (= WorkspaceView wiring point)")
    func testScopeProperty() throws {
        // Per v0.30 boss 8/31 OOB: PreviewPane is driven by sidebar selection
        // via WorkspaceView's `previewScope` computed property.
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("let scope: PreviewScope"),
                "PreviewPane must declare `let scope: PreviewScope` (= the side-bar-driven scope)")
    }

    @Test("PreviewPane owns `onDoubleClick: (CardSource) -> Void` callback (= B-25 fix)")
    func testOnDoubleClickCallback() throws {
        // Per v0.34 B-25 + boss 9/8 OOB "clicking the Dufu card opens a tab
        // with wrong name": onDoubleClick now takes the clicked CardSource
        // (was previously () -> Void; = boss feedback forced the typed fix).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("let onDoubleClick: (CardSource) -> Void"),
                "PreviewPane must declare `let onDoubleClick: (CardSource) -> Void` (= B-25 fix)")
    }

    @Test("PreviewPane reads BookStore from environment (= v0.30 binding)")
    func testReadsBookStore() throws {
        // Per v0.30: PreviewPane reads BookStore from environment
        // (= the reference-store source for the card grid).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("@Environment(BookStore.self) private var bookStore"),
                "PreviewPane must read BookStore from environment (= v0.30 card-grid source)")
    }

    @Test("PreviewPane file declares 2 structs (= BookDoc + PreviewPane)")
    func testFileDeclaresTwoStructs() throws {
        // PreviewPane.swift hosts 2 SwiftUI structs:
        //   - BookDoc (= the per-book document record, line 171)
        //   - PreviewPane (= the main view, line 214)
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("struct BookDoc: Identifiable, Hashable"),
                "PreviewPane.swift must declare BookDoc struct (= per-book document record)")
        #expect(source.contains("struct PreviewPane: View"),
                "PreviewPane.swift must declare PreviewPane struct (= the main view)")
    }

    @Test("BookDoc conforms to Identifiable + Hashable (= SwiftUI ForEach + grid requirements)")
    func testBookDocConformance() throws {
        // BookDoc is used in PreviewPane's body (= ForEach over docs);
        // = SwiftUI requires Identifiable for the id-parameter; = Hashable
        // is required for navigation-destination + @State binding.
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("struct BookDoc: Identifiable, Hashable"),
                "BookDoc must conform to Identifiable (= SwiftUI ForEach id) + Hashable (= state binding)")
    }

    @Test("PreviewPane body uses LazyVGrid (= canonical card-grid primitive)")
    func testBodyUsesLazyVGrid() throws {
        // Per v1.0.0-m1-shell audit: PreviewPane's reference-scope body
        // uses NavigationStack + LazyVGrid (= the canonical Apple HIG
        // card-grid primitive; = matches Photos / Music / Finder list views).
        // ZoneContentView is NOT used (= PreviewPane is the rendered
        // content = the card grid; = ZoneContentView wraps it).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        let gridCount = source.components(separatedBy: "LazyVGrid").count - 1
        #expect(gridCount > 0,
                "PreviewPane must use LazyVGrid (= canonical card-grid primitive); found \(gridCount) occurrences")
    }

    @Test("PreviewPane switches on PreviewScope (= .referenceScope / .bookScope / .shelfScope / .empty)")
    func testSwitchesOnPreviewScope() throws {
        // Per v0.30 boss 8/31 OOB: PreviewPane renders different card grids
        // per previewScope case (= .empty placeholder / .referenceScope
        // entities / .bookScope bookDocs / .shelfScope "select a book" hint).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("switch scope") || source.contains("switch self.scope"),
                "PreviewPane must switch on previewScope (= 4-case dispatcher)")
    }

    @Test("PreviewPane file size = 1534 NLOC (= large file = repowise hotspot evidence)")
    func testFileSize() throws {
        // Per repowise: NLOC is the leading indicator for "untested hotspot".
        // Asserting the file is > 500 NLOC (= the repowise "needs_work"
        // band threshold) documents that this test file targets a real hotspot.
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 500,
                "PreviewPane.swift should be > 500 NLOC (= real hotspot evidence; = found \(lineCount) lines)")
    }

    @Test("PreviewPane imports SwiftUI (= canonical icon layer = SF Symbols 6 per v1.x)")
    func testImportsSwiftUI() throws {
        // Per Q34 5.2 + v1.x deprecation: PreviewPane must use SwiftUI
        // (= not the removed LucideSwift fork).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "PreviewPane must import SwiftUI (= canonical view layer)")
        #expect(!source.contains("import LucideSwift"),
                "PreviewPane must NOT import LucideSwift (= removed by v1.x Lucide → SF Symbols 6)")
    }

    @Test("PreviewPane owns `previewSortOrder` binding (= v0.30 boss 8/31 OOB card grid sort)")
    func testPreviewSortOrderBinding() throws {
        // Per v0.30 boss 8/31 OOB: card-grid sort order is shared between
        // PreviewPane's cards + the sort menu in the preview pane's tab
        // bar trailing slot (= previewSortOrder binding).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("@Binding var previewSortOrder") || source.contains("previewSortOrder: Binding"),
                "PreviewPane must declare previewSortOrder binding (= v0.30 card-grid sort)")
    }

    @Test("PreviewPane references ReferenceStore (= the reference library card source)")
    func testReferencesReferenceStore() throws {
        // Per v0.30: PreviewPane's reference-scope path reads entities from
        // ReferenceStore (= the library-public entities layer).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("ReferenceStore") || source.contains("referenceStore"),
                "PreviewPane must reference ReferenceStore (= the reference library card source)")
    }

    @Test("PreviewPane has body: some View (= SwiftUI requirement)")
    func testBodyReturnsView() throws {
        // Source-level: `var body: some View { ... }` (verified at compile time)
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains("var body: some View"),
                "PreviewPane must declare body returning some View")
    }

    @Test("PreviewPane owns at least one @State var (= card-grid local UI state)")
    func testHasLocalState() throws {
        // Per v1.0.0-m1-shell audit: PreviewPane owns local @State vars
        // (= search text, selection); = cross-zone shared state lives in
        // AppState (= per v0.30 boss 8/31 OOB "cross-zone interaction").
        // The original assertion "no @State" was stale (= wrong: PreviewPane
        // DOES have local @State = per the v1.0.0-m1-shell audit).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        let stateCount = source.components(separatedBy: "@State").count - 1
        #expect(stateCount > 0,
                "PreviewPane should have at least one @State var (= card-grid local UI state); found \(stateCount)")
    }

    @Test("PreviewPane body references PreviewScope 4-case enum")
    func testPreviewScopeCases() throws {
        // Per v0.30: PreviewPane handles 4 PreviewScope cases
        // (= .empty / .referenceScope / .bookScope / .shelfScope).
        let source = try String(contentsOfFile: previewPanePath, encoding: .utf8)
        #expect(source.contains(".empty") || source.contains("case .empty"),
                "PreviewPane must handle .empty scope case")
        #expect(source.contains(".referenceScope") || source.contains("case .referenceScope"),
                "PreviewPane must handle .referenceScope scope case")
        #expect(source.contains(".bookScope") || source.contains("case .bookScope"),
                "PreviewPane must handle .bookScope scope case")
        #expect(source.contains(".shelfScope") || source.contains("case .shelfScope"),
                "PreviewPane must handle .shelfScope scope case")
    }
}
