// ZoneModuleViewTests.swift · Wenshu · v0.93 ticket 002
//
// Source-level structural tests for ZoneModuleView (= the LEGACY
// pane registry helper struct used by RegisteredPanes; = renders
// the 6-zone layout via a switch on zoneSlot).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.93 ticket 001 =
// EditorPaperCanvas (the simplest helper). This ticket = ZoneModuleView
// (the legacy registry path; = previewScope computed + 6-case switch).
//
// ViewInspector behavior tests are limited for @Binding + @Environment
// + multi-case switch structures (= v0.82 Q-lesson); = use source-level
// structural assertions per v0.82 pattern.

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("ZoneModuleView (v0.93 — legacy 6-zone pane registry helper)")
struct ZoneModuleViewTests {

    @Test("struct conforms to View + takes zoneSlot parameter")
    func conformsToView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let editorPaperCanvasRange = source.range(of: "struct ZoneModuleView")!
        let section = String(source[editorPaperCanvasRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPlaceholder")?.lowerBound
            ?? section.endIndex
        let zoneModuleViewSection = String(section[..<endOfStruct])
        #expect(zoneModuleViewSection.contains("struct ZoneModuleView: View"),
                "ZoneModuleView must conform to View protocol")
        #expect(zoneModuleViewSection.contains("let zoneSlot: ZoneSlot"),
                "ZoneModuleView must declare zoneSlot: ZoneSlot parameter")
    }

    @Test("declares 2 @Binding params for entity category + selected entity")
    func declaresBindings() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let startRange = source.range(of: "struct ZoneModuleView")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPlaceholder")?.lowerBound
            ?? section.endIndex
        let zoneModuleViewSection = String(section[..<endOfStruct])
        let codeLines = zoneModuleViewSection.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("@Binding var selectedEntityCategory: EntityCategory?"),
                "ZoneModuleView must declare @Binding var selectedEntityCategory (= v0.30 cross-zone interaction)")
        #expect(codeRegion.contains("@Binding var selectedEntity: Reference?"),
                "ZoneModuleView must declare @Binding var selectedEntity (= v0.30 detail card view)")
    }

    @Test("reads AppState + BookStore from environment")
    func readsAppStateAndBookStore() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let startRange = source.range(of: "struct ZoneModuleView")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPlaceholder")?.lowerBound
            ?? section.endIndex
        let zoneModuleViewSection = String(section[..<endOfStruct])
        #expect(zoneModuleViewSection.contains("@Environment(AppState.self) private var appState"),
                "ZoneModuleView must read AppState from environment (= v0.30 cross-zone interaction)")
        #expect(zoneModuleViewSection.contains("@Environment(BookStore.self) private var bookStore"),
                "ZoneModuleView must read BookStore from environment (= v0.34 B-25-fix)")
    }

    @Test("previewScope computed mirrors WorkspaceView's previewScope (= duplicated for self-containment)")
    func previewScopeMirrorsWorkspaceView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let startRange = source.range(of: "struct ZoneModuleView")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPlaceholder")?.lowerBound
            ?? section.endIndex
        let zoneModuleViewSection = String(section[..<endOfStruct])
        // Per v0.30 boss 8/31 OOB: computed previewScope (= mirrors
        // WorkspaceView's previewScope; = duplicated here to keep
        // ZoneModuleView self-contained without threading the scope
        // through WorkspaceView → ZoneModuleView via another binding).
        #expect(zoneModuleViewSection.contains("private var previewScope: PreviewScope {"),
                "ZoneModuleView must declare private var previewScope: PreviewScope computed (= mirrors WorkspaceView)")
        // All 4 SidebarSelection cases must be handled (= exhaustive switch).
        #expect(zoneModuleViewSection.contains("case .book(let bookId):"),
                "ZoneModuleView.previewScope must switch on SidebarSelection.book case")
        #expect(zoneModuleViewSection.contains("case .folder(let bookId, let folderName):"),
                "ZoneModuleView.previewScope must switch on SidebarSelection.folder case")
        #expect(zoneModuleViewSection.contains("case .shelf(let shelfId):"),
                "ZoneModuleView.previewScope must switch on SidebarSelection.shelf case")
        #expect(zoneModuleViewSection.contains("case .referenceCategory(let dirName):"),
                "ZoneModuleView.previewScope must switch on SidebarSelection.referenceCategory case")
    }

    @Test("init defaults for non-workspace callers")
    func initDefaults() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let startRange = source.range(of: "struct ZoneModuleView")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPlaceholder")?.lowerBound
            ?? section.endIndex
        let zoneModuleViewSection = String(section[..<endOfStruct])
        #expect(zoneModuleViewSection.contains("init(\n        zoneSlot: ZoneSlot,"),
                "ZoneModuleView must declare explicit init taking zoneSlot")
        #expect(zoneModuleViewSection.contains("selectedEntityCategory: Binding<EntityCategory?> = .constant(nil)"),
                "ZoneModuleView init must default selectedEntityCategory to .constant(nil)")
        #expect(zoneModuleViewSection.contains("selectedEntity: Binding<Reference?> = .constant(nil)"),
                "ZoneModuleView init must default selectedEntity to .constant(nil)")
    }

    @Test("body switches on zoneSlot with all 6 ZoneSlot cases (= exhaustive)")
    func bodySwitchesOnZoneSlot() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/WorkspaceView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let startRange = source.range(of: "struct ZoneModuleView")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPlaceholder")?.lowerBound
            ?? section.endIndex
        let zoneModuleViewSection = String(section[..<endOfStruct])
        #expect(zoneModuleViewSection.contains("switch zoneSlot {"),
                "ZoneModuleView body must switch on zoneSlot")
        // All 6 ZoneSlot cases must be present (= exhaustive switch).
        #expect(zoneModuleViewSection.contains("case .projectSidebar:"),
                "ZoneModuleView body must handle .projectSidebar case")
        #expect(zoneModuleViewSection.contains("case .projectPreview:"),
                "ZoneModuleView body must handle .projectPreview case")
        #expect(zoneModuleViewSection.contains("case .editor:"),
                "ZoneModuleView body must handle .editor case")
        #expect(zoneModuleViewSection.contains("case .specializedTools:"),
                "ZoneModuleView body must handle .specializedTools case")
        #expect(zoneModuleViewSection.contains("case .aiChat:"),
                "ZoneModuleView body must handle .aiChat case")
        #expect(zoneModuleViewSection.contains("case .aiDynamic:"),
                "ZoneModuleView body must handle .aiDynamic case")
    }
}