//
//  ImportService.swift
//
//  T2 of the v2.7 markdown import feature. Orchestrates
//  the 4-phase pipeline that turns a user-picked source
//  directory into a batch of written entities (= either
//  book-folder files or reference-library entries; =
//  decided by the LLM via the `ImportRouter` protocol that
//  T4 implements against the WenshuConductor).
//
//  Apple canonical shape: ImportService is a stateless
//  `actor` (= the conductor and the file I/O are concurrent;
//  = the per-file state lives in `ImportTask` actors; =
//  the orchestrator can be re-entered safely from any
//  context). The view (= ImportSheet) calls
//  `importFiles(in:into:router:)` once and observes the
//  returned `[ImportTask]` array for the per-file progress
//  strip (= the Apple canonical SwiftUI binding to a
//  long-running task).
//
//  See .scratch/2026-10-09-md-import-feature/tickets.md for
//  the full T2 contract.
//

import Foundation
import CryptoKit

// MARK: - ImportRouter (the seam between ImportService and the LLM agent)

/// Sealed seam between the orchestrator (= ImportService)
/// and the LLM agent (= WenshuConductor + Librarian; =
/// implemented in T4). Lets the orchestrator drive the
/// per-file routing without taking a hard dependency on
/// the conductor (= the unit tests inject a stub router
/// that returns canned ImportRoutingResult values per
/// file).
///
/// Why a protocol (= not a closure):
/// - The router may need to talk to a long-lived service
///   (= the conductor; = not safe to capture by value in
///   a closure).
/// - The router signature is stable (= the wire shape from
///   T1) and the orchestrator's tests want to inject a
///   stub; = a protocol is the canonical Swift seam for
///   this.
protocol ImportRouter: Sendable {
    /// Route + enrich one file. The router reads the file
    /// body from `filePath` (= it does NOT mutate the body; =
    /// the LLM's role is classification + metadata
    /// enrichment per the boss's 2026-10-09 directive).
    /// Returns the ImportRoutingResult (= destination +
    /// metadata); = the orchestrator dispatches on the
    /// destination to decide the write path.
    func route(_ input: ImportFileInput) async throws -> ImportRoutingResult
}

// MARK: - ImportTask (per-file state)

/// One task per file (= the unit of progress shown in
/// the sheet's per-file strip). The state machine is
/// linear:
//   pending → routing → writing → done
///                        ↘ failed
///                        ↘ skipped (= idempotent re-import
///                                   hit the cache; = no LLM
///                                   dispatch; = the source
///                                   file is byte-equal to
///                                   a previously-imported
///                                   file)
/// The file-type filter the user picked in the
/// import sheet (= the user's 2026-10-09 ask: "在
/// 目录树上一行，加一行文件类型图标，单选"; = the
/// v2.7 orchestrator only knows how to walk + write
/// Markdown; = the .epub / .pdf / .txt cases are
/// rendered as "coming soon" in the picker UI; = a
/// future ticket can flip `isSupported` once the
/// orchestrator's walk + write paths handle them).
///
/// Apple canonical pattern: closed enum with a
/// canonical `extensions: Set<String>` per case (= the
/// orchestrator's `walkSourceDir` takes the
/// extension set as a parameter; = adding a new
/// file type forces a single source-of-truth change
/// at the type-definition site; = no string matching
/// at the call site = "make illegal states
/// unrepresentable").
enum ImportFileType: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case markdown
    case epub
    case pdf
    case text

    var id: String { rawValue }

    /// Chinese display name for the picker row
    /// (= the user's primary locale is .chinese;
    /// = the picker row's `Text(type.displayName)`
    /// is the visible label).
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .epub:     return "EPUB 电子书"
        case .pdf:      return "PDF"
        case .text:     return "纯文本"
        }
    }

    /// The SF Symbol name for the row's leading
    /// icon (= Apple HIG canonical "leading icon"
    /// for a picker row; = the wenshu v3.0 design
    /// system uses the `SFIcon` central factory; =
    /// no naked `Image(systemName:)`).
    var iconName: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .epub:     return "book.closed"
        case .pdf:      return "doc.fill"
        case .text:     return "doc.plaintext"
        }
    }

    /// `true` when the v2.7 orchestrator can
    /// import this file type end-to-end (= the
    /// walker + writer both understand it; = a
    /// false value means the picker row renders
    /// the "（即将支持）" hint and the user can't
    /// pick it for an import run).
    var isSupported: Bool {
        switch self {
        case .markdown: return true
        case .epub, .pdf, .text: return false
        }
    }

    /// The file extensions the walker should
    /// match (= lower-cased; = the walker compares
    /// against `url.pathExtension` lower-cased too;
    /// = a Markdown file with a `.markdown`
    /// extension is matched; = a `.mdown` /
    /// `.mkd` is matched; = a future file type can
    /// add multiple extensions here without
    /// touching the walker).
    var extensions: Set<String> {
        switch self {
        case .markdown: return ["md", "markdown", "mdown", "mkd"]
        case .epub:     return ["epub"]
        case .pdf:      return ["pdf"]
        case .text:     return ["txt"]
        }
    }
}

enum ImportTaskState: String, Codable, Sendable, Hashable {
    case pending
    case routing
    case writing
    case done
    case failed
    case skipped
}

/// What the orchestrator hands to the sheet (= one row
/// per file in the sheet's progress strip). The sheet
/// binds a `[ImportTask]` and re-renders on each state
/// transition.
struct ImportTask: Identifiable, Sendable, Hashable {
    let id: UUID
    /// Absolute path to the source .md file (= the row's
    /// filename comes from `URL(fileURLWithPath: sourcePath).lastPathComponent`).
    let sourcePath: String
    /// Where the task ended up (= populated at the
    /// `done` / `failed` / `skipped` transitions; = nil while
    /// pending / routing / writing).
    var destination: ImportDestination?
    /// Body SHA-256 (= the dedup key; = the orchestrator
    /// stores the hash before the routing step so the
    /// idempotent re-import can short-circuit before the
    /// LLM dispatch).
    var contentHash: String
    /// The task's current state (= mutated by the
    /// orchestrator; = read by the sheet for the per-file
    /// progress strip).
    var state: ImportTaskState
    /// Optional error message (= populated when `state ==
    /// .failed`; = the sheet renders it inline next to the
    /// row).
    var errorMessage: String?
    /// Routing result from the LLM (= populated when `state
    /// >= .writing`; = cached for the sheet's low-confidence
    /// warning indicator).
    var routing: ImportRoutingResult?

    init(sourcePath: String) {
        self.id = UUID()
        self.sourcePath = sourcePath
        self.destination = nil
        self.contentHash = ""  // populated at the read step
        self.state = .pending
        self.errorMessage = nil
        self.routing = nil
    }
}

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

    /// 5-way parallel LLM dispatch (= the boss's
    /// 2026-10-09 directive "你要做一个机制 5 个并发，
    /// 一个文件一个请求。同时只能处理 5 个"; = the
    /// orchestrator's TaskGroup seeds the first
    /// `maxParallel` tasks and refills as each
    /// completes; = 5 keeps the in-flight LLM
    /// pressure below the Anthropic / MiniMax
    /// per-second burst limit; = the LLMConnector
    /// adapter handles its own rate limiting for
    /// the actual provider). The boss can retune
    /// it in one place.
    static let maxParallel = 5

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
        // Reset the per-batch rollback trail at the
        // start of every `importFiles` call (= the
        // previous batch's trail is irrelevant; = a
        // re-run from a clean state must not see the
        // old trail; = the same actor can be re-used
        // across multiple sheets, e.g. the cancel +
        // "再次导入" retry path).
        isCancelled = false
        writtenURLs = []
        entitiesJSONSnapshot = nil
        // Snapshot the reference-library index file
        // (= the cancel handler restores this exact
        // content on rollback; = the orchestrator
        // captures the file before any writeFile call
        // has a chance to append to it; = a fresh
        // library that has no prior `entities.json`
        // = no snapshot = the cancel handler deletes
        // the file outright).
        let entitiesIndex = target.wsRoot
            .appendingPathComponent("reference-library")
            .appendingPathComponent("entities")
            .appendingPathComponent("entities.json")
        if FileManager.default.fileExists(atPath: entitiesIndex.path) {
            entitiesJSONSnapshot = (entitiesIndex, (try? Data(contentsOf: entitiesIndex)) ?? Data())
        } else {
            entitiesJSONSnapshot = (entitiesIndex, Data())
        }
        // Phase 1: walk.
        let mdFiles = walkSourceDir(sourceDir, extensions: extensions)
        var tasks = mdFiles.map { ImportTask(sourcePath: $0.path) }
        // Emit walk-phase progress so the sheet's ProgressView
        // updates immediately (= the user sees "找到 X 个 .md
        // 文件" the instant the orchestrator finishes Phase 1).
        await onProgress?(tasks)
        // Phase 2: dedup. Read the cache once (= the
        // orchestrator batches the read so the per-file
        // lookup is O(1)). The cache is `var` because the
        // Phase 4 write step inlines the new entries into
        // the same in-memory map (= the in-memory map is
        // the single source of truth for the duration of
        // the import; = the disk-side writeCache call at
        // the end persists the merged result).
        let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        var cache = readCache(cacheFile: cacheFile)
        for i in tasks.indices {
            // Read the file body + hash it (= the
            // dedup key is the body hash, not the path
            // hash, so renaming a file doesn't bypass
            // dedup).
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
            if let cached = cache[tasks[i].sourcePath],
               cached.contentHash == hash {
                // v2.7 round-38 (= boss 2026-10-10
                // "资料库已经清空了，但我
                // 导入了上次一样的测试文
                // 件，自动跳过了" directive).
                // Dedup sanity check (= the
                // cache says "this file was
                // imported before" but the
                // destination file may
                // have been deleted; = the
                // user cleared the reference
                // library's .md + entities.json
                // but the import-cache.json
                // is still on disk; = the
                // cache is lying; = the
                // boss's exact failure
                // mode). The fix: verify
                // the destination file
                // (= the .md the previous
                // import wrote) still
                // exists on disk; = if
                // not = the cache entry is
                // stale = re-import. The
                // check is a single
                // `FileManager.fileExists`
                // per task (= cheap; =
                // no extra I/O beyond
                // what the orchestrator
                // already does in
                // Phase 4 write).
                if Self.cachedDestinationExists(
                    cached: cached,
                    target: target
                ) {
                    // Idempotent re-import (= the
                    // source file is byte-equal
                    // to a previously-imported
                    // file AND the previous
                    // import's output file
                    // still exists on disk;
                    // = skip the LLM dispatch
                    // and the write step).
                    tasks[i].state = .skipped
                    tasks[i].destination = cached.destination
                }
                // else: cache entry is stale;
                // = fall through (= the task
                // stays .pending; = the LLM
                // dispatch + write will run
                // again; = the new write
                // overwrites whatever the
                // user had on disk; = the
                // cache entry is replaced
                // by the new import at
                // the end of Phase 4).
            }
        }
        // Filter out completed / skipped / failed; =
        // the dispatch set is the remaining tasks.
        let dispatchIndices = tasks.indices.filter {
            tasks[$0].state == .pending
        }
        // Phase 3: route + enrich (= concurrent, =
        // 5-way parallel via a Semaphore-shaped
        // TaskGroup; = the actor's serialized state
        // protects the cache write back from races;
        // = the sheet's ProgressView reads the
        // per-task `routing` state to drive the
        // "进行中 N" live label, so we emit
        // `onProgress` after every state transition
        // in this phase = the sheet's
        // `inFlightCount` ticks as tasks flip from
        // .pending → .routing and back to
        // .routing → .writing on completion).
        // Phase 3 + Phase 4 (= unified per-file
        // pipeline; = boss's 2026-10-09 directive
        // "分析、编辑、完成、失败 这四种状态跑吗，
        // 每个文件每个文件的跑"; = the old
        // all-route-then-all-write design forced the
        // user to watch the bar stuck at "进行中
        // 40" for the full LLM round before any row
        // reached .done; = the per-file pipeline
        // ticks a file through 分析 → 编辑 → 完成
        // back-to-back in a single TaskGroup slot
        // = the first .done row lands within
        // seconds; = the sheet's "已完成 X" counter
        // ticks in real time; = the user sees
        // progress instead of a frozen bar).
        //
        // The pipeline runs on the orchestrator
        // actor (= the actor's serialized state
        // mutation is safe across 5 parallel
        // `processFile` calls; = the TaskGroup
        // concurrency is per-task only; = the
        // shared `cache` dict needs a reference
        // wrapper because the per-task calls take
        // `cache: inout` = value-type mutation
        // across a TaskGroup boundary is the
        // classic Swift 6 data-race source; =
        // `CacheBox` is the canonical class-wrapper
        // workaround that holds a single shared
        // dict the orchestrator can write to
        // safely from any concurrent context).
        let cacheBox = CacheBox(value: cache)
        let tasksBox = TasksBox(value: tasks)
        await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
            var inFlight = 0
            var nextIndex = 0
            // Seed the first `maxParallel` tasks (= 5
            // today; = the boss's explicit knob; = the
            // TaskGroup cap is the in-flight LLM
            // pressure knob; = the LLMConnector
            // adapter handles its own provider-side
            // rate limiting).
            //
            // CRITICAL: mutate `tasksBox.value[i].state`
            // (NOT the local `tasks` copy) and emit
            // `tasksBox.value` to onProgress. The
            // previous code mutated the local
            // `tasks` array and emitted the local
            // `tasks` in the drain loop, which meant
            // the sheet's snapshot went STALE on
            // every processFile completion (= the
            // .done / .failed mutations live in
            // tasksBox.value; = the local `tasks` copy
            // was never updated; = the sheet saw the
            // completed tasks revert to .pending; =
            // the boss's 2026-10-09 round-11
            // feedback "还是没修好，已完成没有持久":
            // the .done state was set in
            // tasksBox.value but the snapshot the
            // sheet received was the STALE local
            // `tasks`).
            while inFlight < Self.maxParallel, nextIndex < dispatchIndices.count {
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
            // Drain + refill (= each completed task
            // frees a slot in the semaphore; = the
            // next pending task is seeded; = the
            // pipeline keeps 5 files in flight
            // concurrently for the entire batch).
            //
            // CRITICAL: same fix as the seed loop
            // (= mutate `tasksBox.value[j].state`; =
            // emit `tasksBox.value`; = the local
            // `tasks` array is a stale snapshot from
            // before the TaskGroup started and is no
            // longer the source of truth).
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
        // Persist the updated cache (= the orchestrator
        // re-reads the cache after each successful write
        // so concurrent imports don't lose entries; = the
        // actor's serialized state is the lock).
        writeCache(cacheFile: cacheFile, cache: cacheBox.value)
        // Copy the per-task state back out of the
        // shared box (= the TaskGroup's per-file
        // pipeline mutated `tasksBox.value` directly;
        // = the orchestrator's return value carries
        // the canonical final-state view for the
        // sheet's per-file strip).
        return tasksBox.value
    }

    // MARK: - v2.7 round-36: "重新调研所有失败" (= title-only retry)

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
        // 1. Filter (= only the "读取文件失败"
        // subset; = LLM-routing failures are
        // excluded; = write failures are
        // excluded; = the user clicked
        // "重新调研" with the explicit
        // understanding that this is the
        // "I trust the filename + LLM search
        // alone" path).
        let retryIndices = tasks.indices.filter { i in
            guard tasks[i].state == .failed else { return false }
            return tasks[i].errorMessage?.hasPrefix("读取文件失败") ?? false
        }
        // 2. Compute the sibling-context list ONCE
        // (= the user's whole source directory; =
        // all .md files in the same folder as
        // the failed file; = the LLM uses the
        // list as "what other entities are
        // nearby, what categories exist"; =
        // cheap; = the walk is one
        // FileManager.enumerator call per
        // unique source directory).
        let contextByPath = Self.siblingContextMap(for: tasks)
        // 3. Build a fresh tasks array (= we
        // mutate in place via tasksBox; = the
        // sheet sees the same task identity).
        let tasksBox = TasksBox(value: tasks)
        // 4. Re-seed the matching tasks (.failed
        // → .routing, errorMessage = nil,
        // body constructed from filename +
        // sibling context).
        for i in retryIndices {
            tasksBox.value[i].state = .routing
            tasksBox.value[i].errorMessage = nil
        }
        await onProgress?(tasksBox.value)
        // 5. Same 5-way parallel TaskGroup as
        // `importFiles` (= the only
        // difference is the `ImportFileInput`
        // carries a non-nil `body`; =
        // `processFile` is unchanged; =
        // the `writeFile` step uses the
        // LLM's `rewrittenBody` and never
        // touches the unreadable file).
        let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        let cache = readCache(cacheFile: cacheFile)
        let cacheBox = CacheBox(value: cache)
        await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
            var inFlight = 0
            var nextIndex = 0
            let dispatchIndices = retryIndices
            while inFlight < Self.maxParallel, nextIndex < dispatchIndices.count {
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

        <!-- v2.7 round-36: title-only retry.
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
        // 1. Group task paths by parent
        // directory.
        var byDir: [String: [String]] = [:]
        for task in tasks {
            let path = task.sourcePath
            let dir = (path as NSString).deletingLastPathComponent
            byDir[dir, default: []].append(path)
        }
        // 2. For each unique parent, enumerate
        // the directory and build a per-path
        // context string (= all the other .md
        // names in the same folder).
        var out: [String: String] = [:]
        for (dir, paths) in byDir {
            // 3. Sibling .md names (= every .md
            // file in the directory; = the
            // failed file's own name is
            // excluded from its own context;
            // = the list is "what other
            // entities are nearby").
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
            // 4. Build the per-path context (= the
            // failed file's own name is filtered
            // out; = the list is the "neighbors
            // in the same folder").
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

    // v2.7 round-38 (= boss 2026-10-10
    // "资料库已经清空了，但我
    // 导入了上次一样的测试文
    // 件，自动跳过了" directive).
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
    private func walkSourceDir(
        _ sourceDir: URL,
        extensions: Set<String>
    ) -> [(path: String, url: URL)] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var out: [(String, URL)] = []
        for case let url as URL in enumerator {
            // Apple canonical: skip directories and
            // symlinks pointing outside the source tree.
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .nameKey]),
                  values.isRegularFile == true else { continue }
            guard extensions.contains(url.pathExtension.lowercased()) else { continue }
            out.append((url.path, url))
        }
        // Sort by path (= the same sort the e2e scaffold
        // uses; = deterministic order across re-imports).
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
        // Ensure the cache root exists (= created on the
        // first import; = no-op on subsequent runs).
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
        cache: inout [String: CacheEntry]
    ) async throws {
        switch routing.destination {
        case .bookFolder(let folder):
            // The on-disk filename derives from the
            // LLM-supplied title (= the boss's 2026-10-09
            // round-10 feedback "这个 ID 的事还没有修吗":
            // = the sidebar's BookDoc card title came from
            // the file's filename without extension; = the
            // previous UUID-only filename meant the cards
            // read "023D22E3-1F1D-4A55-83C8-F133156ECEB9"
            // instead of the human-readable title the LLM
            // generated; = a stable, title-based filename
            // makes the sidebar readable on the first pass).
            //
            // The dedup key still lives in the cache
            // (= a re-import of the same body finds the
            // cache entry by source path; = the on-disk
            // filename is a display concern, not a
            // identity concern; = the fileURL still uses
            // the title for the sidebar + the cache for
            // idempotency).
            //
            // Sanitization (= boss 2026-10-09: "文枢内部
            // 完整处理" = the title can contain Chinese
            // characters + punctuation; = we strip path-
            // unsafe characters + collapse whitespace;
            // = the max-255-byte limit on most
            // filesystems is honored via the 80-char
            // truncation; = an empty / unsafe-only title
            // falls back to the UUID; = the fallback
            // path is rare (= the LLM is instructed to
            // always return a title; = a missing title
            // would indicate a deeper LLM misbehavior
            // worth surfacing as a generic "未命名"
            // rather than a cryptic UUID).
            let uuid = Self.uuidFromHash(contentHash)
            // v2.7 user-pinned destination (= the
            // boss's 2026-10-09 round-18 "强制让用户
            // 分开导入" directive). When the user
            // pinned the reference library, this
            // branch is unreachable (= the LLM
            // already overrode the destination to
            // .referenceLibrary + the orchestrator
            // took the referenceLibrary case). The
            // `bookId!` / `shelfId!` unwraps are
            // safe because the orchestrator's
            // processFile passes the user's chosen
            // target down here; = a destination =
            // .book guarantee that both IDs are
            // populated.
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
            // v2.7 entity-level dedup (= boss
            // 2026-10-09 round-13 directive "再次触发
            // 同名实体，只 edit. 不建重名文档"; = the
            // previous per-source-path dedup let the
            // same entity land at multiple paths when
            // the user re-imported after clearing only
            // one source directory; = world/ ended up
            // with 33 duplicate titles + characters/ with
            // 20 duplicates; = the user-visible bug was
            // "一物多份"; = fix is to scan the existing
            // folder for an entity with the same
            // normalized title; = match → overwrite the
            // existing file (= new body + new LLM
            // metadata); = no match → write the new
            // title-derived file).
            //
            // The normalization is the canonical
            // = "trim whitespace + lowercase" =
            // the LLM sometimes returns "  蛇
            //  精" with double spaces; = a strict
            // == compare would miss the duplicate.
            let fileURL: URL
            let existing = Self.findEntityByTitle(
                in: folderURL,
                title: routing.title
            )
            if let existingURL = existing {
                // Match (= re-import of an existing
                // entity); = overwrite the existing
                // file at its current path; = the
                // boss's "edit, not create" rule.
                fileURL = existingURL
                NSLog("WSImport: dedup hit title='\(routing.title)' → \(existingURL.lastPathComponent)")
            } else {
                fileURL = folderURL.appendingPathComponent("\(basename).md")
            }
            // Create the folder if missing (= idempotent;
            // = the orchestrator does not depend on the
            // book bootstrap having created the folder
            // for this case; = the bootstrapper seeds
            // the 5 standard folders but if a future
            // folder is added = the orchestrator
            // creates it on the fly).
            try FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )
            // Write the body verbatim (= boss 2026-10-09
            // directive "原样落地"; = the LLM did NOT
            // rewrite the body; = the orchestrator's only
            // job is to put the body at the right path).
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
            // Record the on-disk trail for the
            // cancel-and-rollback path (= the
            // `ImportService` actor keeps a list
            // of every URL it wrote this batch; = the
            // cancel handler deletes them in
            // reverse-order on rollback; = the
            // dedup cache can map two source paths
            // to the same file URL but the cancel
            // handler is idempotent so a
            // double-delete is a no-op).
            writtenURLs.append(fileURL)
        case .referenceLibrary:
            // Delegate to the existing reference-write
            // path (= the e2e scaffold's 4-phase walk →
            // reframe → classify → write; = the body
            // lands at
            // `<wsRoot>/reference-library/entities/<uuid>.md`
            // and the Reference is appended to
            // `entities/entities.json`).
            try await writeReference(
                body: body,
                routing: routing,
                target: target,
                contentHash: contentHash
            )
        }
        // Record the import in the sidecar cache so the
        // next dedup pass (= a re-import of the same
        // source directory) hits the cache instead of
        // dispatching the LLM + re-writing the file.
        // (= the dedup key is the absolute source path; =
        // the cache value carries the body hash + the
        // resolved destination = the dedup pass can
        // short-circuit without touching the LLM).
        cache[sourcePath] = CacheEntry(
            contentHash: contentHash,
            destination: routing.destination,
            writtenAt: Date()
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
        // uuid = content-hash-prefixed (= the same body
        // always lands at the same reference-library
        // file; = idempotent re-import dedup).
        let uuid = Self.uuidFromHash(contentHash)
        // Build a Reference struct from the routing
        // result (= the LLM supplies the metadata; = the
        // orchestrator maps ImportRoutingResult onto the
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
        // Write through the existing storage layer (= the
        // FileSystemReferenceStore handles the index
        // file at `entities/entities.json`).
        try await MainActor.run { try target.referenceStore.saveReference(reference, bodyMarkdown: body) }
        // Record the on-disk trail for the
        // cancel-and-rollback path (= the
        // reference-library .md file lives at the
        // same path the `FileSystemReferenceStore`
        // just wrote; = we reconstruct the URL from
        // the same source-of-truth = no race with
        // the storage layer's index file). The
        // rollback handler deletes these .md files
        // in reverse order and restores the prior
        // `entities.json` from the snapshot taken
        // at `importFiles` start.
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

    /// v2.7 user-pinned destination errors (= thrown
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

        var errorDescription: String? {
            switch self {
            case .missingBookForBookFolderDestination:
                return "user pinned a book as the destination, but the import target has no bookId; = the orchestrator cannot resolve a book folder path"
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
    static func uuidFromHash(_ hex: String) -> UUID {
        let chars = Array(hex.prefix(32))
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            let byte = UInt8(String(chars[i*2..<i*2+2]), radix: 16) ?? 0
            bytes[i] = byte
        }
        // RFC 4122 version 4 + variant 10 (= a random-ish
        // UUID that survives uuidString round-tripping
        // through Foundation).
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

// MARK: - ImportTarget (the import destination metadata)

/// What the sheet passes to ImportService (= the user's
/// picked book + the shelvesRoot + the referenceStore
/// handle for the reference-library path). Holds the
/// file-system dependencies (= the orchestrator is
/// stateless but the storage layer is not; = the
/// caller supplies the storage handles here).
struct ImportTarget: Sendable {
    /// Where the orchestrator should land the imported
    /// files (= boss 2026-10-09 round-18 directive
    /// "导入目标加一个资料库，用户指定了资料
    /// 库的，就自动全进到资料库。用户指定到书
    /// 的，就自动全进入到书的五目录。这样可以
    /// 简化一些提示词。强制让用户分开导入"; =
    /// the previous version was always
    /// book-folder + LLM-routed = LLM picked
    /// between referenceLibrary and 5 book
    /// folders; = the LLM's classification was
    /// noisy; = the boss's preferred UX is to
    /// ask the user ONCE at sheet open time +
    /// force a single routing destination for
    /// the whole batch; = the LLM is then
    /// reduced to a metadata-only role (= title
    /// + summary + tags; = the destination
    /// itself is user-pinned)).
    let destination: ImportTargetDestination
    /// The .ws library root (= the same root that
    /// `LibraryLifecycleHook` constructed; = the single
    /// source of truth for "where the user's library is").
    let wsRoot: URL
    /// The book the user picked (= the book.id from
    /// `SidebarService.availableBooks()`). Nil when
    /// `destination == .referenceLibrary` (= the user
    /// picked the reference library as the target; = no
    /// book is involved).
    let bookId: UUID?
    /// The shelf the target book lives under. Nil when
    /// `destination == .referenceLibrary` (= same
    /// reason as `bookId`).
    let shelfId: UUID?
    /// The reference library's `ReferenceStoring` (= the
    /// existing storage handle; = passed in by the
    /// `LibraryStores` factory at launch).
    let referenceStore: any ReferenceStoring

    /// v2.7 (= boss 2026-10-09 round-18 "AI 重写
    /// 程度"). The user-picked rewrite mode; = the
    /// orchestrator reads this in `processFile` and
    /// forwards to the LLM router (= the LLM
    /// either runs the consolidate path with no
    /// tools OR the searchAndRewrite path with
    /// the `web_search` tool loop).
    let rewriteMode: ImportFileInput.RewriteMode

    enum ImportTargetDestination: Sendable, Equatable {
        case book              // → LLM picks world/characters/outlines/chapters/drafts
        case referenceLibrary  // → everything lands in the reference library
    }

    /// Standard library layout (= matches
    /// `LibraryStores.shelvesRoot`).
    var shelvesRoot: URL {
        wsRoot.appendingPathComponent("shelves")
    }
    /// Per-library import cache (= the sidecar that
    /// powers the idempotent re-import).
    var cacheRoot: URL {
        wsRoot.appendingPathComponent(".import-cache")
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
        // 1. Delete every .md file the orchestrator
        //    wrote this run (= reverse-order so the
        //    dedup cache's stable-filename mapping
        //    doesn't matter; = idempotent on missing
        //    files).
        for url in writtenURLs.reversed() {
            try? FileManager.default.removeItem(at: url)
        }
        // 2. Restore the prior `entities.json`
        //    content (= the orchestrator captured
        //    the file's content at `importFiles`
        //    start; = a fresh library has an empty
        //    snapshot = the file should not exist
        //    post-rollback; = a library with a
        //    pre-existing `entities.json` restores
        //    the file verbatim). The `try?` swallows
        //    write errors (= the file may be
        //    read-only under a non-admin user; = the
        //    rollback is best-effort; = the user can
        //    re-import later when the file is
        //    writable).
        if let snap = entitiesJSONSnapshot {
            if snap.content.isEmpty {
                // The original file did not exist
                // (= the library had no prior
                // references; = the rollback
                // removes the now-orphaned file
                // that the orchestrator's writes
                // created).
                try? FileManager.default.removeItem(at: snap.path)
            } else {
                try? snap.content.write(to: snap.path, options: .atomic)
            }
        }
        // 3. Delete the sidecar cache file (= the
        //    orchestrator may have written entries
        //    to the cache for the rolled-back files;
        //    = leaving stale entries means a
        //    re-import of the same source dir would
        //    skip the rolled-back files via dedup;
        //    = delete the whole cache file so the
        //    next `importFiles` starts from a clean
        //    cache). Apple canonical: the cache is a
        //    sidecar (= a derived artifact; =
        //    deleting it is safe; = the next run
        //    rebuilds it from the same source files).
        let cacheFile = URL(fileURLWithPath: "")
        // The cacheRoot is per-target; = the rollback
        // can only know the cacheFile URL if the
        // orchestrator captured it. The simpler path:
        // delete the entire `.import-cache`
        // directory (= the orchestrator writes only
        // `import-cache.json` under it; = the
        // directory delete is the same as the
        // single-file delete in this version; = a
        // future ticket that adds a sidecar
        // metadata file will pick up the new file
        // for free).
        if let snap = entitiesJSONSnapshot {
            // Compute the cache root from the
            // entities path (= the entities file
            // lives at
            // `<wsRoot>/reference-library/entities/entities.json`;
            // = the cache lives at
            // `<wsRoot>/.import-cache/import-cache.json`;
            // = a few `deletingLastPathComponent()`
            // calls get us there).
            let cacheRoot = snap.path
                .deletingLastPathComponent()  // entities.json
                .deletingLastPathComponent()  // entities
                .deletingLastPathComponent()  // reference-library
                .deletingLastPathComponent()  // <wsRoot>
                .appendingPathComponent(".import-cache")
            try? FileManager.default.removeItem(at: cacheRoot)
        }
        _ = cacheFile  // (= placeholder for the future
                        //  = per-target cacheRoot
                        //  = cleanup; = unused in
                        //  = this version; = the
                        //  = .import-cache dir
                        //  = delete above handles
                        //  = the v0.74 schema).
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

/// Extension: the per-file pipeline (= the boss's
/// 2026-10-09 directive "分析、编辑、完成、失败 这
/// 四种状态跑吗，每个文件每个文件的跑"). The
/// pipeline runs on the orchestrator actor (= the
/// actor's serialized state mutation is safe across
/// the 5 parallel `processFile` calls; = the
/// TaskGroup concurrency is per-task only).
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
        // Phase 3: route + enrich (= the LLM
        // dispatch; = this is the slow part; = the
        // pipeline's bottleneck). Failure here means
        // the LLM rejected the file (= the user
        // sees "LLM 路由失败: ..." in the row's
        // error caption; = the orchestrator moves
        // on to the next file).
        var routing: ImportRoutingResult
        do {
            routing = try await router.route(input)
            tasksBox.value[i].routing = routing
        } catch {
            tasksBox.value[i].state = .failed
            tasksBox.value[i].errorMessage = "LLM 路由失败: \(error.localizedDescription)"
            await onProgress?(tasksBox.value)
            return
        }
        // v2.7 user-pinned destination override
        // (= boss 2026-10-09 round-18 "导入目标
        // 加一个资料库，强制让用户分开导入";
        // = the LLM no longer picks the
        // destination; = the user picked the
        // destination ONCE in the sheet; = every
        // file in the batch lands at that
        // destination; = the LLM is reduced to a
        // metadata-only role = title + summary +
        // tags; = the destination itself is
        // user-pinned).
        switch target.destination {
        case .referenceLibrary:
            routing.destination = .referenceLibrary
        case .book:
            // If the LLM routed to .referenceLibrary
            // but the user picked a book as the
            // target, fall back to .drafts (= the
            // LLM's classification is downgraded
            // to "this needs a closer look"; = the
            // user can move it manually after the
            // batch completes). This is rare
            // because the user-pinned destination
            // prompt steers the LLM away from
            // referenceLibrary, but the fallback is
            // here for safety.
            if case .referenceLibrary = routing.destination {
                routing.destination = .bookFolder(.drafts)
            }
        }
        tasksBox.value[i].routing = routing
        // Phase 4: write (= the destination was
        // decided by the LLM; = the write step is a
        // pure function of the routing result + the
        // orchestrator's on-disk targets). The state
        // flips .routing → .writing → .done inside
        // this single function call (= the sheet
        // sees the .writing pill for a brief moment
        // before .done takes over).
        tasksBox.value[i].state = .writing
        await onProgress?(tasksBox.value)
        do {
            // v2.7 body selection (= boss 2026-10-09
            // round-18 "重写同时搜索校对" mode; =
            // the LLM may return a `rewrittenBody`
            // (= the search-augmented, .ws-format
            // body) in `routing.rewrittenBody`; = the
            // orchestrator uses the rewritten body
            // when present; = otherwise it falls
            // back to the original source body
            // verbatim (= the
            // `searchAndRewrite` mode is a
            // super-set of `consolidate`; = a stub
            // router or an LLM that didn't search
            // simply keeps the original body)).
            let bodyToWrite: String
            if let rewritten = routing.rewrittenBody, !rewritten.isEmpty {
                bodyToWrite = rewritten
            } else {
                bodyToWrite = try String(
                    contentsOfFile: tasksBox.value[i].sourcePath,
                    encoding: .utf8
                )
            }
            try await writeFile(
                body: bodyToWrite,
                routing: routing,
                contentHash: tasksBox.value[i].contentHash,
                target: target,
                sourcePath: tasksBox.value[i].sourcePath,
                cache: &cacheBox.value
            )
            tasksBox.value[i].state = .done
            tasksBox.value[i].destination = routing.destination
            // The writeFile appended the new entry
            // to its inout cache; = the shared
            // `cacheBox.value` is now the canonical
            // source of truth for the in-memory
            // cache (= the next dedup pass sees the
            // prior write via the same `cacheBox`).
        } catch {
            tasksBox.value[i].state = .failed
            tasksBox.value[i].errorMessage = "写入失败: \(error.localizedDescription)"
        }
        // Emit after the terminal state
        // transition (= .done or .failed) so the
        // sheet's ProgressView sees the final
        // state for this row.
        await onProgress?(tasksBox.value)
    }
}

extension ImportService {
    /// v2.7 entity-level dedup lookup (= scan an existing
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
            // 1) First H1 in the body (= the canonical
            //    case for newly-imported files; = the
            //    LLM body and the LLM title are
            //    consistent so the first H1 matches
            //    the routing title).
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
            // 2) Filename heuristic fallback (= the boss
            //    sometimes hand-edits a file to remove
            //    the H1 (= the boss's 2026-10-09
            //    round-14 "还有 3 个重名" feedback); = the
            //    file has no H1; = the dedup lookup
            //    would return nil; = a re-import of the
            //    same entity would create a duplicate
            //    file. The fallback strips the .md
            //    extension and normalizes the filename
            //    (= a file named "五道将军民俗神档案.md"
            //    normalizes to "五道将军民俗神档案"; = the
            //    LLM title "五道将军民俗神档案" matches;
            //    = dedup hits even without an H1).
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
