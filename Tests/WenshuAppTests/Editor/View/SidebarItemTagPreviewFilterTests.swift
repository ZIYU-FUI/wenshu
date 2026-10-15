//
//  SidebarItemTagPreviewFilterTests.swift · Wenshu · v2.9d ticket T37 (boss 2026-09-28 OOB A7 follow-up)
//
//  Structural tests confirming the v2.9d SidebarItem.tag
//  preview-pane filter (= boss 2026-09-28 OOB inventory
//  follow-up A7 = 'SidebarItem.tag 加了但 preview-pane 不接';
//  = the v2.6 facet model added SidebarItem.tag as a sidebar
//  entry point; = v2.9d T37 wires it to the preview pane's
//  card-grid tag filter so clicking a tag actually filters
//  the rendered references).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testWorkspaceUIStateHasActiveTag —
//       WorkspaceUIState exposes `var activeTag: String?`
//       (= the canonical filter source).
//
//    2. testShellMiddleColumnSetsActiveTag —
//       ShellMiddleColumn.previewScope() sets
//       workspaceUI.activeTag on `.tag(String)` selection.
//       (= the canonical producer path).
//
//    3. testPreviewPaneFiltersByActiveTag —
//       PreviewPane.referenceScopeView applies the activeTag
//       filter (= only references whose tags set contains
//       the string pass through).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.9a SpotlightRealSearchTests
//  + v2.9c BackupRestoreUITests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("SidebarItem.tag preview-pane filter (v2.9d — boss 2026-09-28 OOB A7 follow-up)")
struct SidebarItemTagPreviewFilterTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("WorkspaceUIState exposes activeTag filter")
    func testWorkspaceUIStateHasActiveTag() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/State/WorkspaceUIState.swift"), encoding: .utf8)
        #expect(source.contains("var activeTag: String?"),
                "WorkspaceUIState must expose activeTag (= boss A7 follow-up = 'tag preview-pane filter')")
    }

    @Test("ShellMiddleColumn (= now AssetsPane) sets workspaceUI.activeTag on .tag(String) selection")
    func testShellMiddleColumnSetsActiveTag() throws {
        // ShellMiddleColumn was renamed to AssetsPane and moved to
        // Views/Workspace/ in 2026-10-03 (= commit 5723d226c). The
        // production contract = "workspaceUI.activeTag = tagString"
        // is preserved in AssetsPane.swift L185.
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Workspace/AssetsPane.swift"), encoding: .utf8)
        #expect(source.contains("workspaceUI.activeTag = tagString"),
                "AssetsPane.previewScope() must set workspaceUI.activeTag on .tag(String) (= the canonical producer path)")
    }

    @Test("PreviewPane.referenceScopeView filters by activeTag (= only references whose tags contains the string)")
    func testPreviewPaneFiltersByActiveTag() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Workspace/PreviewPane.swift"), encoding: .utf8)
        let hasFilter = source.contains("entity.tags.contains(activeTag)")
        let hasBinding = source.contains("@Binding var activeTag: String?")
        #expect(hasFilter && hasBinding,
                "PreviewPane.referenceScopeView must filter references by activeTag (= boss A7 follow-up = 'tag chip was dead UI affordance')")
    }
}