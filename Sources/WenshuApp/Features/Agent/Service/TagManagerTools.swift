// 
// … (= 46 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// MARK: - TagCategory enum
// … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / the actor does not auto-dedupe across categories).
enum TagCategory: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// A thematic label (= e.g. "redemption", "coming-of-age").
    case theme
    /// A recurring narrative motif (= e.g. "the broken mirror",
    /// "the colour red").
    case motif
    /// A genre-coded narrative pattern (= e.g. "love triangle",
    /// "chosen one").
    case trope
    /// A symbolic object / image (= e.g. "the withered oak").
    case symbol
    /// A pacing anchor (= e.g. "midpoint", "act-break-2").
    case pacingMarker

    var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    var displayName: String {
        switch self {
        case .theme:         return "Theme"
        case .motif:         return "Motif"
        case .trope:         return "Trope"
        case .symbol:        return "Symbol"
        case .pacingMarker:  return "Pacing Marker"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .theme:         return "bookmark"          // Lucide 'bookmark'
        case .motif:         return "repeat"            // Lucide 'repeat'
        case .trope:         return "square.on.circle"  // Lucide 'shapes'
        case .symbol:        return "diamond"           // Lucide 'gem'
        case .pacingMarker:  return "flag"              // Lucide 'flag'
        }
    }
}

// MARK: - TagTarget enum
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / its underlying entity (= view-layer responsibility).
enum TagTarget: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    case chapter
    case character
    case scene
    case plotThread

    var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    var displayName: String {
        switch self {
        case .chapter:     return "Chapter"
        case .character:   return "Character"
        case .scene:       return "Scene"
        case .plotThread:  return "Plot Thread"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .chapter:     return "book.pages"                  // Lucide 'book-open'
        case .character:   return "person"                      // Lucide 'user'
        case .scene:       return "movieclapper"                // Lucide 'clapperboard'
        case .plotThread:  return "arrow.triangle.branch"       // Lucide 'git-branch'
        }
    }
}

// MARK: - Tag struct
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / sidecar.
struct Tag: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / remove /
    /// cloud / filter lookups; never re-used even across books).
    let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    let bookId: UUID

    // / Short, human-readable label (= e.g. "redemption",
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / time so empty / whitespace-only labels are rejected.
    let label: String

    /// Category bucket (= theme / motif / trope / symbol /
    /// pacing-marker).
    let category: TagCategory

    /// Creation timestamp (= `Date.now` at add time).
    let createdAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        label: String,
        category: TagCategory,
        createdAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        // Trim + collapse internal whitespace for stable
        // dedupe + display.
        self.label = Tag.trimmed(label)
        self.category = category
        self.createdAt = createdAt
    }

    private static func trimmed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - TagApplication struct
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `tags.json` sidecar.
struct TagApplication: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for unapply +
    /// filter lookups; never re-used even across books).
    let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    let bookId: UUID

    /// The tag being applied (= resolves to a `Tag` row in the
    /// same sidecar).
    let tagId: UUID

    /// What kind of entity the tag is attached to (= chapter /
    /// character / scene / plot-thread).
    let target: TagTarget

    // / The entity id the tag is attached to. Interpretation
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / plotThreadId).
    let targetId: UUID

    /// When the tag was applied (= `Date.now` at apply time).
    let appliedAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        tagId: UUID,
        target: TagTarget,
        targetId: UUID,
        appliedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.tagId = tagId
        self.target = target
        self.targetId = targetId
        self.appliedAt = appliedAt
    }
}

// MARK: - TagCloudEntry struct
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / distinct applications across the book.
struct TagCloudEntry: Sendable, Codable, Equatable, Identifiable {

    /// Tag (= re-exported for the cloud row).
    let tag: Tag

    /// Count of applications for this tag in the owning book.
    let count: Int

    /// Convenience id (= delegates to `tag.id` so cloud rows are
    /// `Identifiable` in SwiftUI lists).
    var id: UUID { tag.id }

    init(tag: Tag, count: Int) {
        self.tag = tag
        self.count = count
    }
}

// MARK: - Sidecar on-disk shape
// … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / sidecar shape).
struct TagManagerSidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var tags: [Tag]
    var applications: [TagApplication]
    var updatedAt: Date

    init(
        bookId: UUID,
        tags: [Tag] = [],
        applications: [TagApplication] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.tags = tags
        self.applications = applications
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors
// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / error conventions (= a LocalizedError per case).
enum TagManagerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case tagNotFound(id: UUID)
    case applicationNotFound(id: UUID)

    var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "TagManager: book directory not found for id \(id.uuidString)"
        case .tagNotFound(let id):
            return "TagManager: tag \(id.uuidString) not found"
        case .applicationNotFound(let id):
            return "TagManager: application \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor
// … (= 22 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / module's internal scope).
actor TagManager {

    // / Sidecar on-disk filename (= parallel to
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `character-relationships.json`).
    private static let sidecarFilename = "tags.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: TagManagerSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     render usefully in the UI).
    func addTag(_ tag: Tag) async throws {
        guard !tag.label.isEmpty else { return }
        var sidecar = try await loadOrCreateSidecar(bookId: tag.bookId)
        // Replace if a row with the same id already exists.
        if let idx = sidecar.tags.firstIndex(where: { $0.id == tag.id }) {
            sidecar.tags[idx] = tag
        } else {
            sidecar.tags.append(tag)
        }
        sidecar.updatedAt = Date()
        cache[tag.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// All tags in a book (= filterable by category). When
    /// `category` is nil, returns every row.
    func listTags(
        bookId: UUID,
        category: TagCategory? = nil
    ) async throws -> [Tag] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.tags.filter { tag in
            category.map { $0 == tag.category } ?? true
        }
        // Stable display order: label ascending, then id
        // ascending as tiebreaker.
        return filtered.sorted { lhs, rhs in
            if lhs.label.localizedCaseInsensitiveCompare(rhs.label) != .orderedSame {
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // / Remove a tag by id. Throws `.tagNotFound` when the id is
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Python implementation per the design contract).
    func removeTag(id: UUID) async throws {
        var owningBookId: UUID?
        for (bookId, sidecar) in cache where sidecar.tags.contains(where: { $0.id == id }) {
            owningBookId = bookId
            break
        }
        guard let bookId = owningBookId else {
            throw TagManagerError.tagNotFound(id: id)
        }
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        guard let idx = sidecar.tags.firstIndex(where: { $0.id == id }) else {
            throw TagManagerError.tagNotFound(id: id)
        }
        sidecar.tags.remove(at: idx)
        // Cascade: drop applications that referenced the
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // consistent).
        sidecar.applications.removeAll { $0.tagId == id }
        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    // / Apply a tag to an entity (= record a `TagApplication`).
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     application row).
    func apply(_ application: TagApplication) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: application.bookId)
        guard sidecar.tags.contains(where: { $0.id == application.tagId }) else {
            throw TagManagerError.tagNotFound(id: application.tagId)
        }
        if let idx = sidecar.applications.firstIndex(where: { $0.id == application.id }) {
            sidecar.applications[idx] = application
        } else {
            sidecar.applications.append(application)
        }
        sidecar.updatedAt = Date()
        cache[application.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Remove an application by id. Throws `.applicationNotFound`
    /// when the id is unknown for any cached book.
    func unapply(id: UUID) async throws {
        var owningBookId: UUID?
        for (bookId, sidecar) in cache where sidecar.applications.contains(where: { $0.id == id }) {
            owningBookId = bookId
            break
        }
        guard let bookId = owningBookId else {
            throw TagManagerError.applicationNotFound(id: id)
        }
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        guard let idx = sidecar.applications.firstIndex(where: { $0.id == id }) else {
            throw TagManagerError.applicationNotFound(id: id)
        }
        sidecar.applications.remove(at: idx)
        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// List applications in a book (= filterable by target and /
    /// or tag). When both filters are nil, returns every row.
    func applications(
        bookId: UUID,
        target: TagTarget? = nil,
        tagId: UUID? = nil
    ) async throws -> [TagApplication] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.applications.filter { application in
            let targetMatches = target.map { $0 == application.target } ?? true
            let tagMatches = tagId.map { $0 == application.tagId } ?? true
            return targetMatches && tagMatches
        }
        // Stable display order: oldest applied first.
        return filtered.sorted { lhs, rhs in
            if lhs.appliedAt != rhs.appliedAt { return lhs.appliedAt < rhs.appliedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // / Build the tag cloud for a book: one row per tag, with
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / applications.
    func tagCloud(bookId: UUID) async throws -> [TagCloudEntry] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        // Group applications by tagId, then count distinct
        // (target, targetId) pairs.
        var triplesPerTag: [UUID: Set<String>] = [:]
        for application in sidecar.applications {
            let key = "\(application.target.rawValue)|\(application.targetId.uuidString)"
            triplesPerTag[application.tagId, default: []].insert(key)
        }
        let cloud: [TagCloudEntry] = sidecar.tags.compactMap { tag in
            guard let triple = triplesPerTag[tag.id], !triple.isEmpty else { return nil }
            return TagCloudEntry(tag: tag, count: triple.count)
        }
        // Stable sort: count descending, then label ascending.
        return cloud.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.tag.label.localizedCaseInsensitiveCompare(rhs.tag.label) == .orderedAscending
        }
    }

    // / Filter books by tag + target: returns the set of entity
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / tag has zero applications.
    func filterByTag(
        bookId: UUID,
        tagId: UUID,
        target: TagTarget
    ) async throws -> [UUID] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let ids = sidecar.applications
            .filter { $0.tagId == tagId && $0.target == target }
            .map { $0.targetId }
        // De-duplicate while preserving first-seen order (= so
        // tests get a stable output).
        var seen = Set<UUID>()
        var ordered: [UUID] = []
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }

    // MARK: - Internals
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw TagManagerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    // / Load the sidecar from disk (= or create an empty one if
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / lifecycle / relationships convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> TagManagerSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = TagManagerSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // actually adds a tag).
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(TagManagerSidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: log nothing (= no logger dependency);
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // `BookTodoStore` load paths.
            let empty = TagManagerSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors `BookProjectConfigStore.atomicWrite`).
    private func persistSidecar(_ sidecar: TagManagerSidecar) async throws {
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
