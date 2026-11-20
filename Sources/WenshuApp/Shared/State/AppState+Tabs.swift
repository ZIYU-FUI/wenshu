//
//  AppState+Tabs.swift · Wenshu
//
//  Extension on `AppState` (= 237 LOC of openTabs persistence / restore).
//  `openTabs` / `activeTabId` vars (= the @Observable state itself)
//  stay in AppState (= the `didSet` body calls `self.persistOpenTabs()`
//  which lives here in the extension — Swift allows this because
//  methods declared in extensions on the same module + target are
//  visible to the class's own didSet body).
//
//  The tab pair is persisted here and nowhere else: `persistOpenTabs`
//  writes the list, and the ACTIVE id is written by
//  `ActiveTabPersistence` (= AppState.activeTabId's didSet hands it the
//  value instead of writing defaults inside the interaction frame), so
//  a switch costs this path nothing. Both read and write go through
//  `tabDefaults`, so a session can be pointed at its own suite.
//

import Foundation

extension AppState {
    /// Persisted shape = PersistedEditorTab (= id + documentPath +
    /// draft + originalBody + mode). Tasks / file-watchers / dirty
    /// state are runtime-only (= recreated on launch when tabs are
    /// reloaded from disk).
    func persistOpenTabs() {
        let snapshot = Self.snapshot(of: openTabs)
        if let data = try? JSONEncoder().encode(snapshot) {
            tabDefaults.setData(data, forKey: .openTabs)
        }
    }

    /// Restore openTabs from UserDefaults. Called from init() so
    /// subsequent view code reads the restored state on the first
    /// render.
    ///
    /// RATIONALE: the `restoreOpenTabs`
    /// function filters out the legacy
    /// welcome tab from the persisted
    /// list (= the empty state is
    /// truly empty; = no welcome
    /// tab is restored on next launch).
    /// `documentPath == nil && draft == "" &&
    /// originalBody == ""`; = this is the
    /// canonical wenshu 1:1 fingerprint of
    /// "empty placeholder"; = restoring it
    /// would re-introduce the placeholder the
    /// boss just asked us to remove; = the
    /// `compactMap` filter below drops it). Real
    /// documents (= `documentPath != nil`) are
    /// restored as before.
    func restoreOpenTabs() {
        guard let data = tabDefaults.data(forKey: .openTabs),
              let persisted = try? JSONDecoder().decode([PersistedEditorTab].self, from: data)
        else {
            return
        }
        openTabs = Self.tabs(from: persisted)
        if let activeId = tabDefaults.uuid(forKey: .activeTabId),
           openTabs.contains(where: { $0.id == activeId })
        {
            activeTabId = activeId
        } else if let first = openTabs.first {
            activeTabId = first.id
        }
    }

    /// The record the tabs' snapshot is made of: a tab to its persisted
    /// shape.  `persistOpenTabs` writes exactly this array, so a test of
    /// what a restart keeps can read exactly this array instead of the one
    /// process-global defaults record every other suite also writes.
    /// Measured 2026-11-19: the relaunch case passed alone and failed
    /// inside a combined `--filter` run, because another suite's `closeTab`
    /// overwrote that record between the write and the read.
    static func snapshot(of tabs: [EditorTab]) -> [PersistedEditorTab] {
        tabs.map {
            PersistedEditorTab(
                id: $0.id,
                documentPath: $0.documentPath,
                draft: $0.draft,
                originalBody: $0.originalBody,
                mode: $0.mode.rawValue,
                title: $0.title,
                sourceScope: $0.sourceScope
            )
        }
    }

    /// The record back to tabs: what `restoreOpenTabs` installs, and what a
    /// test of the restore path can install itself (= the same production
    /// mapping, no shared defaults in the middle).
    static func tabs(from persisted: [PersistedEditorTab]) -> [EditorTab] {
        persisted.compactMap { p in
            // Drop the legacy welcome/placeholder tab (= a
            // tab with no `documentPath` AND empty body; = the
            // empty-state placeholder that the boss asked
            // us to remove; = the `compactMap` here means a
            // future session with no real documents opens
            // to a truly empty editor).
            if p.documentPath == nil, p.draft.isEmpty, p.originalBody.isEmpty {
                return nil
            }
            guard let mode = EditorMode(rawValue: p.mode) else { return nil }
            // 2026-10-14: the previous
            // `restoreOpenTabs` populated `tab.draft`
            // and `tab.originalBody` from the
            // UserDefaults snapshot directly (= the
            // same `p.draft` / `p.originalBody` that
            // the previous `persistOpenTabs` wrote
            // at the last `openTabs.didSet` event).
            // This was a "fake autosave" path: the
            // `EditorPersistence.handleDirtyTransition`
            // auto-save task writes the tab's draft
            // to disk (= `<book>/chapters/<uuid>.md`)
            // AND sets `tab.originalBody = tab.draft`
            // to mark the tab clean, but the
            // `tab.draft` mutation is on the
            // `EditorTab` instance (= a mutable
            // field on an `@Observable` class), not
            // on the `AppState.openTabs` array. The
            // `openTabs.didSet` only fires on
            // array-level mutations (= add / remove /
            // reorder), not on per-tab field
            // mutations. Result: `persistOpenTabs()`
            // was never called after the user's
            // typing-triggered draft mutations, = the
            // UserDefaults `draft` field stayed at
            // its initial empty-string value forever,
            // = the next session's `restoreOpenTabs`
            // loaded `tab.draft = ""` from UserDefaults
            // = the user's typing appeared to be lost
            // (= the user reported 2026-10-14 "自动
            // 保存机制是假的" = exactly this
            // regression). The on-disk file was
            // always correct (= the auto-save did
            // write `<book>/chapters/<uuid>.md`); =
            // the user was being shown a stale
            // UserDefaults-cached `tab.draft` instead
            // of the on-disk file content.
            //
            // The fix: re-read the on-disk file at
            // `p.documentPath` and use that as both
            // `tab.draft` and `tab.originalBody`
            // (= the file IS the single source of
            // truth; = UserDefaults only tracks the
            // tab metadata = id / documentPath / mode
            // / title; = the file content lives on
            // disk, not in UserDefaults). The file
            // content read here is the post-auto-save
            // (= the last `EditorPersistence.save(tab:)`
            // call wrote the user's draft to disk; =
            // the file is the canonical truth). For a
            // file that does not exist (= the user
            // deleted it from Finder while the app
            // was closed, = an external crash, = etc.),
            // fall back to the UserDefaults `draft` if
            // it is non-empty (= the file is gone
            // but the previous `persistOpenTabs` did
            // capture a draft for this tab at some
            // point in history; = the cached draft
            // is the last-known in-memory content
            // before the file went missing; =
            // preserving the draft = the user does
            // not lose the entire document to a
            // missing file = the user can copy the
            // content out before the next save
            // clobbers it).
            let (restoredDraft, restoredOriginal): (String, String) = {
                guard let path = p.documentPath else {
                    return (p.draft, p.originalBody)
                }
                let url = URL(fileURLWithPath: path)
                guard let fileContent = try? String(contentsOf: url, encoding: .utf8) else {
                    // File missing or unreadable. Fall
                    // back to the UserDefaults-cached
                    // draft if the user has ever typed
                    // into this tab (= a previous
                    // `persistOpenTabs` snapshot
                    // captured a non-empty draft). If
                    // the cached draft is also empty,
                    // treat the tab as gone (= a
                    // `compactMap` nil return; = the
                    // editor opens with one fewer
                    // tab).
                    if !p.draft.isEmpty {
                        return (p.draft, p.draft)
                    }
                    return ("", "")
                }
                // File read OK. Use the file content
                // as both `draft` (= the on-disk
                // post-auto-save snapshot) and
                // `originalBody` (= the on-disk
                // snapshot IS the canonical
                // baseline; = the auto-save invariant
                // is `draft == originalBody` = the tab
                // opens clean; = the user starts with
                // a non-dirty tab = no immediate
                // "已保存" -> "未保存" flicker on
                // launch).
                return (fileContent, fileContent)
            }()
            let tab = EditorTab(
                id: p.id,
                documentPath: p.documentPath,
                draft: restoredDraft,
                originalBody: restoredOriginal,
                mode: mode,
                title: p.title
            )
            // The scope is set after init (= the same way the open paths
            // set it, = `SidebarOpenOps` / `CardOpenOps`), so a restored
            // tab names the SAME book its pre-relaunch self named (= the
            // format page's target survives a restart).
            tab.sourceScope = p.sourceScope
            return tab
        }
    }

    /// The book the document in front of the user belongs to, = or nil
    /// when the active tab is a placeholder, = a reference-library card,
    /// or a document opened before a scope was recorded.
    ///
    /// This is what makes "the book" mean the same thing on the format
    /// page and in the editor: the page and the editor both read the
    /// store's selected book, = and the store adopts THIS on every tab
    /// change (= `LibraryRootView`). Opening a book's document from the
    /// card grid therefore names that book, = which the sidebar's outline
    /// click alone never did.
    var activeBookId: UUID? {
        guard let tab = openTabs.first(where: { $0.id == activeTabId }) else { return nil }
        if case let .bookScope(bookId, _) = tab.sourceScope {
            return bookId
        }
        return nil
    }
}
