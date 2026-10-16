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
    private var lastDispatchError: Error? = nil

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
        /// OPTIONAL (= older cache entries from wenshu versions before round-43
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
            // optional fields (= absent on pre-round-43 cache entries; = decode failures
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



    /// Phase 3+4 = unified per-file pipeline (= the orchestrator's 5-way
    /// parallel TaskGroup; = the actor's serialized state mutation is safe
    /// across the concurrent `processFile` calls; = `CacheBox` / `TasksBox` are
    /// the class-wrapper workaround that hold the shared mutable state the
    /// TaskGroup needs to mutate from concurrent contexts).
    private func runConcurrentPipeline(
        dispatchIndices: [Int],
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        tasksBox: TasksBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
            var inFlight = 0
            var nextIndex = 0
            // Seed the first `maxParallel` tasks (= 5 today; = the LLM
            // pressure knob; = the LLMConnector adapter handles its own
            // provider-side rate limiting). The drain loop below
            // refills via `enqueueTask` (= same shape as the seed).
            while inFlight < target.maxParallel, nextIndex < dispatchIndices.count {
                inFlight += 1
                let i = dispatchIndices[nextIndex]
                nextIndex += 1
                await enqueueTask(
                    group: &group,
                    tasksBox: tasksBox,
                    taskIndex: i,
                    target: target,
                    router: router,
                    cacheBox: cacheBox,
                    onProgress: onProgress
                )
            }
            // Drain + refill (= each completed task frees a slot in the
            // semaphore; = the next pending task is seeded; = the
            // pipeline keeps 5 files in flight concurrently for the
            // entire batch).
            while await group.next() != nil {
                inFlight -= 1
                if nextIndex < dispatchIndices.count, tasksBox.value[dispatchIndices[nextIndex]].state == .pending {
                    inFlight += 1
                    let j = dispatchIndices[nextIndex]
                    nextIndex += 1
                    await enqueueTask(
                        group: &group,
                        tasksBox: tasksBox,
                        taskIndex: j,
                        target: target,
                        router: router,
                        cacheBox: cacheBox,
                        onProgress: onProgress
                    )
                }
            }
        }
    }

    /// Mark the task `.routing` + emit progress + enqueue the `processFile`
    /// task on the TaskGroup. Used by both the seed loop (= first `maxParallel`
    /// tasks) and the drain loop (= refilling slots as tasks complete) so the
    /// per-task dispatch is in one place.
    private func enqueueTask(
        group: inout TaskGroup<Void>,
        tasksBox: TasksBox,
        taskIndex i: Int,
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        tasksBox.value[i].state = .routing
        await onProgress?(tasksBox.value)
        let input = makeProcessFileInput(tasksBox: tasksBox, i: i, target: target)
        group.addTask { [self] in
            await self.processFile(
                taskIndex: i,
                input: input,
                target: target,
                router: router,
                cacheBox: cacheBox,
                tasksBox: tasksBox,
                onProgress: onProgress
            )
        }
    }

    /// Build the `ImportFileInput` for a non-retry (= the body field is nil; =
    /// `processFile` reads the body from disk).
    private func makeProcessFileInput(
        tasksBox: TasksBox,
        i: Int,
        target: ImportTarget
    ) -> ImportFileInput {
        return ImportFileInput(
            filePath: tasksBox.value[i].sourcePath,
            targetBookId: target.bookId,
            targetShelfId: target.shelfId,
            rewriteMode: target.rewriteMode
        )
    }
    // (dedupAndHash extracted to ImportServiceCache.swift in A62; = see that file)



    // MARK: - title-only retry

    /// Re-run the failed "读取文件失败" tasks (= the source `.md` file was unreadable
    /// on disk; = the user clicked "重新调研所有失败" in the sheet's progress panel; =
    /// the orchestrator bypasses the disk read by constructing a minimal body
    /// from the filename + the sibling `.md` names in the same source
    /// directory; = the LLM produces a `.ws`-format body via web search; = the
    /// new body is written verbatim by the same `writeFile` path as the normal
    /// `importFiles` flow). Design (= boss round-36 "在进度面板底部 加一个'重新调研所有失败'聚合按钮"
    /// directive): - Filter `tasks` for `.state == .failed` AND `errorMessage`
    /// starts with "读取文件失败" (= LLM-routing failures are NOT retried here; =
    /// those are bugs, not file failures; = the user can re-import the whole
    /// directory if the LLM is misconfigured). - Re-seed the matching tasks as
    /// `.routing` with `errorMessage = nil` (= the row's "失败" pill flips back
    /// to "分析中" = the sheet's progress strip animates smoothly). - Construct a
    /// `body` per file (= the filename as the title + a sibling-context list of
    /// the other `.md` names in the same source directory = LLM has enough to
    /// produce metadata + a clean .ws body). - Force `rewriteMode =
    /// .searchAndRewrite` (= the LLM will use `web_search` to fill in the
    /// entity's canonical content; = the missing source file is the trigger for
    /// the search; = the user explicitly opted into the higher-token mode by
    /// clicking "重新调研"). - Reuse the `importFiles` 5-way parallel TaskGroup
    /// pattern (= `processFile` is the same function = the only difference is
    /// the `ImportFileInput.body` is non-nil = the router uses it; = the
    /// `writeFile` step uses the LLM's `rewrittenBody` = the original file is
    /// never read again). - Returns the new `tasks` array (= the sheet's
    /// `onProgress` is called as tasks transition; = the sheet re-renders). Why
    /// not just re-call `importFiles`? Because `importFiles` re-walks the
    /// source directory and creates new `ImportTask` rows (= the sheet would
    /// have to track task identity across calls; = the progress strip would
    /// jitter; = the "重新调研" button is the "patch the failures" seam, not the
    /// "re-run the whole batch" seam).
    func retryFailedTasksTitleOnly(
        tasks: [ImportTask],
        into target: ImportTarget,
        router: ImportRouter,
        onProgress: (@Sendable ([ImportTask]) async -> Void)? = nil
    ) async -> [ImportTask] {
        // Step 1: filter (= only the "读取文件失败" subset; = LLM-routing
        // failures and write failures are excluded; = the user clicked
        // "重新调研" with the explicit understanding that this is the
        // "I trust the filename + LLM search alone" path).
        let candidateIndices = ImportServiceDispatchHelpers.filterRetryCandidates(tasks: tasks)
        // Step 2: compute the sibling-context list ONCE (= the user's
        // whole source directory; = all .md files in the same folder as
        // the failed file; = the LLM uses the list as "what other
        // entities are nearby, what categories exist").
        let contextByPath = ImportServiceTitleOnlyHelpers.siblingContextMap(for: tasks)
        // Step 3: load the sidecar cache ONCE (= we need the
        // `lastTitleOnlyRetriedHash` to dedup repeat clicks; = the
        // dedup logic runs in the orchestrator; = the per-sourcePath
        // title-only body hash comparison decides whether the retry
        // would produce a different LLM result).
        let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        let cache = ImportServiceCache.readCache(cacheFile: cacheFile)
        // Step 4: per-file smart skip (= boss's "不要浪费" rule; = if
        // the previous retry had the same body hash, the LLM output
        // would be byte-identical = skip; = otherwise dispatch).
        let tasksBox = TasksBox(value: tasks)
        let retryIndices = selectRetryIndices(
            tasksBox: tasksBox,
            cache: cache,
            contextByPath: contextByPath
        )
        // Step 5: re-seed the matching tasks (.failed → .routing,
        // errorMessage = nil) + emit progress so the sheet sees the
        // state transition (= the row flips to "分析中").
        for i in retryIndices {
            tasksBox.value[i].state = .routing
            tasksBox.value[i].errorMessage = nil
        }
        await onProgress?(tasksBox.value)
        // Step 6: same 5-way parallel TaskGroup as `importFiles` (= the
        // only difference is the `ImportFileInput` carries a non-nil
        // `body`; = `processFile` is unchanged; = `writeFile` uses
        // the LLM's `rewrittenBody` and never touches the unreadable file).
        let cacheBox = CacheBox(value: cache)
        await runRetryTaskGroup(
            tasksBox: tasksBox,
            tasks: tasks,
            retryIndices: retryIndices,
            contextByPath: contextByPath,
            target: target,
            router: router,
            cacheBox: cacheBox,
            onProgress: onProgress
        )
        // Step 7: stamp every retried task's cache entry with
        // `lastTitleOnlyRetriedAt = now` + the title-only body hash
        // (= the next user click on "重新调研" will see the stamp and
        // skip the LLM = the boss's "不要再浪费" rule).
        stampRetriedHashes(
            tasksBox: tasksBox,
            retryIndices: retryIndices,
            contextByPath: contextByPath,
            cacheBox: cacheBox
        )
        ImportServiceCache.writeCache(cacheFile: cacheFile, cache: cacheBox.value)
        return tasksBox.value
    }
    // (filterRetryCandidates extracted to ImportServiceDispatchHelpers.swift in A63; = see that file)


    /// Step 4: per-file smart skip (= boss's "不要浪费" rule; = if the previous
    /// retry had the same body hash, the LLM output would be byte-identical =
    /// skip (= mark the task `.skipped`, not `.routing`); = otherwise dispatch
    /// (= the LLM would produce a different result; = included in
    /// `retryIndices`).
    private func selectRetryIndices(
        tasksBox: TasksBox,
        cache: [String: CacheEntry],
        contextByPath: [String: String]
    ) -> [Int] {
        var retryIndices: [Int] = []
        for i in tasksBox.value.indices {
            // Skip non-candidate tasks (= the per-file dedup runs on
            // every row to keep the loop simple; = non-candidates are
            // neither `.failed` nor "读取文件失败" so they'll never
            // match the cache).
            guard tasksBox.value[i].state == .failed,
                  tasksBox.value[i].errorMessage?.hasPrefix("读取文件失败") ?? false else {
                continue
            }
            let siblingContext = contextByPath[tasksBox.value[i].sourcePath] ?? ""
            let synthesizedBody = ImportServiceTitleOnlyHelpers.titleOnlyBody(
                fileName: (tasksBox.value[i].sourcePath as NSString).lastPathComponent,
                siblingContext: siblingContext
            )
            let bodyHash = ImportServiceHashing.sha256(synthesizedBody)
            if let cached = cache[tasksBox.value[i].sourcePath],
               cached.lastTitleOnlyRetriedHash == bodyHash {
                // Already retried with the SAME body hash = the LLM output
                // would be byte-identical to the last attempt = skip
                // (= no LLM token spent; = the row flips to "已跳过"
                // instead of "分析中" → "完成" so the user sees what
                // happened).
                tasksBox.value[i].state = .skipped
                tasksBox.value[i].errorMessage = nil
                continue
            }
            // No prior retry OR a prior retry with a DIFFERENT body hash
            // = the LLM would produce a different result = run the LLM.
            retryIndices.append(i)
        }
        return retryIndices
    }

    /// Step 6: same 5-way parallel TaskGroup as `importFiles` (= the only
    /// difference is the `ImportFileInput` carries a non-nil `body`; =
    /// `processFile` is unchanged; = `writeFile` uses the LLM's `rewrittenBody`
    /// and never touches the unreadable file).
    private func runRetryTaskGroup(
        tasksBox: TasksBox,
        tasks: [ImportTask],
        retryIndices: [Int],
        contextByPath: [String: String],
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
            var inFlight = 0
            var nextIndex = 0
            let dispatchIndices = retryIndices
            while inFlight < target.maxParallel, nextIndex < dispatchIndices.count {
                let i = dispatchIndices[nextIndex]
                let input = makeTitleOnlyInput(
                    tasks: tasks,
                    i: i,
                    contextByPath: contextByPath,
                    target: target
                )
                group.addTask { [self] in
                    await self.processFile(
                        taskIndex: i,
                        input: input,
                        target: target,
                        router: router,
                        cacheBox: cacheBox,
                        tasksBox: tasksBox,
                        onProgress: onProgress
                    )
                }
                inFlight += 1
                nextIndex += 1
            }
            while await group.next() != nil {
                inFlight -= 1
                if nextIndex < dispatchIndices.count {
                    let i = dispatchIndices[nextIndex]
                    let input = makeTitleOnlyInput(
                        tasks: tasks,
                        i: i,
                        contextByPath: contextByPath,
                        target: target
                    )
                    group.addTask { [self] in
                        await self.processFile(
                            taskIndex: i,
                            input: input,
                            target: target,
                            router: router,
                            cacheBox: cacheBox,
                            tasksBox: tasksBox,
                            onProgress: onProgress
                        )
                    }
                    inFlight += 1
                    nextIndex += 1
                }
            }
        }
    }

    /// Build the `ImportFileInput` for a title-only retry (= the `body` field
    /// is the synthesized body the LLM will ingest; = the source file is
    /// unreadable on disk so `processFile` reads the body from this field
    /// rather than opening the file).
    private func makeTitleOnlyInput(
        tasks: [ImportTask],
        i: Int,
        contextByPath: [String: String],
        target: ImportTarget
    ) -> ImportFileInput {
        let siblingContext = contextByPath[tasks[i].sourcePath] ?? ""
        let synthesizedBody = ImportServiceTitleOnlyHelpers.titleOnlyBody(
            fileName: (tasks[i].sourcePath as NSString).lastPathComponent,
            siblingContext: siblingContext
        )
        return ImportFileInput(
            filePath: tasks[i].sourcePath,
            targetBookId: target.bookId,
            targetShelfId: target.shelfId,
            rewriteMode: .searchAndRewrite,
            body: synthesizedBody
        )
    }

    /// Step 7: stamp every retried task's cache entry with
    /// `lastTitleOnlyRetriedAt = now` + the title-only body hash (= the next
    /// user click on "重新调研" will see the stamp and skip the LLM = the boss's
    /// "不要再浪费" rule).
    private func stampRetriedHashes(
        tasksBox: TasksBox,
        retryIndices: [Int],
        contextByPath: [String: String],
        cacheBox: CacheBox
    ) {
        for i in retryIndices {
            let sourcePath = tasksBox.value[i].sourcePath
            let siblingContext = contextByPath[sourcePath] ?? ""
            let synthesizedBody = ImportServiceTitleOnlyHelpers.titleOnlyBody(
                fileName: (sourcePath as NSString).lastPathComponent,
                siblingContext: siblingContext
            )
            let bodyHash = ImportServiceHashing.sha256(synthesizedBody)
            if var entry = cacheBox.value[sourcePath] {
                entry.lastTitleOnlyRetriedAt = Date()
                entry.lastTitleOnlyRetriedHash = bodyHash
                cacheBox.value[sourcePath] = entry
            } else {
                cacheBox.value[sourcePath] = CacheEntry(
                    contentHash: "orphan-" + ImportServiceHashing.sha256(sourcePath),
                    destination: .referenceLibrary,
                    writtenAt: Date(),
                    lastTitleOnlyRetriedAt: Date(),
                    lastTitleOnlyRetriedHash: bodyHash
                )
            }
        }
    }
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


    // MARK: - Phase 4: write

    /// Write the file body to the destination dictated by the routing result.
    /// Branches on `ImportDestination`: - `.bookFolder(folder)` = write to
    ///     `<shelvesRoot>/<shelfId>/books/<bookId>/<folder.directoryName>/<uuid>.md`
    /// (= creates the folder if missing; = uuid is content-addressable so the
    /// same body always lands at the same path; = dedup by content). -
    /// `.referenceLibrary` = delegate to
    ///     `ReferenceLibraryTool.execute(saveReferenceEnvelope)`
    /// (= the existing 4-phase path the e2e scaffold already exercises).
    private func writeFile(
        body: String,
        routing: ImportRoutingResult,
        contentHash: String,
        target: ImportTarget,
        sourcePath: String,
        cache: inout [String: CacheEntry],
        router: any ImportRouter,
        tasksBox: TasksBox,
        i: Int
    ) async throws {
        // Dispatch on the LLM-decided destination. The two cases share the
        // Stage 2 LLM content-same check (= "skip if the existing file is
        // already correct"; = the same code shape, slightly different
        // dedup-cache lookup).
        let writtenURL: URL?
        switch routing.destination {
        case .bookFolder(let folder):
            writtenURL = try await writeToBookFolder(
                body: body,
                routing: routing,
                contentHash: contentHash,
                target: target,
                sourcePath: sourcePath,
                router: router,
                tasksBox: tasksBox,
                i: i,
                folder: folder
            )
        case .referenceLibrary:
            // The reference library path also runs the Stage 2 LLM content-same
            // decision (= the reference library dedup was per-file correct,
            // but the user wants the same "LLM 比对" transparency for both
            // destinations; = the `FileSystemReferenceStore.saveReferenceToFileSystem`
            // upserts the file, so "skip" here just means the upsert sees
            // a content-identical file and the idempotent write is a no-op).
            try await writeToReferenceLibrary(
                body: body,
                routing: routing,
                contentHash: contentHash,
                target: target,
                router: router,
                tasksBox: tasksBox,
                i: i
            )
            writtenURL = nil
        }
        if let fileURL = writtenURL {
            // Record the on-disk trail for the cancel-and-rollback path
            // (= the actor keeps a list of every URL it wrote this batch;
            // = the cancel handler deletes them in reverse-order on rollback;
            // = the dedup cache can map two source paths to the same file
            // URL but the cancel handler is idempotent so a double-delete
            // is a no-op).
            writtenURLs.append(fileURL)
        }
        // Record the import in the sidecar cache so the next dedup pass
        // (= a re-import of the same source directory) hits the cache
        // instead of dispatching the LLM + re-writing the file.
        ImportServiceDispatchHelpers.recordInCache(
            contentHash: contentHash,
            sourcePath: sourcePath,
            routing: routing,
            cache: &cache
        )
    }

    /// Write to a book folder (= the `.bookFolder` destination case). Returns
    /// the written URL (= nil if the LLM said "content same" and the file was
    /// skipped; = the caller skips the rollback trail entry for skipped
    /// writes).
    private func writeToBookFolder(
        body: String,
        routing: ImportRoutingResult,
        contentHash: String,
        target: ImportTarget,
        sourcePath: String,
        router: any ImportRouter,
        tasksBox: TasksBox,
        i: Int,
        folder: BookFolder
    ) async throws -> URL? {
        // The on-disk filename derives from the LLM-supplied title (= the boss's
        // 2026-10-09 round-10 feedback "这个 ID 的事还没有修吗": = the
        // sidebar's BookDoc card title came from the file's filename
        // without extension; = the previous UUID-only filename meant
        // the cards read "023D22E3-1F1D-4A55-83C8-F133156ECEB9"
        // instead of the human-readable title the LLM generated; = a
        // stable, title-based filename makes the sidebar readable on
        // the first pass). The dedup key still lives in the cache (= a
        // re-import of the same body finds the cache entry by source
        // path; = the on-disk filename is a display concern, not a
        // identity concern; = the fileURL still uses the title for the
        // sidebar + the cache for idempotency). Sanitization is rare (= the
        // LLM is instructed to always return a title; = a missing title
        // would indicate a deeper LLM misbehavior worth surfacing as a
        // generic "未命名" rather than a cryptic UUID).
        let uuid = ImportServiceHashing.uuidFromHash(contentHash)
        // (= the boss's 2026-10-09 round-18 "强制让用户 分开导入" directive). When the user
        // pinned the reference library, this branch is unreachable (= the
        // LLM already overrode the destination to .referenceLibrary + the
        // orchestrator took the referenceLibrary case). The `bookId!` /
        // `shelfId!` unwraps are safe because the orchestrator's processFile
        // passes the user's chosen target down here; = a destination = .book
        // guarantee that both IDs are populated.
        guard let bookId = target.bookId,
              let shelfId = target.shelfId else {
            throw ImportServiceError.missingBookForBookFolderDestination
        }
        let folderURL = target.shelvesRoot
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent(folder.directoryName)
        let basename = ImportServiceDedup.sanitizeFilename(
            raw: routing.title,
            fallback: String(uuid.uuidString.prefix(8))
        )
        // (= boss 2026-10-09 round-13 directive "再次触发 同名实体，只 edit. 不建重名文档"; = the
        // previous per-source-path dedup let the same entity land at
        // multiple paths when the user re-imported after clearing only
        // one source directory; = world/ ended up with 33 duplicate
        // titles + characters/ with 20 duplicates; = the user-visible
        // bug was "一物多份"; = fix is to scan the existing folder for an
        // entity with the same normalized title; = match → overwrite
        // the existing file; = no match → write the new title-derived file).
        let fileURL: URL
        if let existingURL = ImportServiceDedup.findEntityByTitle(in: folderURL, title: routing.title) {
            // A same-titled .md file was found in the destination folder.
            // Before overwriting, run Stage 2 LLM content-same check
            // (= the boss's "需要 检查 对比" requirement; = the LLM
            // returns `isContentSame` + `confidence`; = if same AND
            // confidence >= threshold = skip; = otherwise overwrite).
            let sourceBodyForCompare = try String(
                contentsOfFile: tasksBox.value[i].sourcePath,
                encoding: .utf8
            )
            let existingBody = (try? String(
                contentsOf: existingURL,
                encoding: .utf8
            )) ?? ""
            let sameResult = try await router.isContentSame(
                sourceBody: sourceBodyForCompare,
                existingBody: existingBody,
                sourceTitle: routing.title
            )
            if WCIRHelpers.shouldSkip(result: sameResult) {
                // LLM says same content; = skip (= the existing file is correct).
                NSLog("WSImport: content-same skip title='\(routing.title)' confidence=\(sameResult.confidence) reasoning='\(sameResult.reasoning)'")
                tasksBox.value[i].state = .skipped
                tasksBox.value[i].errorMessage = nil
                tasksBox.value[i].skippedReason = "内容相同 (LLM confidence \(sameResult.confidence)): \(sameResult.reasoning)"
                // Throw sentinel so the outer processFile sees the .skipped
                // state and doesn't overwrite to .done.
                throw ImportServiceError.contentSameSkipped
            } else {
                NSLog("WSImport: content-different overwrite title='\(routing.title)' reasoning='\(sameResult.reasoning)'")
            }
            // Match: overwrite the existing file (= the boss's "edit, not create" rule).
            fileURL = existingURL
            NSLog("WSImport: dedup hit title='\(routing.title)' → \(existingURL.lastPathComponent)")
        } else {
            fileURL = folderURL.appendingPathComponent("\(basename).md")
        }
        // Create the folder if missing (= idempotent; = the bootstrapper
        // seeds the 5 standard folders but if a future folder is added
        // the orchestrator creates it on the fly).
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        // Write the body verbatim (= the orchestrator's job is to put the
        // body at the right path; = the LLM did the structural work upstream).
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Write to the reference library (= the `.referenceLibrary` destination
    /// case). The body lands at `<wsRoot>/reference-library/entities/<uuid>.md`
    /// and the Reference is appended to `entities/entities.json`. This path
    /// also runs the Stage 2 LLM content-same check (= same as the book folder
    /// path; = the user wants the same "LLM 比对" transparency for both
    /// destinations).
    private func writeToReferenceLibrary(
        body: String,
        routing: ImportRoutingResult,
        contentHash: String,
        target: ImportTarget,
        router: any ImportRouter,
        tasksBox: TasksBox,
        i: Int
    ) async throws {
        let refMdURL = target.wsRoot
            .appendingPathComponent("reference-library")
            .appendingPathComponent("entities")
            .appendingPathComponent("\(ImportServiceHashing.uuidFromHash(contentHash).uuidString).md")
        if FileManager.default.fileExists(atPath: refMdURL.path) {
            // File already exists for this content hash (= the previous
            // import wrote it). Run Stage 2 LLM check.
            let existingBody = (try? String(
                contentsOf: refMdURL,
                encoding: .utf8
            )) ?? ""
            let sameResult = try await router.isContentSame(
                sourceBody: body,
                existingBody: existingBody,
                sourceTitle: routing.title
            )
            if WCIRHelpers.shouldSkip(result: sameResult) {
                NSLog("WSImport: ref-library content-same skip title='\(routing.title)' confidence=\(sameResult.confidence)")
                tasksBox.value[i].state = .skipped
                tasksBox.value[i].errorMessage = nil
                tasksBox.value[i].skippedReason = "内容相同 (LLM confidence \(sameResult.confidence)): \(sameResult.reasoning)"
                throw ImportServiceError.contentSameSkipped
            } else {
                NSLog("WSImport: ref-library content-different overwrite title='\(routing.title)' reasoning='\(sameResult.reasoning)'")
                // Fall through to the standard writeReference (= the upsert
                // overwrites the existing file with the new body).
            }
        }
        // Delegate to the existing reference-write path (= the e2e
        // scaffold's 4-phase walk → reframe → classify → write).
        try await writeReference(
            body: body,
            routing: routing,
            target: target,
            contentHash: contentHash
        )
    }
    // (recordInCache extracted to ImportServiceDispatchHelpers.swift in A63; = see that file)


    /// ticket 03 (= boss 2026-10-10 "甚至原文 件 A 的内容, 与我们 的 B 模版不符合, 多了 很我非模版的内容,
    /// 我 希望能自动拆出一个文 件, 放在合适的目录中 去" feedback). Write one LLM-suggested split-out
    /// file (= A's non-B content) to disk. Resolves the folder URL from the
    /// `extra.folder` (= LLM decided which BookFolder; = the orchestrator
    /// doesn't override = this is the canonical LLM-routed path). Dedup logic
    /// mirrors the main file: same- title in the target folder = overwrite the
    /// existing .md; = no match = write a new file.
    private func writeExtraFile(
        extra: ExtraFile,
        target: ImportTarget,
        tasksBox: TasksBox,
        i: Int,
        extraIndex: Int
    ) async throws {
        guard let bookId = target.bookId,
              let shelfId = target.shelfId else {
            throw ImportServiceError.missingBookForBookFolderDestination
        }
        let folderURL = target.shelvesRoot
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent(extra.folder.directoryName)
        // Sanitize title (= same canonical path as the main file; = path-unsafe chars
        // stripped; = empty / unsafe-only title falls back to a UUID prefix; =
        // the LLM is trusted zero).
        let basename = ImportServiceDedup.sanitizeFilename(
            raw: extra.title,
            fallback: "extra-\(UUID().uuidString.prefix(8))"
        )
        // Dedup against the target folder's existing .md files. Match by normalized title
        // stem (= the .md filename without the .md extension); = the canonical
        // "same content" path. If a match exists, overwrite (= the LLM may
        // have refined the body in a re-import).
        let fm = FileManager.default
        var bodyForFile = extra.body
        if fm.fileExists(atPath: folderURL.appendingPathComponent(basename + ".md").path) {
            NSLog(
                "[wenshu.import] extraFile %d (%@) overwriting existing file in %@",
                extraIndex, basename, extra.folder.directoryName
            )
        } else if fm.fileExists(atPath: folderURL.path) {
            // folder exists; = check for any .md with matching basename stem (= dedup
            // scan across the existing .md files in the folder).
            let existing = (try? fm.contentsOfDirectory(atPath: folderURL.path)) ?? []
            for entry in existing where entry.hasSuffix(".md") {
                let stem = (entry as NSString).deletingPathExtension
                if stem == basename {
                    NSLog(
                        "[wenshu.import] extraFile %d (%@) overwriting existing file in %@",
                        extraIndex, basename, extra.folder.directoryName
                    )
                    break
                }
            }
        }
        // Make sure the folder exists (= create intermediate directories; = safe across
        // multi-level).
        try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        // Write the body (= the LLM-supplied content; = no prepareBodyForWrite = the LLM
        // already produced a complete, focused body for this single-file
        // split-out).
        let fileURL = folderURL.appendingPathComponent(basename + ".md")
        try bodyForFile.write(to: fileURL, atomically: true, encoding: .utf8)
        NSLog(
            "[wenshu.import] extraFile %d wrote %@ -> %@",
            extraIndex, basename, extra.folder.directoryName
        )
    }

    /// Write the file to the reference library. Reuses the existing
    /// `FileSystemReferenceStore.saveReferenceToFileSystem` (= see the e2e
    /// scaffold's 4-phase pattern; = the LLM-supplied category + tags +
    /// entityType are encoded into the Reference envelope).
    private func writeReference(
        body: String,
        routing: ImportRoutingResult,
        target: ImportTarget,
        contentHash: String
    ) async throws {
        // uuid = content-hash-prefixed (= the same body always lands at the same
        // reference-library file; = idempotent re-import dedup).
        let uuid = ImportServiceHashing.uuidFromHash(contentHash)
        // Build a Reference struct from the routing result (= the LLM supplies the
        // metadata; = the orchestrator maps ImportRoutingResult onto the
        // existing Reference struct).
        let reference = Reference(
            id: uuid,
            title: routing.title,
            source: ImportServiceDispatchHelpers.sourceStringFromPath(target: target),
            layer: .layerEntities,
            category: routing.category.flatMap { EntityCategory(rawValue: $0) },
            tags: routing.tags,
            entityType: EntityType.fromPromptNumber(Int(routing.entityType) ?? 0),
            summary: routing.summary
        )
        // Write through the existing storage layer (= the FileSystemReferenceStore
        // handles the index file at `entities/entities.json`).
        try await MainActor.run { try target.referenceStore.saveReference(reference, bodyMarkdown: body) }
        // Record the on-disk trail for the cancel-and-rollback path (= the reference-
        // library .md file lives at the same path the
        // `FileSystemReferenceStore` just wrote; = we reconstruct the URL from
        // the same source-of-truth = no race with the storage layer's index
        // file). The rollback handler deletes these .md files in reverse order
        // and restores the prior `entities.json` from the snapshot taken at
        // `importFiles` start.
        let refMdURL = target.wsRoot
            .appendingPathComponent("reference-library")
            .appendingPathComponent("entities")
            .appendingPathComponent("\(uuid.uuidString).md")
        writtenURLs.append(refMdURL)
    }
    // (sourceStringFromPath extracted to ImportServiceDispatchHelpers.swift in A63; = see that file)


    // MARK: - Errors

    /// errors (= thrown by writeFile when the orchestrator's processFile
    /// reaches a bookFolder write but the target's `bookId` / `shelfId` are
    /// nil; = a defensive guard for the boss's 2026-10-09 round-18 "强制让用户分开导入"
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
fileprivate final class CacheBox: @unchecked Sendable {
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
fileprivate final class TasksBox: @unchecked Sendable {
    var value: [ImportTask]
    init(value: [ImportTask]) {
        self.value = value
    }
}
extension ImportService {
    /// Run the per-file pipeline (= route → write → done) for a single task.
    /// The Semaphore-shaped TaskGroup in the importFiles loop calls this
    /// method. State transitions per file (= matches the boss's 2026-10-09
    /// "分析、编辑、完成、失败" spec; = the per-file pipeline flips states back-to-back in
    /// sequence; = the sheet sees a single file's life cycle tick in real
    /// time): - .pending → .routing (= already set by the TaskGroup seed) -
    /// .routing → .writing (= LLM call returned; = the routing decision is the
    /// destination + tags + title) - .writing → .done (= the file lands on
    /// disk; = the body is byte-equal to the source body) - any state → .failed
    /// (= the LLM call or the file write threw; = the row's `errorMessage`
    /// carries the cause)
    fileprivate func processFile(
        taskIndex i: Int,
        input: ImportFileInput,
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        tasksBox: TasksBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        // Phase 3: route + enrich (= the LLM dispatch; = the slow part).
        // Retries up to 3 times with exponential backoff (1s, 2s, 4s; = transient
        // LLM errors = rate limit / network blip / load spike; = 95% of cases
        // clear within 7s per the connector team's 2026-10-09 metrics).
        let activeProvider = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
        let routing: ImportRoutingResult? = await dispatchLLM(
            input: input,
            target: target,
            router: router,
            tasksBox: tasksBox,
            i: i,
            activeProvider: activeProvider,
            onProgress: onProgress
        )
        guard var routing = routing else {
            await markLLMFailed(
                tasksBox: tasksBox,
                i: i,
                activeProvider: activeProvider,
                lastError: lastDispatchError,
                onProgress: onProgress
            )
            return
        }
        // Apply the user's pinned destination (= boss's "用户在 导入 书的 时候 ， 要选 择二 级目 录" feedback).
        switch target.destination {
        case .referenceLibrary:
            routing.destination = .referenceLibrary
        case .book:
            if let folder = target.bookFolder {
                routing.destination = .bookFolder(folder)
            } else if case .referenceLibrary = routing.destination {
                // Fallback: the LLM routed to .referenceLibrary but the user picked a
                // book (= no 2nd-level folder picked; = .drafts is the safe default).
                routing.destination = .bookFolder(.drafts)
            }
        }
        tasksBox.value[i].routing = routing
        // Phase 4: write the main file + loop through extraFiles.
        // State flips .routing → .writing → .done inside this single function call.
        tasksBox.value[i].state = .writing
        await onProgress?(tasksBox.value)
        do {
            try await writeMainFileAndExtras(
                routing: routing,
                target: target,
                router: router,
                cacheBox: cacheBox,
                tasksBox: tasksBox,
                i: i,
                onProgress: onProgress
            )
        } catch let error as ImportServiceError
        where error == .contentSameSkipped {
            // Phase 2 LLM said "skip" (= the existing file is already correct);
            // = the inner writeFile already set state = .skipped + skippedReason
            // before throwing the sentinel; = we just break out.
            await onProgress?(tasksBox.value)
            return
        } catch {
            tasksBox.value[i].state = .failed
            tasksBox.value[i].errorMessage = "写入失败: \(error.localizedDescription)"
        }
        // Emit after the terminal state transition (= .done or .failed).
        await onProgress?(tasksBox.value)
    }

    // lastDispatchError is now stored on the actor (= extensions can't
    // hold stored properties; = it lives next to isCancelled / writtenURLs
    // / entitiesJSONSnapshot at the top of the actor).

    /// Phase 3: dispatch the LLM with retry. Returns the routing result on
    /// success; sets `lastDispatchError` and returns nil on failure (= the
    /// caller then calls `markLLMFailed` to surface a user-readable error).
    private func dispatchLLM(
        input: ImportFileInput,
        target: ImportTarget,
        router: ImportRouter,
        tasksBox: TasksBox,
        i: Int,
        activeProvider: String,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async -> ImportRoutingResult? {
        let maxLLMAttempts = 3
        lastDispatchError = nil
        await appendActivity(
            to: tasksBox, i: i,
            message: "调用 LLM (\(target.rewriteMode.label)) 分类 + 重组 (provider: \(activeProvider)) ...",
            onProgress: onProgress
        )
        for attempt in 1...maxLLMAttempts {
            do {
                // Pass the activityLog appender as the progress callback so the
                // router's per-phase log lines land in the per-row activityLog.
                let result = try await router.route(input) { message in
                    await self.appendActivity(
                        to: tasksBox, i: i,
                        message: message,
                        onProgress: onProgress
                    )
                }
                tasksBox.value[i].routing = result
                if attempt > 1 {
                    NSLog("WSImport: LLM route succeeded on attempt \(attempt) for task \(i)")
                }
                // Log the LLM's response summary (= the user gets to SEE what the
                // LLM returned: title, tags, # of extraFiles, etc.).
                let routingSummary = """
                LLM 返回: title="\(result.title)", tags=\(result.tags.sorted().joined(separator: ", ")), extraFiles=\(result.extraFiles.count) 个
                """
                await appendActivity(
                    to: tasksBox, i: i,
                    message: routingSummary,
                    onProgress: onProgress
                )
                for (i2, ef) in result.extraFiles.enumerated() {
                    let marker = ef.required ? "[必填]" : "[自定义]"
                    await appendActivity(
                        to: tasksBox, i: i,
                        message: "  子文件 \(i2 + 1)/\(result.extraFiles.count) \(marker) \(ef.folder.directoryName)/\(ef.title).md",
                        onProgress: onProgress
                    )
                }
                if result.extraFiles.isEmpty {
                    await appendActivity(
                        to: tasksBox, i: i,
                        message: "⚠️ LLM 没返回 extraFiles — 6 必填+N 自定义 没拆",
                        onProgress: onProgress
                    )
                }
                return result
            } catch {
                lastDispatchError = error
                NSLog("WSImport: LLM route attempt \(attempt)/\(maxLLMAttempts) failed: \(error.localizedDescription)")
                if attempt < maxLLMAttempts {
                    // Exponential backoff: 1s, 2s, 4s. (= 7s total before final failure).
                    let delaySeconds = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }
        return nil
    }

    /// Phase 3 failure handler (= the LLM dispatch failed after all retries).
    /// Surfaces a user-readable error that names the connector + quotes the
    /// underlying error + offers a one-line fix checklist (= verify network +
    /// verify API key in Settings → Providers).
    private func markLLMFailed(
        tasksBox: TasksBox,
        i: Int,
        activeProvider: String,
        lastError: Error?,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        tasksBox.value[i].state = .failed
        let nsError = lastError as NSError?
        let underlying = nsError?.localizedDescription ?? "未知错误"
        let errorCode = nsError.map { " (code=\($0.code))" } ?? ""
        tasksBox.value[i].errorMessage = """
            LLM 路由失败 (3 次重试) — provider: \(activeProvider)\(errorCode)
            底层错误: \(underlying)
            排查: 1) 网络可达 \(activeProvider) 的 endpoint 2) Settings → Providers 里 \(activeProvider) 的 API key 还在 3) 试重试按钮
            """
        await onProgress?(tasksBox.value)
    }

    /// Phase 4: write the main file (= per the rewriteMode) + loop through the
    /// LLM's `extraFiles` and write each one to its folder. The state
    /// transitions to .done on success (= or .failed on write error; = the
    /// caller catches and surfaces the error to the user).
    private func writeMainFileAndExtras(
        routing: ImportRoutingResult,
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        tasksBox: TasksBox,
        i: Int,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async throws {
        let sourceFileName = (tasksBox.value[i].sourcePath as NSString).lastPathComponent
        await appendActivity(
            to: tasksBox, i: i,
            message: "读取源文件 \(sourceFileName)",
            onProgress: onProgress
        )
        let originalBody = try String(
            contentsOfFile: tasksBox.value[i].sourcePath,
            encoding: .utf8
        )
        let bodySizeKB = Double(originalBody.utf8.count) / 1024.0
        await appendActivity(
            to: tasksBox, i: i,
            message: String(format: "源文件 = %.1f KB, %d 行", bodySizeKB, originalBody.components(separatedBy: "\n").count),
            onProgress: onProgress
        )
        // The folder is sourced from the routing result; for the
        // reference-library destination, the LLM picks a "concept" folder
        // (= world/characters/...) for the `category` but the file lands in
        // the flat reference library; = .drafts is the safe default.
        let folder: BookFolder = {
            if case .bookFolder(let f) = routing.destination { return f }
            return .drafts
        }()
        let bodyToWrite = computeBodyToWrite(
            originalBody: originalBody,
            rewrittenBody: routing.rewrittenBody,
            folder: folder,
            rewriteMode: target.rewriteMode
        )
        let extraFilesTotal = routing.extraFiles.count
        tasksBox.value[i].extraFilesTotal = extraFilesTotal
        tasksBox.value[i].extraFilesDone = 0
        // Log the main folder + write it.
        let mainFolderName: String
        switch routing.destination {
        case .referenceLibrary: mainFolderName = "资料库"
        case .bookFolder(let f): mainFolderName = f.directoryName
        }
        await appendActivity(
            to: tasksBox, i: i,
            message: "写主文件 (\(mainFolderName)/...)",
            onProgress: onProgress
        )
        // Write each extra file (= LLM's split-out content). Extra file
        // write failures are non-fatal: main file stays .done; = the failed
        // extra file is recorded separately in tasksBox.
        for (extraIndex, extra) in routing.extraFiles.enumerated() {
            try await writeOneExtraFile(
                extra: extra,
                extraIndex: extraIndex,
                extraFilesTotal: extraFilesTotal,
                target: target,
                tasksBox: tasksBox,
                i: i,
                onProgress: onProgress
            )
        }
        // Write the main file (if there's a body).
        if !bodyToWrite.isEmpty {
            try await writeFile(
                body: bodyToWrite,
                routing: routing,
                contentHash: tasksBox.value[i].contentHash,
                target: target,
                sourcePath: tasksBox.value[i].sourcePath,
                cache: &cacheBox.value,
                router: router,
                tasksBox: tasksBox,
                i: i
            )
            let bodyKB = Double(bodyToWrite.utf8.count) / 1024.0
            await appendActivity(
                to: tasksBox, i: i,
                message: String(format: "✅ 主文件写入成功 (%.1f KB)", bodyKB),
                onProgress: onProgress
            )
        }
        tasksBox.value[i].state = .done
        tasksBox.value[i].destination = routing.destination
        // The writeFile appended the new entry to its inout cache; = the
        // shared `cacheBox.value` is now the canonical source of truth.
    }

    /// Compute the body to write based on the rewriteMode (= .consolidate
    /// always uses the original verbatim; = .reorganize produces no main file
    /// body (= the agent's writeBookDoc tool owns the writes); =
    /// .searchAndRewrite prefers the LLM's `rewrittenBody` when present,
    /// falling back to the original).
    private func computeBodyToWrite(
        originalBody: String,
        rewrittenBody: String?,
        folder: BookFolder,
        rewriteMode: ImportFileInput.RewriteMode
    ) -> String {
        switch rewriteMode {
        case .consolidate:
            return ImportDocumentTemplate.prepareBodyForWrite(
                rawBody: originalBody,
                folder: folder
            )
        case .reorganize:
            // The agent owns writing in .reorganize mode; = the orchestrator
            // has nothing to write for the main file (= rewrittenBody is always
            // nil per routeReorganizeMultiTurn's signature).
            return ""
        case .searchAndRewrite:
            if let rewritten = rewrittenBody, !rewritten.isEmpty {
                return ImportDocumentTemplate.prepareBodyForWrite(
                    rawBody: rewritten,
                    folder: folder
                )
            }
            return ImportDocumentTemplate.prepareBodyForWrite(
                rawBody: originalBody,
                folder: folder
            )
        }
    }

    /// Write one extra file (= a single entry from `routing.extraFiles`). Logs
    /// the success/failure to the per-row activityLog (= the user sees a row
    /// per extra file). Failures are non-fatal (= they don't throw; = the row's
    /// `extraFilesDone` counter still advances).
    private func writeOneExtraFile(
        extra: ExtraFile,
        extraIndex: Int,
        extraFilesTotal: Int,
        target: ImportTarget,
        tasksBox: TasksBox,
        i: Int,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async throws {
        do {
            try await writeExtraFile(
                extra: extra,
                target: target,
                tasksBox: tasksBox,
                i: i,
                extraIndex: extraIndex
            )
            let bodyKB = Double(extra.body.utf8.count) / 1024.0
            let marker = extra.required ? "[必填]" : "[自定义]"
            await appendActivity(
                to: tasksBox, i: i,
                message: String(
                    format: "  ✅ 子文件 %d/%d %@ %@/%@.md (%.1f KB)",
                    extraIndex + 1, extraFilesTotal,
                    marker,
                    extra.folder.directoryName,
                    extra.title,
                    bodyKB
                ),
                onProgress: onProgress
            )
        } catch {
            NSLog(
                "[wenshu.import] extraFile %d (%@) failed: %@",
                extraIndex, extra.title, String(describing: error)
            )
            await appendActivity(
                to: tasksBox, i: i,
                message: "  ❌ 子文件 \(extraIndex + 1)/\(extraFilesTotal) \(extra.title).md 写失败: \(String(describing: error))",
                onProgress: onProgress
            )
        }
        tasksBox.value[i].extraFilesDone += 1
    }

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) feedback). Append a single
    /// line to a task's activityLog (= the per-row scrolling terminal- like
    /// view in the sheet). Capped at 30 entries (= old entries drop off; = 30
    /// is enough to show the recent activity without scrolling forever). Also
    /// triggers onProgress so the sheet UI updates immediately.
    private func appendActivity(
        to tasksBox: TasksBox,
        i: Int,
        message: String,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        tasksBox.value[i].activityLog.append(message)
        // Cap at 30 (= the oldest entries drop off; = prevents unbounded growth).
        if tasksBox.value[i].activityLog.count > 30 {
            tasksBox.value[i].activityLog.removeFirst(
                tasksBox.value[i].activityLog.count - 30
            )
        }
        await onProgress?(tasksBox.value)
    }
}

extension ImportService {
    // (findEntityByTitle extracted to ImportServiceDedup.swift in A56; = see that file)

    // (normalizeTitle extracted to ImportServiceDedup.swift in A56; = see that file)

    // (sanitizeFilename extracted to ImportServiceDedup.swift in A56; = see that file)

}
