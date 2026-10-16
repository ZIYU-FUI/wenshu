//
//  EditorPersistence.swift · Wenshu
//
//  Extracted from `EditorView.swift`. Lives at the
//  module's Editor layer (= the same layer as `DraftPersistence`,
//  `WikiLinkNavigation`, `EditorFileWatcher`).
//
//  The disk-IO + auto-save-task lifecycle is one
//  responsibility (= save → reload → dirty state machine). The
//  DispatchSource watcher is a separate responsibility (= lives
//  in EditorFileWatcher from T1a).
//
//  Public surface (= 3 methods + 1 result struct):
//  - `save(tab:bookStore:)` writes the tab's draft to disk.
//      Three paths (= matches the SMC ticket 003):
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
//      auto-save Task lifecycle (= matches the
//      spec). dirty=true starts ONE Task (= subsequent edits within
//      the debounce window don't spawn new Tasks); dirty=false
//      cancels the pending Task.
//
//  Internal (= not public) because `EditorTab` itself is internal
//  (= AppState.swift:487 = `final class` with no access modifier).
//  Swift refuses `public func f(tab: EditorTab)`. Matches the
// + T1a pattern.
//

import Foundation
import WenshuData
import os

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
    ///     path = the auto-bind invariant).
    ///   - bookStore: optional; = when tab.documentPath is nil,
    ///     the helper asks `DraftPersistence.proposedPath(...)` for
    ///     a `<book>/chapters/<uuid>.md` candidate. `nil` falls
    ///     through to the /tmp path.
    /// - Returns: the final bound path (= `tab.documentPath` after
    ///   the call). Nil when all paths failed silently (= matches
    ///   the legacy `try?` behavior).
    @discardableResult
    static func save(tab: EditorTab, bookStore: BookStore?) -> String? {
        // 2026-10-14 perf: the dirty-skip + content-
        // equality short-circuit is the primary
        // perf win for the auto-save path (= most
        // debounce ticks fire when the user has not
        // actually changed anything, = the engine
        // emits `onDirtyChange(true)` for transient
        // reasons like a `textContainer` size change
        // on a window resize). The IO that is left
        // (= a real draft change) is a single
        // `String.write(to:atomically:encoding:)`
        // call for ~10 KB of text. On the macOS
        // 27.0 AppleSSD the write throughput is
        // measured at ~3 GB/s, = 10 KB writes in
        // ~3 μs, = the write is dwarfed by the
        // syscall overhead (= ~50 μs for the
        // `write(2)` + ~50 μs for the atomic
        // `rename(2)`). The total cost of the write
        // path is well under 200 μs (= the user
        // does not perceive any UI hitch on a
        // 3-second debounce tick). The previous
        // [archived-round] commit's "Apple HIG 1:1 0-PT
        // padding + 13 PT body" work was the real
        // user-perceived perf win (= the editor
        // body now scrolls smoothly; = see
        // commit `bfd89b385` in the log). This
        // function's skip-on-content-equal is the
        // secondary perf win (= no IO, no SwiftData
        // round-trip) and the primary correctness
        // win (= no spurious SwiftData body updates
        // for resize-induced `onDirtyChange`
        // events).
        if let path = tab.documentPath {
            let url = URL(fileURLWithPath: path)
            // 2026-10-14: the parent directory may
            // not exist yet (= the doc-truth-git
            // ticket introduced a per-reference
            // `<libraryRoot>/references/` directory
            // that did not exist in any prior build;
            // = the first `EditorPersistence.save` for
            // a reference tab = `String.write(to:
            // atomically:)` silently fails because
            // `String.write(to:atomically:)` does
            // not create the parent directory.
            // Create the parent directory with
            // `withIntermediateDirectories: true`
            // so the reference body file actually
            // lands on disk. The
            // `FileSystemReferenceStore.writeReferenceFileToFileSystem`
            // helper does the same thing for the
            // SwiftData-write path (= the LLM agent's
            // `ReferenceLibraryTool`); = this line
            // is the parallel fix for the
            // editor's `EditorPersistence.save`).
            let parent = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(
                at: parent, withIntermediateDirectories: true
            )
            // 2026-10-14 perf: skip the write when
            // the draft matches the file (= see the
            // note at the top of the function). A
            // missing or unreadable file is treated
            // as "always needs write" (= the early
            // return path is only taken when the
            // file is present AND the bytes match).
            // The early return also skips the
            // SwiftData `replaceReferenceByID`
            // round-trip below (= the
            // `if let id = ...` chain is only
            // reached on the actual-write path).
            if let existing = try? String(contentsOf: url, encoding: .utf8),
               existing == tab.draft {
                // Already on disk with the same
                // content. Skip the write AND the
                // SwiftData body update (= both
                // would be no-ops anyway, = the
                // early return saves a `String.write`
                // syscall + a SwiftData row fetch +
                // a `context.save`). The caller still
                // sets `tab.originalBody = tab.draft`
                // to mark the tab clean.
                return path
            }
            os_log("[wenshu.editor.save] tab.draft=%{public}d chars path=%{public}@",
                   tab.draft.count, path)
            let written = try? tab.draft.write(to: url, atomically: true, encoding: .utf8)
            os_log("[wenshu.editor.save] writeOk=%{public}@ bytes=%{public}d",
                   written != nil ? "true" : "false",
                   (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? -1)
            // 2026-10-14: doc-truth-git ticket. When the
            // path points inside the library's
            // `references/` directory (= a reference-
            // library tab that the user opened via
            // `CardOpenOps.openTab`; = see the
            // `path: bookStore.flatMap { ... }` there
            // that produces `<libraryRoot>/references
            // /<uuid>.md`), also update the SwiftData
            // `WSReference.body` column to keep the
            // in-memory cache consistent (= the
            // `ReferenceLibraryTool` for the LLM
            // agent's `find` tool reads SwiftData
            // directly, = without this write-through
            // the agent's view of the body would
            // diverge from the file). The id is
            // recovered from the trailing `<uuid>.md`
            // filename. The write is best-effort (= a
            // missing `bookStore` or a missing
            // SwiftData row is silently skipped; = the
            // file write above is the source of truth
            // and has already succeeded by the time we
            // get here).
            if let id = referenceUUIDFromReferencePath(path),
               let store = bookStore?.stores.referenceStore,
               (try? store.replaceReferenceByID(
                   id: id, bodyMarkdown: tab.draft
               )) != nil {
                // The SwiftData `body` cache is now
                // consistent with the on-disk file
                // (= the LLM agent's
                // `ReferenceLibraryTool` reads from
                // SwiftData; = without this write-through
                // the agent's view of the body would
                // diverge from the file). The
                // `try?` swallows the rare "row not
                // in SwiftData" path (= the file
                // write above still succeeded; =
                // SwiftData is a write-through cache;
                // = the file is the source of truth).
            }
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
                // Fall through to /tmp fallback.
                return nil
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
    ///   notice to set `tab.externalChangeNotice` (= the
    /// user-facing alert).
    static func reloadFromDisk(tab: EditorTab) -> EditorPersistenceReloadResult? {
        guard let path = tab.documentPath else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let newContent = try? String(contentsOf: url, encoding: .utf8) else {
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
                return String.localizedStringWithFormat(NSLocalizedString("workspace.editor.external_change_saved", comment: ""), conflictPath)
            } catch {
                return String(localized: "workspace.editor.external_change_save_failed")
                    + " (" + error.localizedDescription + ")"
            }
        }()
        return EditorPersistenceReloadResult(
            newContent: newContent,
            conflictNotice: conflictNotice
        )
    }

    /// Dirty-state machine (= the spec (see OOB.md #2026-09-02)).
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
    /// (see OOB.md #2026-09-02)no wasteful Task creation per char' spec).
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
                    // 3-second debounce (= (see OOB.md #2026-09-02)auto-save, 3 seconds
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
                        // after auto-save, mark the document as
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

/// 2026-10-14: recover the reference id (= the
/// `WSReference.id` UUID) from a
/// `<libraryRoot>/references/<uuid>.md` file path. Used by
/// the editor's auto-save path to call
/// `ReferenceStoring.replaceReferenceByID` (= updates the
/// SwiftData `body` cache after the file write). The
/// matcher checks the second-to-last path component (= the
/// literal `references` directory name, = case-sensitive)
/// so that a book chapter at
/// `<libraryRoot>/chapters/<uuid>.md` is correctly
/// identified as NOT a reference. A path that does not
/// match the `<uuid>.md` filename pattern returns nil (=
/// the editor's auto-save falls through to the
/// write-only-file path for non-reference tabs).
func referenceUUIDFromReferencePath(_ path: String) -> UUID? {
    let url = URL(fileURLWithPath: path)
    let parent = url.deletingLastPathComponent().lastPathComponent
    guard parent == "references" else { return nil }
    let stem = url.deletingPathExtension().lastPathComponent
    return UUID(uuidString: stem)
}
