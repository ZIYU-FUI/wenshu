// ImportService.swift T2 of the markdown import feature. Orchestrates the 4-phase
// pipeline that turns a user-picked source directory into a batch of written entities
// (= either book-folder files or reference-library entries; = decided by the LLM via
// the `ImportRouter` protocol that T4 implements against the WenshuConductor). Apple
// canonical shape: ImportService is a stateless `actor` (= the conductor and the file
// I/O are concurrent; = the per-file state lives in `ImportTask` actors; = the
// orchestrator can be re-entered safely from any context). The view (= ImportSheet)
// calls `importFiles(in:into:router:)` once and observes the returned `[ImportTask]`
// array for the per-file progress strip (= the Apple canonical SwiftUI binding to a
// long-running task). See .scratch/2026-10-09-md-import-feature/tickets.md for the
// full T2 contract.

import CryptoKit
import Foundation
import UniformTypeIdentifiers
import WenshuData


// MARK: - ImportService (the orchestrator)

/// The orchestrator. Stateless (= all state lives in the per-task `ImportTask`
/// actors + the sidecar cache on disk). The view holds a `[ImportTask]` and the
/// `ImportService` mutates the array in place (= the orchestrator returns the
/// array; = the view diffs).
actor ImportService {
    /// Cancellation flag (= boss's 2026-10-09 directive "取消退出时，所有已经导入的内容回退
    /// 清掉。类似 MAC OS 的系统升级，取消等于放弃 这个工作，不留痕"; = the sheet's cancel button + the
    /// `.onDisappear` lifecycle hook both set this to `true`; = the
    /// orchestrator's `importFiles` loop polls it on every per-task transition;
    /// = when `true`, the in-flight tasks stop early (= the TaskGroup finishes
    /// whatever it has; = `importFiles` returns with the remaining tasks in
    /// `.pending`; = the `writtenURLs` set carries the on-disk trail for the
    /// rollback pass)).
    var isCancelled: Bool = false

    /// Per-batch rollback trail (= the URLs of every .md file the orchestrator
    /// wrote this run; = a `Set<URL>` because the dedup cache can map two
    /// source paths to the same on-disk file when the bodies are byte-equal; =
    /// the cancel handler iterates this set + deletes each file in the
    /// most-recent-import order; = the reference-library side restores the
    /// prior `entities.json` from the snapshot the orchestrator took at the
    /// start of the run).
    var writtenURLs: [URL] = []

    /// Snapshot of the on-disk reference-library index file (= the path to the
    /// prior `entities.json` content, captured at `importFiles` start; = the
    /// cancel handler restores this file verbatim; = the "all-or-nothing"
    /// semantic the boss asked for = cancel = nothing lands on disk = the user
    /// can re-import from a clean state).
    var entitiesJSONSnapshot: (path: URL, content: Data)? = nil

    /// Per-task mutable state used by the `dispatchLLM` helper (= extensions
    /// can't hold stored properties; = this lives on the actor).
    /// `lastDispatchError` is the final error from the last failed LLM attempt;
    /// = `dispatchLLM` returns nil and sets this so the orchestrator can
    /// surface the user-readable error via `markLLMFailed`).
    var lastDispatchError: Error? = nil

    /// 5-way parallel LLM dispatch (= the boss's 2026-10-09 directive "你要做一个机制
    /// 5 个并发， 一个文件一个请求。同时只能处理 5 个"; = the orchestrator's TaskGroup seeds the
    /// first `maxParallel` tasks and refills as each completes; = 5 keeps the
    /// in-flight LLM pressure below the Anthropic / MiniMax per-second burst
    /// limit; = the LLMConnector adapter handles its own rate limiting for (=
    /// boss 2026-10-10 (see OOB.md #2026-10-10) directive). The historical
    /// default was 5; = we kept `defaultMaxParallel = 5` as a reference (= the
    /// docs and the `ImportTarget` Picker UI's max = 5) but the actual cap is
    /// `target.maxParallel` (= the per-import user-picked value; = the default
    /// ImportTarget init defaults to 3; = the Picker exposes 1..5).
    static let defaultMaxParallel = 5

    /// Where the sidecar cache lives (= per-library; =
    /// `<wsRoot>/.import-cache/`; = deletable by the user if they want a full
    /// re-import). One path's hash → the destination metadata. The orchestrator
    /// reads this at the dedup step; = writes a fresh entry after each
    /// successful import.
    struct CacheEntry: Codable, Sendable {
        let contentHash: String
        let destination: ImportDestination
        let writtenAt: Date
        /// (= boss 2026-10-10 (see OOB.md #2026-10-10) 浪费" directive). The
        /// timestamp of the last title-only retry on this file (= the user
        /// clicked "重新调研 所有失败" while this entry was in `.failed` state). The
        /// retry method uses this to detect "already retried with the same
        /// body" (= skip the LLM dispatch; = save token + time). The field is
        /// OPTIONAL (= older cache entries from wenshu versions before [archived-round]
        /// don't have it; = the Codable decoder tolerates the missing key).
        /// Custom `init(from:)` is required (= default memberwise init doesn't
        /// expose a default for the optional field).
        var lastTitleOnlyRetriedAt: Date?
        /// the body hash at the time of the last title-only retry (= SHA-256 of
        /// the LLM-ingested body = the title-only-synthesized body constructed
        /// from the filename + sibling context; = NOT the source file's body
        /// hash because the source file is unreadable; = if this hash changes
        /// between retries, the retry result would differ; = the retry method
        /// compares this against the freshly computed hash to decide
        /// skip-vs-run). If the source file's body hash changes (= the user
        /// edited the file; = the title-only body stays the same; = this hash
        /// is stable) the retry still skips; = the boss's intent is "if I
        /// haven't changed anything, don't re-run the LLM" = the title-only
        /// body hash is the right signal.
        var lastTitleOnlyRetriedHash: String?

        init(
            contentHash: String,
            destination: ImportDestination,
            writtenAt: Date,
            lastTitleOnlyRetriedAt: Date? = nil,
            lastTitleOnlyRetriedHash: String? = nil
        ) {
            self.contentHash = contentHash
            self.destination = destination
            self.writtenAt = writtenAt
            self.lastTitleOnlyRetriedAt = lastTitleOnlyRetriedAt
            self.lastTitleOnlyRetriedHash = lastTitleOnlyRetriedHash
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.contentHash = try c.decode(String.self, forKey: .contentHash)
            self.destination = try c.decode(ImportDestination.self, forKey: .destination)
            self.writtenAt = try c.decode(Date.self, forKey: .writtenAt)
            // optional fields (= absent on pre-[archived-round] cache entries; = decode failures
            // silently fall back to nil = the dedup then sees nil = treats
            // it as "never retried" = a fresh retry will run; = no
            // migration step needed).
            self.lastTitleOnlyRetriedAt = try? c.decode(Date.self, forKey: .lastTitleOnlyRetriedAt)
            self.lastTitleOnlyRetriedHash = try? c.decode(String.self, forKey: .lastTitleOnlyRetriedHash)
        }

        private enum CodingKeys: String, CodingKey {
            case contentHash, destination, writtenAt
            case lastTitleOnlyRetriedAt, lastTitleOnlyRetriedHash
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(contentHash, forKey: .contentHash)
            try c.encode(destination, forKey: .destination)
            try c.encode(writtenAt, forKey: .writtenAt)
            // Optional fields: only encode when present (= older wenshu versions reading
            // these entries won't choke on a present-but- unrecognized
            // key; = future-proofs the cache format).
            try? c.encode(lastTitleOnlyRetriedAt, forKey: .lastTitleOnlyRetriedAt)
            try? c.encode(lastTitleOnlyRetriedHash, forKey: .lastTitleOnlyRetriedHash)
        }
    }

    /// Apple canonical convenience: stateless (= no init body; = the actor's
    /// empty default state is enough because all state lives in the per-task
    /// actors + the sidecar cache on disk).
    init() {}

    // MARK: - Public entry point

    /// Run the import. Returns the per-file tasks (= the view binds them; = the
    /// orchestrator mutates state in place via the returned array; = the array
    /// is the sheet's per-file progress strip). 4 phases (mirrors
    /// ObsidianVaultBatchImportTests): 1. walk = recursive .md scan 2. dedup =
    /// cache diff (= skip already-imported) 3. route + enrich = concurrent LLM
    /// dispatch 4. write = branch on ImportDestination `onProgress` (=
    /// optional) is a `@Sendable` closure that the orchestrator invokes after
    /// each per-file state transition (= the sheet's progress strip +
    /// ProgressView reads from this closure; = the closure is invoked on the
    /// orchestrator's actor = the sheet must hop to `@MainActor` to update its
    /// `@State`). The closure receives the current task array (= the same array
    /// the method returns at the end; = the sheet can render the live progress
    /// strip directly from the closure's payload). The closure is called at the
    /// end of Phase 1 (walk), at the end of Phase 2 (dedup), at the end of
    /// Phase 4 (write) per file, and once at the end of the method.
    /// `extensions` (= optional, default `["md"]`) is the file-type filter the
    /// user picked in the import sheet (= the user's 2026-10-09 ask). The
    /// walker's `extensions` parameter accepts a `Set<String>` of lower-cased
    /// extensions (= the walker's source-of-truth is the
    /// `ImportFileType.extensions` property; = the orchestrator never
    /// hard-codes a single extension; = the walker's match site is a single
    /// `Set.contains(...)` call so a new file type is a one-line change at the
    /// enum definition).
    func importFiles(
        in sourceDir: URL,
        into target: ImportTarget,
        router: ImportRouter,
        onProgress: (@Sendable ([ImportTask]) async -> Void)? = nil,
        extensions: Set<String> = ["md"]
    ) async -> [ImportTask] {
        resetRollbackTrail()
        // Phase 1: walk.
        let mdFiles = ImportServiceFileSystem.walkSourceDir(sourceDir, extensions: extensions)
        var tasks = mdFiles.map { ImportTask(sourcePath: $0.path) }
        // Emit walk-phase progress so the sheet's ProgressView updates immediately (= the
        // user sees "找到 X 个 .md 文件" the instant the orchestrator finishes
        // Phase 1).
        await onProgress?(tasks)
                let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        let cache = ImportServiceCache.dedupAndHash(tasks: &tasks, cacheFile: cacheFile)
        // Filter out completed / skipped / failed; = the dispatch set is the remaining
        // tasks.
        let dispatchIndices = tasks.indices.filter {
            tasks[$0].state == .pending
        }
        // Phase 3: route + enrich (= concurrent, = 5-way parallel via a Semaphore-shaped
        // TaskGroup; = the actor's serialized state protects the cache write
        // back from races; = the sheet's ProgressView reads the per-task
        // `routing` state to drive the "进行中 N" live label, so we emit
        // `onProgress` after every state transition in this phase = the
        // sheet's `inFlightCount` ticks as tasks flip from .pending → .routing
        // and back to .routing → .writing on completion).
        let cacheBox = CacheBox(value: cache)
        let tasksBox = TasksBox(value: tasks)
        await runConcurrentPipeline(
            dispatchIndices: dispatchIndices,
            target: target,
            router: router,
            cacheBox: cacheBox,
            tasksBox: tasksBox,
            onProgress: onProgress
        )
        // Persist the updated cache (= the orchestrator re-reads the cache after each
        // successful write so concurrent imports don't lose entries; = the
        // actor's serialized state is the lock).
        ImportServiceCache.writeCache(cacheFile: cacheFile, cache: cacheBox.value)
        // Copy the per-task state back out of the shared box (= the TaskGroup's per-file
        // pipeline mutated `tasksBox.value` directly; = the orchestrator's
        // return value carries the canonical final-state view for the sheet's
        // per-file strip).
        return tasksBox.value
    }
    /// Reset the per-batch rollback trail at the start of every `importFiles`
    /// call (= the same actor can be re-used across multiple sheets, e.g. the
    /// cancel + "再次导入" retry path).
    // (resetRollbackTrail extracted to ImportServiceCancellation.swift in A57; = see that file)


    /// Snapshot the reference-library `entities.json` for the cancel handler to
    /// restore on rollback (= captures the file before any writeFile call has a
    /// chance to append to it; = a fresh library with no prior `entities.json`
    /// stores an empty-data sentinel = the cancel handler deletes the file
    /// outright).
    // (snapshotReferenceLibraryIndex extracted to ImportServiceCancellation.swift in A57; = see that file)
    // (runConcurrentPipeline extracted to ImportServiceConcurrency.swift in A71; = see that file)

    // (enqueueTask extracted to ImportServiceConcurrency.swift in A71; = see that file)

    // (makeProcessFileInput extracted to ImportServiceConcurrency.swift in A71; = see that file)

    // (dedupAndHash extracted to ImportServiceCache.swift in A62; = see that file)



    // (retryFailedTasksTitleOnly extracted to ImportServiceRetryEntry.swift in A74; = see that file)

    // (filterRetryCandidates extracted to ImportServiceDispatchHelpers.swift in A63; = see that file)
    // (selectRetryIndices extracted to ImportServiceRetryPipeline.swift in A72; = see that file)

    // (runRetryTaskGroup extracted to ImportServiceRetryPipeline.swift in A72; = see that file)

    // (makeTitleOnlyInput extracted to ImportServiceRetryPipeline.swift in A72; = see that file)

    // (stampRetriedHashes extracted to ImportServiceRetryPipeline.swift in A72; = see that file)

    // (titleOnlyBody extracted to ImportServiceTitleOnlyHelpers.swift in A64; = see that file)

    // (siblingContextMap extracted to ImportServiceTitleOnlyHelpers.swift in A64; = see that file)


    // (= boss 2026-10-10 (see OOB.md #2026-10-10) 件，自动跳过了" directive).
    /// Verify the cache entry's destination file still exists on disk. Returns
    /// `true` if the previous import's output is still there (= the cache entry
    /// is valid; = skip is safe); returns `false` if the destination file is
    /// gone (= the cache is stale; = re-import instead of skip). For the
    /// reference library: the destination file is
    /// `<wsRoot>/reference-library/entities/<uuid>.md` where `uuid =
    /// uuidFromHash(contentHash)` (= deterministic; = we can reconstruct the
    /// exact path from the cache entry's `contentHash`; = no need for the LLM's
    /// title). This is the boss's exact bug case (= cleared the ref lib's .md +
    /// entities.json but the cache remained; = the file existence check
    /// correctly returns false; = re-import). For a book folder: the
    /// destination file is
    /// `<shelves>/<shelfId>/books/<bookId>/<folder>/<basename>.md`
    /// where `basename = sanitizeFilename(LLM title)`. The cache does NOT store
    /// the LLM title. For the book case, the conservative check is the
    /// directory existence + non-empty (= at least one .md was previously
    /// imported; = the cache entry is likely valid; = the user can re-import
    /// individual files manually if they want). This is a soft signal (= the
    /// user can delete the cache to force a full re-import if needed). For
    /// unknown destination variants (= future enum cases): return `false` (=
    /// conservative; = don't skip; = re-import).
    private static func cachedDestinationExists(
        cached: CacheEntry,
        target: ImportTarget
    ) -> Bool {
        switch cached.destination {
        case .referenceLibrary:
            let uuid = ImportServiceHashing.uuidFromHash(cached.contentHash)
            let refMdURL = target.wsRoot
                .appendingPathComponent("reference-library")
                .appendingPathComponent("entities")
                .appendingPathComponent("\(uuid.uuidString).md")
            return FileManager.default.fileExists(atPath: refMdURL.path)
        case .bookFolder(let folder):
            guard let bookId = target.bookId,
                  let shelfId = target.shelfId else {
                return false
            }
            let folderURL = target.shelvesRoot
                .appendingPathComponent(shelfId.uuidString)
                .appendingPathComponent("books")
                .appendingPathComponent(bookId.uuidString)
                .appendingPathComponent(folder.directoryName)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: folderURL.path, isDirectory: &isDir
            ), isDir.boolValue else {
                return false
            }
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil
            )) ?? []
            return !contents.isEmpty
        }
    }

// (walkSourceDir extracted to ImportServiceFileSystem.swift in A58; = see that file)
// (= the 33-LOC file-system walker = recursive enumerator that filters by
// extension. The `private` qualifier was relaxed to internal; = required for
// the cross-file extension access.)

    // (readCache extracted to ImportServiceCache.swift in A62; = see that file)

    // (writeCache extracted to ImportServiceCache.swift in A62; = see that file)


    // (writeFile extracted to ImportServiceWriters.swift in A68; = see that file)

    // (writeToBookFolder extracted to ImportServiceWriters.swift in A68; = see that file)

    // (writeToReferenceLibrary extracted to ImportServiceWriters.swift in A68; = see that file)

    // (recordInCache extracted to ImportServiceDispatchHelpers.swift in A63; = see that file)
    // (writeExtraFile extracted to ImportServiceExtraFileWriter.swift in A66; = see that file)
    // (writeReference extracted to ImportServiceReferenceWriter.swift in A67; = see that file)

    // (sourceStringFromPath extracted to ImportServiceDispatchHelpers.swift in A63; = see that file)


    // MARK: - Errors

    /// errors (= thrown by writeFile when the orchestrator's processFile
    /// reaches a bookFolder write but the target's `bookId` / `shelfId` are
    /// nil; = a defensive guard for the boss's 2026-10-09 [archived-round] "强制让用户分开导入"
    /// directive; = the user pinned a book, the LLM overrode to
    /// .referenceLibrary in error, and the orchestrator's processFile would
    /// otherwise crash on a force-unwrap).
    enum ImportServiceError: Error, LocalizedError {
        case missingBookForBookFolderDestination
        /// (= boss 2026-10-10 (see OOB.md #2026-10-10) " 反馈). Sentinel error
        /// thrown by `writeFile` when the Phase 2 LLM content-same decision
        /// says "skip" (= the existing file already has the same content; = the
        /// orchestrator catches this sentinel and recognizes "the task was
        /// already marked .skipped" = no overwrite to .done; = the user sees
        /// "已跳过 - 内容相同" in the per-row result strip). The sentinel is NOT a
        /// real error (= the catch block checks for this specific case and
        /// treats it as the non-error "skip" path).
        case contentSameSkipped

        var errorDescription: String? {
            switch self {
            case .missingBookForBookFolderDestination:
                return "user pinned a book as the destination, but the import target has no bookId; = the orchestrator cannot resolve a book folder path"
            case .contentSameSkipped:
                return "sentinel (= the Phase 2 LLM content-same decision said skip; = the task is .skipped, not .failed)"
            }
        }
    }

    // (sha256 extracted to ImportServiceHashing.swift in A59; = see that file)

    // (uuidFromHash extracted to ImportServiceHashing.swift in A59; = see that file)

}

// (extracted to ImportServiceCancellation.swift in A55; = see that file)
// (= the cross-file `extension ImportService { ... cancel() ... rollback() ... }`
// = 77 LOC moved out of the main file. The `private` qualifiers on
// `isCancelled` + `writtenURLs` + `entitiesJSONSnapshot` were relaxed
// to internal; = required for the cross-file extension access.)

/// Reference-type wrapper around the dedup cache (= the per-file pipeline runs
/// 5 tasks in parallel via TaskGroup; = each task mutates the cache via
/// `writeFile(... cache: inout ...)`; = Swift 6 forbids capturing `inout`
/// across a TaskGroup boundary; = the canonical fix is a class that holds a
/// single shared dictionary the orchestrator can reach from any concurrent
/// context). Apple canonical pattern: a class-wrapper for cross-actor mutable
/// state (= the orchestrator's `writtenURLs` is a value-type `Array<URL>`
/// living on the actor itself; = the `cache` is a value-type `Dictionary` that
/// needs the same kind of "share-by-reference" treatment the test mocks get).
final class CacheBox: @unchecked Sendable {
    var value: [String: ImportService.CacheEntry]
    init(value: [String: ImportService.CacheEntry]) {
        self.value = value
    }
}

/// Reference-type wrapper around the per-task state array (= the per-file
/// pipeline runs 5 tasks in parallel via TaskGroup; = each task mutates
/// `tasksBox.value[i]` (= its own slot; = the mutation is safe because each
/// task only touches a disjoint index; = the shared `value` is read by the
/// orchestrator's TaskGroup loop for state-transition emits). Apple canonical
/// pattern: a class-wrapper for cross-actor mutable state (= the same trick the
/// `CacheBox` uses; = both the dedup cache + the per-task state array need the
/// reference-type wrapper because the per-file pipeline runs concurrently
/// across the 5 TaskGroup slots).
final class TasksBox: @unchecked Sendable {
    var value: [ImportTask]
    init(value: [ImportTask]) {
        self.value = value
    }
}
extension ImportService {
    // (processFile extracted to ImportServiceProcessFile.swift in A73; = see that file)


    // lastDispatchError is now stored on the actor (= extensions can't
    // hold stored properties; = it lives next to isCancelled / writtenURLs
    // / entitiesJSONSnapshot at the top of the actor).
    // (dispatchLLM extracted to ImportServiceLLMDispatch.swift in A69; = see that file)

    // (markLLMFailed extracted to ImportServiceLLMDispatch.swift in A69; = see that file)
    // (writeMainFileAndExtras extracted to ImportServiceMainFileWriter.swift in A70; = see that file)

    // (computeBodyToWrite extracted to ImportServiceBodyWriter.swift in A65; = see that file)
    // (writeOneExtraFile extracted to ImportServiceMainFileWriter.swift in A70; = see that file)
    // (appendActivity extracted to ImportServiceRetryEntry.swift in A74; = see that file)

}

extension ImportService {
    // (findEntityByTitle extracted to ImportServiceDedup.swift in A56; = see that file)

    // (normalizeTitle extracted to ImportServiceDedup.swift in A56; = see that file)

    // (sanitizeFilename extracted to ImportServiceDedup.swift in A56; = see that file)

}
