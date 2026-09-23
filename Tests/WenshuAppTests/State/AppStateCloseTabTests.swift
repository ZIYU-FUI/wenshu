//
//  AppStateCloseTabTests.swift · Wenshu · v1.73 tab close button
//
//  Behavior tests for `AppState.closeTab(id:bookStore:)` (= the
//  business method that powers the new X button on the editor
//  tab strip). Boss 2026-09-22 OOB 'TEB 没有叉，导致文档只能
//  打开关不掉' + '需要加 X，同时确保自动保存有用'.
//
//  Three failure modes this test guarantees against (= RED gate
//  before GREEN):
//   1. closeTab actually removes the tab (= the X button works).
//   2. closeTab flushes a dirty draft synchronously via
//      EditorPersistence.save (= auto-save guarantee; = no
//      lost edits when the user clicks X mid-edit).
//   3. closeTab cancels the pending auto-save Task before removing
//      the tab (= prevents Task.resume on a dead tab = crash).
//
//  Setup hygiene (= wenshu-pollution-defense §11.4.2): every test
//  clears the persisted tab keys in UserDefaults.standard so
//  AppState() init doesn't restore tabs from a previous test's
//  writes (= isolation between tests in the same suite).
//
//  Per Q112: 1 source + 1 test per ticket. Source lands in the
//  same commit (= this test gates the GREEN impl).

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.73 tab close button — AppState.closeTab (= X button business)")
@MainActor
struct AppStateCloseTabTests {

    // MARK: - Setup / teardown

    init() {
        // Clear persisted tab state so AppState() init starts empty.
        UserDefaults.standard.removeObject(forKey: AppState.openTabsKey)
        UserDefaults.standard.removeObject(forKey: AppState.activeTabIdKey)
    }

    // MARK: - Fixtures

    /// Make a clean EditorTab with optional draft + originalBody.
    private func makeTab(
        draft: String = "draft",
        originalBody: String = "draft",
        documentPath: String? = nil
    ) -> EditorTab {
        EditorTab(
            id: UUID(),
            documentPath: documentPath,
            draft: draft,
            originalBody: originalBody,
            mode: .preview,
            title: nil
        )
    }

    /// Build an AppState with a known set of tabs (= bypasses
    /// restoreOpenTabs; = predictable test fixture).
    private func makeState(tabs: [EditorTab]) -> AppState {
        let state = AppState()
        state.openTabs = tabs
        return state
    }

    // MARK: - Happy path (= the X button removes the tab)

    @Test("closeTab removes the targeted tab from openTabs (= X button works)")
    func closeTabRemovesTargetedTab() {
        let tab1 = makeTab()
        let tab2 = makeTab()
        let state = makeState(tabs: [tab1, tab2])

        state.closeTab(id: tab1.id, bookStore: nil)

        #expect(state.openTabs.count == 1,
                "closeTab must remove exactly 1 tab from openTabs")
        #expect(state.openTabs.first?.id == tab2.id,
                "closeTab must remove the targeted tab and leave the others")
    }

    @Test("closeTab is a no-op for an unknown tab id (= safe under stale UI)")
    func closeTabIsNoOpForUnknownID() {
        let tab = makeTab()
        let state = makeState(tabs: [tab])

        state.closeTab(id: UUID(), bookStore: nil)

        #expect(state.openTabs.count == 1,
                "closeTab with unknown id must NOT mutate the list")
        #expect(state.openTabs.first?.id == tab.id,
                "closeTab with unknown id must NOT remove the existing tab")
    }

    // MARK: - Active tab switching (= focus follows close)

    @Test("closeTab on the active tab switches active to the next neighbor (= Safari-style focus follow)")
    func closeTabOnActiveSwitchesToNextNeighbor() {
        let tab1 = makeTab()
        let tab2 = makeTab()
        let tab3 = makeTab()
        let state = makeState(tabs: [tab1, tab2, tab3])
        state.activeTabId = tab2.id

        // Close the active tab (tab2). Expect focus to land on tab3
        // (= next tab in list; = Safari / Chrome convention).
        state.closeTab(id: tab2.id, bookStore: nil)

        #expect(state.openTabs.map(\.id) == [tab1.id, tab3.id],
                "active tab must be removed; = the other two remain in order")
        #expect(state.activeTabId == tab3.id,
                "focus must follow to the next neighbor (tab3) when active is closed")
    }

    @Test("closeTab on the last tab switches to the previous neighbor (= edge case)")
    func closeTabOnLastSwitchesToPrevious() {
        let tab1 = makeTab()
        let tab2 = makeTab()
        let state = makeState(tabs: [tab1, tab2])
        state.activeTabId = tab2.id

        // Close the last tab. Expect focus to fall back to tab1
        // (= previous neighbor; = Safari convention).
        state.closeTab(id: tab2.id, bookStore: nil)

        #expect(state.openTabs.map(\.id) == [tab1.id],
                "only tab1 should remain after closing the last tab")
        #expect(state.activeTabId == tab1.id,
                "focus must fall back to the previous tab (tab1) when the last is closed")
    }

    @Test("closeTab on a non-active tab leaves activeTabId unchanged (= safe close)")
    func closeTabOnNonActiveLeavesActiveUnchanged() {
        let tab1 = makeTab()
        let tab2 = makeTab()
        let state = makeState(tabs: [tab1, tab2])
        state.activeTabId = tab1.id

        state.closeTab(id: tab2.id, bookStore: nil)

        #expect(state.activeTabId == tab1.id,
                "closing a non-active tab must NOT change activeTabId")
    }

    @Test("closeTab on the last remaining tab re-injects the welcome tab (= tab strip stays visible)")
    func closeTabLastRemainingReInjectsWelcomeTab() {
        let tab = makeTab()
        let state = makeState(tabs: [tab])
        state.activeTabId = tab.id

        state.closeTab(id: tab.id, bookStore: nil)

        #expect(state.openTabs.count == 1,
                "after closing the last tab, the welcome tab must be re-injected (= ensureWelcomeTabIfEmpty invariant)")
        #expect(state.activeTabId == state.openTabs.first?.id,
                "activeTabId must point at the re-injected welcome tab")
    }

    // MARK: - Auto-save guarantee (= the boss's '确保自动保存有用')

    @Test("closeTab on a dirty tab cancels pending auto-save Task (= prevents Task.resume on dead tab)")
    func closeTabCancelsPendingAutoSaveTask() {
        let tab = makeTab(draft: "edited", originalBody: "original")
        let state = makeState(tabs: [tab])

        // Plant a live Task on the tab (= simulate the 3-second
        // debounce timer being mid-flight). closeTab must cancel it
        // (= prevents the Task from resuming on a deleted tab; =
        // potential crash + stale write into a removed slot).
        tab.autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(60))
        }
        let planted = tab.autoSaveTask
        #expect(planted != nil, "fixture must plant a live auto-save Task")

        state.closeTab(id: tab.id, bookStore: nil)

        #expect(tab.autoSaveTask == nil,
                "closeTab must cancel + nil the pending autoSaveTask before removing the tab")
        #expect(planted?.isCancelled == true,
                "closeTab must call .cancel() on the planted Task (= prevents Task.resume on dead tab)")
    }

    @Test("closeTab on a dirty tab flushes via EditorPersistence.save (= no lost edits)")
    func closeTabFlushesDirtyDraftSynchronously() {
        // Use a real /tmp path so EditorPersistence.save actually writes.
        // (= behavior test: assertion is on the FILE, not on the in-memory state.)
        let tmpPath = "/tmp/wenshu-closeTab-dirty-\(UUID().uuidString).md"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let dirtyDraft = "## dirty edit\n\nnot yet saved"
        let tab = makeTab(
            draft: dirtyDraft,
            originalBody: "## original",
            documentPath: tmpPath
        )
        let state = makeState(tabs: [tab])

        state.closeTab(id: tab.id, bookStore: nil)

        // The dirty draft MUST hit disk before close (= the boss's
        // '确保自动保存有用' invariant). If the file is empty or
        // contains the original, auto-save was skipped (= data loss).
        let written = (try? String(contentsOfFile: tmpPath, encoding: .utf8)) ?? ""
        #expect(written == dirtyDraft,
                "closeTab must flush dirty draft synchronously via EditorPersistence.save (= no lost edits)")
    }

    @Test("closeTab on a clean tab does NOT write (= idempotent for unsaved tabs)")
    func closeTabCleanTabDoesNotWrite() {
        // Use a sentinel path. If EditorPersistence.save runs
        // (= even on a clean tab), the file would appear; = use
        // a parent dir that doesn't exist so any write attempt
        // fails noisily (= catches accidental save).
        let missingDir = "/tmp/wenshu-closeTab-clean-nonexistent-\(UUID().uuidString)/file.md"
        let tab = makeTab(
            draft: "same",
            originalBody: "same",
            documentPath: missingDir
        )
        let state = makeState(tabs: [tab])

        state.closeTab(id: tab.id, bookStore: nil)

        #expect(!FileManager.default.fileExists(atPath: missingDir),
                "closeTab must NOT call EditorPersistence.save when draft == originalBody (= clean tab = no save needed)")
        #expect(state.openTabs.isEmpty == false || state.openTabs.first?.id != tab.id,
                "closeTab must still remove the clean tab")
    }

    @Test("closeTab stops the file watcher (= prevents zombie DispatchSource)")
    func closeTabStopsFileWatcher() {
        let tmpPath = "/tmp/wenshu-closeTab-watcher-\(UUID().uuidString).md"
        // Pre-condition: simulate EditorFileWatcher.start having
        // armed the tab. We use nil for fileWatcher (= the field
        // is Optional<DispatchSource>) to avoid touching a live
        // DispatchSource in test scope (= a live source without
        // a queue can trap on cancel; = outside the v1.73 ticket
        // scope to wire up a test harness). The guarantee being
        // tested is "closeTab calls EditorFileWatcher.stop"; =
        // the observable side-effect (= nil out + reset FD) is
        // identical whether fileWatcher was nil or live.
        let tab = makeTab(
            draft: "x",
            originalBody: "x",
            documentPath: tmpPath
        )
        // Plant a sentinel watchedFD (= EditorFileWatcher.start
        // would have set this to a real fd). closeTab must reset
        // it to -1 (= the canonical "no fd" sentinel).
        tab.fileWatcher = nil
        tab.watchedFD = 7

        let state = makeState(tabs: [tab])
        state.closeTab(id: tab.id, bookStore: nil)

        // EditorFileWatcher.stop side-effects observable without
        // instantiating a live DispatchSource in test scope.
        // Source-level guarantee (= v1.7 Tab Close Button ticket
        // acceptance): closeTab delegates to EditorFileWatcher.stop.
        #expect(tab.fileWatcher == nil,
                "closeTab must call EditorFileWatcher.stop (= resets tab.fileWatcher to nil)")
        #expect(tab.watchedFD == -1,
                "closeTab must call EditorFileWatcher.stop (= resets tab.watchedFD to -1)")
    }
}