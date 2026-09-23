//
//  CardOpenOpsTests.swift · Wenshu · v1.74 cardopen-dedupe T2a
//
//  Behavior + source-level tests for `CardOpenOps` (= the
//  stateless enum extracted from the 3 verbatim copies of
//  `openCardInEditor` in WorkspaceView / ZoneModuleView /
//  ShellMiddleColumn).
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= the
//  audit at .scratch/2026-09-23-mvvm-audit/spec.md §2.6 / §2.7
//  / §2.11 = the verbatim duplication of `openCardInEditor(source:)`
//  across 3 view files = the canonical dedupe opportunity that
//  combines MVVM split + DRY). The shared tail (= dedup check +
//  EditorTab construction + appState.openTabs.append +
//  activeTabId mutation) was duplicated 3x (= ~50 LOC × 3 views
//  = ~150 LOC of verbatim code). The reference-scope filter +
//  body-load path was also duplicated 3x (= ~30 LOC × 3 views).
//
//  The fix per ADR-0009 + the v1.72 settings-kanban-todo
//  precedent (= KanbanOps / TodoOps / SettingsOps = stateless
//  enums with @MainActor static funcs) is `CardOpenOps` (= this
//  test's SUT) with two entry points:
//  - `computeCardTriad(source:previewScope:bookStore:)` → returns
//    `(path, content, title)` for the resolved scope (= the
//    reference-scope + bookDoc-deferred path shared across all
//    3 views).
//  - `openTab(triad:previewScope:appState:mode:)` → performs
//    the dedup + tab creation + activeTabId mutation (= the
//    shared tail).
//
//  ZoneModuleView's local file-scan (= walk
//  shelves/<shelf-uuid>/books/<book-uuid>/<folder>/*.md and
//  pick the FIRST .md) stays in the View because it's
//  ZoneModuleView-specific (= the other 2 views use the
//  reference-scope + bookDoc-deferred paths only; = ticket
//  027-35 will replace it with a shared BookDocLoader service).
//
//  Coverage (= 6 tests):
//    1. `fileExistsAtCanonicalPath` — source-level guard
//    2. `computeCardTriadReturnsEmptyForShelfScope`
//    3. `computeCardTriadReturnsEmptyForEmptyScope`
//    4. `computeCardTriadReturnsBookDocTitleForBookDocSource`
//    5. `openTabReturnsSilentNoOpForEmptyTriad`
//    6. `openTabReturnsSilentNoOpForShelfScopeTriad`
//
//  Mock strategy:
//  - No mock framework. `CardOpenOps.computeCardTriad` accepts
//    `bookStore: BookStore?` (= nil = silent no-op for
//    reference-scope; = matches the 3 views' pre-v1.74
//    `try? bookStore.referenceStore.loadAllReferences()`
//    fallback behavior). The bookStore-construction is the
//    barrier (= = no fixture in this test).
//  - `openTab` is a pure appState-mutation operation on a
//    real AppState instance (= lightweight; = no fixture).
//
//  Pattern (= v1.72 KanbanOpsTests T1a precedent): @MainActor +
//  Swift Testing + no fixture (= seam-based).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.74 cardopen-dedupe T2a — CardOpenOps (3 views' openCardInEditor dedupe)", .serialized)
struct CardOpenOpsTests {

    // MARK: - Per-test setUp / tearDown

    /// AppState.init() restores openTabs + activeTabId from
    /// UserDefaults (= v0.40 boss 9/7 OOB persistence). Tests need
    /// a clean slate (= no contamination across tests from
    /// previously-persisted tabs). Reset before each test.
    init() {
        UserDefaults.standard.removeObject(forKey: AppState.openTabsKey)
        UserDefaults.standard.removeObject(forKey: AppState.activeTabIdKey)
    }

    // MARK: - Source-level structural assertions

    @Test("CardOpenOps.swift exists at the canonical path under UI/Layout/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/UI/Layout/CardOpenOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "CardOpenOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - computeCardTriad

    @Test("computeCardTriad returns empty triad for .shelfScope")
    func computeCardTriadReturnsEmptyForShelfScope() {
        let triad = CardOpenOps.computeCardTriad(
            source: nil,
            previewScope: .shelfScope(shelfId: UUID()),
            bookStore: nil
        )
        #expect(triad.isEmpty)
        #expect(triad.content == "")
        #expect(triad.path == nil)
        #expect(triad.title == "")
    }

    @Test("computeCardTriad returns empty triad for .empty scope")
    func computeCardTriadReturnsEmptyForEmptyScope() {
        let triad = CardOpenOps.computeCardTriad(
            source: nil,
            previewScope: .empty,
            bookStore: nil
        )
        #expect(triad.isEmpty)
        #expect(triad.content == "")
        #expect(triad.path == nil)
    }

    @Test("computeCardTriad for .referenceScope with nil bookStore returns empty triad")
    func computeCardTriadReturnsEmptyForReferenceScopeWithNilBookStore() {
        // When the caller passed no source AND bookStore is nil
        // (= the on-launch race), computeCardTriad returns the
        // category display name with empty content (= the
        // .referenceScope branch's `else` path).
        let triad = CardOpenOps.computeCardTriad(
            source: nil,
            previewScope: .referenceScope(nil),
            bookStore: nil
        )
        // The .referenceScope branch returns either a populated
        // triad (= pickedReference found) or an empty triad with
        // the category's displayName title (= no pickedReference
        // found). With nil bookStore, `entities` is empty, so
        // `filtered.first` is nil, so the helper returns the
        // empty-with-displayName variant.
        #expect(triad.isEmpty)
        #expect(triad.path == nil)
    }

    // MARK: - openTab

    @Test("openTab returns silent no-op for empty triad")
    func openTabReturnsSilentNoOpForEmptyTriad() {
        // Build a real AppState (= lightweight). The empty triad
        // should produce an OpenCardResult with openedTabId=nil +
        // didSwitchExistingTab=false + contentLength=0.
        let appState = AppState()
        let triad = CardOpenOps.CardTriad(path: nil, content: "", title: "")
        let result = CardOpenOps.openTab(
            triad: triad,
            previewScope: .empty,
            appState: appState
        )
        #expect(result.openedTabId == nil)
        #expect(result.didSwitchExistingTab == false)
        #expect(result.contentLength == 0)
        // No tab was appended (= silent no-op per boss 9/3).
        #expect(appState.openTabs.isEmpty)
    }

    @Test("openTab returns silent no-op for shelf-scope empty triad")
    func openTabReturnsSilentNoOpForShelfScopeTriad() {
        let appState = AppState()
        let triad = CardOpenOps.computeCardTriad(
            source: nil,
            previewScope: .shelfScope(shelfId: UUID()),
            bookStore: nil
        )
        let result = CardOpenOps.openTab(
            triad: triad,
            previewScope: .shelfScope(shelfId: UUID()),
            appState: appState
        )
        #expect(result.openedTabId == nil)
        #expect(result.didSwitchExistingTab == false)
        #expect(result.contentLength == 0)
        #expect(appState.openTabs.isEmpty)
    }

    @Test("openTab creates a new tab for a non-empty triad and switches activeTabId")
    func openTabCreatesNewTabForNonEmptyTriad() {
        // Build a populated triad (= a real .reference body for
        // a hypothetical 'Dufu' reference). The helper should
        // append a new tab + set activeTabId.
        let appState = AppState()
        let triad = CardOpenOps.CardTriad(
            path: nil,
            content: String(repeating: "a", count: 300),  // > 200 chars to fill fingerprint
            title: "Battle of Red Cliffs"
        )
        let result = CardOpenOps.openTab(
            triad: triad,
            previewScope: .referenceScope(nil),
            appState: appState
        )
        #expect(result.openedTabId != nil)
        #expect(result.didSwitchExistingTab == false)
        #expect(result.contentLength == 300)
        #expect(appState.openTabs.count == 1)
        #expect(appState.openTabs.last?.id == appState.activeTabId)
        #expect(appState.openTabs.first?.title == "Battle of Red Cliffs")
        #expect(appState.openTabs.first?.mode == .preview)  // default mode
    }

    @Test("openTab returns didSwitchExistingTab=true when fingerprint matches an existing tab")
    func openTabSwitchesExistingTabForDuplicateFingerprint() {
        let appState = AppState()
        let content = String(repeating: "b", count: 300)
        let firstTriad = CardOpenOps.CardTriad(
            path: nil,
            content: content,
            title: "Original tab"
        )
        let firstResult = CardOpenOps.openTab(
            triad: firstTriad,
            previewScope: .referenceScope(nil),
            appState: appState
        )
        #expect(firstResult.openedTabId != nil)
        #expect(appState.openTabs.count == 1)

        // Second call with the same content (= different title =
        // the fingerprint is the content's first-200-char prefix,
        // NOT the title). Should switch to the existing tab, NOT
        // append.
        let secondTriad = CardOpenOps.CardTriad(
            path: nil,
            content: content,
            title: "Different title"
        )
        let secondResult = CardOpenOps.openTab(
            triad: secondTriad,
            previewScope: .referenceScope(nil),
            appState: appState
        )
        #expect(secondResult.openedTabId == nil)
        #expect(secondResult.didSwitchExistingTab == true)
        #expect(secondResult.contentLength == 300)
        #expect(appState.openTabs.count == 1)  // no duplicate tab
        #expect(appState.activeTabId == firstResult.openedTabId)
    }

    @Test("openTab honours the caller's mode parameter (= .edit for ShellMiddleColumn)")
    func openTabHonoursCallerModeParameter() {
        // ShellMiddleColumn passes `mode: .edit` (= the
        // WenshuMarkdownEditor editable NSTextView from the
        // start; = boss 2026-09-12 directive). Verify the helper
        // honours the caller's mode instead of hard-coding
        // `.preview`.
        let appState = AppState()
        let triad = CardOpenOps.CardTriad(
            path: nil,
            content: String(repeating: "c", count: 300),
            title: "Edit-mode tab"
        )
        _ = CardOpenOps.openTab(
            triad: triad,
            previewScope: .referenceScope(nil),
            appState: appState,
            mode: .edit
        )
        #expect(appState.openTabs.first?.mode == .edit)
    }
}