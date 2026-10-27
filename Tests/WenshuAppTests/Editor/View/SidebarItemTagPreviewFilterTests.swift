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
//    2. testSidebarSelectionCarriesTagString —
//       the sidebar's tag-row selection writes the row's title
//       (= the tag string) into the workspace selection
//       (= the canonical producer path).
//
//    3. testPreviewPaneFiltersByEffectiveTag —
//       PreviewPane.referenceScopeView applies the effective tag
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
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("WorkspaceUIState exposes activeTag filter")
    func testWorkspaceUIStateHasActiveTag() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Shared/State/WorkspaceUIState.swift"), encoding: .utf8)
        #expect(source.contains("var activeTag: String?"),
                "WorkspaceUIState must expose activeTag (= boss A7 follow-up = 'tag preview-pane filter')")
    }

    @Test("the sidebar's tag row writes the tag string into the workspace selection")
    func testSidebarSelectionCarriesTagString() throws {
        // The producer is the sidebar's selection writer: its .tag
        // case writes the row's title (= the tag string) into the
        // workspace selection, and the preview pane reads the tag
        // back out of it.
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Features/Library/View/AppleSidebarSelection.swift"), encoding: .utf8)
        #expect(source.contains("workspaceUI.sidebarSelection = .tag(node.title)"),
                "the sidebar's tag-row selection MUST write the tag string into the workspace selection (= the canonical producer path)")
    }

    @Test("PreviewPane.referenceScopeView filters by the effective tag (= only references whose tags contains the string)")
    func testPreviewPaneFiltersByEffectiveTag() throws {
        // The filter applies the scope's tag override, falling back
        // to the active tag the pane holds.
        let pane = try String(contentsOfFile: resolve("Sources/WenshuApp/Features/Editor/View/PreviewPane.swift"), encoding: .utf8)
        let scopeViews = try String(contentsOfFile: resolve("Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift"), encoding: .utf8)
        let hasFilter = scopeViews.contains("let effectiveTag = tagOverride ?? activeTag")
            && scopeViews.contains("entity.tags.contains(effectiveTag)")
        let hasBinding = pane.contains("@Binding var activeTag: String?")
        #expect(hasFilter && hasBinding,
                "PreviewPane.referenceScopeView must filter references by the effective tag (= the tag override first, = the active tag second)")
    }
}