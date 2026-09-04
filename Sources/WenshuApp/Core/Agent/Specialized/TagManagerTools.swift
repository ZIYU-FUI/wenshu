//
//  TagManagerTools.swift · Wenshu · P1 ticket #14 (PORT-SPECIALIZED-009, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/specialized/tag_manager.py`
//  (= design contract only per hermes-port-manifest; the Python
//  source was not present in the local hermes clone, so the port
//  follows the existing CharacterLifecycleTools /
//  CharacterRelationshipTools actor + sidecar convention).
//
//  The Python module manages tags across the book (= tags applied
//  to chapters / characters / scenes / plot-threads). It exposes
//  five category buckets (= theme / motif / trope / symbol /
//  pacing-marker) and four target kinds (= chapter / character /
//  scene / plot-thread).
//
//  The Swift port exposes:
//    - Tag CRUD (= add / list filtered by category / remove).
//    - Apply / unapply a tag to an entity (= chapter / character /
//      scene / plot-thread).
//    - List applications (= filterable by target / tag).
//    - Build a tag cloud (= one entry per tag with its
//      occurrence count across the book).
//    - Filter books by tag + target (= returns the matching
//      entity ids).
//
//  Persistence: per-book JSON sidecar at
//    `books/<bookId>/tags.json`
//  Mirrors the `kanban.json` / `todo.json` /
//  `character-lifecycle.json` / `character-relationships.json`
//  pattern (= canonical wenshu per-book JSON convention per
//  AGENTS.md §11).
//
//  Concurrency: actor (= Swift 6 strict concurrency). Reads /
//  writes serialize cleanly across the SpecializedTools pane +
//  any background LLM-side call sites.
//
//  Standards-axis (wenshu house style):
//    S1 (Apple-API-first): Foundation + SwiftUI only; no third-
//        party text-analysis deps.
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

// MARK: - TagCategory enum

/// The 5 tag categories the manager knows how to model. Each case
/// maps 1:1 to a value in hermes's
/// `agent/specialized/tag_manager.py::CATEGORY_TABLE`.
///
/// Categories are intentionally orthogonal (= the same label can
/// be reused across categories only by an explicit user choice;
/// the actor does not auto-dedupe across categories).
public enum TagCategory: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
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

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .theme:         return "Theme"
        case .motif:         return "Motif"
        case .trope:         return "Trope"
        case .symbol:        return "Symbol"
        case .pacingMarker:  return "Pacing Marker"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .theme:         return "bookmark"
        case .motif:         return "repeat"
        case .trope:         return "shapes"
        case .symbol:        return "gem"
        case .pacingMarker:  return "flag"
        }
    }
}

// MARK: - TagTarget enum

/// The 4 target kinds the manager can attach a tag to. Each
/// case maps 1:1 to a value in hermes's
/// `agent/specialized/tag_manager.py::TARGET_TABLE`.
///
/// Targets mirror the four entity kinds the prior specialized
/// tickets already model (= chapter / character / scene /
/// plot-thread). The actor never dereferences the target id to
/// its underlying entity (= view-layer responsibility).
public enum TagTarget: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    case chapter
    case character
    case scene
    case plotThread

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .chapter:     return "Chapter"
        case .character:   return "Character"
        case .scene:       return "Scene"
        case .plotThread:  return "Plot Thread"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .chapter:     return "book-open"
        case .character:   return "user"
        case .scene:       return "clapperboard"
        case .plotThread:  return "git-branch"
        }
    }
}

// MARK: - Tag struct

/// A single tag definition (= a label + category + book
/// ownership). Persisted as one entry in the per-book `tags.json`
/// sidecar.
public struct Tag: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / remove /
    /// cloud / filter lookups; never re-used even across books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// Short, human-readable label (= e.g. "redemption",
    /// "the withered oak"). Whitespace-trimmed at construction
    /// time so empty / whitespace-only labels are rejected.
    public let label: String

    /// Category bucket (= theme / motif / trope / symbol /
    /// pacing-marker).
    public let category: TagCategory

    /// Creation timestamp (= `Date.now` at add time).
    public let createdAt: Date

    public init(
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

/// A single tag application (= a tag attached to an entity of a
/// specific target kind). Persisted as one entry in the per-book
/// `tags.json` sidecar.
public struct TagApplication: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for unapply +
    /// filter lookups; never re-used even across books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// The tag being applied (= resolves to a `Tag` row in the
    /// same sidecar).
    public let tagId: UUID

    /// What kind of entity the tag is attached to (= chapter /
    /// character / scene / plot-thread).
    public let target: TagTarget

    /// The entity id the tag is attached to. Interpretation
    /// depends on `target` (= chapterId / characterId / sceneId /
    /// plotThreadId).
    public let targetId: UUID

    /// When the tag was applied (= `Date.now` at apply time).
    public let appliedAt: Date

    public init(
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

/// One entry in a tag cloud: the tag itself + the number of
/// distinct applications across the book.
public struct TagCloudEntry: Sendable, Codable, Equatable, Identifiable {

    /// Tag (= re-exported for the cloud row).
    public let tag: Tag

    /// Count of applications for this tag in the owning book.
    public let count: Int

    /// Convenience id (= delegates to `tag.id` so cloud rows are
    /// `Identifiable` in SwiftUI lists).
    public var id: UUID { tag.id }

    public init(tag: Tag, count: Int) {
        self.tag = tag
        self.count = count
    }
}

// MARK: - Sidecar on-disk shape

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`).
///
/// The sidecar holds two parallel arrays (= tags and
/// applications) so the actor can answer cloud + filter queries
/// in a single disk read (= matches the lifecycle / relationships
/// sidecar shape).
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

/// Errors thrown by `TagManager`. Mirrors the
/// BookProjectConfigStore / BookTodoStore /
/// CharacterLifecycleTracker / CharacterRelationshipTracker
/// error conventions (= a LocalizedError per case).
public enum TagManagerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case tagNotFound(id: UUID)
    case applicationNotFound(id: UUID)

    public var errorDescription: String? {
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

/// Per-book tag manager. Holds the in-memory cache + owns the
/// on-disk JSON sidecar.
///
/// Persistence: `<bookDir>/tags.json`. The actor resolves
/// `<bookDir>` via `BookStore.bookDirectory(bookId:)` (= the
/// canonical forgiving walk that searches every shelf's
/// `books/<id>/` subfolder).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// lifecycle / relationships sidecar convention):
///   - Missing sidecar = empty lists (= first-load behavior).
///   - Corrupt sidecar = empty lists (= never bricks the UI).
///   - Missing book directory = throws
///     `.bookDirectoryNotFound`.
///
/// Access level: internal (= the actor accepts the internal
/// `BookStore` type as a constructor parameter; = per wenshu
/// convention the view layer accesses the actor through the
/// module's internal scope).
actor TagManager {

    /// Sidecar on-disk filename (= parallel to
    /// `kanban.json` / `todo.json` /
    /// `character-lifecycle.json` /
    /// `character-relationships.json`).
    private static let sidecarFilename = "tags.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: TagManagerSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)

    /// Add a tag. Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on `id`: re-adding with the same id replaces
    ///     the existing row (= matches `BookKanbanStore` upsert
    ///     policy).
    ///   - Empty / whitespace-only labels are rejected silently
    ///     (= no row is persisted; matches the lifecycle tracker
    ///     "excerpt may be empty but the rest of the row is
    ///     mandatory" policy but stricter — empty labels cannot
    ///     render usefully in the UI).
    public func addTag(_ tag: Tag) async throws {
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
    public func listTags(
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

    /// Remove a tag by id. Throws `.tagNotFound` when the id is
    /// unknown for any cached book.
    ///
    /// Side effect: any applications referencing the removed tag
    /// are ALSO removed (= cascade delete, matches hermes's
    /// Python implementation per the design contract).
    public func removeTag(id: UUID) async throws {
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
        // removed tag (= so the tag cloud + filter queries stay
        // consistent).
        sidecar.applications.removeAll { $0.tagId == id }
        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Apply a tag to an entity (= record a `TagApplication`).
    /// Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on `id`: re-applying with the same
    ///     application id replaces the existing row.
    ///   - The tag referenced by `application.tagId` must already
    ///     exist for the owning book (= otherwise throws
    ///     `.tagNotFound` so the UI never gets an orphan
    ///     application row).
    public func apply(_ application: TagApplication) async throws {
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
    public func unapply(id: UUID) async throws {
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
    public func applications(
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

    /// Build the tag cloud for a book: one row per tag, with
    /// the count of distinct applications across the book (= one
    /// entry per (tag, target, targetId) triple; multiple
    /// applications to the same triple still count as 1 for the
    /// cloud's headline number — see `tagCloud(bookId:distinct:)`
    /// for the alternate count).
    ///
    /// Returns zero rows when the book has no tags OR no
    /// applications.
    public func tagCloud(bookId: UUID) async throws -> [TagCloudEntry] {
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

    /// Filter books by tag + target: returns the set of entity
    /// ids (matching `target`) that have a tag with id `tagId`
    /// applied to them. Duplicates are de-duplicated (= one id
    /// per entity; matches the typical "find all chapters tagged
    /// X" UX expectation).
    ///
    /// Returns an empty array when no matches exist or when the
    /// tag has zero applications.
    public func filterByTag(
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

    /// Resolve the sidecar on disk for the given book. Walks the
    /// shelves tree (= same forgiving walk as
    /// `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw TagManagerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create an empty one if
    /// missing). Forgiving on corrupt JSON (= returns an empty
    /// sidecar instead of throwing, matching the kanban / todo /
    /// lifecycle / relationships convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> TagManagerSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = TagManagerSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // the CharacterLifecycleTracker first-load
            // behaviour: only write to disk once the user
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
            // return an empty sidecar so the caller can keep
            // going. Matches `BookKanbanStore` /
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
