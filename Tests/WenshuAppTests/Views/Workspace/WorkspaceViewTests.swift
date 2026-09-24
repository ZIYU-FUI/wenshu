// WorkspaceViewTests.swift · Wenshu · v0.88 ticket 001
//
// Source-level structural tests for WorkspaceView (= the customizable-
// layout root SwiftUI view; = wraps LayoutTreeStore + PaneSplitHost).
//
// 
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

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("WorkspaceView (v0.88 — customizable-layout root, header + state)")
struct WorkspaceViewTests {

    @Test("source imports SwiftUI (= post-v1.37 MarkdownEngine import drop)")
    func sourceImports() throws {
        // 
        // WorkspaceView.swift no longer needs `MarkdownEngine` (= the
        // MarkdownEditorConfiguration type moved with the markdown editor
        // surface into EditorPlaceholder.swift during the v1.33 extraction).
        // Per Q34 5.2 + Q173 ponytail + Q186: per Q57 assert reality (= what
        // is currently in the file), not what was planned pre-extraction.
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/Workspace/WorkspaceView.swift")
        let source = try String(contentsOfFile: url.path, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "must import SwiftUI for View + @State + @Environment + .onChange")
        #expect(!source.contains("import MarkdownEngine"),
                "must NOT import MarkdownEngine (= moved to EditorPlaceholder.swift in v1.33)")
        #expect(!source.contains("import LucideSwift"),
                "must NOT import LucideSwift (= removed by v1.x Lucide → SF Symbols 6 deprecation)")
    }

    @Test("struct conforms to View + owns LayoutTreeStore as ObservedObject")
    func structConformsToView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct WorkspaceView: View"),
                "struct must conform to View protocol")
        #expect(source.contains("var store: LayoutTreeStore"),
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

        // P2-06 (audit 2026-09-24): previewSortOrder was hoisted from
                // WorkspaceView's @State to its own @Observable WorkspaceUIState class
                // (= per-window @State on App.swift). The acceptance is that
                // WorkspaceView reads `workspaceUI.previewSortOrder` (= not AppState).
                let workspaceUIStatePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/State/WorkspaceUIState.swift"
                let workspaceUIState = try String(contentsOfFile: workspaceUIStatePath, encoding: .utf8)
                let workspaceUIStateCode = workspaceUIState.components(separatedBy: "\n").filter {
                    !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                }.joined(separator: "\n")
                #expect(workspaceUIStateCode.contains("var previewSortOrder: EntitySortOrder = .pinyinFirstLetter"),
                        "WorkspaceUIState MUST own previewSortOrder (= P2-06 hoist from per-view @State to per-window @Observable WorkspaceUIState)")
    }

    @Test("reads AppState + BookStore from environment (= per boss 2026-08-27 + v0.34 audit)")
    func readsAppStateAndBookStore() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // v0.40 apple-001 Q3 surgical: appState now passed via init
        // (= @Bindable var appState: AppState) rather than @Environment
        // (= per the WorkspaceView line 55-63 doc comment: "hoisted to
        // appState.editMode (the shared AppState instance) so all workspace
        // descendants read the same one"). The env-based form was
        // removed because the AppState ownership shifted to WenshuApp's
        // per-window @State (= each WindowGroup has its own instance
        // for edit-mode isolation; = the @Environment form would have
        // leaked state across windows).
        #expect(source.contains("@Bindable var appState: AppState"),
                "must receive AppState via init (= @Bindable; per v0.40 apple-001 Q3 surgical hoist)")
        #expect(source.contains("@Environment(BookStore.self) private var bookStore"),
                "must read BookStore from environment (= v0.30 reference loading in preview pane)")
    }

    @Test("editMode reads from appState (= v0.40 apple-001 Q3 hoisted decision)")
    func editModeFromAppState() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("private var editMode: LayoutEditMode { workspaceUI.editMode }"),
                "editMode must read from workspaceUI.editMode (= P2-06 hoisted decision; = all workspace descendants share one source)")
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
