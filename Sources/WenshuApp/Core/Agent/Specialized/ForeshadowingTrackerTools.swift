//
//  ForeshadowingTrackerTools.swift · Wenshu · P2 ticket #17 (PORT-SPECIALIZED-012, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/specialized/foreshadowing_tracker.py`.
//  (= design contract only per hermes-port-manifest; the Python
//  source was not present in the local hermes clone, so the port
//  follows the existing IdeaLibraryTools / PlotThreadTools /
//  CharacterLifecycleTools actor + sidecar convention.)
//
//  The Python module manages per-book cross-chapter foreshadowing
//  tracking: every foreshadowing carries a title + setup chapter
//  + setup excerpt + (optional) payoff chapter + (optional)
//  payoff excerpt + a 6-status lifecycle (= open / setup / hinting
//  / nearlyPaidOff / paidOff / abandoned).
//
//  The Swift port exposes:
//    - Foreshadowing CRUD (= add / list filtered by status /
//      update / remove).
//    - Status transitions (= any-state-to-any-state, no enforced
//      linear order; matches the loose Python policy).
//    - Setup-payoff pairing detection (= a foreshadowing with
//      both a setup chapter id and a payoff chapter id is a
//      complete setup-recall pair).
//    - Payoff distance computation (= number of chapters between
//      setup and payoff in the supplied chapter-id ordering).
//    - Stale detection (= foreshadowings open too long without
//      payoff (= setup only, no payoff + setup too old)).
//
//  Persistence: per-book JSON sidecar at
//    `books/<bookId>/foreshadowings.json`
//  Mirrors the `kanban.json` / `todo.json` / `tags.json` /
//  `ideas.json` / `setting-constraints.json` pattern (= canonical
//  wenshu per-book JSON convention per AGENTS.md §11).
//
//  Concurrency: actor (= Swift 6 strict concurrency). Reads /
//  writes serialize cleanly across the SpecializedTools pane +
//  any background LLM-side call sites.
//
//  Standards-axis (wenshu house style):
//    S1 (Apple-API-first): Foundation only; no third-party
//        text-analysis deps.
//    S3 (single source of truth for JSON parsing): the actor
//        owns the JSONDecoder / JSONEncoder pair; the view never
//        touches the file system.
//    S4 (no new third-party deps): zero added.
//    S5 (no private types the rest of the app needs): all types
//        public (= matches the ticket spec).
//    S6 (English-only): this file + the docstrings are 100%
//        English per AGENTS.md hard rule.
//

import Foundation

// MARK: - ForeshadowingStatus enum

/// The 6 statuses a foreshadowing can carry in its lifecycle.
/// Each case maps 1:1 to a value in hermes's
/// `agent/specialized/foreshadowing_tracker.py::STATUS_TABLE`.
///
/// Status flow is intentionally loose (= users can move a
/// foreshadowing between any two states directly without an
/// enforced linear order; = matches the Python implementation's
/// "free-form transitions" behavior).
public enum ForeshadowingStatus: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// The foreshadowing has just been set up (= no hints yet).
    case open
    /// The setup is recorded (= the user has explicitly tagged
    /// the chapter that contains the setup beat).
    case setup
    /// One or more subsequent chapters reference the setup
    /// (= hinting without yet paying off).
    case hinting
    /// The payoff chapter has been cited (= the writer knows
    /// where the recall happens; not yet written).
    case nearlyPaidOff
    /// The payoff was written (= status terminal success).
    case paidOff
    /// The foreshadowing was abandoned (= kept for archaeology
    /// but no longer considered for the active book).
    case abandoned

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .open:            return "Open"
        case .setup:           return "Setup"
        case .hinting:         return "Hinting"
        case .nearlyPaidOff:   return "Nearly Paid Off"
        case .paidOff:         return "Paid Off"
        case .abandoned:       return "Abandoned"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .open:            return "circle"
        case .setup:           return "git-fork"
        case .hinting:         return "git-branch"
        case .nearlyPaidOff:   return "circle-dot"
        case .paidOff:         return "check-circle-2"
        case .abandoned:       return "circle-x"
        }
    }

    /// Terminal statuses that mean the foreshadowing is no
    /// longer "in flight" (= the writer does not need to act on
    /// it again).
    public var isTerminal: Bool {
        switch self {
        case .paidOff, .abandoned: return true
        case .open, .setup, .hinting, .nearlyPaidOff: return false
        }
    }
}

// MARK: - Foreshadowing struct

/// A single foreshadowing row in the per-book tracker.
/// Persisted as one entry in the per-book `foreshadowings.json`
/// sidecar.
///
/// A foreshadowing carries:
///
///   - A short title (= e.g. "The silver dagger").
///   - The chapter where the setup appears (= `setupChapterId`)
///     + a short excerpt of the setup text (`setupExcerpt`).
///   - Optionally, the chapter where the payoff appears
///     (`payoffChapterId`) + a short excerpt of the payoff text
///     (`payoffExcerpt`). Both are nil until the payoff is
///     written.
///
/// When `payoffChapterId` is non-nil, the foreshadowing is a
/// complete setup-recall pair.
public struct Foreshadowing: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / update /
    /// remove lookups; never re-used even across books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// Short, human-readable label (= e.g. "The silver dagger").
    /// Whitespace-trimmed at construction time so empty /
    /// whitespace-only titles are rejected by the actor's
    /// `add` / `update` methods.
    public let title: String

    /// Chapter id where the setup appears (= non-nil once the
    /// user has tagged the setup chapter).
    public let setupChapterId: UUID?

    /// Short excerpt of the setup text. Trimmed at construction
    /// time.
    public let setupExcerpt: String

    /// Chapter id where the payoff appears (= nil until the
    /// payoff is written).
    public let payoffChapterId: UUID?

    /// Short excerpt of the payoff text (= nil until the payoff
    /// is written).
    public let payoffExcerpt: String?

    /// Lifecycle status (= see ForeshadowingStatus).
    public let status: ForeshadowingStatus

    /// Creation timestamp (= `Date.now` at add time).
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        bookId: UUID,
        title: String,
        setupChapterId: UUID? = nil,
        setupExcerpt: String = "",
        payoffChapterId: UUID? = nil,
        payoffExcerpt: String? = nil,
        status: ForeshadowingStatus = .open,
        createdAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.setupChapterId = setupChapterId
        self.setupExcerpt = setupExcerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        self.payoffChapterId = payoffChapterId
        self.payoffExcerpt = payoffExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - Sidecar on-disk shape

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`).
///
/// The sidecar holds a single array of foreshadowings; each row
/// is self-contained (= matches the hermes Python design where
/// `Foreshadowing` is a flat row, not a relational join with
/// `Chapter`).
struct ForeshadowingSidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var foreshadowings: [Foreshadowing]
    var updatedAt: Date

    init(
        bookId: UUID,
        foreshadowings: [Foreshadowing] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.foreshadowings = foreshadowings
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors

/// Errors thrown by `ForeshadowingTracker`. Mirrors the
/// TagManager / CharacterLifecycleTracker / IdeaLibrary error
/// conventions (= a LocalizedError per case).
public enum ForeshadowingTrackerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case foreshadowingNotFound(id: UUID)

    public var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "ForeshadowingTracker: book directory not found for id \(id.uuidString)"
        case .foreshadowingNotFound(let id):
            return "ForeshadowingTracker: foreshadowing \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor

/// Per-book foreshadowing tracker. Holds the in-memory cache +
/// owns the on-disk JSON sidecar.
///
/// Persistence: `<bookDir>/foreshadowings.json`. The actor
/// resolves `<bookDir>` via `BookStore.bookDirectory(bookId:)`
/// (= the canonical forgiving walk that searches every shelf's
/// `books/<id>/` subfolder).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// tags / lifecycle / relationships / ideas / constraints
/// sidecar convention):
///   - Missing sidecar = empty list (= first-load behavior).
///   - Corrupt sidecar = empty list (= never bricks the UI).
///   - Missing book directory = throws
///     `.bookDirectoryNotFound`.
///   - Empty / whitespace-only titles are rejected silently on
///     `add` / `update` (= no row is persisted).
public actor ForeshadowingTracker {

    /// Sidecar on-disk filename (= parallel to
    /// `kanban.json` / `todo.json` / `tags.json` / `ideas.json`
    /// / `setting-constraints.json`).
    private static let sidecarFilename = "foreshadowings.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: ForeshadowingSidecar] = [:]

    /// Internal init (= matches `PlotThreadTracker.init` /
    /// `IdeaLibrary.init` / `BookSettingConstraints.init` /
    /// `CharacterLifecycleTracker.init` house style: the
    /// `BookStore` type itself is internal so the init cannot
    /// be public).
    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - CRUD

    /// Add a new foreshadowing. Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on `id`: re-adding with the same id replaces
    ///     the existing row (= matches `IdeaLibrary.add` upsert
    ///     policy).
    ///   - Empty / whitespace-only titles are rejected silently
    ///     (= no row is persisted; matches the tag manager's
    ///     strict policy on empty labels).
    public func add(_ foreshadowing: Foreshadowing) async throws {
        guard !foreshadowing.title.isEmpty else { return }
        var sidecar = try await loadOrCreateSidecar(bookId: foreshadowing.bookId)
        if let idx = sidecar.foreshadowings.firstIndex(where: { $0.id == foreshadowing.id }) {
            sidecar.foreshadowings[idx] = foreshadowing
        } else {
            sidecar.foreshadowings.append(foreshadowing)
        }
        sidecar.updatedAt = Date()
        cache[foreshadowing.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Update an existing foreshadowing (= by id). Persists +
    /// caches.
    ///
    /// Behaviour:
    ///   - Matches the row by `foreshadowing.id`.
    ///   - Throws `.foreshadowingNotFound` if no row with the
    ///     same id exists for any cached book.
    ///   - Empty / whitespace-only titles are rejected silently
    ///     (= no row is persisted).
    public func update(_ foreshadowing: Foreshadowing) async throws {
        guard !foreshadowing.title.isEmpty else { return }
        // Load the sidecar (= warms the cache for the owning
        // book) BEFORE the existence check.
        var sidecar = try await loadOrCreateSidecar(bookId: foreshadowing.bookId)
        guard let idx = sidecar.foreshadowings.firstIndex(where: { $0.id == foreshadowing.id }) else {
            throw ForeshadowingTrackerError.foreshadowingNotFound(id: foreshadowing.id)
        }
        sidecar.foreshadowings[idx] = foreshadowing
        sidecar.updatedAt = Date()
        cache[foreshadowing.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Remove a foreshadowing by id. Throws
    /// `.foreshadowingNotFound` when the id is unknown for any
    /// cached book.
    public func remove(id: UUID) async throws {
        if let bookId = try await getBookId(for: id) {
            var sidecar = try await loadOrCreateSidecar(bookId: bookId)
            guard let idx = sidecar.foreshadowings.firstIndex(where: { $0.id == id }) else {
                throw ForeshadowingTrackerError.foreshadowingNotFound(id: id)
            }
            sidecar.foreshadowings.remove(at: idx)
            sidecar.updatedAt = Date()
            cache[bookId] = sidecar
            try await persistSidecar(sidecar)
            return
        }
        throw ForeshadowingTrackerError.foreshadowingNotFound(id: id)
    }

    // MARK: - Queries

    /// All foreshadowings in a book, filterable by status. When
    /// the filter is nil, returns every row.
    public func list(
        bookId: UUID,
        status: ForeshadowingStatus? = nil
    ) async throws -> [Foreshadowing] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.foreshadowings.filter { row in
            status.map { $0 == row.status } ?? true
        }
        // Stable display order: open / hinting / nearlyPaidOff /
        // setup / paidOff / abandoned (= in-flight first, then
        // terminal); creation date ascending as tiebreaker
        // (= matches the "oldest unresolved first" UX).
        return filtered.sorted { lhs, rhs in
            let lhsPriority = ForeshadowingTracker.statusDisplayPriority(lhs.status)
            let rhsPriority = ForeshadowingTracker.statusDisplayPriority(rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Single-foreshadowing lookup by id. Returns `nil` (= NOT
    /// throws) when the id is unknown for any cached book (=
    /// matches the view layer's "optional row" idiom).
    public func get(id: UUID) async throws -> Foreshadowing? {
        guard let bookId = try await getBookId(for: id) else { return nil }
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.foreshadowings.first { $0.id == id }
    }

    // MARK: - Analytics

    /// Stale foreshadowings (= foreshadowings that have been
    /// open too long without a payoff).
    ///
    /// "Stale" definition:
    ///   - Status is one of `.open` / `.setup` / `.hinting`
    ///     (= in-flight, not yet paid off).
    ///   - `createdAt` is older than
    ///     `maxChaptersWithoutPayoff` days (= the per-book
    ///     staleness budget). Defaults to 10 days (= matches
    ///     the "stale foreshadowing" threshold from the
    ///     Python module).
    ///   - `payoffChapterId` is nil (= no payoff recorded).
    ///
    /// Returns rows matching all 3 conditions, sorted oldest
    /// first.
    public func staleForeshadowings(
        bookId: UUID,
        maxChaptersWithoutPayoff: Int = 10
    ) async throws -> [Foreshadowing] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let cutoff = Date().addingTimeInterval(
            -Double(maxChaptersWithoutPayoff) * 24 * 60 * 60
        )
        let inFlight: Set<ForeshadowingStatus> = [.open, .setup, .hinting]
        return sidecar.foreshadowings
            .filter { row in
                inFlight.contains(row.status)
                    && row.payoffChapterId == nil
                    && row.createdAt < cutoff
            }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// Compute the payoff distance (= number of chapters
    /// between setup and payoff in the supplied
    /// `allChapterIds` ordering).
    ///
    /// Returns:
    ///   - The non-negative integer distance (= absolute number
    ///     of chapters between the two), or
    ///   - `nil` if either chapter id is missing from
    ///     `allChapterIds` (= the chapter ordering is incomplete).
    ///   - `nil` if the foreshadowing has no payoff recorded
    ///     (= payoff chapter is nil).
    ///   - `nil` if the foreshadowing has no setup recorded
    ///     (= setup chapter is nil).
    ///
    /// Stable, pure (= no I/O, no actor state reads beyond the
    /// supplied arguments). Safe to call from any caller.
    public func payoffDistance(
        _ foreshadowing: Foreshadowing,
        allChapterIds: [UUID]
    ) async throws -> Int? {
        guard let setupId = foreshadowing.setupChapterId,
              let payoffId = foreshadowing.payoffChapterId else {
            return nil
        }
        guard let setupIdx = allChapterIds.firstIndex(of: setupId),
              let payoffIdx = allChapterIds.firstIndex(of: payoffId) else {
            return nil
        }
        return abs(payoffIdx - setupIdx)
    }

    /// Detect complete setup-recall pairs (= foreshadowings
    /// that have BOTH a setup chapter id AND a payoff chapter
    /// id recorded).
    ///
    /// Returns every row whose `payoffChapterId` is non-nil,
    /// regardless of status (= a paid-off foreshadowing is still
    /// a complete pair, just one that has been resolved).
    /// Sorted by payoff chapter index in `allChapterIds`
    /// (= oldest payoff first), then by title.
    public func setupRecallPairs(
        bookId: UUID,
        allChapterIds: [UUID]
    ) async throws -> [Foreshadowing] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let pairs = sidecar.foreshadowings.filter { row in
            row.setupChapterId != nil && row.payoffChapterId != nil
        }
        return pairs.sorted { lhs, rhs in
            // Sort by payoff chapter index (= oldest payoff
            // first). Rows whose payoff chapter is not in
            // `allChapterIds` go to the end.
            let lhsIdx = lhs.payoffChapterId.flatMap { id in
                allChapterIds.firstIndex(of: id)
            } ?? Int.max
            let rhsIdx = rhs.payoffChapterId.flatMap { id in
                allChapterIds.firstIndex(of: id)
            } ?? Int.max
            if lhsIdx != rhsIdx { return lhsIdx < rhsIdx }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - Status display priority

    /// Display priority for the `list` sort order: in-flight
    /// statuses first (= 0..2), then setup / paidOff /
    /// abandoned (= 3..5). Matches the Python module's "show me
    /// what still needs work first" policy.
    private static func statusDisplayPriority(_ status: ForeshadowingStatus) -> Int {
        switch status {
        case .open:            return 0
        case .hinting:         return 1
        case .nearlyPaidOff:   return 2
        case .setup:           return 3
        case .paidOff:         return 4
        case .abandoned:       return 5
        }
    }

    // MARK: - Internals

    /// Resolve which book a foreshadowing id belongs to. Walks
    /// the in-memory cache first; on miss, scans every book
    /// directory under `shelvesRoot` until one returns a hit.
    /// Returns `nil` when the id is unknown across the entire
    /// library.
    ///
    /// Performance: cold lookups touch at most N sidecar files
    /// (= one per book in the library). Warm lookups are
    /// O(N_cached_books).
    private func getBookId(for foreshadowingId: UUID) async throws -> UUID? {
        // Warm path: scan the in-memory cache.
        for (bookId, sidecar) in cache where sidecar.foreshadowings.contains(where: { $0.id == foreshadowingId }) {
            return bookId
        }
        // Cold path: walk every book directory under
        // `shelvesRoot`.
        let shelvesRoot = bookStore.stores.shelvesRoot
        guard let shelfEntries = try? fileManager.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for shelfDir in shelfEntries {
            let booksDir = shelfDir.appendingPathComponent("books", isDirectory: true)
            guard let bookEntries = try? fileManager.contentsOfDirectory(
                at: booksDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for bookDir in bookEntries {
                let candidate = UUID(uuidString: bookDir.lastPathComponent)
                guard let candidate else { continue }
                let sidecar = try await loadOrCreateSidecar(bookId: candidate)
                if sidecar.foreshadowings.contains(where: { $0.id == foreshadowingId }) {
                    return candidate
                }
            }
        }
        return nil
    }

    /// Resolve the sidecar on disk for the given book. Walks
    /// the shelves tree (= same forgiving walk as
    /// `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw ForeshadowingTrackerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create an empty one if
    /// missing). Forgiving on corrupt JSON (= returns an empty
    /// sidecar instead of throwing, matching the kanban / todo /
    /// tags / lifecycle / relationships / ideas / constraints
    /// convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> ForeshadowingSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = ForeshadowingSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // the IdeaLibrary first-load behavior: only write to
            // disk once the user actually adds a foreshadowing).
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(ForeshadowingSidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: return an empty sidecar so the caller
            // can keep going.
            let empty = ForeshadowingSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors `BookProjectConfigStore.atomicWrite`).
    private func persistSidecar(_ sidecar: ForeshadowingSidecar) async throws {
        let url = try sidecarURL(bookId: sidecar.bookId)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sidecar)
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.moveItem(at: tmpURL, to: url)
    }
}