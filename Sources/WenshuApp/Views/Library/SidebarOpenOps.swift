//
//  SidebarOpenOps.swift · Wenshu · v1.75 apple-sidebar-mvvm T1b
//
//  AppleSidebarView's openBook/openFolder business layer, extracted from
//  AppleSidebarView (= the P1 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file. Per boss rule:
//  "SidebarOpenOps dedupes the verbatim openBookInEditor + openFolderInEditor
//   pattern (= v1.74d CardOpenOps analog)".
//
//  Public surface (= 2 entry points + 1 Result type):
//    1. openBookInEditor(appState:bookId:) -> OpenResult
//    2. openFolderInEditor(appState:bookId:folderName:) -> OpenResult
//
//  Returns didOpen / didSwitchExistingTab (= same shape as CardOpenOps).
//  Caller decides whether to act on the result.
//

import Foundation

/// Stateless business layer for AppleSidebarView. Mirrors the v1.72 +
/// v1.74 + v1.75a-f precedents.
@MainActor
enum SidebarOpenOps {

    // MARK: - Result types

    struct OpenResult {
        var openedTabId: UUID?
        var didSwitchExistingTab: Bool
    }

    // MARK: - Entry points

    /// Open a book (= no folder anchor) in the editor's tab strip.
    static func openBookInEditor(
        appState: AppState?,
        bookId: UUID
    ) -> OpenResult {
        guard let appState else {
            return OpenResult(openedTabId: nil, didSwitchExistingTab: false)
        }
        // Duplicate-tab check (= Safari multi-tab strip behavior).
        if let existing = appState.openTabs.first(where: {
            if case .bookScope(let id, _) = $0.sourceScope { return id == bookId }
            return false
        }) {
            appState.activeTabId = existing.id
            return OpenResult(openedTabId: nil, didSwitchExistingTab: true)
        }
        let tab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .edit,
            title: nil
        )
        tab.sourceScope = .bookScope(bookId: bookId, folderName: nil)
        appState.openTabs.append(tab)
        appState.activeTabId = tab.id
        return OpenResult(openedTabId: tab.id, didSwitchExistingTab: false)
    }

    /// Open a folder (= `<book-id>/<folder-name>/` directory's first
    /// .md file) in the editor's tab strip.
    static func openFolderInEditor(
        appState: AppState?,
        bookId: UUID,
        folderName: String
    ) -> OpenResult {
        guard let appState else {
            return OpenResult(openedTabId: nil, didSwitchExistingTab: false)
        }
        // Duplicate-tab check (= same book + folder = same tab).
        if let existing = appState.openTabs.first(where: {
            if case .bookScope(let id, let folder) = $0.sourceScope {
                return id == bookId && folder == folderName
            }
            return false
        }) {
            appState.activeTabId = existing.id
            return OpenResult(openedTabId: nil, didSwitchExistingTab: true)
        }
        let tab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .edit,
            title: nil
        )
        tab.sourceScope = .bookScope(bookId: bookId, folderName: folderName)
        appState.openTabs.append(tab)
        appState.activeTabId = tab.id
        return OpenResult(openedTabId: tab.id, didSwitchExistingTab: false)
    }
}