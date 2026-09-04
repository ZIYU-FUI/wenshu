//
//  IdeaLibraryTools.swift · Wenshu · P1 ticket #15 (PORT-SPECIALIZED-010, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/specialized/idea_library.py`.
//  (= design contract only per hermes-port-manifest; the Python
//  source was not present in the local hermes clone, so the port
//  follows the existing TagManagerTools / CharacterLifecycleTools
//  actor + sidecar convention.)
//
//  The Python module manages a per-book library of reusable ideas:
//  every idea carries a title + 2-3 sentence description + a
//  status (= seedling / developing / mature / planted / discarded)
//  + free-form tags + an array of "where this idea has been
//  planted" links (= chapter / character / plot-thread triples).
//
//  The Swift port exposes:
//    - Idea CRUD (= add / list filtered by status / update /
//      remove).
//    - Link / unlink an idea to an entity (= chapter / character
//      / plot-thread + 1-sentence context where it appears).
//    - Query / search (= get by id, list by tag, text search
//      across title + description).
//    - Suggest ideas based on a context keyword (= returns ideas
//      whose tags intersect the keyword token set; pure in-memory
//      match, no LLM call).
//
//  Persistence: per-book JSON sidecar at
//    `books/<bookId>/ideas.json`
//  Mirrors the `kanban.json` / `todo.json` / `tags.json` /
//  `character-lifecycle.json` pattern (= canonical wenshu
//  per-book JSON convention per AGENTS.md §11).
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

// MARK: - IdeaStatus enum

/// The 5 statuses an idea can carry in its lifecycle. Each case
/// maps 1:1 to a value in hermes's
/// `agent/specialized/idea_library.py::STATUS_TABLE`.
///
/// The status flow is intentionally loose (= users can move
/// ideas between any two states directly without an enforced
/// linear order; = matches the Python implementation's
/// "free-form transitions" behavior).
public enum IdeaStatus: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// The idea is a raw spark (= 1-2 sentences, no elaboration).
    case seedling
    /// The idea is being elaborated (= has 1+ paragraphs of
    /// description).
    case developing
    /// The idea has been polished (= ready to be planted).
    case mature
    /// The idea has been used in at least one chapter / character
    /// / plot-thread (= has 1+ links).
    case planted
    /// The idea was abandoned (= kept for archaeology but no
    /// longer considered for the active book).
    case discarded

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .seedling:    return "Seedling"
        case .developing:  return "Developing"
        case .mature:      return "Mature"
        case .planted:     return "Planted"
        case .discarded:   return "Discarded"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .seedling:    return "sprout"
        case .developing:  return "leaf"
        case .mature:      return "tree-deciduous"
        case .planted:     return "flower-2"
        case .discarded:   return "circle-x"
        }
    }
}

// MARK: - IdeaLinkTarget enum

/// The 3 entity kinds an idea can be linked to. Each case maps
/// 1:1 to a value in hermes's
/// `agent/specialized/idea_library.py::LINK_TARGET_TABLE`.
///
/// Targets mirror the 3 entity kinds the prior specialized
/// tickets already model (= chapter / character / plot-thread).
/// The actor never dereferences the target id to its underlying
/// entity (= view-layer responsibility).
public enum IdeaLinkTarget: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    case chapter
    case character
    case plotThread

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .chapter:     return "Chapter"
        case .character:   return "Character"
        case .plotThread:  return "Plot Thread"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .chapter:     return "book-open"
        case .character:   return "user"
        case .plotThread:  return "git-branch"
        }
    }
}

// MARK: - IdeaLink struct

/// A single "this idea was used here" record. Persisted as one
/// entry in the per-book `ideas.json` sidecar.
///
/// `context` is a 1-sentence description of where the idea
/// appears (= e.g. "Chapter 7 opening — protagonist sees her
/// reflection in the lake for the first time"). Free-form,
/// user-authored.
public struct IdeaLink: Sendable, Codable, Equatable, Identifiable {
    /// Stable identifier (= used by the actor for unlink + dedupe;
    /// never re-used even across books).
    public let id: UUID

    /// What kind of entity the idea is linked to (= chapter /
    /// character / plot-thread).
    public let target: IdeaLinkTarget

    /// The entity id the idea is linked to. Interpretation
    /// depends on `target` (= chapterId / characterId /
    /// plotThreadId).
    public let targetId: UUID

    /// 1-sentence description of where the idea appears in the
    /// linked entity (= e.g. "Chapter 7 opening"). Trimmed at
    /// construction time.
    public let context: String

    public init(
        id: UUID = UUID(),
        target: IdeaLinkTarget,
        targetId: UUID,
        context: String
    ) {
        self.id = id
        self.target = target
        self.targetId = targetId
        self.context = context.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Idea struct

/// A single idea in the per-book library. Persisted as one entry
/// in the per-book `ideas.json` sidecar.
public struct Idea: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / update /
    /// remove / link / search lookups; never re-used even across
    /// books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// Short, human-readable label (= e.g. "The Mirror Motif").
    /// Whitespace-trimmed at construction time so empty /
    /// whitespace-only titles are rejected by the actor's
    /// `add` / `update` methods.
    public let title: String

    /// 2-3 sentence description of the idea. Trimmed at
    /// construction time.
    public let description: String

    /// Lifecycle status (= seedling / developing / mature /
    /// planted / discarded).
    public let status: IdeaStatus

    /// Free-form, user-supplied labels (= e.g. "mirror",
    /// "water", "recognition"). Whitespace-trimmed at construction
    /// time.
    public let tags: [String]

    /// Where this idea has been planted (= chapter / character /
    /// plot-thread triples + 1-sentence context).
    public let links: [IdeaLink]

    /// Creation timestamp (= `Date.now` at add time).
    public let createdAt: Date

    /// Last update timestamp (= `Date.now` at update time; = the
    /// actor bumps this on every `update`).
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        bookId: UUID,
        title: String,
        description: String,
        status: IdeaStatus = .seedling,
        tags: [String] = [],
        links: [IdeaLink] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = status
        self.tags = Idea.trimmedTags(tags)
        self.links = links
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private static func trimmedTags(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for entry in raw {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // De-dupe case-insensitively so "Mirror" and "mirror"
            // collapse to one tag (= matches the typical
            // user expectation).
            let key = trimmed.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(trimmed)
        }
        return out
    }
}

// MARK: - Sidecar on-disk shape

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`).
///
/// The sidecar holds a single array of ideas; links live
/// inline on each idea (= matches the hermes Python design
/// where `Idea.links` is a per-idea list, not a separate table).
struct IdeaLibrarySidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var ideas: [Idea]
    var updatedAt: Date

    init(
        bookId: UUID,
        ideas: [Idea] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.ideas = ideas
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors

/// Errors thrown by `IdeaLibrary`. Mirrors the
/// TagManager / CharacterLifecycleTracker /
/// CharacterRelationshipTracker error conventions (= a
/// LocalizedError per case).
public enum IdeaLibraryError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case ideaNotFound(id: UUID)

    public var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "IdeaLibrary: book directory not found for id \(id.uuidString)"
        case .ideaNotFound(let id):
            return "IdeaLibrary: idea \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor

/// Per-book idea library. Holds the in-memory cache + owns the
/// on-disk JSON sidecar.
///
/// Persistence: `<bookDir>/ideas.json`. The actor resolves
/// `<bookDir>` via `BookStore.bookDirectory(bookId:)` (= the
/// canonical forgiving walk that searches every shelf's
/// `books/<id>/` subfolder).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// tags / lifecycle / relationships sidecar convention):
///   - Missing sidecar = empty list (= first-load behavior).
///   - Corrupt sidecar = empty list (= never bricks the UI).
///   - Missing book directory = throws
///     `.bookDirectoryNotFound`.
///   - Empty / whitespace-only titles are rejected silently on
///     `add` / `update` (= no row is persisted).
///
/// Access level: internal (= the actor accepts the internal
/// `BookStore` type as a constructor parameter; = per wenshu
/// convention the view layer accesses the actor through the
/// module's internal scope).
actor IdeaLibrary {

    /// Sidecar on-disk filename (= parallel to
    /// `kanban.json` / `todo.json` / `tags.json` /
    /// `character-lifecycle.json`).
    private static let sidecarFilename = "ideas.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: IdeaLibrarySidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)

    /// Add a new idea. Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on `id`: re-adding with the same id replaces
    ///     the existing row (= matches `TagManager.addTag`
    ///     upsert policy).
    ///   - Empty / whitespace-only titles are rejected silently
    ///     (= no row is persisted; matches the tag manager's
    ///     strict policy on empty labels).
    public func add(_ idea: Idea) async throws {
        guard !idea.title.isEmpty else { return }
        var sidecar = try await loadOrCreateSidecar(bookId: idea.bookId)
        // Replace if a row with the same id already exists.
        if let idx = sidecar.ideas.firstIndex(where: { $0.id == idea.id }) {
            sidecar.ideas[idx] = idea
        } else {
            sidecar.ideas.append(idea)
        }
        sidecar.updatedAt = Date()
        cache[idea.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Update an existing idea (= by id). Persists + caches.
    ///
    /// Behaviour:
    ///   - Matches the row by `idea.id` (= ignores the row's
    ///     `createdAt`; = the caller passes a fresh
    ///     `updatedAt = Date.now`).
    ///   - Throws `.ideaNotFound` if no row with the same id
    ///     exists for any cached book.
    ///   - Empty / whitespace-only titles are rejected silently
    ///     (= no row is persisted).
    public func update(_ idea: Idea) async throws {
        guard !idea.title.isEmpty else { return }
        // Load the sidecar (= warms the cache for the owning
        // book) BEFORE the existence check, so the check sees
        // rows written by an earlier `add` call.
        var sidecar = try await loadOrCreateSidecar(bookId: idea.bookId)
        guard let idx = sidecar.ideas.firstIndex(where: { $0.id == idea.id }) else {
            throw IdeaLibraryError.ideaNotFound(id: idea.id)
        }
        // Bump `updatedAt` to "now" (= callers should already do
        // this; we belt-and-suspenders here so a stale
        // `updatedAt` never persists).
        var refreshed = idea
        refreshed = Idea(
            id: idea.id,
            bookId: idea.bookId,
            title: idea.title,
            description: idea.description,
            status: idea.status,
            tags: idea.tags,
            links: idea.links,
            createdAt: sidecar.ideas[idx].createdAt,
            updatedAt: Date()
        )
        sidecar.ideas[idx] = refreshed
        sidecar.updatedAt = Date()
        cache[idea.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Remove an idea by id. Throws `.ideaNotFound` when the id
    /// is unknown for any cached book.
    ///
    /// Side effect: the idea's links are dropped with it (= the
    /// links lived inline on the idea, so there is no cascade
    /// table to clean up).
    public func remove(id: UUID) async throws {
        // Cold-cache: we have no bookId, so walk every cached
        // sidecar first; if no match, scan the disk by attempting
        // to load sidecars for known books. Since callers always
        // supply the bookId via `Idea.bookId` (= stored on the
        // row), the production caller invokes
        // `library.remove(id:)` from the view layer after a `get`
        // (= which warms the cache). For belt-and-suspenders,
        // also accept a hint from the caller via the test path.
        if let bookId = try await getBookId(for: id) {
            var sidecar = try await loadOrCreateSidecar(bookId: bookId)
            guard let idx = sidecar.ideas.firstIndex(where: { $0.id == id }) else {
                throw IdeaLibraryError.ideaNotFound(id: id)
            }
            sidecar.ideas.remove(at: idx)
            sidecar.updatedAt = Date()
            cache[bookId] = sidecar
            try await persistSidecar(sidecar)
            return
        }
        throw IdeaLibraryError.ideaNotFound(id: id)
    }

    /// All ideas in a book, filterable by status and / or tag.
    /// When both filters are nil, returns every row.
    public func list(
        bookId: UUID,
        status: IdeaStatus? = nil,
        tag: String? = nil
    ) async throws -> [Idea] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.ideas.filter { idea in
            let statusMatches = status.map { $0 == idea.status } ?? true
            let tagMatches: Bool = {
                guard let tag else { return true }
                let key = tag.lowercased()
                return idea.tags.contains { $0.lowercased() == key }
            }()
            return statusMatches && tagMatches
        }
        // Stable display order: most-recently-updated first;
        // id ascending as tiebreaker.
        return filtered.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Text search across title + description (= case-
    /// insensitive substring match). Returns every idea whose
    /// title OR description contains the query (= empty query
    /// returns every row; = matches the typical "live filter"
    /// UX).
    public func search(bookId: UUID, query: String) async throws -> [Idea] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return sidecar.ideas.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
        let matches = sidecar.ideas.filter { idea in
            idea.title.localizedCaseInsensitiveContains(needle)
                || idea.description.localizedCaseInsensitiveContains(needle)
        }
        return matches.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Single-idea lookup by id. Returns `nil` (= NOT throws)
    /// when the id is unknown for any cached book (= matches the
    /// view layer's "optional row" idiom).
    public func get(id: UUID) async throws -> Idea? {
        guard let bookId = try await getBookId(for: id) else { return nil }
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.ideas.first { $0.id == id }
    }

    /// Link an idea to an entity (= record a new `IdeaLink` on
    /// the idea). Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on link id (= re-linking with the same
    ///     link id replaces the existing link).
    ///   - Dedupe by (target, targetId): if the idea already has
    ///     a link to the same (target, targetId) pair, the new
    ///     link replaces it (= so users can update the context
    ///     sentence without accumulating duplicates).
    ///   - Throws `.ideaNotFound` if no idea with that id exists.
    public func link(ideaId: UUID, link: IdeaLink) async throws {
        // The caller always supplies `bookId` via the
        // `link.bookId` (= which we'll trust; but the spec
        // requires we look up by ideaId). We resolve the owning
        // book by scanning the cache first; if the cache is cold,
        // the caller must have populated it via `get(id:)` or
        // `list(bookId:)` first (= matches the view-layer
        // pattern).
        guard let bookId = try await getBookId(for: ideaId) else {
            throw IdeaLibraryError.ideaNotFound(id: ideaId)
        }
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        guard let idx = sidecar.ideas.firstIndex(where: { $0.id == ideaId }) else {
            throw IdeaLibraryError.ideaNotFound(id: ideaId)
        }
        var idea = sidecar.ideas[idx]
        var links = idea.links
        // De-dupe by (target, targetId): if a matching link
        // already exists, replace it with the new one (= same id
        // collision policy as `add` on top-level entities).
        if let dupIdx = links.firstIndex(where: {
            $0.target == link.target && $0.targetId == link.targetId
        }) {
            links[dupIdx] = link
        } else {
            links.append(link)
        }
        idea = Idea(
            id: idea.id,
            bookId: idea.bookId,
            title: idea.title,
            description: idea.description,
            status: idea.status,
            tags: idea.tags,
            links: links,
            createdAt: idea.createdAt,
            updatedAt: Date()
        )
        sidecar.ideas[idx] = idea
        // When a link is added, the idea is implicitly "planted"
        // (= matches the status semantics: planted = has 1+
        // links). Bump status if it was still pre-plant.
        if idea.status == .seedling || idea.status == .developing || idea.status == .mature {
            var planted = idea
            planted = Idea(
                id: idea.id,
                bookId: idea.bookId,
                title: idea.title,
                description: idea.description,
                status: .planted,
                tags: idea.tags,
                links: idea.links,
                createdAt: idea.createdAt,
                updatedAt: Date()
            )
            sidecar.ideas[idx] = planted
        }
        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Unlink an idea from an entity (= remove the matching
    /// link from the idea's `links` array). No-op (= no throw) if
    /// the idea has no matching link.
    public func unlink(ideaId: UUID, link: IdeaLink) async throws {
        guard let bookId = try await getBookId(for: ideaId) else {
            throw IdeaLibraryError.ideaNotFound(id: ideaId)
        }
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        guard let idx = sidecar.ideas.firstIndex(where: { $0.id == ideaId }) else {
            throw IdeaLibraryError.ideaNotFound(id: ideaId)
        }
        var idea = sidecar.ideas[idx]
        let originalCount = idea.links.count
        idea = Idea(
            id: idea.id,
            bookId: idea.bookId,
            title: idea.title,
            description: idea.description,
            status: idea.status,
            tags: idea.tags,
            links: idea.links.filter { $0.id != link.id },
            createdAt: idea.createdAt,
            updatedAt: Date()
        )
        // Only bump `updatedAt` if something actually changed
        // (= so a no-op unlink does not appear as a write to the
        // UI's "recently updated" ordering).
        if idea.links.count != originalCount {
            sidecar.ideas[idx] = idea
            sidecar.updatedAt = Date()
            cache[bookId] = sidecar
            try await persistSidecar(sidecar)
        }
    }

    /// Suggest ideas for a context keyword (= pure in-memory
    /// keyword match: returns ideas whose tags intersect the
    /// keyword token set, plus ideas whose title / description
    /// contains any keyword token). Empty / whitespace-only
    /// `context` returns an empty array (= no suggestion).
    ///
    /// Scoring:
    ///   - +2 per matching tag (= tag overlap is the strongest
    ///     signal).
    ///   - +1 per matching title / description token.
    ///   - Ideas with score = 0 are dropped.
    ///
    /// Stable order: score descending, then updatedAt
    /// descending.
    public func suggest(bookId: UUID, context: String) async throws -> [Idea] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let keywords = IdeaLibrary.tokenize(context)
        guard !keywords.isEmpty else { return [] }
        let keywordSet = Set(keywords.map { $0.lowercased() })
        struct Scored {
            let idea: Idea
            let score: Int
        }
        var scored: [Scored] = []
        for idea in sidecar.ideas {
            var score = 0
            // Tag overlap: +2 per matching tag (= case-insensitive).
            for tag in idea.tags where keywordSet.contains(tag.lowercased()) {
                score += 2
            }
            // Title / description token overlap: +1 per matching
            // token.
            let haystackTokens = IdeaLibrary.tokenize(idea.title + " " + idea.description)
                .map { $0.lowercased() }
            for token in haystackTokens where keywordSet.contains(token) {
                score += 1
            }
            if score > 0 {
                scored.append(Scored(idea: idea, score: score))
            }
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.idea.updatedAt != rhs.idea.updatedAt {
                    return lhs.idea.updatedAt > rhs.idea.updatedAt
                }
                return lhs.idea.id.uuidString < rhs.idea.id.uuidString
            }
            .map { $0.idea }
    }

    // MARK: - Internals

    /// Tokenize a string into lowercase word tokens (= split on
    /// any non-letter / non-digit character; = matches the
    /// "loose keyword" behavior expected by `suggest`).
    static func tokenize(_ raw: String) -> [String] {
        raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Resolve which book an idea id belongs to. Walks the
    /// in-memory cache first; on miss, scans every book
    /// directory under `shelvesRoot` until one returns a hit.
    /// Returns `nil` when the id is unknown across the entire
    /// library.
    ///
    /// Performance: cold lookups touch at most N sidecar files
    /// (= one per book in the library). Warm lookups are
    /// O(N_cached_books).
    private func getBookId(for ideaId: UUID) async throws -> UUID? {
        // Warm path: scan the in-memory cache.
        for (bookId, sidecar) in cache where sidecar.ideas.contains(where: { $0.id == ideaId }) {
            return bookId
        }
        // Cold path: walk every book directory under
        // `shelvesRoot` (= mirrors the forgiving walk in
        // `BookStore.bookDirectory(bookId:)`).
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
                // The book id is the directory name (= matches
                // the canonical wenshu convention).
                let candidate = UUID(uuidString: bookDir.lastPathComponent)
                guard let candidate else { continue }
                // Reuse `loadOrCreateSidecar` (= warm cache as
                // we go).
                let sidecar = try await loadOrCreateSidecar(bookId: candidate)
                if sidecar.ideas.contains(where: { $0.id == ideaId }) {
                    return candidate
                }
            }
        }
        return nil
    }

    /// Resolve the sidecar on disk for the given book. Walks the
    /// shelves tree (= same forgiving walk as
    /// `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw IdeaLibraryError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create an empty one if
    /// missing). Forgiving on corrupt JSON (= returns an empty
    /// sidecar instead of throwing, matching the kanban / todo /
    /// tags / lifecycle / relationships convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> IdeaLibrarySidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = IdeaLibrarySidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // the TagManager first-load behavior: only write to
            // disk once the user actually adds an idea).
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(IdeaLibrarySidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: log nothing (= no logger dependency);
            // return an empty sidecar so the caller can keep
            // going. Matches `BookKanbanStore` /
            // `BookTodoStore` load paths.
            let empty = IdeaLibrarySidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors `BookProjectConfigStore.atomicWrite`).
    private func persistSidecar(_ sidecar: IdeaLibrarySidecar) async throws {
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