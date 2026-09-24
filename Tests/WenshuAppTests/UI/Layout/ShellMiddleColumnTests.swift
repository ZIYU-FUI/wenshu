// ShellMiddleColumnTests.swift · Wenshu · v1.80 health-ticket 4
//
// ShellMiddleColumn.swift = 502 LOC SwiftUI View (= the Apple HIG
// content column = 1 zone: the card grid; = extracted from
// NavigationSplitShell). repowise health score 4.74 = prior_defect
// + 9 bug-fixes in last 6 months + weighted_deficit 1610 (= repo
// gap 2.3%). Note: prior_defect is history-derived and out of
// test scope per Q112; this test addresses only the structural
// source-level invariants that boundary regressions tend to break.
//
// Per wenshu test convention (= value/identifier statics + source-
// level assertions + @MainActor isolation for view deps):
//   - ShellMiddleColumn itself is a SwiftUI View with `@Bindable
//     AppState + ShellState + WorkspaceUIState + @Environment
//     BookStore`. Cannot be instantiated without the full env
//     chain (= wenshu test convention does not currently use
//     ViewInspector; = instantiation would require a manual env
//     injector).
//   - The test covers the 3 source-level invariants that prior
//     defect-fixes touch (= @Bindable entry, previewSortOrder
//     wiring, PreviewScope reference).
//
// Coverage:
//   1. Source declares the @Bindable AppState + ShellState +
//      WorkspaceUIState fields (= canonical Observation entry
//      points; = required for SwiftUI body re-render on
//      shell.sidebarSelection mutations).
//   2. Source wires the @Environment(BookStore.self) entry for
//      openCardInEditor (= the double-click-from-card path reads
//      BookStore.referenceStore).
//   3. Source binds previewSortOrder via $workspaceUI
//      .previewSortOrder (= WorkspaceUIState is the SSOT; =
//      survives column collapse-expand).
//   4. Source maps sidebarSelection → PreviewScope (=
//      private func previewScope(); = this is the canonical
//      hot path; = the prior_defect history shows it regresses
//      when the case-mismatch logic drifts).
//   5. Source passes the scope to PreviewPane twice (= once for
//      the body + once for the search filter; = both call sites
//      must read from the same `previewScope()` to avoid
//      desync between display + filter lists).

import Foundation
import Testing
@testable import WenshuApp

@Suite("ShellMiddleColumn (= Apple HIG content column = 1 zone = card grid)")
@MainActor
struct ShellMiddleColumnTests {

    // MARK: - Source-level invariants

    @Test("Source declares @Bindable AppState + ShellState + WorkspaceUIState (= canonical Observation entry)")
    func sourceBindableEntries() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("@Bindable var envAppState: AppState"),
                "ShellMiddleColumn must declare @Bindable var envAppState: AppState (= canonical SwiftUI @Observable tracking)")
        #expect(content.contains("@Bindable var shell: ShellState"),
                "ShellMiddleColumn must declare @Bindable var shell: ShellState (= shell.sidebarSelection observation)")
        #expect(content.contains("@Bindable var workspaceUI: WorkspaceUIState"),
                "ShellMiddleColumn must declare @Bindable var workspaceUI: WorkspaceUIState (= previewSortOrder SSOT)")
    }

    @Test("Source wires @Environment(BookStore.self) for openCardInEditor's reference-store reads")
    func sourceBookStoreEnvironment() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("@Environment(BookStore.self) private var envBookStore"),
                "ShellMiddleColumn must read BookStore via @Environment (= openCardInEditor needs referenceStore)")
    }

    @Test("Source passes previewSortOrder binding via $workspaceUI (= WorkspaceUIState is the SSOT)")
    func sourcePreviewSortOrderBinding() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("previewSortOrder: $workspaceUI.previewSortOrder"),
                "ShellMiddleColumn must bind previewSortOrder through workspaceUI (= single source of truth)")
    }

    @Test("Source maps sidebarSelection → PreviewScope via private func previewScope()")
    func sourcePreviewScopeMapper() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("private func previewScope() -> PreviewScope"),
                "ShellMiddleColumn must expose the private previewScope() (= canonical scope mapper)")
        #expect(content.contains("let scope = previewScope()"),
                "ShellMiddleColumn body must read previewScope() into a local before passing to PreviewPane")
    }

    @Test("Source wires PreviewPane with previewScope: scope in BOTH call sites (= display + search)")
    func sourcePreviewScopeBothCallSites() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // Two call sites that must both use the same scope value
        // (= the second site is the search filter; = desync = a
        // bug class the prior_defect history specifically tracks).
        let occurrences = content.components(separatedBy: "previewScope: scope,").count - 1
        #expect(occurrences >= 2,
                "ShellMiddleColumn must thread previewScope: scope to both the display path AND the search-filter path (= desync is the prior_defect regress class)")
    }
}
