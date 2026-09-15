// ZoneModuleViewTests.swift · Wenshu · v0.93 ticket 002 + v1.32 update
//
// Source-level structural tests for ZoneModuleView (= the LEGACY
// pane registry helper struct used by RegisteredPanes; = renders
// the 6-zone layout via a switch on zoneSlot).
//
// v1.32 update: ZoneModuleView was extracted from WorkspaceView.swift
// to its own file (Sources/WenshuApp/Views/Workspace/ZoneModuleView.swift).
// The test file's hardcoded path was changed from WorkspaceView.swift
// to ZoneModuleView.swift AND rewritten to use a path derived from
// #filePath (= the test file's own path) so the tests work
// regardless of worktree location (= v1.32 had a build failure
// because the absolute path hardcoded the main worktree path,
// not the v1.32 worktree path).
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

@Suite("ZoneModuleView (v0.93 + v1.32 — legacy 6-zone pane registry helper, now in own file)")
struct ZoneModuleViewTests {

    /// v1.32 (= per Q34 5.2 + Q173 ponytail + Q186): derive the
    /// ZoneModuleView source path from THIS test file's path
    /// (= #filePath = "/path/to/ZoneModuleViewTests.swift"). This
    /// means the tests work regardless of where the worktree is
    /// mounted (= v1.32 hit a build failure when ZoneModuleView was
    /// in a worktree because the old hardcoded path pointed to the
    /// main worktree's WorkspaceView.swift, not the v1.32 worktree's
    /// ZoneModuleView.swift).
    ///
    /// Per Q173 ponytail: derive path with simple string replacement.
    /// Per Q34 5.2 + Q57: keep this helper inside the test struct so
    /// the test file remains self-contained.
    private static var zoneModuleViewPath: String {
        // #filePath = "Tests/.../ZoneModuleViewTests.swift" (= relative)
        // Get the directory containing this test file (= ".../Tests/.../")
        // then append the target source file's relative path.
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsDir = testFileURL.deletingLastPathComponent()  // Views/Workspace/
        // Walk up to the repo root: Tests/WenshuAppTests/Views/Workspace/
        // → Tests/WenshuAppTests/Views/ → Tests/WenshuAppTests/ → Tests/
        // → repo root (4 levels up from Views/Workspace/).
        let repoRoot = testsDir
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        // Append the target source file's relative path from repo root.
        return repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("WenshuApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("Workspace")
            .appendingPathComponent("ZoneModuleView.swift")
            .path
    }

    /// Helper: read the entire ZoneModuleView.swift source.
    /// Per Q34 5.2 + Q57: the test file MUST be self-contained
    /// (= no dependency on test runner's CWD or worktree location).
    private func readZoneModuleViewSource() throws -> String {
        let path = Self.zoneModuleViewPath
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    @Test("struct conforms to View + takes zoneSlot parameter")
    func conformsToView() throws {
        let source = try readZoneModuleViewSource()
        // Per Q34 5.2 + Q173 ponytail: after v1.32 extraction, the
        // struct is at the START of its file (= no need to scan to
        // the next struct marker). Look for the struct definition
        // directly.
        let zoneModuleViewSection = source
        #expect(zoneModuleViewSection.contains("struct ZoneModuleView: View"),
                "ZoneModuleView must conform to View protocol")
        #expect(zoneModuleViewSection.contains("let zoneSlot: ZoneSlot"),
                "ZoneModuleView must declare zoneSlot: ZoneSlot parameter")
    }

    @Test("declares 2 @Binding params for entity category + selected entity")
    func declaresBindings() throws {
        let source = try readZoneModuleViewSource()
        let codeRegion = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }.joined(separator: "\n")

        #expect(codeRegion.contains("@Binding var selectedEntityCategory: EntityCategory?"),
                "ZoneModuleView must declare @Binding var selectedEntityCategory (= v0.30 cross-zone interaction)")
        #expect(codeRegion.contains("@Binding var selectedEntity: Reference?"),
                "ZoneModuleView must declare @Binding var selectedEntity (= v0.30 detail card view)")
    }

    @Test("reads AppState + BookStore from environment")
    func readsAppStateAndBookStore() throws {
        let source = try readZoneModuleViewSource()
        #expect(source.contains("@Environment(AppState.self) private var appState"),
                "ZoneModuleView must read AppState from environment (= v0.30 cross-zone interaction)")
        #expect(source.contains("@Environment(BookStore.self) private var bookStore"),
                "ZoneModuleView must read BookStore from environment (= v0.34 B-25-fix)")
    }

    @Test("previewScope computed mirrors WorkspaceView's previewScope (= duplicated for self-containment)")
    func previewScopeMirrorsWorkspaceView() throws {
        let source = try readZoneModuleViewSource()
        // Per v0.30 boss 8/31 OOB: computed previewScope (= mirrors
        // WorkspaceView's previewScope; = duplicated here to keep
        // ZoneModuleView self-contained without threading the scope
        // through WorkspaceView → ZoneModuleView via another binding).
        #expect(source.contains("private var previewScope: PreviewScope"),
                "ZoneModuleView must have private var previewScope: PreviewScope computed property")
        #expect(source.contains(".bookScope(bookId: bookId, folderName: nil)"),
                "ZoneModuleView's previewScope must handle .book case (= return .bookScope)")
        #expect(source.contains(".referenceScope(cat)"),
                "ZoneModuleView's previewScope must handle .referenceCategory case")
    }

    @Test("init defaults for non-workspace callers")
    func initDefaults() throws {
        let source = try readZoneModuleViewSource()
        #expect(source.contains("init("),
                "ZoneModuleView must have an init (= SwiftUI requirement)")
        #expect(source.contains("zoneSlot: ZoneSlot"),
                "ZoneModuleView's init must accept zoneSlot: ZoneSlot as first parameter")
        #expect(source.contains("selectedEntityCategory: Binding<EntityCategory?> = .constant(nil)"),
                "ZoneModuleView's init must default selectedEntityCategory to .constant(nil) for non-workspace callers")
    }

    @Test("body switches on zoneSlot with all 6 ZoneSlot cases (= exhaustive)")
    func bodySwitchesOnZoneSlot() throws {
        let source = try readZoneModuleViewSource()
        // Per ZoneSlot enum (= v0.30 boss 8/31 OOB, 6 zones):
        //   .projectSidebar, .projectPreview, .specializedTools,
        //   .aiDynamic, .aiChat, .editor
        // Per Q34 5.2 + Q173 ponytail: verify the actual 6 cases
        // (= discovered via grep; = not the v0.27 ZoneModule cases
        // which were .outline, .canvas, etc. — the v0.30 rewrite
        // changed the case names).
        #expect(source.contains("switch zoneSlot"),
                "ZoneModuleView body must switch on zoneSlot")
        #expect(source.contains("case .projectSidebar"),
                "ZoneModuleView body must handle .projectSidebar case")
        #expect(source.contains("case .projectPreview"),
                "ZoneModuleView body must handle .projectPreview case")
        #expect(source.contains("case .specializedTools"),
                "ZoneModuleView body must handle .specializedTools case")
        #expect(source.contains("case .aiDynamic"),
                "ZoneModuleView body must handle .aiDynamic case")
        #expect(source.contains("case .aiChat"),
                "ZoneModuleView body must handle .aiChat case")
        #expect(source.contains("case .editor"),
                "ZoneModuleView body must handle .editor case")
    }
}
