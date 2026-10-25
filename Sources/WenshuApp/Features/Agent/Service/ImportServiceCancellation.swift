//
//  ImportServiceCancellation.swift
//
//  Cancel + rollback logic extracted from ImportService.swift
//  (= §6.6 god-class split: the cross-file `extension ImportService` with
//  the cancel flag + rollback trail is now in this dedicated file).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1961 LOC = 3.3x the 600-LOC cap. The cancel
//  + rollback logic is a single concern (= cancel = "user said stop; clean
//  up everything we wrote this run"). Putting it in a dedicated file
//  named after the concern (= ImportServiceCancellation.swift) lets the
//  next reader find the cancel logic by name (= same pattern as
//  A31's `SidebarServiceMutation.swift`).
//
//  Access-level changes (= required for cross-file extension access):
//    - `isCancelled` + `writtenURLs` + `entitiesJSONSnapshot` are now
//      `var` (= internal scope, was `private var`).
//

import Foundation

extension ImportService {
    /// Set the cancellation flag (= the sheet's cancel button + the sheet's
    /// `.onDisappear` lifecycle hook both call this; = the orchestrator's
    /// `importFiles` loop polls `isCancelled` between per-task transitions; =
    /// the next dispatch step is a no-op once the flag is set; = the in-flight
    /// TaskGroup finishes whatever it has, then `importFiles` returns with the
    /// remaining tasks in `.pending`).
    func cancel() {
        isCancelled = true
    }

    /// Roll back the partial write-side effects of the current batch (= deletes
    /// every .md file the orchestrator wrote this run; = restores the prior
    /// `entities.json` content from the snapshot taken at `importFiles` start;
    /// = deletes the sidecar cache file). Apple canonical pattern: the rollback
    /// is best-effort + idempotent (= a missing file is a no-op; = a re-run of
    /// the same rollback doesn't double-delete). Boss 2026-10-09 directive:
    /// "取消退出时，所有 已经导入的内容回退清掉。类似 MAC OS 的系统 升级，取消等于放弃这个工作，不留痕". The "不留痕"
    /// requirement is strict (= cancel = nothing lands on disk; = the user can
    /// re- import from a clean state).
    func rollback() {
        // 1. Delete every .md file the orchestrator wrote this run (= reverse-order so
        // the dedup cache's stable-filename mapping doesn't matter; =
        // idempotent on missing files).
        for url in writtenURLs.reversed() {
            try? FileManager.default.removeItem(at: url)
        }
        // 1b. Remove what the agent wrote into the book (= in the
        // reorganize mode the agent is the only writer; = so the
        // orchestrator's own trail is empty and the tree diff is what
        // finds the agent's files).
        removeBookTreeChanges()
        // 2. Restore the prior `entities.json` content (= the orchestrator captured the
        // file's content at `importFiles` start; = a fresh library has an
        // empty snapshot = the file should not exist post-rollback; = a
        // library with a pre-existing `entities.json` restores the file
        // verbatim). The `try?` swallows write errors (= the file may be read-
        // only under a non-admin user; = the rollback is best-effort; = the
        // user can re-import later when the file is writable).
        if let snap = entitiesJSONSnapshot {
            if snap.content.isEmpty {
                // The original file did not exist (= the library had no prior references;
                // = the rollback removes the now-orphaned file that
                // the orchestrator's writes created).
                try? FileManager.default.removeItem(at: snap.path)
            } else {
                try? snap.content.write(to: snap.path, options: .atomic)
            }
        }
        // 3. Delete the sidecar cache file (= the orchestrator may have written entries
        // to the cache for the rolled-back files; = leaving stale entries
        // means a re-import of the same source dir would skip the rolled-back
        // files via dedup; = delete the whole cache file so the next
        // `importFiles` starts from a clean cache). Apple canonical: the cache
        // is a sidecar (= a derived artifact; = deleting it is safe; = the
        // next run rebuilds it from the same source files).
        let cacheFile = URL(fileURLWithPath: "")
        // The cacheRoot is per-target; = the rollback can only know the cacheFile URL if
        // the orchestrator captured it. The simpler path: delete the entire
        // `.import-cache` directory (= the orchestrator writes only `import-
        // cache.json` under it; = the directory delete is the same as the
        // single-file delete in this version; = a future ticket that adds a
        // sidecar metadata file will pick up the new file for free).
        if let snap = entitiesJSONSnapshot {
            // Compute the cache root from the entities path (= the entities file lives at
            // `<wsRoot>/reference-library/entities/entities.json`; = the
            // cache lives at `<wsRoot>/.import-cache/import-cache.json`; =
            // a few `deletingLastPathComponent()` calls get us there).
            let cacheRoot = snap.path
                .deletingLastPathComponent()  // entities.json
                .deletingLastPathComponent()  // entities
                .deletingLastPathComponent()  // reference-library
                .deletingLastPathComponent()  // <wsRoot>
                .appendingPathComponent(".import-cache")
            try? FileManager.default.removeItem(at: cacheRoot)
        }
        _ = cacheFile  // (= placeholder for the future
                        // = per-target cacheRoot = cleanup; = unused in = this version; =
                        // the = .import-cache dir = delete
                        // above handles = the v0.74 schema).
    }

    // A57 extension: prepare-rollback helpers (= setup the cancel + rollback trail
    // at importFiles start). Companion to cancel() / rollback() above.
    /// Reset the cancel flag + clear the rollback trail (= called at the
    /// start of every `importFiles` run; = ensures a fresh cancel/rollback
    /// context per batch).
    func resetRollbackTrail() {
        isCancelled = false
        writtenURLs = []
        entitiesJSONSnapshot = nil
        bookTreeSnapshot = .init()
        bookRootURL = nil
    }

    /// Snapshot the book tree before the run (= the rollback diffs the
    /// tree against it; = the agent writes into the book directly, = so
    /// the orchestrator cannot know the written files from its own
    /// bookkeeping).
    func snapshotBookTree(target: ImportTarget) {
        guard let bookId = target.bookId,
              let shelfId = target.shelfId else { return }
        let root = target.shelvesRoot
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
        bookRootURL = root
        bookTreeSnapshot = ImportServiceBookTree.snapshot(root)
    }

    /// Remove what the run wrote into the book (= the agent's own
    /// writes; = the orchestrator's own trail covers the files it wrote
    /// itself).
    ///
    /// A file that is new, or that changed, was written by this run. A
    /// directory the run created goes too (= the boss's directive is
    /// "不留痕" = leave no trace).
    func removeBookTreeChanges() {
        guard let root = bookRootURL else { return }
        for url in ImportServiceBookTree.changedFiles(
            since: bookTreeSnapshot,
            in: root
        ) {
            try? FileManager.default.removeItem(at: url)
        }
        // The directories the run created (= deepest first; = a directory
        // can only go after the one inside it is gone).
        for url in ImportServiceBookTree.createdDirectories(
            since: bookTreeSnapshot,
            in: root
        ) {
            let contents = (try? FileManager.default.contentsOfDirectory(
                atPath: url.path
            )) ?? []
            if contents.isEmpty {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Snapshot the reference-library `entities.json` for the cancel handler to
    /// restore on rollback (= captures the file before any writeFile call has a
    /// chance to append to it; = a fresh library with no prior `entities.json`
    /// stores an empty-data sentinel = the cancel handler deletes the file
    /// outright).
    func snapshotReferenceLibraryIndex(target: ImportTarget) -> URL {
        let entitiesIndex = target.wsRoot
            .appendingPathComponent("reference-library")
            .appendingPathComponent("entities")
            .appendingPathComponent("entities.json")
        if FileManager.default.fileExists(atPath: entitiesIndex.path) {
            entitiesJSONSnapshot = (entitiesIndex, (try? Data(contentsOf: entitiesIndex)) ?? Data())
        } else {
            entitiesJSONSnapshot = (entitiesIndex, Data())
        }
        return entitiesIndex
    }

}
