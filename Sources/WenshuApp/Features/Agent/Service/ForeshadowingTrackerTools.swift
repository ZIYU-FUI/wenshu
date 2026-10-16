// 
// … (= 48 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// MARK: - ForeshadowingStatus enum
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / "free-form transitions" behavior).
enum ForeshadowingStatus: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
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

    var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    var displayName: String {
        switch self {
        case .open:            return "Open"
        case .setup:           return "Setup"
        case .hinting:         return "Hinting"
        case .nearlyPaidOff:   return "Nearly Paid Off"
        case .paidOff:         return "Paid Off"
        case .abandoned:       return "Abandoned"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .open:            return "circle"             // Lucide 'circle'
        case .setup:           return "arrow.triangle.branch"  // Lucide 'git-fork'
        case .hinting:         return "arrow.triangle.branch"  // Lucide 'git-branch'
        case .nearlyPaidOff:   return "circle.dotted"      // Lucide 'circle.dotted'
        case .paidOff:         return "checkmark.circle"   // Lucide 'check-circle-2'
        case .abandoned:       return "xmark.circle"       // Lucide 'xmark.circle'
        }
    }

    // / Terminal statuses that mean the foreshadowing is no
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / it again).
    var isTerminal: Bool {
        switch self {
        case .paidOff, .abandoned: return true
        case .open, .setup, .hinting, .nearlyPaidOff: return false
        }
    }
}

// MARK: - Foreshadowing struct
// … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / complete setup-recall pair.
struct Foreshadowing: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / update /
    /// remove lookups; never re-used even across books).
    let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    let bookId: UUID

    // / Short, human-readable label (= e.g. "The silver dagger").
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `add` / `update` methods.
    let title: String

    /// Chapter id where the setup appears (= non-nil once the
    /// user has tagged the setup chapter).
    let setupChapterId: UUID?

    /// Short excerpt of the setup text. Trimmed at construction
    /// time.
    let setupExcerpt: String

    /// Chapter id where the payoff appears (= nil until the
    /// payoff is written).
    let payoffChapterId: UUID?

    /// Short excerpt of the payoff text (= nil until the payoff
    /// is written).
    let payoffExcerpt: String?

    /// Lifecycle status (= see ForeshadowingStatus).
    let status: ForeshadowingStatus

    /// Creation timestamp (= `Date.now` at add time).
    let createdAt: Date

    init(
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
// … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `Chapter`).
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
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / conventions (= a LocalizedError per case).
enum ForeshadowingTrackerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case foreshadowingNotFound(id: UUID)

    var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "ForeshadowingTracker: book directory not found for id \(id.uuidString)"
        case .foreshadowingNotFound(let id):
            return "ForeshadowingTracker: foreshadowing \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor
// … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
// /     `add` / `update` (= no row is persisted).
actor ForeshadowingTracker {

    // / Sidecar on-disk filename (= parallel to
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / / `setting-constraints.json`).
    private static let sidecarFilename = "foreshadowings.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: ForeshadowingSidecar] = [:]

    // / Internal init (= matches `PlotThreadTracker.init` /
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / be public).
    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - CRUD
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     strict policy on empty labels).
    func add(_ foreshadowing: Foreshadowing) async throws {
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

    // / Update an existing foreshadowing (= by id). Persists +
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     (= no row is persisted).
    func update(_ foreshadowing: Foreshadowing) async throws {
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

    // / Remove a foreshadowing by id. Throws
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / cached book.
    func remove(id: UUID) async throws {
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
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the filter is nil, returns every row.
    func list(
        bookId: UUID,
        status: ForeshadowingStatus? = nil
    ) async throws -> [Foreshadowing] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.foreshadowings.filter { row in
            status.map { $0 == row.status } ?? true
        }
        // Stable display order: open / hinting / nearlyPaidOff /
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // (= matches the "oldest unresolved first" UX).
        return filtered.sorted { lhs, rhs in
            let lhsPriority = ForeshadowingTracker.statusDisplayPriority(lhs.status)
            let rhsPriority = ForeshadowingTracker.statusDisplayPriority(rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // / Single-foreshadowing lookup by id. Returns `nil` (= NOT
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / matches the view layer's "optional row" idiom).
    func get(id: UUID) async throws -> Foreshadowing? {
        guard let bookId = try await getBookId(for: id) else { return nil }
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.foreshadowings.first { $0.id == id }
    }

    // MARK: - Analytics
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / first.
    func staleForeshadowings(
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

    // / Compute the payoff distance (= number of chapters
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / supplied arguments). Safe to call from any caller.
    func payoffDistance(
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

    // / Detect complete setup-recall pairs (= foreshadowings
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / (= oldest payoff first), then by title.
    func setupRecallPairs(
        bookId: UUID,
        allChapterIds: [UUID]
    ) async throws -> [Foreshadowing] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let pairs = sidecar.foreshadowings.filter { row in
            row.setupChapterId != nil && row.payoffChapterId != nil
        }
        return pairs.sorted { lhs, rhs in
            // Sort by payoff chapter index (= oldest payoff
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / what still needs work first" policy.
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
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / O(N_cached_books).
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

    // / Resolve the sidecar on disk for the given book. Walks
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw ForeshadowingTrackerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    // / Load the sidecar from disk (= or create an empty one if
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> ForeshadowingSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = ForeshadowingSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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