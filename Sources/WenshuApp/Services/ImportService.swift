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
    /// 4-way parallel (= the same knob the existing
    /// `Librarian` agent uses for `--max-concurrent-tool-
    /// calls`; = the boss can retune it in one place).
    static let maxParallel = 4

    /// Where the sidecar cache lives (= per-library;
    /// = `<wsRoot>/.import-cache/`; = deletable by the user
    /// if they want a full re-import).

    /// One path's hash → the destination metadata. The
    /// orchestrator reads this at the dedup step; = writes
    /// a fresh entry after each successful import.
    private struct CacheEntry: Codable, Sendable {
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
    func importFiles(
        in sourceDir: URL,
        into target: ImportTarget,
        router: ImportRouter
    ) async -> [ImportTask] {
        // Phase 1: walk.
        let mdFiles = walkSourceDir(sourceDir)
        var tasks = mdFiles.map { ImportTask(sourcePath: $0.path) }
        // Phase 2: dedup. Read the cache once (= the
        // orchestrator batches the read so the per-file
        // lookup is O(1)).
        let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        let cache = readCache(cacheFile: cacheFile)
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
                // Idempotent re-import (= the source file
                // is byte-equal to a previously-imported
                // file; = skip the LLM dispatch and the
                // write step).
                tasks[i].state = .skipped
                tasks[i].destination = cached.destination
            }
        }
        // Filter out completed / skipped / failed; =
        // the dispatch set is the remaining tasks.
        let dispatchIndices = tasks.indices.filter {
            tasks[$0].state == .pending
        }
        // Phase 3: route + enrich (= concurrent, = 4-way
        // parallel via a Semaphore-shaped TaskGroup; = the
        // actor's serialized state protects the cache
        // write back from races).
        await withTaskGroup(of: (Int, Result<ImportRoutingResult, Error>).self) { (group: inout TaskGroup<(Int, Result<ImportRoutingResult, Error>)>) in
            var inFlight = 0
            var nextIndex = 0
            // Seed the first `maxParallel` tasks.
            while inFlight < Self.maxParallel, nextIndex < dispatchIndices.count {
                let i = dispatchIndices[nextIndex]
                tasks[i].state = .routing
                let input = ImportFileInput(
                    filePath: tasks[i].sourcePath,
                    targetBookId: target.bookId,
                    targetShelfId: target.shelfId
                )
                group.addTask {
                    do {
                        let r = try await router.route(input)
                        return (i, .success(r))
                    } catch {
                        return (i, .failure(error))
                    }
                }
                inFlight += 1
                nextIndex += 1
            }
            // Drain + refill.
            while let result = await group.next() {
                inFlight -= 1
                let (i, r) = result
                switch r {
                case .success(let routing):
                    tasks[i].routing = routing
                case .failure(let error):
                    tasks[i].state = .failed
                    tasks[i].errorMessage = "LLM 路由失败: \(error.localizedDescription)"
                }
                if nextIndex < dispatchIndices.count {
                    let j = dispatchIndices[nextIndex]
                    if tasks[j].state == .pending {
                        tasks[j].state = .routing
                        let input = ImportFileInput(
                            filePath: tasks[j].sourcePath,
                            targetBookId: target.bookId,
                            targetShelfId: target.shelfId
                        )
                        group.addTask {
                            do {
                                let r = try await router.route(input)
                                return (j, .success(r))
                            } catch {
                                return (j, .failure(error))
                            }
                        }
                        inFlight += 1
                        nextIndex += 1
                    }
                }
            }
        }
        // Phase 4: write (= the destination is decided by
        // the LLM in Phase 3; = the write step is a
        // pure function of the routing result + the
        // orchestrator's on-disk targets).
        for i in tasks.indices {
            guard tasks[i].state == .routing,
                  let routing = tasks[i].routing else { continue }
            tasks[i].state = .writing
            do {
                let body = try String(contentsOfFile: tasks[i].sourcePath, encoding: .utf8)
                try await writeFile(
                    body: body,
                    routing: routing,
                    contentHash: tasks[i].contentHash,
                    target: target,
                    sourcePath: tasks[i].sourcePath,
                    cache: cache
                )
                tasks[i].state = .done
                tasks[i].destination = routing.destination
            } catch {
                tasks[i].state = .failed
                tasks[i].errorMessage = "写入失败: \(error.localizedDescription)"
            }
        }
        // Persist the updated cache (= the orchestrator
        // re-reads the cache after each successful write
        // so concurrent imports don't lose entries; = the
        // actor's serialized state is the lock).
        writeCache(cacheFile: cacheFile, cache: cache)
        return tasks
    }

    // MARK: - Phase 1: walk

    /// Walk the source directory recursively. Returns the
    /// `.md` files (sorted for deterministic order; = the
    /// sheet's per-file strip renders in the same order
    /// every re-import).
    private func walkSourceDir(_ sourceDir: URL) -> [(path: String, url: URL)] {
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
            guard url.pathExtension.lowercased() == "md" else { continue }
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
        cache: [String: CacheEntry]
    ) async throws {
        switch routing.destination {
        case .bookFolder(let folder):
            // uuid = content-hash-prefixed (= the same
            // body always lands at the same on-disk
            // filename; = the idempotent re-import's
            // dedup key).
            let uuid = Self.uuidFromHash(contentHash)
            let folderURL = target.shelvesRoot
                .appendingPathComponent(target.shelfId.uuidString)
                .appendingPathComponent("books")
                .appendingPathComponent(target.bookId.uuidString)
                .appendingPathComponent(folder.directoryName)
            let fileURL = folderURL.appendingPathComponent("\(uuid.uuidString).md")
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
    }

    /// Where the reference came from (= used in the
    /// Reference.source field; = "导入: <source dir>"
    /// for now; = a future ticket can ask the user to
    /// label the source).
    private func sourceStringFromPath(target: ImportTarget) -> String {
        "导入: \(target.bookId.uuidString.prefix(8))"
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
    /// The .ws library root (= the same root that
    /// `LibraryLifecycleHook` constructed; = the single
    /// source of truth for "where the user's library is").
    let wsRoot: URL
    /// The book the user picked (= the book.id from
    /// `SidebarService.availableBooks()`).
    let bookId: UUID
    /// The shelf the target book lives under.
    let shelfId: UUID
    /// The reference library's `ReferenceStoring` (= the
    /// existing storage handle; = passed in by the
    /// `LibraryStores` factory at launch).
    let referenceStore: any ReferenceStoring

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
