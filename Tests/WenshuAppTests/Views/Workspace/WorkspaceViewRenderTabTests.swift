// WorkspaceViewRenderTabTests.swift · Wenshu · v0.88 ticket 003
//
// Source-level tests for WorkspaceView.renderTabByKind (= the
// TabKind → SwiftUI view dispatcher; = 4 cases: .projectSidebar /
// .projectPreview / .editor / .specializedTools; = the canonical
// rendering surface for the 4-zone layout).
//
// Per boss 2026-08-27 OOB 'land the refactor': the 4-case switch
// is the production (= only) render path since v0.30. Per v0.34
// boss 9/2 OOB (multi-layer audit): the ZoneContentView chrome
// layer (30 PT RegionTabBar) is uniform across all 4 tabs; =
// Y alignment invariant.
//
// renderTab wrapper (= line 605-608) = legacy forwarder to
// renderTabByKind. Kept for backward compatibility with downstream
// extensions.

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("WorkspaceView.renderTabByKind (v0.88 — TabKind → SwiftUI view dispatcher)")
struct WorkspaceViewRenderTabTests {

    @Test("renderTabByKind switches on TabKind (= 4-case dispatcher)")
    func rendersAllFourCases() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("@ViewBuilder"),
                "renderTabByKind must use @ViewBuilder (= multi-branch view return)")
        #expect(source.contains("private func renderTabByKind(_ kind: TabKind) -> some View {"),
                "renderTabByKind must take a TabKind parameter")
        #expect(source.contains("switch kind {"),
                "renderTabByKind must switch on kind (= canonical SwiftUI dispatcher pattern)")
    }

    @Test(".projectSidebar uses ZoneContentView with 'book-open' tab icon")
    func projectSidebarDispatch() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .projectSidebar:"),
                "must have .projectSidebar case (= canonical left-rail zone)")
        // The Bookshelf tab with book-open Lucide icon (= per v0.28
        // Boss UX round 43 fix that wrapped NewLibraryOutlineView in
        // ZoneContentView for Y alignment).
        #expect(source.contains("ZoneContentView(zoneSlug: \"projectSidebar\""),
                ".projectSidebar must render ZoneContentView with zoneSlug='projectSidebar'")
        #expect(source.contains("WenshuI18n.t(\"tab.title.bookshelf\")"),
                ".projectSidebar must localize the Bookshelf tab title via WenshuI18n")
        #expect(source.contains("\"book-open\""),
                ".projectSidebar Bookshelf tab icon must be the Lucide 'book-open' (= canonical library icon)")
    }

    @Test(".projectPreview uses ZoneContentView with PreviewPane")
    func projectPreviewDispatch() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .projectPreview:"),
                "must have .projectPreview case (= canonical middle zone)")
        #expect(source.contains("ZoneContentView(zoneSlug: \"projectPreview\""),
                ".projectPreview must render ZoneContentView with zoneSlug='projectPreview'")
        #expect(source.contains("PreviewPane("),
                ".projectPreview must instantiate PreviewPane (= the material management zone)")
        #expect(source.contains("scope: previewScope"),
                ".projectPreview must pass the computed previewScope (= per boss 8/31 OOB)")
    }

    @Test(".editor uses ZoneContentView with editor tab (= WenshuMarkdownEditor)")
    func projectEditorDispatch() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .editor:"),
                "must have .editor case (= canonical right zone)")
        #expect(source.contains("ZoneContentView(zoneSlug: \"editor\""),
                ".editor must render ZoneContentView with zoneSlug='editor'")
    }

    @Test(".specializedTools uses ZoneContentView with specialized tab content")
    func specializedToolsDispatch() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("case .specializedTools:"),
                "must have .specializedTools case (= canonical bottom-rail zone)")
        #expect(source.contains("ZoneContentView(zoneSlug: \"specializedTools\""),
                ".specializedTools must render ZoneContentView with zoneSlug='specializedTools'")
    }

    @Test("renderTab wrapper forwards to renderTabByKind (= legacy backward-compat)")
    func renderTabWrapper() throws {
        // Per the comment at line 602-608: legacy method kept for
        // backward-compatibility; = downstream extensions may still
        // reference it via the renderTab closure. Forwards to
        // renderTabByKind after looking up the tab spec.
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("private func renderTab(_ tab: TabSpec) -> some View {"),
                "renderTab must take a TabSpec parameter (= the legacy signature)")
        #expect(source.contains("renderTabByKind(tab.kind)"),
                "renderTab must forward to renderTabByKind(tab.kind) (= canonical wrapper pattern)")
    }

    @Test("uniform ZoneContentView chrome across all 4 zones (= v0.34 30 PT alignment invariant)")
    func uniformZoneContentViewChrome() throws {
        // Per v0.34 boss 9/2 OOB: all 4 zones must use the same 30 PT
        // RegionTabBar via ZoneContentView (= Y alignment invariant).
        // Previously, Preview/Tools used ZoneModuleView (= DOUBLE
        // chrome = 60 PT), causing 30 PT Y misalignment.
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        let zoneContentViewCount = codeRegion.components(separatedBy: "ZoneContentView(zoneSlug:").count - 1
        #expect(zoneContentViewCount >= 4,
                "must use ZoneContentView chrome across all 4 zones (= per the v0.34 audit; found \(zoneContentViewCount) occurrences in code region)")
    }

    @Test("file declares 4 separate structs (= WorkspaceView + ZoneModuleView + EditorPlaceholder + EditorPaperCanvas)")
    func declaresFourStructs() throws {
        // WorkspaceView.swift hosts 4 separate SwiftUI structs
        // (= WorkspaceView, ZoneModuleView, EditorPlaceholder,
        // EditorPaperCanvas) for the 4-zone layout. Verify all 4
        // declarations.
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct WorkspaceView: View"),
                "must declare WorkspaceView struct (= the main root)")
        #expect(source.contains("struct ZoneModuleView: View"),
                "must declare ZoneModuleView struct (= the zone-slot wrapper)")
        #expect(source.contains("struct EditorPlaceholder: View"),
                "must declare EditorPlaceholder struct (= the empty-state for the editor pane)")
        #expect(source.contains("struct EditorPaperCanvas<Content: View>: View"),
                "must declare EditorPaperCanvas generic struct (= the paper-canvas overlay)")
    }
}