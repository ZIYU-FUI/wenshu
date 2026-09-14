// WorkspaceViewTests.swift · Wenshu · v0.88 ticket 001
//
// Source-level structural tests for WorkspaceView (= the customizable-
// layout root SwiftUI view; = wraps LayoutTreeStore + PaneSplitHost).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': test the WorkspaceView
// main file (= 2,139 LOC, = health score 4.15 = lowest in the repo).
// Per v0.77 spec decision (= ViewInspector behavior tests on this view
// require ~150-200 LOC of mock scaffolding for LayoutTreeStore /
// PaneSplitHost / WorkspaceMode; = exceeds 1-ticket scope per Q112).
// v0.88 = 3 source-level structural test files covering the main view's
// boss-spec invariants (= the things the boss has explicitly called
// out in OOB messages over the v0.27-v0.40 development window).
//
// Three test files (= per Q112 = 1 ticket 1 file 1 commit):
// - WorkspaceViewTests.swift (this file) = header + @State/@Environment
//   declarations + PaneSplitHost instantiation
// - WorkspaceViewPreviewScopeTests.swift (= ticket 002) = previewScope
//   computed property logic (= sidebar selection → PreviewScope mapping)
// - WorkspaceViewRenderTabTests.swift (= ticket 003) = renderTab
//   dispatcher (= TabKind → existing wenshu view mapping)

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("WorkspaceView (v0.88 — customizable-layout root, header + state)")
struct WorkspaceViewTests {

    @Test("source imports SwiftUI + MarkdownEngine + LucideSwift")
    func sourceImports() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "must import SwiftUI for View + @State + @Environment + .onChange")
        #expect(source.contains("import MarkdownEngine"),
                "must import MarkdownEngine (= the SPM product providing MarkdownEditorConfiguration per v0.39 ticket 001)")
        #expect(source.contains("import LucideSwift"),
                "must import LucideSwift (= wenshu v0.27 Lucide-only mandate; = no SF Symbols)")
    }

    @Test("struct conforms to View + owns LayoutTreeStore as ObservedObject")
    func structConformsToView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct WorkspaceView: View"),
                "struct must conform to View protocol")
        #expect(source.contains("@ObservedObject var store: LayoutTreeStore"),
                "must own LayoutTreeStore as @ObservedObject (= the layout tree source of truth)")
    }

    @Test("declares required @State fields (per boss 2026-08-27 OOB 'land the refactor')")
    func declaresStateFields() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // Per the v0.30 boss OOB (= entity card stream layout):
        #expect(codeRegion.contains("@State private var selectedEntityCategory: EntityCategory? = nil"),
                "must declare selectedEntityCategory state (= v0.30 entity classification)")

        #expect(codeRegion.contains("@State private var selectedEntity: Reference? = nil"),
                "must declare selectedEntity state (= v0.30 detail card view)")

        // Per the v0.30 boss OOB (= card-grid sort order):
        #expect(codeRegion.contains("@State private var previewSortOrder: EntitySortOrder = .pinyinFirstLetter"),
                "must declare previewSortOrder state (= v0.30 preview pane card sort)")
    }

    @Test("reads AppState + BookStore from environment (= per boss 2026-08-27 + v0.34 audit)")
    func readsAppStateAndBookStore() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("@Environment(AppState.self) private var appState"),
                "must read AppState from environment (= v0.30 cross-zone interaction source of truth)")
        #expect(source.contains("@Environment(BookStore.self) private var bookStore"),
                "must read BookStore from environment (= v0.30 reference loading in preview pane)")
    }

    @Test("editMode reads from appState (= v0.40 apple-001 Q3 hoisted decision)")
    func editModeFromAppState() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("private var editMode: LayoutEditMode { appState.editMode }"),
                "editMode must read from appState.editMode (= v0.40 hoisted decision; = all workspace descendants share one source)")
    }

    @Test("DEFERRED header documents the v0.77 spec decision (= not dead code per Q57)")
    func deferredHeaderDocumentsSpec() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("DEFERRED (v0.77 spec decision)"),
                "header must document the v0.77 spec deferral decision (= not silent dead code)")
        #expect(source.contains("This file is NOT dead code"),
                "header must explicitly claim non-dead-code status (= per Q57: 3rd-party verdict ≠ authority)")
        #expect(source.contains(".scratch/v0.77-workspaceview-tests/spec.md"),
                "header must reference the v0.77 spec doc")
    }
}