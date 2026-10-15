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

/// The orchestrator. Stateless (= all state lives in the
/// per-task `ImportTask` actors + the sidecar cache on
/// disk). The view holds a `[ImportTask]` and the
/// `ImportService` mutates the array in place (= the
/// orchestrator returns the array; = the view diffs).
actor ImportService {
    /// Cancellation flag (= boss's 2026-10-09
    /// directive "取消退出时，所有已经导入的内容回退
    /// 清掉。类似 MAC OS 的系统升级，取消等于放弃
    /// 这个工作，不留痕"; = the sheet's cancel
    /// button + the `.onDisappear` lifecycle hook
    /// both set this to `true`; = the orchestrator's
    /// `importFiles` loop polls it on every per-task
    /// transition; = when `true`, the in-flight tasks
    /// stop early (= the TaskGroup finishes whatever
    /// it has; = `importFiles` returns with the
    /// remaining tasks in `.pending`; = the
    /// `writtenURLs` set carries the on-disk trail
    /// for the rollback pass)).
    private var isCancelled: Bool = false

    /// Per-batch rollback trail (= the URLs of every
    /// .md file the orchestrator wrote this run; =
    /// a `Set<URL>` because the dedup cache can map
    /// two source paths to the same on-disk file
    /// when the bodies are byte-equal; = the cancel
    /// handler iterates this set + deletes each file
    /// in the most-recent-import order; = the
    /// reference-library side restores the prior
    /// `entities.json` from the snapshot the
    /// orchestrator took at the start of the run).
    private var writtenURLs: [URL] = []

    /// Snapshot of the on-disk reference-library
    /// index file (= the path to the prior
    /// `entities.json` content, captured at
    /// `importFiles` start; = the cancel handler
    /// restores this file verbatim; = the
    /// "all-or-nothing" semantic the boss asked
    /// for = cancel = nothing lands on disk = the
    /// user can re-import from a clean state).
    private var entitiesJSONSnapshot: (path: URL, content: Data)? = nil

    /// Per-task mutable state used by the `dispatchLLM` helper
    /// (= extensions can't hold stored properties; = this lives on
    /// the actor). `lastDispatchError` is the final error from the
    /// last failed LLM attempt; = `dispatchLLM` returns nil and
    /// sets this so the orchestrator can surface the user-readable
    /// error via `markLLMFailed`).
    private var lastDispatchError: Error? = nil

    /// 5-way parallel LLM dispatch (= the boss's
    /// 2026-10-09 directive "你要做一个机制 5 个并发，
    /// 一个文件一个请求。同时只能处理 5 个"; = the
    /// orchestrator's TaskGroup seeds the first
    /// `maxParallel` tasks and refills as each
    /// completes; = 5 keeps the in-flight LLM
    /// pressure below the Anthropic / MiniMax
    /// per-second burst limit; = the LLMConnector
    /// adapter handles its own rate limiting for
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// directive). The historical
    /// default was 5; = we kept
    /// `defaultMaxParallel = 5` as a
    /// reference (= the docs and the
    /// `ImportTarget` Picker UI's max
    /// = 5) but the actual cap is
    /// `target.maxParallel` (= the
    /// per-import user-picked value;
    /// = the default ImportTarget init
    /// defaults to 3; = the Picker
    /// exposes 1..5).
    static let defaultMaxParallel = 5

    /// Where the sidecar cache lives (= per-library;
    /// = `<wsRoot>/.import-cache/`; = deletable by the user
    /// if they want a full re-import).

    /// One path's hash → the destination metadata. The
    /// orchestrator reads this at the dedup step; = writes
    /// a fresh entry after each successful import.
    fileprivate struct CacheEntry: Codable, Sendable {
        let contentHash: String
        let destination: ImportDestination
        let writtenAt: Date
        /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
        /// 浪费" directive). The
        /// timestamp of the last
        /// title-only retry on
        /// this file (= the user
        /// clicked "重新调研
        /// 所有失败" while this
        /// entry was in `.failed`
        /// state). The retry
        /// method uses this to
        /// detect "already
        /// retried with the same
        /// body" (= skip the LLM
        /// dispatch; = save
        /// token + time). The
        /// field is OPTIONAL
        /// (= older cache entries
        /// from wenshu versions
        /// before round-43
        /// don't have it; = the
        /// Codable decoder
        /// tolerates the missing
        /// key). Custom
        /// `init(from:)` is
        /// required (= default
        /// memberwise init
        /// doesn't expose a
        /// default for the
        /// optional field).
        var lastTitleOnlyRetriedAt: Date?
        /// the body
        /// hash at the time of the
        /// last title-only retry
        /// (= SHA-256 of the
        /// LLM-ingested body = the
        /// title-only-synthesized
        /// body constructed from
        /// the filename + sibling
        /// context; = NOT the
        /// source file's body
        /// hash because the source
        /// file is unreadable; =
        /// if this hash changes
        /// between retries, the
        /// retry result would
        /// differ; = the retry
        /// method compares this
        /// against the freshly
        /// computed hash to
        /// decide skip-vs-run). If
        /// the source file's body
        /// hash changes (= the
        /// user edited the file;
        /// = the title-only body
        /// stays the same; = this
        /// hash is stable) the
        /// retry still skips; =
        /// the boss's intent is
        /// "if I haven't changed
        /// anything, don't re-run
        /// the LLM" = the
        /// title-only body hash
        /// is the right signal.
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

    /// Apple canonical convenience: stateless (= no init
    /// body; = the actor's empty default state is enough
    /// because all state lives in the per-task actors + the
    /// sidecar cache on disk).
    init() {}

    // MARK: - Public entry point

    /// Run the import. Returns the per-file tasks (= the
    /// view binds them; = the orchestrator mutates state
    /// in place via the returned array; = the array is
    /// the sheet's per-file progress strip).
    ///
    /// 4 phases (mirrors ObsidianVaultBatchImportTests):
    ///   1. walk = recursive .md scan
    ///   2. dedup = cache diff (= skip already-imported)
    ///   3. route + enrich = concurrent LLM dispatch
    ///   4. write = branch on ImportDestination
    ///
    /// `onProgress` (= optional) is a `@Sendable` closure that
    /// the orchestrator invokes after each per-file state
    /// transition (= the sheet's progress strip + ProgressView
    /// reads from this closure; = the closure is invoked on
    /// the orchestrator's actor = the sheet must hop to
    /// `@MainActor` to update its `@State`).
    ///
    /// The closure receives the current task array (= the
    /// same array the method returns at the end; = the sheet
    /// can render the live progress strip directly from the
    /// closure's payload). The closure is called at the end
    /// of Phase 1 (walk), at the end of Phase 2 (dedup), at
    /// the end of Phase 4 (write) per file, and once at the
    /// end of the method.
    /// `extensions` (= optional, default `["md"]`) is
    /// the file-type filter the user picked in the
    /// import sheet (= the user's 2026-10-09 ask).
    /// The walker's `extensions` parameter accepts a
    /// `Set<String>` of lower-cased extensions (= the
    /// walker's source-of-truth is the
    /// `ImportFileType.extensions` property; = the
    /// orchestrator never hard-codes a single
    /// extension; = the walker's match site is a
    /// single `Set.contains(...)` call so a new file
    /// type is a one-line change at the enum
    /// definition).
    func importFiles(
        in sourceDir: URL,
        into target: ImportTarget,
        router: ImportRouter,
        onProgress: (@Sendable ([ImportTask]) async -> Void)? = nil,
        extensions: Set<String> = ["md"]
    ) async -> [ImportTask] {
        resetRollbackTrail()
        let entitiesIndex = snapshotReferenceLibraryIndex(target: target)
        // Phase 1: walk.
        let mdFiles = walkSourceDir(sourceDir, extensions: extensions)
        var tasks = mdFiles.map { ImportTask(sourcePath: $0.path) }
        // Emit walk-phase progress so the sheet's ProgressView updates immediately (= the
        // user sees "找到 X 个 .md 文件" the instant the orchestrator finishes
        // Phase 1).
        await onProgress?(tasks)
                let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        let cache = dedupAndHash(tasks: &tasks, cacheFile: cacheFile)
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
        writeCache(cacheFile: cacheFile, cache: cacheBox.value)
        // Copy the per-task state back out of the shared box (= the TaskGroup's per-file
        // pipeline mutated `tasksBox.value` directly; = the orchestrator's
        // return value carries the canonical final-state view for the sheet's
        // per-file strip).
        return tasksBox.value
    }
    /// Reset the per-batch rollback trail at the start of every
    /// `importFiles` call (= the same actor can be re-used across
    /// multiple sheets, e.g. the cancel + "再次导入" retry path).
    private func resetRollbackTrail() {
        isCancelled = false
        writtenURLs = []
        entitiesJSONSnapshot = nil
    }

    /// Snapshot the reference-library `entities.json` for the cancel
    /// handler to restore on rollback (= captures the file before any
    /// writeFile call has a chance to append to it; = a fresh library
    /// with no prior `entities.json` stores an empty-data sentinel
    /// = the cancel handler deletes the file outright).
    private func snapshotReferenceLibraryIndex(target: ImportTarget) -> URL {
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


    /// Phase 3+4 = unified per-file pipeline
    /// (= the orchestrator's 5-way parallel
    /// TaskGroup; = the actor's serialized
    /// state mutation is safe across the
    /// concurrent `processFile` calls; =
    /// `CacheBox` / `TasksBox` are the
    /// class-wrapper workaround that hold
    /// the shared mutable state the
    /// TaskGroup needs to mutate from
    /// concurrent contexts).
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
            // Seed the first `maxParallel` tasks (= 5 today; = the LLM pressure knob; =
            // the LLMConnector adapter handles its own provider-side rate
            // limiting).
            while inFlight < target.maxParallel, nextIndex < dispatchIndices.count {
                let i = dispatchIndices[nextIndex]
                tasksBox.value[i].state = .routing
                await onProgress?(tasksBox.value)
                let input = ImportFileInput(
                    filePath: tasksBox.value[i].sourcePath,
                    targetBookId: target.bookId,
                    targetShelfId: target.shelfId,
                    rewriteMode: target.rewriteMode
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
            // Drain + refill (= each completed task frees a slot in the semaphore; = the
            // next pending task is seeded; = the pipeline keeps 5 files in
            // flight concurrently for the entire batch).
            while await group.next() != nil {
                inFlight -= 1
                if nextIndex < dispatchIndices.count {
                    let j = dispatchIndices[nextIndex]
                    if tasksBox.value[j].state == .pending {
                        tasksBox.value[j].state = .routing
                        await onProgress?(tasksBox.value)
                        let input = ImportFileInput(
                            filePath: tasksBox.value[j].sourcePath,
                            targetBookId: target.bookId,
                            targetShelfId: target.shelfId,
                            rewriteMode: target.rewriteMode
                        )
                        group.addTask { [self] in
                            await self.processFile(
                                taskIndex: j,
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
    }


    /// Phase 2 = read the on-disk cache once and hash
    /// every pending task's body (= the dedup key is
    /// the body hash, not the path hash; = renaming a
    /// file does not bypass dedup; = the in-memory
    /// cache is the source of truth for the import
    /// batch; = `writeCache` at the end persists the
    /// merged result; = the `if let cached` branch is
    /// a no-op per the 2026-10-10 short-circuit
    /// removal directive; = the cache is consulted
    /// downstream by the title-only retry path via
    /// `cache[sourcePath].lastTitleOnlyRetriedHash`).
    private func dedupAndHash(
        tasks: inout [ImportTask],
        cacheFile: URL
    ) -> [String: CacheEntry] {
        var cache = readCache(cacheFile: cacheFile)
        for i in tasks.indices {
            let hash: String
            do {
                let body = try String(contentsOfFile: tasks[i].sourcePath, encoding: .utf8)
                hash = Self.sha256(body)
            } catch {
                tasks[i].state = .failed
                tasks[i].errorMessage = "读取文件失败: \(error.localizedDescription)"
                continue
            }
            tasks[i].contentHash = hash
            _ = cache  // consulted downstream by the title-only retry path
        }
        return cache
    }


    // MARK: - title-only retry

    /// Re-run the failed "读取文件失败" tasks (= the
    /// source `.md` file was unreadable on disk; = the
    /// user clicked "重新调研所有失败" in the sheet's
    /// progress panel; = the orchestrator bypasses
    /// the disk read by constructing a minimal body
    /// from the filename + the sibling `.md` names
    /// in the same source directory; = the LLM
    /// produces a `.ws`-format body via web search;
    /// = the new body is written verbatim by the
    /// same `writeFile` path as the normal
    /// `importFiles` flow).
    ///
    /// Design (= boss round-36 "在进度面板底部
    /// 加一个'重新调研所有失败'聚合按钮"
    /// directive):
    /// - Filter `tasks` for `.state == .failed` AND
    ///   `errorMessage` starts with "读取文件失败"
    ///   (= LLM-routing failures are NOT retried
    ///   here; = those are bugs, not file
    ///   failures; = the user can re-import the
    ///   whole directory if the LLM is misconfigured).
    /// - Re-seed the matching tasks as `.routing`
    ///   with `errorMessage = nil` (= the row's
    ///   "失败" pill flips back to "分析中" =
    ///   the sheet's progress strip animates
    ///   smoothly).
    /// - Construct a `body` per file (= the
    ///   filename as the title + a sibling-context
    ///   list of the other `.md` names in the same
    ///   source directory = LLM has enough to
    ///   produce metadata + a clean .ws body).
    /// - Force `rewriteMode = .searchAndRewrite`
    ///   (= the LLM will use `web_search` to fill
    ///   in the entity's canonical content; = the
    ///   missing source file is the trigger for
    ///   the search; = the user explicitly opted
    ///   into the higher-token mode by clicking
    ///   "重新调研").
    /// - Reuse the `importFiles` 5-way parallel
    ///   TaskGroup pattern (= `processFile` is the
    ///   same function = the only difference is
    ///   the `ImportFileInput.body` is non-nil =
    ///   the router uses it; = the `writeFile`
    ///   step uses the LLM's `rewrittenBody` =
    ///   the original file is never read again).
    /// - Returns the new `tasks` array (= the
    ///   sheet's `onProgress` is called as tasks
    ///   transition; = the sheet re-renders).
    ///
    /// Why not just re-call `importFiles`? Because
    /// `importFiles` re-walks the source
    /// directory and creates new `ImportTask`
    /// rows (= the sheet would have to track
    /// task identity across calls; = the
    /// progress strip would jitter; = the
    /// "重新调研" button is the "patch the
    /// failures" seam, not the "re-run the
    /// whole batch" seam).
    func retryFailedTasksTitleOnly(
        tasks: [ImportTask],
        into target: ImportTarget,
        router: ImportRouter,
        onProgress: (@Sendable ([ImportTask]) async -> Void)? = nil
    ) async -> [ImportTask] {
        // 1. Filter (= only the "读取文件失败" subset; = LLM-routing failures are excluded; =
        // write failures are excluded; = the user clicked "重新调研" with the
        // explicit understanding that this is the "I trust the filename + LLM
        // search alone" path).
        let candidateIndices = tasks.indices.filter { i in
            guard tasks[i].state == .failed else { return false }
            return tasks[i].errorMessage?.hasPrefix("读取文件失败") ?? false
        }
        // 2. Compute the sibling-context list ONCE (= the user's whole source directory;
        // = all .md files in the same folder as the failed file; = the LLM
        // uses the list as "what other entities are nearby, what categories
        // exist"; = cheap; = the walk is one FileManager.enumerator call per
        // unique source directory).
        let contextByPath = Self.siblingContextMap(for: tasks)
        // 3. Load the sidecar cache ONCE (= we need to read the
        // `lastTitleOnlyRetriedHash` to dedup repeat clicks; = the dedup logic
        // runs here in the orchestrator; = the sheet doesn't need to do any
        // extra work; = the dedup is per-sourcePath keyed by the title-only
        // body hash (= if the source file's body changes, the title-only body
        // is unchanged = the retry still skips; = if the user renames the
        // source file = the title-only body changes because the filename
        // changed = the retry runs; = the boss's intent is "if nothing about
        // the input changed, don't re-run the LLM").
        let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        let cache = readCache(cacheFile: cacheFile)
        // 3.5. the tasks box (= mutates `tasks` in place; = the dedup loop marks
        // `.skipped`; = the retry loop later marks `.routing`).
        let tasksBox = TasksBox(value: tasks)
        // 4. (= boss 2026-10-10 (see OOB.md #2026-10-10) 浪费" directive). The smart skip
        // (= per-file dedup; = the boss's accepted answer: "如果上次调研的 hash 不一样 →
        // 重新调研, 否则 skip"). For each candidate (= a `.failed` "读取文件失 败" task),
        // compute the title-only body (= the same synthesized body the LLM
        // would ingest = filename + sibling context) + hash it. Compare
        // against the cached `lastTitleOnlyRetriedHash`. Match (= retry would
        // produce the same result as the last retry) = mark the task
        // `.skipped` (= not `.routing`) and do NOT dispatch the LLM. Mismatch
        // (= retry would produce a different result) = include in
        // `retryIndices` and dispatch the LLM. No cache entry (= never
        // retried) = dispatch (= first retry = the standard path).
        var retryIndices: [Int] = []
        for i in candidateIndices {
            let siblingContext = contextByPath[tasksBox.value[i].sourcePath] ?? ""
            let synthesizedBody = Self.titleOnlyBody(
                fileName: (tasksBox.value[i].sourcePath as NSString).lastPathComponent,
                siblingContext: siblingContext
            )
            let bodyHash = Self.sha256(synthesizedBody)
            if let cached = cache[tasksBox.value[i].sourcePath],
               cached.lastTitleOnlyRetriedHash == bodyHash {
                // Already retried with the SAME body hash = the LLM output would be byte-
                // identical to the last attempt = skip (= the boss's
                // "不要浪费" rule; = no LLM token spent; = the row flips
                // to "已跳过" instead of "分析中" → "完成" so the user sees
                // what happened).
                tasksBox.value[i].state = .skipped
                tasksBox.value[i].errorMessage = nil
                continue
            }
            // No prior retry OR a prior retry with a DIFFERENT body hash = the LLM would
            // produce a different result = run the LLM.
            retryIndices.append(i)
        }
        // 5. Re-seed the matching tasks (.failed → .routing, errorMessage = nil, body
        // constructed from filename + sibling context).
        for i in retryIndices {
            tasksBox.value[i].state = .routing
            tasksBox.value[i].errorMessage = nil
        }
        await onProgress?(tasksBox.value)
        // 6. Same 5-way parallel TaskGroup as `importFiles` (= the only difference is the
        // `ImportFileInput` carries a non-nil `body`; = `processFile` is
        // unchanged; = the `writeFile` step uses the LLM's `rewrittenBody` and
        // never touches the unreadable file).
        let cacheBox = CacheBox(value: cache)
        await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
            var inFlight = 0
            var nextIndex = 0
            let dispatchIndices = retryIndices
            while inFlight < target.maxParallel, nextIndex < dispatchIndices.count {
                let i = dispatchIndices[nextIndex]
                let siblingContext = contextByPath[tasks[i].sourcePath] ?? ""
                let synthesizedBody = Self.titleOnlyBody(
                    fileName: (tasks[i].sourcePath as NSString).lastPathComponent,
                    siblingContext: siblingContext
                )
                let input = ImportFileInput(
                    filePath: tasks[i].sourcePath,
                    targetBookId: target.bookId,
                    targetShelfId: target.shelfId,
                    rewriteMode: .searchAndRewrite,
                    body: synthesizedBody
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
                    let siblingContext = contextByPath[tasks[i].sourcePath] ?? ""
                    let synthesizedBody = Self.titleOnlyBody(
                        fileName: (tasks[i].sourcePath as NSString).lastPathComponent,
                        siblingContext: siblingContext
                    )
                    let input = ImportFileInput(
                        filePath: tasks[i].sourcePath,
                        targetBookId: target.bookId,
                        targetShelfId: target.shelfId,
                        rewriteMode: .searchAndRewrite,
                        body: synthesizedBody
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
        // 8. (= boss 2026-10-10 "如果已经 重复过了，再重新调 研一次，有些浪费" directive). After the retry
        // batch finishes (= success or fail), stamp every retried task's cache
        // entry with `lastTitleOnlyRetriedAt = now` + the title-only body hash
        // (= the next user click on "重新调 研" will see the stamp + skip the LLM
        // = the boss's "不要再浪费" rule).
        for i in retryIndices {
            let sourcePath = tasksBox.value[i].sourcePath
            let siblingContext = contextByPath[sourcePath] ?? ""
            let synthesizedBody = Self.titleOnlyBody(
                fileName: (sourcePath as NSString).lastPathComponent,
                siblingContext: siblingContext
            )
            let bodyHash = Self.sha256(synthesizedBody)
            if var entry = cacheBox.value[sourcePath] {
                entry.lastTitleOnlyRetriedAt = Date()
                entry.lastTitleOnlyRetriedHash = bodyHash
                cacheBox.value[sourcePath] = entry
            } else {
                cacheBox.value[sourcePath] = CacheEntry(
                    contentHash: "orphan-" + Self.sha256(sourcePath),
                    destination: .referenceLibrary,
                    writtenAt: Date(),
                    lastTitleOnlyRetriedAt: Date(),
                    lastTitleOnlyRetriedHash: bodyHash
                )
            }
        }
        writeCache(cacheFile: cacheFile, cache: cacheBox.value)
        return tasksBox.value
    }

    /// Construct a "title-only" body for the LLM
    /// (= the source file is unreadable; = the
    /// body is the minimum context the LLM
    /// needs to produce metadata + a `.ws`-format
    /// body). The body follows the same
    /// structure as the `userPrompt` expects
    /// (= the LLM's prompt is "read this body
    /// + produce title / summary / tags +
    /// rewrittenBody" = the title-only body
    /// is a short synthesized markdown with
    /// the title as the H1 + a brief context
    /// block).
    private static func titleOnlyBody(
        fileName: String,
        siblingContext: String
    ) -> String {
        let titleStem = (fileName as NSString).deletingPathExtension
        return """
        # \(titleStem)

        <!-- title-only retry.
             The original .md file at the same path
             failed to read on disk (= malformed utf-8
             or unsupported format). The orchestrator
             constructed this body from the filename
             + the sibling .md names in the same
             source directory. The LLM should use
             web_search to fill in the canonical
             content for "\(titleStem)" and produce
             the standard .ws-format body (3 必填 + 2
             可选 frontmatter + 自由 markdown 正文). -->
        \(siblingContext.isEmpty ? "" : siblingContext)
        """
    }

    /// Build a map from each task's source path to
    /// a sibling-context string (= the names of
    /// the other `.md` files in the same source
    /// directory). One walk per unique parent
    /// directory (= the wenshu user's import
    /// directories typically hold hundreds of
    /// files; = the walk is the only I/O = we
    /// amortize it across the failed set).
    private static func siblingContextMap(for tasks: [ImportTask]) -> [String: String] {
        let fm = FileManager.default
        // 1. Group task paths by parent directory.
        var byDir: [String: [String]] = [:]
        for task in tasks {
            let path = task.sourcePath
            let dir = (path as NSString).deletingLastPathComponent
            byDir[dir, default: []].append(path)
        }
        // 2. For each unique parent, enumerate the directory and build a per-path context
        // string (= all the other .md names in the same folder).
        var out: [String: String] = [:]
        for (dir, paths) in byDir {
            // 3. Sibling .md names (= every .md file in the directory; = the failed
            // file's own name is excluded from its own context; = the list
            // is "what other entities are nearby").
            let siblingNames: [String]
            if let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                siblingNames = enumerator.compactMap { url in
                    guard let url = url as? URL,
                          (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                          url.pathExtension.lowercased() == "md"
                    else { return nil }
                    return url.lastPathComponent
                }
            } else {
                siblingNames = []
            }
            // 4. Build the per-path context (= the failed file's own name is filtered
            // out; = the list is the "neighbors in the same folder").
            for path in paths {
                let myName = (path as NSString).lastPathComponent
                let others = siblingNames.filter { $0 != myName }
                let context = others.isEmpty
                    ? ""
                    : "## 同目录其他文件 (= entity neighbors in this folder)\n\n" +
                      others.sorted().prefix(20).map { "- \($0)" }.joined(separator: "\n") + "\n"
                out[path] = context
            }
        }
        return out
    }

    // (= boss 2026-10-10 (see OOB.md #2026-10-10) 件，自动跳过了" directive).
    /// Verify the cache entry's destination
    /// file still exists on disk. Returns
    /// `true` if the previous import's
    /// output is still there (= the cache
    /// entry is valid; = skip is safe);
    /// returns `false` if the destination
    /// file is gone (= the cache is stale;
    /// = re-import instead of skip).
    ///
    /// For the reference library: the
    /// destination file is
    /// `<wsRoot>/reference-library/entities/<uuid>.md`
    /// where `uuid = uuidFromHash(contentHash)`
    /// (= deterministic; = we can
    /// reconstruct the exact path from
    /// the cache entry's `contentHash`;
    /// = no need for the LLM's title).
    /// This is the boss's exact bug case
    /// (= cleared the ref lib's .md +
    /// entities.json but the cache
    /// remained; = the file existence
    /// check correctly returns false; =
    /// re-import).
    ///
    /// For a book folder: the
    /// destination file is
    /// `<shelves>/<shelfId>/books/<bookId>/<folder>/<basename>.md`
    /// where `basename = sanitizeFilename(LLM title)`.
    /// The cache does NOT store the LLM
    /// title. For the book case, the
    /// conservative check is the
    /// directory existence + non-empty
    /// (= at least one .md was
    /// previously imported; = the cache
    /// entry is likely valid; = the user
    /// can re-import individual files
    /// manually if they want). This is a
    /// soft signal (= the user can
    /// delete the cache to force a full
    /// re-import if needed).
    ///
    /// For unknown destination variants
    /// (= future enum cases): return
    /// `false` (= conservative; = don't
    /// skip; = re-import).
    private static func cachedDestinationExists(
        cached: CacheEntry,
        target: ImportTarget
    ) -> Bool {
        switch cached.destination {
        case .referenceLibrary:
            let uuid = Self.uuidFromHash(cached.contentHash)
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

    // MARK: - Phase 1: walk

    /// Walk the source directory recursively. Returns
    /// files whose extension is in the
    /// `extensions` set (sorted for deterministic
    /// order; = the sheet's per-file strip renders
    /// in the same order every re-import). Apple
    /// canonical pattern: the match site is a
    /// single `Set.contains(...)` call so a new
    /// file type is a one-line change at the
    /// enum-definition site (= the orchestrator
    /// never hard-codes a single extension).
    /// (= boss
    /// 2026-10-10 "现在
    /// 有个问题, 我
    /// 们只能选目
    /// 录, 而不能
    /// 选择单文件"
    /// directive). The
    /// walker now
    /// accepts BOTH a
    /// directory (= the
    /// old behavior) AND
    /// a single file (= a
    /// file the user
    /// picked directly
    /// from the open
    /// panel; = the
    /// walker returns
    /// just that one
    /// file; = the
    /// import pipeline
    /// (= walk + dedup +
    /// LLM + write)
    /// is unchanged; =
    /// the user can
    /// pick a single
    /// file OR a
    /// directory; = the
    /// orchestrator's
    /// 5-way parallel
    /// TaskGroup still
    /// runs, but with
    /// only 1 task).
    private func walkSourceDir(
        _ source: URL,
        extensions: Set<String>
    ) -> [(path: String, url: URL)] {
        let fm = FileManager.default
        // if `source` is a regular file (= the user picked a single file from the open
        // panel), return it directly (after validating the extension matches).
        if let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]),
           values.isRegularFile == true {
            guard extensions.contains(source.pathExtension.lowercased()) else { return [] }
            return [(source.path, source)]
        }
        // the old walk = recursive enumerator. The caller can pass a directory; the
        // walker recurses and filters by extension.
        guard let enumerator = fm.enumerator(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var out: [(String, URL)] = []
        for case let url as URL in enumerator {
            // Apple canonical: skip directories and symlinks pointing outside the source
            // tree.
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .nameKey]),
                  values.isRegularFile == true else { continue }
            guard extensions.contains(url.pathExtension.lowercased()) else { continue }
            out.append((url.path, url))
        }
        // Sort by path (= the same sort the e2e scaffold uses; = deterministic order
        // across re-imports).
        out.sort { $0.0 < $1.0 }
        return out
    }

    // MARK: - Phase 2: cache

    /// Read the sidecar cache (= the actor's serialized
    /// state is the lock; = the orchestrator batches the
    /// read once at the start of importFiles).
    private func readCache(cacheFile: URL) -> [String: CacheEntry] {
        guard let data = try? Data(contentsOf: cacheFile),
              let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data)
        else { return [:] }
        return decoded
    }

    /// Persist the cache back (= the orchestrator writes
    /// the whole map each time; = small file size; = the
    /// map is in-memory at this point).
    private func writeCache(cacheFile: URL, cache: [String: CacheEntry]) {
        // Ensure the cache root exists (= created on the first import; = no-op on
        // subsequent runs).
        try? FileManager.default.createDirectory(
            at: cacheFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheFile, options: [.atomic])
    }

    // MARK: - Phase 4: write

    /// Write the file body to the destination dictated by
    /// the routing result. Branches on `ImportDestination`:
    ///   - `.bookFolder(folder)` = write to
    ///     `<shelvesRoot>/<shelfId>/books/<bookId>/<folder.directoryName>/<uuid>.md`
    ///     (= creates the folder if missing; = uuid is
    ///     content-addressable so the same body always lands
    ///     at the same path; = dedup by content).
    ///   - `.referenceLibrary` = delegate to
    ///     `ReferenceLibraryTool.execute(saveReferenceEnvelope)`
    ///     (= the existing 4-phase path the e2e scaffold
    ///     already exercises).
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
        switch routing.destination {
        case .bookFolder(let folder):
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
            // sidebar + the cache for idempotency). Sanitization (= boss
            // 2026-10-09 (see OOB.md #2026-10-09) path is rare (= the LLM
            // is instructed to always return a title; = a missing title
            // would indicate a deeper LLM misbehavior worth surfacing as a
            // generic "未命名" rather than a cryptic UUID).
            let uuid = Self.uuidFromHash(contentHash)
            // (= the boss's 2026-10-09 round-18 "强制让用户 分开导入" directive). When the user
            // pinned the reference library, this branch is unreachable (=
            // the LLM already overrode the destination to
            // .referenceLibrary + the orchestrator took the
            // referenceLibrary case). The `bookId!` / `shelfId!` unwraps
            // are safe because the orchestrator's processFile passes the
            // user's chosen target down here; = a destination = .book
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
            let basename = Self.sanitizeFilename(
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
            // the existing file (= new body + new LLM metadata); = no
            // match → write the new title-derived file). The normalization
            // is the canonical = "trim whitespace + lowercase" = the LLM
            // sometimes returns "  蛇 精" with double spaces; = a strict ==
            // compare would miss the duplicate.
            let fileURL: URL
            let existing = Self.findEntityByTitle(
                in: folderURL,
                title: routing.title
            )
            if let existingURL = existing {
                // (= boss 2026-10-10 "我 选故事宪 法，直接 跳到了步 骤 3，没有 重新分析 是不是内 容相同" 反馈). A same-
                // titled .md file was found in the destination folder.
                // Before overwriting, the orchestrator now asks the
                // LLM (= Phase 2 of the 2-stage dedup) to compare the
                // source body against the existing body. The LLM
                // returns `isContentSame` + `confidence`; = if same
                // AND confidence >= threshold = skip (= treat as a no-
                // op = the existing file is already correct); =
                // otherwise overwrite (= the source has new content
                // the user wants to land). The existing per-file dedup
                // is now LLM-driven (= the previous "filename ==
                // sanitized title" check was too coarse = the user
                // reported 故事宪法 as a false skip = the folder had
                // *other* .md files but the 故事宪法 file didn't actually
                // exist by the same name; = the old
                // `cachedDestinationExists` check returned true for
                // any non-empty folder; = wrong conclusion).
                let existingBody = (try? String(
                    contentsOf: existingURL,
                    encoding: .utf8
                )) ?? ""
                let sourceBodyForCompare = try String(
                    contentsOfFile: tasksBox.value[i].sourcePath,
                    encoding: .utf8
                )
                let sameResult = try await router.isContentSame(
                    sourceBody: sourceBodyForCompare,
                    existingBody: existingBody,
                    sourceTitle: routing.title
                )
                if WCIRHelpers.shouldSkip(result: sameResult) {
                    // LLM says same content; = skip (= the existing file is the correct
                    // representation; = the user sees "已跳过 - 内容相同"
                    // in the per-row result strip).
                    NSLog("WSImport: content-same skip title='\(routing.title)' confidence=\(sameResult.confidence) reasoning='\(sameResult.reasoning)'")
                    // Set the .skipped state + the reason on the task; = the outer
                    // processFile sees the .skipped state and
                    // won't overwrite to .done. We throw
                    // `ImportServiceError.contentSameSkipped` (= a
                    // sentinel error type) so the outer catch
                    // block recognises the "skip via throw"
                    // pattern (= the outer block also catches
                    // genuine errors = the sentinel pattern is
                    // idiomatic for this orchestrator's existing
                    // structure).
                    tasksBox.value[i].state = .skipped
                    tasksBox.value[i].errorMessage = nil
                    tasksBox.value[i].skippedReason = "内容相同 (LLM confidence \(sameResult.confidence)): \(sameResult.reasoning)"
                    throw ImportServiceError.contentSameSkipped
                } else {
                    // LLM says different content (or low confidence); = overwrite the
                    // existing file.
                    NSLog("WSImport: content-different overwrite title='\(routing.title)' reasoning='\(sameResult.reasoning)'")
                }
                // Match (= re-import of an existing entity); = overwrite the existing
                // file at its current path; = the boss's "edit, not
                // create" rule.
                fileURL = existingURL
                NSLog("WSImport: dedup hit title='\(routing.title)' → \(existingURL.lastPathComponent)")
            } else {
                fileURL = folderURL.appendingPathComponent("\(basename).md")
            }
            // Create the folder if missing (= idempotent; = the orchestrator does not
            // depend on the book bootstrap having created the folder for
            // this case; = the bootstrapper seeds the 5 standard folders
            // but if a future folder is added = the orchestrator creates
            // it on the fly).
            try FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )
            // Write the body verbatim (= boss 2026-10-09 (see OOB.md #2026-10-09) job is
            // to put the body at the right path).
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
            // Record the on-disk trail for the cancel-and-rollback path (= the
            // `ImportService` actor keeps a list of every URL it wrote
            // this batch; = the cancel handler deletes them in reverse-
            // order on rollback; = the dedup cache can map two source
            // paths to the same file URL but the cancel handler is
            // idempotent so a double-delete is a no-op).
            writtenURLs.append(fileURL)
        case .referenceLibrary:
            // the reference library path now also runs the Stage 2 LLM content-same
            // decision (= the reference library dedup was per-file
            // correct, but the user wants the same "LLM 比对" transparency
            // for both destinations; = the
            // `FileSystemReferenceStore.saveReferenceToFileSystem` upserts
            // the file (= round-42), so "skip" here just means the upsert
            // sees a content-identical file and the idempotent write is a
            // no-op; = "overwrite" means the content differs and the
            // upsert overwrites with the new body).
            let refMdURL = target.wsRoot
                .appendingPathComponent("reference-library")
                .appendingPathComponent("entities")
                .appendingPathComponent("\(Self.uuidFromHash(contentHash).uuidString).md")
            if FileManager.default.fileExists(atPath: refMdURL.path) {
                // File already exists for this content hash (= the previous import wrote
                // it). Run Stage 2 LLM check (= the boss's "需要 检查 对比"
                // requirement).
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
                    // No need to write; = the file is already correct. Mark the task as
                    // .skipped + set the reason; = throw the
                    // sentinel so the outer processFile doesn't
                    // overwrite to .done.
                    tasksBox.value[i].state = .skipped
                    tasksBox.value[i].errorMessage = nil
                    tasksBox.value[i].skippedReason = "内容相同 (LLM confidence \(sameResult.confidence)): \(sameResult.reasoning)"
                    throw ImportServiceError.contentSameSkipped
                } else {
                    NSLog("WSImport: ref-library content-different overwrite title='\(routing.title)' reasoning='\(sameResult.reasoning)'")
                    // Fall through to the standard writeReference (= the upsert
                    // overwrites the existing file with the new
                    // body).
                }
            }
            // Delegate to the existing reference-write path (= the e2e scaffold's 4-phase
            // walk → reframe → classify → write; = the body lands at
            // `<wsRoot>/reference-library/entities/<uuid>.md` and the
            // Reference is appended to `entities/entities.json`).
            try await writeReference(
                body: body,
                routing: routing,
                target: target,
                contentHash: contentHash
            )
        }
        // Record the import in the sidecar cache so the next dedup pass (= a re-import of
        // the same source directory) hits the cache instead of dispatching the
        // LLM + re-writing the file. (= the dedup key is the absolute source
        // path; = the cache value carries the body hash + the resolved
        // destination = the dedup pass can short-circuit without touching the
        // LLM). (= boss 2026-10-10 (see OOB.md #2026-10-10) 3 files; =
        // `uuidFromHash("")` returned the SAME deterministic UUID for all 3
        // files; = the orchestrator wrote the .md at the same path for the
        // first file; = the second and third files crashed with "Reference ...
        // already exists on disk"). The fix: NEVER write an empty / short
        // contentHash to the cache; = if the input is empty (= the source
        // file's contentHash was somehow not populated), compute a stable
        // placeholder (= sha256 of the source path; = unique per file; = the
        // uuid derives to a unique UUID; = the dedup still works). The
        // previous code propagated the empty hash verbatim, which led to the
        // "all empty hashes → same UUID" collision.
        let safeContentHash: String
        if contentHash.isEmpty || contentHash.count < 16 {
            safeContentHash = "orphan-" + Self.sha256(sourcePath)
        } else {
            safeContentHash = contentHash
        }
        cache[sourcePath] = CacheEntry(
            contentHash: safeContentHash,
            destination: routing.destination,
            writtenAt: Date()
        )
    }

    /// ticket 03 (= boss
    /// 2026-10-10 "甚至原文
    /// 件 A 的内容, 与我们
    /// 的 B 模版不符合, 多了
    /// 很我非模版的内容, 我
    /// 希望能自动拆出一个文
    /// 件, 放在合适的目录中
    /// 去" feedback). Write
    /// one LLM-suggested
    /// split-out file (= A's
    /// non-B content) to
    /// disk. Resolves the
    /// folder URL from the
    /// `extra.folder` (= LLM
    /// decided which
    /// BookFolder; = the
    /// orchestrator doesn't
    /// override = this is
    /// the canonical
    /// LLM-routed path).
    /// Dedup logic mirrors
    /// the main file: same-
    /// title in the target
    /// folder = overwrite
    /// the existing .md; =
    /// no match = write a
    /// new file.
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
        let basename = Self.sanitizeFilename(
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

    /// Write the file to the reference library. Reuses
    /// the existing `FileSystemReferenceStore.saveReferenceToFileSystem`
    /// (= see the e2e scaffold's 4-phase pattern; = the
    /// LLM-supplied category + tags + entityType are
    /// encoded into the Reference envelope).
    private func writeReference(
        body: String,
        routing: ImportRoutingResult,
        target: ImportTarget,
        contentHash: String
    ) async throws {
        // uuid = content-hash-prefixed (= the same body always lands at the same
        // reference-library file; = idempotent re-import dedup).
        let uuid = Self.uuidFromHash(contentHash)
        // Build a Reference struct from the routing result (= the LLM supplies the
        // metadata; = the orchestrator maps ImportRoutingResult onto the
        // existing Reference struct).
        let reference = Reference(
            id: uuid,
            title: routing.title,
            source: sourceStringFromPath(target: target),
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

    /// Where the reference came from (= used in the
    /// Reference.source field; = "导入: <source dir>"
    /// for now; = a future ticket can ask the user to
    /// label the source).
    private func sourceStringFromPath(target: ImportTarget) -> String {
        if let bookId = target.bookId {
            return "导入: \(bookId.uuidString.prefix(8))"
        }
        return "导入: 资料库"
    }

    // MARK: - Errors

    /// errors (= thrown
    /// by writeFile when the orchestrator's
    /// processFile reaches a bookFolder write but
    /// the target's `bookId` / `shelfId` are nil; =
    /// a defensive guard for the boss's
    /// 2026-10-09 round-18 "强制让用户分开导入"
    /// directive; = the user pinned a book, the
    /// LLM overrode to .referenceLibrary in error,
    /// and the orchestrator's processFile would
    /// otherwise crash on a force-unwrap).
    enum ImportServiceError: Error, LocalizedError {
        case missingBookForBookFolderDestination
        /// 
        /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
        /// " 反馈).
        /// Sentinel error
        /// thrown by
        /// `writeFile`
        /// when the Phase
        /// 2 LLM
        /// content-same
        /// decision says
        /// "skip" (= the
        /// existing file
        /// already has
        /// the same
        /// content; = the
        /// orchestrator
        /// catches this
        /// sentinel and
        /// recognizes
        /// "the task was
        /// already marked
        /// .skipped" =
        /// no overwrite
        /// to .done; = the
        /// user sees
        /// "已跳过 -
        /// 内容相同"
        /// in the
        /// per-row
        /// result
        /// strip).
        /// The sentinel
        /// is NOT a real
        /// error (= the
        /// catch block
        /// checks for
        /// this specific
        /// case and
        /// treats it as
        /// the
        /// non-error
        /// "skip"
        /// path).
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

    // MARK: - Crypto helpers (= Apple-native; = no third-party deps per AGENTS.md §11.1)

    /// SHA-256 of a String (= the body dedup key; = uses
    /// Apple's CryptoKit; = AGENTS.md §11.1 forbids
    /// third-party crypto).
    static func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Derive a stable UUID from a SHA-256 hex string (= the
    /// on-disk filename for a body-hash). Takes the first
    /// 16 bytes (= 32 hex chars); = sets RFC 4122 version
    /// (= 4) and variant (= 10) bits so the UUID round-trips
    /// through `UUID(uuidString:)`.
    ///
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// (= `chars[i*2..<i*2+2]` index out
    /// of range at i=15; = the
    /// `Array._checkIndex` failure
    /// captured in the wenshu.ips crash
    /// report at 2026-10-10 10:44:08).
    /// The trigger: a stale cache
    /// entry (= the boss's
    /// `import-cache.json` from a
    /// previous wenshu version) had a
    /// `contentHash` shorter than 32
    /// hex chars (= the older wenshu
    /// stored a UUID string or a
    /// truncated hash); = the
    /// `retryFailedTasksTitleOnly`
    /// flow ran `uuidFromHash` on that
    /// short string; = crash; =
    /// SIGTRAP → Trace/BPT trap →
    /// `termination.indicator =
    /// "Trace/BPT trap: 5"`).
    ///
    /// Fix: validate the hex length
    /// BEFORE indexing; = if too
    /// short, return a stable UUID
    /// derived from a hashed-padded
    /// version of the input (= the
    /// on-disk filename won't match
    /// the previously-imported
    /// file's path = the
    /// re-import will write a new
    /// .md at a new UUID; = the old
    /// cache entry is effectively
    /// invalidated; = this is the
    /// right behavior for a cache
    /// entry that was written by a
    /// wenshu version with a
    /// different hash format).
    static func uuidFromHash(_ hex: String) -> UUID {
        let chars = Array(hex.prefix(32))
        // validate the input length BEFORE indexing. If too short, re-hash the input to a
        // 32-char hex string (= the output is a deterministic UUID that
        // doesn't match any previously-imported file's path; = the re-import
        // writes a new .md at this UUID; = the old cache entry is effectively
        // orphaned).
        let safeHex: String
        if chars.count < 32 {
            safeHex = Self.sha256(hex.isEmpty ? "wenshu-orphan-\(hex)" : hex)
                .prefix(32)
                .description
        } else {
            safeHex = hex
        }
        let safeChars = Array(safeHex.prefix(32))
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            let byte = UInt8(String(safeChars[i*2..<i*2+2]), radix: 16) ?? 0
            bytes[i] = byte
        }
        // RFC 4122 version 4 + variant 10 (= a random-ish UUID that survives uuidString
        // round-tripping through Foundation).
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }
}

extension ImportService {
    /// Set the cancellation flag (= the sheet's
    /// cancel button + the sheet's `.onDisappear`
    /// lifecycle hook both call this; = the
    /// orchestrator's `importFiles` loop polls
    /// `isCancelled` between per-task transitions;
    /// = the next dispatch step is a no-op once the
    /// flag is set; = the in-flight TaskGroup
    /// finishes whatever it has, then `importFiles`
    /// returns with the remaining tasks in
    /// `.pending`).
    func cancel() {
        isCancelled = true
    }

    /// Roll back the partial write-side effects of
    /// the current batch (= deletes every .md file
    /// the orchestrator wrote this run; = restores
    /// the prior `entities.json` content from the
    /// snapshot taken at `importFiles` start; =
    /// deletes the sidecar cache file). Apple
    /// canonical pattern: the rollback is
    /// best-effort + idempotent (= a missing file
    /// is a no-op; = a re-run of the same rollback
    /// doesn't double-delete).
    ///
    /// Boss 2026-10-09 directive: "取消退出时，所有
    /// 已经导入的内容回退清掉。类似 MAC OS 的系统
    /// 升级，取消等于放弃这个工作，不留痕". The
    /// "不留痕" requirement is strict (= cancel =
    /// nothing lands on disk; = the user can re-
    /// import from a clean state).
    func rollback() {
        // 1. Delete every .md file the orchestrator wrote this run (= reverse-order so
        // the dedup cache's stable-filename mapping doesn't matter; =
        // idempotent on missing files).
        for url in writtenURLs.reversed() {
            try? FileManager.default.removeItem(at: url)
        }
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
}

/// Reference-type wrapper around the dedup cache
/// (= the per-file pipeline runs 5 tasks in parallel
/// via TaskGroup; = each task mutates the cache via
/// `writeFile(... cache: inout ...)`; = Swift 6
/// forbids capturing `inout` across a TaskGroup
/// boundary; = the canonical fix is a class that
/// holds a single shared dictionary the orchestrator
/// can reach from any concurrent context). Apple
/// canonical pattern: a class-wrapper for
/// cross-actor mutable state (= the orchestrator's
/// `writtenURLs` is a value-type `Array<URL>` living
/// on the actor itself; = the `cache` is a value-type
/// `Dictionary` that needs the same kind of
/// "share-by-reference" treatment the test mocks
/// get).
fileprivate final class CacheBox: @unchecked Sendable {
    var value: [String: ImportService.CacheEntry]
    init(value: [String: ImportService.CacheEntry]) {
        self.value = value
    }
}

/// Reference-type wrapper around the per-task
/// state array (= the per-file pipeline runs 5
/// tasks in parallel via TaskGroup; = each task
/// mutates `tasksBox.value[i]` (= its own slot;
/// = the mutation is safe because each task only
/// touches a disjoint index; = the shared `value`
/// is read by the orchestrator's TaskGroup loop
/// for state-transition emits). Apple canonical
/// pattern: a class-wrapper for cross-actor
/// mutable state (= the same trick the `CacheBox`
/// uses; = both the dedup cache + the per-task
/// state array need the reference-type wrapper
/// because the per-file pipeline runs concurrently
/// across the 5 TaskGroup slots).
fileprivate final class TasksBox: @unchecked Sendable {
    var value: [ImportTask]
    init(value: [ImportTask]) {
        self.value = value
    }
}
extension ImportService {
    /// Run the per-file pipeline (= route → write → done)
    /// for a single task. The Semaphore-shaped TaskGroup
    /// in the importFiles loop calls this method.
    ///
    /// State transitions per file (= matches the boss's
    /// 2026-10-09 "分析、编辑、完成、失败" spec; = the
    /// per-file pipeline flips states back-to-back in
    /// sequence; = the sheet sees a single file's life
    /// cycle tick in real time):
    /// - .pending  → .routing (= already set by the
    ///   TaskGroup seed)
    /// - .routing  → .writing (= LLM call returned; = the
    ///   routing decision is the destination + tags +
    ///   title)
    /// - .writing  → .done (= the file lands on disk; = the
    ///   body is byte-equal to the source body)
    /// - any state → .failed (= the LLM call or the file
    ///   write threw; = the row's `errorMessage` carries
    ///   the cause)
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
        let activeProvider = WenshuAppDelegate.activeConnectorSlug()
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

    /// Phase 4: write the main file (= per the rewriteMode) + loop through
    /// the LLM's `extraFiles` and write each one to its folder. The state
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
    /// always uses the original verbatim; = .reorganize produces no main
    /// file body (= the agent's writeBookDoc tool owns the writes); =
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

    /// Write one extra file (= a single entry from `routing.extraFiles`).
    /// Logs the success/failure to the per-row activityLog (= the user
    /// sees a row per extra file). Failures are non-fatal (= they don't
    /// throw; = the row's `extraFilesDone` counter still advances).
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

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// feedback). Append a
    /// single line to a
    /// task's activityLog
    /// (= the per-row
    /// scrolling terminal-
    /// like view in the
    /// sheet). Capped at
    /// 30 entries (= old
    /// entries drop off;
    /// = 30 is enough to
    /// show the recent
    /// activity without
    /// scrolling forever).
    /// Also triggers
    /// onProgress so the
    /// sheet UI updates
    /// immediately.
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
    /// lookup (= scan an existing
    /// bookFolder for a .md whose first H1 heading
    /// matches the LLM-supplied title; = used by the
    /// orchestrator to decide between "create" (= no
    /// match) and "edit" (= match found) when writing
    /// a new .md file; = the boss's 2026-10-09
    /// round-13 directive "再次触发同名实体，只
    /// edit. 不建重名文档").
    ///
    /// Why scan the file body instead of trusting the
    /// filename: the filename derives from the title
    /// via `sanitizeFilename` (= path-unsafe chars
    /// stripped; = truncated to 80 chars; = the LLM
    /// might rephrase the title slightly between
    /// runs); = the FIRST H1 in the body is the
    /// canonical identity (= the LLM's most stable
    /// output; = survives filename normalization
    /// drift).
    ///
    /// Performance: O(n) over the folder's .md files;
    /// = n is bounded by the 5-way parallel import
    /// (= 456 files max in the boss's test corpus; =
    /// the folder scan is ~5-50 ms on a fast SSD; =
    /// 5-way parallel can amortize this if needed
    /// but a sync scan is acceptable for now; = the
    /// 5-way parallelism is in the LLM dispatch, not
    /// the file writes).
    static func findEntityByTitle(in folderURL: URL, title: String) -> URL? {
        let normalized = Self.normalizeTitle(title)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        ) else { return nil }
        for entry in entries where entry.pathExtension == "md" {
            // 1) First H1 in the body (= the canonical case for newly-imported files; =
            // the LLM body and the LLM title are consistent so the first
            // H1 matches the routing title).
            if let body = try? String(contentsOf: entry, encoding: .utf8) {
                for line in body.split(separator: "\n").prefix(20) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("# ") {
                        let h1 = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                        if Self.normalizeTitle(h1) == normalized {
                            return entry
                        }
                        break
                    }
                }
            }
            // 2) Filename heuristic fallback (= the boss sometimes hand-edits a file to
            // remove the H1 (= the boss's 2026-10-09 round-14 "还有 3 个重名"
            // feedback); = the file has no H1; = the dedup lookup would
            // return nil; = a re-import of the same entity would create a
            // duplicate file. The fallback strips the .md extension and
            // normalizes the filename (= a file named "五道将军民俗神档案.md"
            // normalizes to "五道将军民俗神档案"; = the LLM title "五道将军民俗神档案"
            // matches; = dedup hits even without an H1).
            let filenameNoExt = entry.deletingPathExtension().lastPathComponent
            if Self.normalizeTitle(filenameNoExt) == normalized {
                return entry
            }
        }
        return nil
    }

    /// Normalize a title for dedup comparison (= the
    /// canonical "trim + collapse whitespace + lowercase"
    /// transform; = matches the import's LLM output
    /// even when the LLM varies whitespace or
    /// capitalization across runs).
    static func normalizeTitle(_ s: String) -> String {
        let collapsed = s.replacingOccurrences(
            of: "[\\s]+",
            with: " ",
            options: .regularExpression
        )
        return collapsed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    /// filename basename (= the previous UUID-only
    /// filename made the sidebar cards unreadable).
    static func sanitizeFilename(raw: String, fallback: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
        var stripped: String = ""
        stripped.reserveCapacity(raw.unicodeScalars.count)
        for scalar in raw.unicodeScalars where !unsafe.contains(scalar) {
            stripped.unicodeScalars.append(scalar)
        }
        stripped = stripped.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty { return fallback }
        if stripped.count > 80 {
            stripped = String(stripped.prefix(80))
        }
        return stripped
    }
}
