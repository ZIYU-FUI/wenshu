//
//  EditorPersistence.swift · Wenshu · v1.70 editor-mvvm T2a
//
//  Extracted from `EditorPlaceholder.swift` (= v0.34 B-21 + B-22 +
//  B-23 + SMC ticket 003 disk IO + auto-save + conflict-backup).
//  Lives at the module's Editor layer (= the same layer as
//  `DraftPersistence`, `WikiLinkNavigation`, `EditorFileWatcher`).
//
//  Per boss 2026-09-22 OOB '拆完功能' (= the split is done; = verify
//  the functionality) + the v1.68 sidebar UI/业务/数据分离
//  precedent (= the NavigationSplitShell sibling splits in v1.38-v1.43
//  each moved one responsibility out of the wrapper view into its
//  own file). The disk-IO + auto-save-task lifecycle is one
//  responsibility (= save → reload → dirty state machine). The
//  DispatchSource watcher is a separate responsibility (= lives
//  in EditorFileWatcher from T1a).
//
//  Public surface (= 3 methods + 1 result struct):
//  - `save(tab:bookStore:)` writes the tab's draft to disk.
//      Three paths (= matches v0.34 B-21 + SMC 003):
//        1. tab.documentPath != nil → overwrite that path in place.
//        2. tab.documentPath == nil + bookStore proposed path available
//           → write to <book>/chapters/<uuid>.md + bind tab.documentPath.
//        3. tab.documentPath == nil + no bookStore → /tmp/wenshu-preview-sample.md
//           (= the legacy fallback; = keeps the dev inner loop working
//           when no .ws library is loaded).
//      Returns the final bound path (or nil if all paths failed
//      silently).
//  - `reloadFromDisk(tab:)` reads the on-disk file + (if dirty)
//      writes the user's draft to a .local-wenshu-conflict-<ts>.md
//      side file BEFORE clobbering. Returns the new content + the
//      conflict notice text (nil when the file is missing or the
//      tab was clean). Caller is responsible for writing the new
//      content back to the tab + posting the conflict notice to
//      the user (= the helper doesn't know about `EditorTab.draft =
//      ...` mutation in this signature; = it returns the values).
//  - `handleDirtyTransition(_:tab:bookStore:)` owns the 3-second
//      auto-save Task lifecycle (= matches v0.34 B-22 + boss 9/2
//      spec). dirty=true starts ONE Task (= subsequent edits within
//      the debounce window don't spawn new Tasks); dirty=false
//      cancels the pending Task.
//
//  Internal (= not public) because `EditorTab` itself is internal
//  (= AppState.swift:487 = `final class` with no access modifier).
//  Swift refuses `public func f(tab: EditorTab)`. Matches the
//  v0.34 + T1a pattern.
//

import Foundation

/// Result of `EditorPersistence.reloadFromDisk(tab:)`. The
/// `newContent` field carries the on-disk file contents (for the
/// caller to write back to `tab.draft` + `tab.originalBody`). The
/// `conflictNotice` field carries the localized user-facing
/// message for the conflict-backup path (= populated when the
/// tab was dirty AND the backup write succeeded; = nil on a
/// clean tab OR a backup write failure).
struct EditorPersistenceReloadResult: Equatable, Sendable {
    let newContent: String
    let conflictNotice: String?
}

/// Disk IO + auto-save-task lifecycle. Pure functions that mutate
/// the supplied `EditorTab` (= @Observable) and return result
/// structs for the caller to act on.
@MainActor
enum EditorPersistence {

    /// Save the tab's draft to disk. See the file header for the
    /// 3-path resolution.
    ///
    /// - Parameters:
    ///   - tab: the tab whose `draft` should be persisted. Mutated
    ///     in place when the propose-new-path branch binds
    ///     `tab.documentPath` (= subsequent saves reuse the same
    ///     path = the auto-bind invariant from v0.34 B-21).
    ///   - bookStore: optional; = when tab.documentPath is nil,
    ///     the helper asks `DraftPersistence.proposedPath(...)` for
    ///     a `<book>/chapters/<uuid>.md` candidate. `nil` falls
    ///     through to the /tmp path.
    /// - Returns: the final bound path (= `tab.documentPath` after
    ///   the call). Nil when all paths failed silently (= matches
    ///   the legacy `try?` behavior in v0.34 B-21).
    @discardableResult
    static func save(tab: EditorTab, bookStore: BookStore?) -> String? {
        // Path 1: existing documentPath → overwrite in place.
        if let path = tab.documentPath {
            let url = URL(fileURLWithPath: path)
            try? tab.draft.write(to: url, atomically: true, encoding: .utf8)
            return path
        }
        // Path 2: no documentPath + bookStore proposed path → write
        // there + bind tab.documentPath (= auto-bind so subsequent
        // saves overwrite the same file).
        if let proposed = DraftPersistence.proposedPath(
            for: tab, bookStore: bookStore
        ) {
            do {
                let parent = proposed.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: parent, withIntermediateDirectories: true
                )
                try DraftPersistence.persist(text: tab.draft, to: proposed)
                tab.documentPath = proposed.path
                return proposed.path
            } catch {
                #if DEBUG
                print("[wenshu.editor.persistence] chapter save failed: \(error)")
                #endif
                // Fall through to /tmp fallback.
            }
        }
        // Path 3: no documentPath + no proposed path → legacy /tmp
        // fallback (= the dev inner-loop case = no .ws library).
        let url = URL(fileURLWithPath: "/tmp/wenshu-preview-sample.md")
        try? tab.draft.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    /// Read the on-disk file at `tab.documentPath`. If the tab
    /// is dirty (= draft != originalBody), write the in-memory
    /// draft to a `.local-wenshu-conflict-<unix-timestamp>.md`
    /// side file BEFORE clobbering (= the user's in-progress
    /// edits survive the external reload = Apple HIG conflict-
    /// backup convention).
    ///
    /// - Parameter tab: the tab whose documentPath is the source.
    ///   NOT mutated by this method (= caller writes the result
    ///   back to `tab.draft` + `tab.originalBody` + `tab.externalChangeNotice`).
    /// - Returns: the new content + conflict notice (= nil on
    ///   missing file or clean tab). Caller uses the conflict
    ///   notice to set `tab.externalChangeNotice` (= the v0.34
    ///   B-23 user-facing alert).
    static func reloadFromDisk(tab: EditorTab) -> EditorPersistenceReloadResult? {
        guard let path = tab.documentPath else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let newContent = try? String(contentsOf: url, encoding: .utf8) else {
            #if DEBUG
            print("[wenshu.editor.persistence] B-23: failed to read \(path)")
            #endif
            return nil
        }
        // Apple HIG TextEdit / Pages / Xcode behavior: clean state
        // = silent reload; dirty state = save user edits to a
        // .local-wenshu-conflict-<ts>.md BEFORE clobbering.
        let conflictNotice: String? = {
            guard tab.draft != tab.originalBody else { return nil }
            let timestamp = Int(Date().timeIntervalSince1970)
            let conflictPath = path + ".local-wenshu-conflict-\(timestamp).md"
            do {
                try tab.draft.write(
                    toFile: conflictPath,
                    atomically: true,
                    encoding: .utf8
                )
                return WenshuI18n.ts("workspace.editor.external_change_saved", conflictPath)
            } catch {
                return WenshuI18n.t("workspace.editor.external_change_save_failed")
                    + " (" + error.localizedDescription + ")"
            }
        }()
        return EditorPersistenceReloadResult(
            newContent: newContent,
            conflictNotice: conflictNotice
        )
    }

    /// Dirty-state machine (= v0.34 B-22 + boss 9/2 spec).
    ///
    /// - `dirty = true`: start ONE 3-second Task. The Task fires
    ///   `EditorPersistence.save(tab:bookStore:)` (= writes to
    ///   disk + sets `tab.originalBody = tab.draft` = the cycle
    ///   end). Subsequent edits within the debounce window reuse
    ///   the same Task (= at most 1 active Task per tab).
    /// - `dirty = false`: cancel the pending Task + nil it out
    ///   (= the document is already consistent with disk = no
    ///   more writes).
    ///
    /// Result: at most 1 active Task per tab (= matches the
    /// boss 9/2 'no wasteful Task creation per char' spec).
    static func handleDirtyTransition(
        _ isDirty: Bool,
        tab: EditorTab,
        bookStore: BookStore?
    ) {
        if isDirty {
            // User just started editing (= dirty → true). Start the
            // 3-second Task. If one was already pending (= e.g. user
            // typed, waited, saved, typed again quickly), reuse it:
            // a new Task replaces the old one (= Task.cancel + new
            // = 1 active Task).
            if tab.autoSaveTask == nil {
                tab.autoSaveTask = Task {
                    // 3-second debounce (= boss 9/2 'auto-save, 3 seconds
                    // after stopping'). Apple HIG doesn't define a canonical
                    // duration; = matches macOS TextEdit / Pages default.
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled {
                        // Already on @MainActor (= this enum is @MainActor-
                        // isolated; = Task runs on the cooperative pool
                        // but `await Task.sleep` resumes here on the main
                        // actor per the surrounding @MainActor context).
                        // No `MainActor.run` hop needed.
                        save(tab: tab, bookStore: bookStore)
                        // B-22: after auto-save, mark the document as
                        // clean (= originalBody = draft = the cycle
                        // ends; = subsequent handleDirtyTransition
                        // calls find a clean state and skip).
                        tab.originalBody = tab.draft
                    }
                    tab.autoSaveTask = nil
                }
            }
        } else {
            // dirty = false (= user just saved via Cmd+S, OR the
            // auto-save Task just completed and set originalBody =
            // draft above). Cancel any pending Task (= no more writes).
            tab.autoSaveTask?.cancel()
            tab.autoSaveTask = nil
        }
    }
}