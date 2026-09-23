// WorkspaceViewPreviewScopeTests.swift · Wenshu · v0.88 ticket 002
//
// Source-level tests for WorkspaceView.previewScope (= the computed
// property that maps SidebarSelection → PreviewScope; = critical
// for the preview pane's boss-spec invariants: "shelf row → select a
// book hint", "reference __root__ → all references", etc.).
//
// Per boss 2026-08-27 OOB + v0.30 boss 8/31 OOB:
// - `.book(bookId)` → `.bookScope(bookId:, folderName: nil)`
// - `.folder(bookId, folderName)` → `.bookScope(bookId:, folderName:)`
// - `.shelf(shelfId)` → `.shelfScope(shelfId:)` (= NOT `.empty`; the
//   previous mapping to .empty was flagged as FAIL by the spec sub-agent)
// - `.referenceCategory("__root__")` → `.referenceScope(nil)`
// - `.referenceCategory(dirName)` (where dirName matches an
//   EntityCategory.directoryName) → `.referenceScope(cat)`
// - `.referenceCategory(<unknown>)` → `.empty` (defensive fallback)
// - `nil` selection → `.empty`
//
// Behavior testing skipped (= SidebarSelection is internal to
// AppleSidebarView; = source-level is the right altitude).

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("WorkspaceView.previewScope (v0.88 — SidebarSelection → PreviewScope mapping)")
struct WorkspaceViewPreviewScopeTests {

    @Test("previewScope is a computed property (= not stored)")
    func isComputedProperty() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // Strip comments (the header mentions "previewScope" in prose).
        let codeLines = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("private var previewScope: PreviewScope {"),
                "previewScope must be a private computed property (= no stored state for routing)")
    }

    @Test("book case maps to bookScope(bookId:, folderName: nil)")
    func bookCase() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .book(let bookId):"),
                "previewScope must switch on SidebarSelection.book case")
        #expect(source.contains("return .bookScope(bookId: bookId, folderName: nil)"),
                ".book must map to bookScope(bookId:, folderName: nil) (= folder nil = book root)")
    }

    @Test("folder case maps to bookScope(bookId:, folderName:)")
    func folderCase() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .folder(let bookId, let folderName):"),
                "previewScope must switch on SidebarSelection.folder case")
        #expect(source.contains("return .bookScope(bookId: bookId, folderName: folderName)"),
                ".folder must map to bookScope(bookId:, folderName:) (= preserves folder context)")
    }

    @Test("shelf case maps to shelfScope(shelfId:) — NOT .empty (= boss 8/31 OOB fix)")
    func shelfCase() throws {
        // Per boss 2026-08-31 OOB spec criterion #2: "clicking a shelf row
        // shows the 'select a book' hint" — previously this mapped to
        // .empty which the spec sub-agent flagged as FAIL.
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .shelf(let shelfId):"),
                "previewScope must switch on SidebarSelection.shelf case")
        #expect(source.contains("return .shelfScope(shelfId: shelfId)"),
                ".shelf must map to .shelfScope(shelfId:) (= per boss 8/31 OOB fix; NOT .empty)")
    }

    @Test("referenceCategory __root__ maps to referenceScope(nil)")
    func referenceRootCase() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .referenceCategory(let dirName):"),
                "previewScope must switch on SidebarSelection.referenceCategory case")
        #expect(source.contains("if dirName == \"__root__\""),
                ".referenceCategory must special-case the __root__ sentinel")
        #expect(source.contains("return .referenceScope(nil)"),
                "__root__ must map to .referenceScope(nil) (= 'all references' scope)")
    }

    @Test("referenceCategory with known directoryName maps to referenceScope(cat)")
    func referenceKnownCase() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("EntityCategory.allCases.first(where: {"),
                "must look up the EntityCategory by directoryName")
        #expect(source.contains("$0.directoryName == dirName"),
                "must match by directoryName (= the directory layout key)")
        #expect(source.contains("return .referenceScope(cat)"),
                "known category must map to .referenceScope(cat) (= category-filtered scope)")
    }

    @Test("referenceCategory with unknown directoryName falls back to .empty")
    func referenceUnknownFallback() throws {
        // Defensive fallback: if a category directoryName is not in
        // EntityCategory.allCases (= stale data, deleted category),
        // return .empty rather than crash.
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("return .empty"),
                "previewScope must return .empty as fallback (= for unknown dirName + nil selection)")
    }

    @Test("nil selection returns .empty")
    func nilSelectionCase() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("guard let item = appState.sidebarSelection else { return .empty }"),
                "nil selection must return .empty (= 'no selection' default)")
    }
}