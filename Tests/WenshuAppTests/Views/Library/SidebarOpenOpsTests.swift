//
//  SidebarOpenOpsTests.swift · Wenshu · v1.75 apple-sidebar-mvvm T1a
//
//  Behavior + source-level tests for `SidebarOpenOps`
//  (= the stateless enum extracted from AppleSidebarView;
//  = the P1 dedupe view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9).
//
//  Coverage (= 9 tests):
//    1.  fileExistsAtCanonicalPath
//    2.  openBookInEditor ignores nil appState
//    3.  openFolderInEditor ignores nil appState
//    4.  openBookInEditor returns didSwitchExistingTab=true for duplicate book scope
//    5.  openBookInEditor appends a new tab for a unique book scope
//    6.  openFolderInEditor returns didSwitchExistingTab=true for duplicate book+folder
//    7.  openFolderInEditor appends a new tab for a unique book+folder
//    8.  sourceHasTwoPublicStaticFuncs marker
//    9.  sourceIsStatelessEnum marker
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 apple-sidebar-mvvm T1a — SidebarOpenOps (sidebar open-book + open-folder dedup)")
@MainActor
struct SidebarOpenOpsTests {

    /// AppState.init() restores openTabs + activeTabId from UserDefaults
    /// (= v0.40 boss 9/7 persistence). Tests need a clean baseline
    /// (= per v1.74d CardOpenOpsTests pattern; = stale tabs from a prior
    /// run would otherwise cause `openTabs.count` to be wrong).
    init() {
        UserDefaults.standard.removeObject(forKey: AppState.openTabsKey)
        UserDefaults.standard.removeObject(forKey: AppState.activeTabIdKey)
    }

    // MARK: - Path guard

    @Test("SidebarOpenOps.swift exists at the canonical path under Views/Library/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Library/SidebarOpenOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "SidebarOpenOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - nil appState

    @Test("openBookInEditor ignores nil appState")
    func openBookIgnoresNilAppState() async {
        let r = await SidebarOpenOps.openBookInEditor(appState: nil, bookId: UUID())
        #expect(r.openedTabId == nil)
        #expect(r.didSwitchExistingTab == false)
    }

    @Test("openFolderInEditor ignores nil appState")
    func openFolderIgnoresNilAppState() async {
        let r = await SidebarOpenOps.openFolderInEditor(appState: nil, bookId: UUID(), folderName: "drafts")
        #expect(r.openedTabId == nil)
        #expect(r.didSwitchExistingTab == false)
    }

    // MARK: - duplicate-tab behavior

    @Test("openBookInEditor returns didSwitchExistingTab=true for duplicate book scope")
    func openBookReturnsDidSwitchForDuplicate() async {
        // Use the real AppState so we exercise the openTabs logic.
        let appState = AppState()
        let bookId = UUID()
        let firstTab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .edit,
            title: nil
        )
        firstTab.sourceScope = .bookScope(bookId: bookId, folderName: nil)
        appState.openTabs.append(firstTab)
        let r = await SidebarOpenOps.openBookInEditor(appState: appState, bookId: bookId)
        #expect(r.didSwitchExistingTab == true)
        #expect(r.openedTabId == nil)
        #expect(appState.openTabs.count == 1)
    }

    @Test("openBookInEditor appends a new tab for a unique book scope")
    func openBookAppendsNewTab() async {
        let appState = AppState()
        let bookId = UUID()
        let r = await SidebarOpenOps.openBookInEditor(appState: appState, bookId: bookId)
        #expect(r.openedTabId != nil)
        #expect(r.didSwitchExistingTab == false)
        #expect(appState.openTabs.count == 1)
        #expect(appState.openTabs.first?.sourceScope == .bookScope(bookId: bookId, folderName: nil))
    }

    @Test("openFolderInEditor returns didSwitchExistingTab=true for duplicate book+folder")
    func openFolderReturnsDidSwitchForDuplicate() async {
        let appState = AppState()
        let bookId = UUID()
        let folder = "drafts"
        let firstTab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .edit,
            title: nil
        )
        firstTab.sourceScope = .bookScope(bookId: bookId, folderName: folder)
        appState.openTabs.append(firstTab)
        let r = await SidebarOpenOps.openFolderInEditor(appState: appState, bookId: bookId, folderName: folder)
        #expect(r.didSwitchExistingTab == true)
        #expect(r.openedTabId == nil)
        #expect(appState.openTabs.count == 1)
    }

    @Test("openFolderInEditor appends a new tab for a unique book+folder")
    func openFolderAppendsNewTab() async {
        let appState = AppState()
        let bookId = UUID()
        let folder = "drafts"
        let r = await SidebarOpenOps.openFolderInEditor(appState: appState, bookId: bookId, folderName: folder)
        #expect(r.openedTabId != nil)
        #expect(r.didSwitchExistingTab == false)
        #expect(appState.openTabs.count == 1)
        #expect(appState.openTabs.first?.sourceScope == .bookScope(bookId: bookId, folderName: folder))
    }

    // MARK: - Source-level markers

    @Test("source-marker: ops file contains 2 public static funcs")
    func sourceHasTwoPublicStaticFuncs() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Library/SidebarOpenOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func openBookInEditor"))
        #expect(source.contains("static func openFolderInEditor"))
    }

    @Test("ops file is a stateless enum (= no @Observable / @MainActor class)")
    func sourceIsStatelessEnum() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Library/SidebarOpenOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum SidebarOpenOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class SidebarOpenOps"))
    }
}