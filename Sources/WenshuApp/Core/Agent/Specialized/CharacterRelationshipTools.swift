//
//  CharacterRelationshipTools.swift · Wenshu · P1 ticket #12 (PORT-SPECIALIZED-007, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/specialized/character_relationships.py`.
//
//  The Python module models relationships between characters in a
//  book. Each relationship is a typed edge (= ally / rival /
//  mentor / family / romantic / enemy / neutral / acquaintance)
//  between two character IDs, optionally anchored to a chapter.
//
//  The Swift port exposes:
//    - Add / update / remove a relationship.
//    - List relationships for a book (= filterable by kind +
//      character).
//    - Build a relationship graph (= nodes = characters that
//      participate in at least one edge, edges = typed + weighted
//      rows).
//    - Detect relationship inconsistencies (= the same pair
//      declared with conflicting kinds).
//    - Suggest relationship arcs (= for chapter pairs declared
//      on the edge, the actor flags pairs that never evolve
//      across the chapter timeline).
//
//  Persistence: per-book JSON sidecar at
//    `books/<bookId>/character-relationships.json`
//  Mirrors the `kanban.json` / `todo.json` /
//  `long-form-guardrails.json` pattern (= canonical wenshu
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

// MARK: - Kind enum

/// The 8 relationship kinds the tracker knows how to model.
/// Each case maps 1:1 to a value in hermes's
/// `agent/specialized/character_relationships.py::KIND_TABLE`.
public enum RelationshipKind: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// Allied / on the same side.
    case ally
    /// Direct competitor / foil.
    case rival
    /// Teacher / mentee.
    case mentor
    /// Family tie (= blood / adoption / marriage).
    case family
    /// Romantic involvement.
    case romantic
    /// Active antagonism / hostile opposition.
    case enemy
    /// Neutral / no declared alignment.
    case neutral
    /// Acquaintance = known to each other but no declared arc.
    case acquaintance

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .ally:          return "Ally"
        case .rival:         return "Rival"
        case .mentor:        return "Mentor"
        case .family:        return "Family"
        case .romantic:      return "Romantic"
        case .enemy:         return "Enemy"
        case .neutral:       return "Neutral"
        case .acquaintance:  return "Acquaintance"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .ally:          return "handshake"
        case .rival:         return "swords"
        case .mentor:        return "graduation-cap"
        case .family:        return "users-round"
        case .romantic:      return "heart"
        case .enemy:         return "skull"
        case .neutral:       return "minus-circle"
        case .acquaintance:  return "user"
        }
    }
}

// MARK: - Relationship struct

/// A single typed relationship between two characters in a book.
/// Persisted as one entry in the per-book
/// `character-relationships.json` sidecar.
public struct CharacterRelationship: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / remove /
    /// graph + inconsistency lookups; never re-used even across
    /// books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// Source character id.
    public let fromCharacterId: UUID

    /// Target character id.
    public let toCharacterId: UUID

    /// Edge kind.
    public var kind: RelationshipKind

    /// Chapter where this relationship was first established
    /// (= optional; nil = declared outside of any specific
    /// chapter, = used by the arc-suggester as a "neutral"
    /// baseline).
    public var establishedInChapterId: UUID?

    /// One-sentence context describing the relationship
    /// (= surfaced in the SwiftUI list row).
    public var description: String

    /// = true when both directions of the pair exist (= A→B and
    /// B→A). The actor flips this flag on every add / update to
    /// keep the value consistent without forcing the user to
    /// author two rows.
    public var isMutual: Bool

    /// Creation timestamp (= `Date.now` at add time).
    public let createdAt: Date

    /// Last-modified timestamp (= updated by the actor on
    /// every `update(_:)` call).
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        bookId: UUID,
        fromCharacterId: UUID,
        toCharacterId: UUID,
        kind: RelationshipKind,
        establishedInChapterId: UUID? = nil,
        description: String = "",
        isMutual: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.fromCharacterId = fromCharacterId
        self.toCharacterId = toCharacterId
        self.kind = kind
        self.establishedInChapterId = establishedInChapterId
        self.description = description
        self.isMutual = isMutual
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Inconsistency struct

/// A detected inconsistency: the same character pair carries two
/// conflicting kinds (= e.g. A is both `ally` AND `enemy` of B).
/// The actor emits one row per conflicting pair (= the
/// `conflictingKinds` array lists the kind set).
public struct RelationshipInconsistency: Sendable, Codable, Equatable {
    /// Source character id (= canonical ordering: smaller UUID
    /// sorts first; the actor normalizes both sides so the
    /// output is symmetric).
    public let fromCharacterId: UUID

    /// Target character id.
    public let toCharacterId: UUID

    /// The set of kinds the actor detected for this pair
    /// (= always >= 2 entries; = 1 entry means the pair is
    /// consistent and the row would not be emitted).
    public let conflictingKinds: [RelationshipKind]

    /// Human-readable one-line description (= e.g. "A is both
    /// 'ally' and 'enemy' of B"). Suitable for direct UI display.
    public let message: String

    public init(
        fromCharacterId: UUID,
        toCharacterId: UUID,
        conflictingKinds: [RelationshipKind],
        message: String
    ) {
        self.fromCharacterId = fromCharacterId
        self.toCharacterId = toCharacterId
        // Defensive copy + sort for stable test assertions.
        self.conflictingKinds = conflictingKinds.sorted { $0.rawValue < $1.rawValue }
        self.message = message
    }
}

// MARK: - Graph structs

/// A relationship graph (= the actor's `graph(bookId:)` output).
///
/// `characterIds` is the set of characters that participate in at
/// least one relationship (= nodes). `edges` is the directed edge
/// list (= one row per `CharacterRelationship`).
public struct RelationshipGraph: Sendable, Codable, Equatable {

    /// Graph nodes (= the character ids that appear in at least
    /// one edge; = sorted for stable display + tests).
    public let characterIds: [UUID]

    /// Graph edges (= typed + weighted rows). Weight is the
    /// edge's "strength" in 0.0 .. 1.0 (= derived from
    /// `RelationshipKind`; = the view can render thicker lines
    /// for stronger kinds).
    public let edges: [RelationshipEdge]

    public struct RelationshipEdge: Sendable, Codable, Equatable {

        /// Source character id.
        public let fromId: UUID

        /// Target character id.
        public let toId: UUID

        /// Edge kind.
        public let kind: RelationshipKind

        /// Edge weight in 0.0 .. 1.0. The actor computes it from
        /// `RelationshipKind` via `weight(for:)`; = a fixed
        /// per-kind scalar so the graph is deterministic.
        public let weight: Double

        public init(
            fromId: UUID,
            toId: UUID,
            kind: RelationshipKind,
            weight: Double
        ) {
            self.fromId = fromId
            self.toId = toId
            self.kind = kind
            self.weight = max(0.0, min(1.0, weight))
        }
    }

    public init(characterIds: [UUID], edges: [RelationshipEdge]) {
        self.characterIds = characterIds.sorted { $0.uuidString < $1.uuidString }
        self.edges = edges
    }
}

// MARK: - Arc suggestion

/// A relationship-arc suggestion (= emitted by `suggestArcs(...)`
/// when two characters are declared in chapter 1 as one kind but
/// never evolve across the timeline).
public struct RelationshipArcSuggestion: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let fromCharacterId: UUID
    public let toCharacterId: UUID
    public let firstKind: RelationshipKind
    public let chapterCount: Int
    public let message: String

    public init(
        id: UUID = UUID(),
        fromCharacterId: UUID,
        toCharacterId: UUID,
        firstKind: RelationshipKind,
        chapterCount: Int,
        message: String
    ) {
        self.id = id
        self.fromCharacterId = fromCharacterId
        self.toCharacterId = toCharacterId
        self.firstKind = firstKind
        self.chapterCount = max(0, chapterCount)
        self.message = message
    }
}

// MARK: - Sidecar on-disk shape

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`).
struct CharacterRelationshipSidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var relationships: [CharacterRelationship]
    var updatedAt: Date

    init(
        bookId: UUID,
        relationships: [CharacterRelationship] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.relationships = relationships
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors

/// Errors thrown by `CharacterRelationshipTracker`. Mirrors the
/// BookProjectConfigStore / BookTodoStore / LongFormGuardrails
/// error conventions (= a LocalizedError per case).
public enum CharacterRelationshipTrackerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case relationshipNotFound(id: UUID)
    case selfRelationship(id: UUID)

    public var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "CharacterRelationshipTracker: book directory not found for id \(id.uuidString)"
        case .relationshipNotFound(let id):
            return "CharacterRelationshipTracker: relationship \(id.uuidString) not found"
        case .selfRelationship(let id):
            return "CharacterRelationshipTracker: relationship \(id.uuidString) cannot target itself (from == to)"
        }
    }
}

// MARK: - Actor

/// Per-book character-relationship tracker. Holds the in-memory
/// cache + owns the on-disk JSON sidecar.
///
/// Persistence: `<bookDir>/character-relationships.json`. The
/// actor resolves `<bookDir>` via `BookStore.bookDirectory(bookId:)`
/// (= the canonical forgiving walk that searches every shelf's
/// `books/<id>/` subfolder).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// long-form-guardrails sidecar convention):
///   - Missing sidecar = empty list (= first-load behavior).
///   - Corrupt sidecar = empty list (= never bricks the UI).
///   - Missing book directory = throws
///     `.bookDirectoryNotFound`.
///
/// Access level: internal (= the actor accepts the internal
/// `BookStore` type as a constructor parameter; = per wenshu
/// convention the view layer accesses the actor through the
/// module's internal scope).
actor CharacterRelationshipTracker {

    /// Sidecar on-disk filename (= parallel to
    /// `kanban.json` / `todo.json` /
    /// `long-form-guardrails.json`).
    private static let sidecarFilename = "character-relationships.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: CharacterRelationshipSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)

    /// Add a relationship. Persists + caches.
    ///
    /// Behaviour:
    ///   - Refuses self-targeting edges (`from == to`) by throwing
    ///     `.selfRelationship`.
    ///   - Updates `isMutual` automatically (= true when the
    ///     inverse direction already exists for the same pair).
    ///   - Idempotent on `id`: re-adding with the same id replaces
    ///     the existing row (= matches `BookKanbanStore` upsert
    ///     policy).
    public func add(_ relationship: CharacterRelationship) async throws {
        guard relationship.fromCharacterId != relationship.toCharacterId else {
            throw CharacterRelationshipTrackerError.selfRelationship(id: relationship.id)
        }
        var sidecar = try await loadOrCreateSidecar(bookId: relationship.bookId)

        // Auto-flip `isMutual` if the inverse direction already
        // exists for the same pair. We look across all existing
        // rows; if any row has from = B and to = A, the new row
        // is mutual AND we back-fill the inverse row too.
        let inverseExists = sidecar.relationships.contains { row in
            row.fromCharacterId == relationship.toCharacterId
                && row.toCharacterId == relationship.fromCharacterId
        }
        var stamped = relationship
        stamped.updatedAt = Date()
        stamped.isMutual = relationship.isMutual || inverseExists

        // Replace if a row with the same id already exists.
        if let idx = sidecar.relationships.firstIndex(where: { $0.id == stamped.id }) {
            sidecar.relationships[idx] = stamped
        } else {
            sidecar.relationships.append(stamped)
        }

        // Back-fill the inverse row when we just declared this
        // edge as mutual AND the inverse did not previously
        // carry the mutual flag. The back-fill mirrors the
        // from/to kind so the graph stays consistent.
        if stamped.isMutual {
            for idx in sidecar.relationships.indices
            where sidecar.relationships[idx].fromCharacterId == relationship.toCharacterId
                && sidecar.relationships[idx].toCharacterId == relationship.fromCharacterId
                && sidecar.relationships[idx].id != stamped.id
                && !sidecar.relationships[idx].isMutual
            {
                sidecar.relationships[idx].isMutual = true
                sidecar.relationships[idx].updatedAt = Date()
            }
        }

        sidecar.updatedAt = Date()
        cache[relationship.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Update an existing relationship (= by id). Throws
    /// `.relationshipNotFound` if the id is unknown.
    ///
    /// Re-runs the `isMutual` auto-flip after the update so the
    /// flag stays consistent.
    public func update(_ relationship: CharacterRelationship) async throws {
        guard relationship.fromCharacterId != relationship.toCharacterId else {
            throw CharacterRelationshipTrackerError.selfRelationship(id: relationship.id)
        }
        var sidecar = try await loadOrCreateSidecar(bookId: relationship.bookId)
        guard let idx = sidecar.relationships.firstIndex(where: { $0.id == relationship.id }) else {
            throw CharacterRelationshipTrackerError.relationshipNotFound(id: relationship.id)
        }
        var stamped = relationship
        stamped.updatedAt = Date()

        // Re-compute `isMutual` from the rest of the sidecar
        // (= any inverse row wins).
        let inverseExists = sidecar.relationships.contains { row in
            row.id != stamped.id
                && row.fromCharacterId == stamped.toCharacterId
                && row.toCharacterId == stamped.fromCharacterId
        }
        stamped.isMutual = relationship.isMutual || inverseExists

        sidecar.relationships[idx] = stamped

        // Back-fill the inverse row.
        if stamped.isMutual {
            for invIdx in sidecar.relationships.indices
            where sidecar.relationships[invIdx].fromCharacterId == stamped.toCharacterId
                && sidecar.relationships[invIdx].toCharacterId == stamped.fromCharacterId
                && sidecar.relationships[invIdx].id != stamped.id
                && !sidecar.relationships[invIdx].isMutual
            {
                sidecar.relationships[invIdx].isMutual = true
                sidecar.relationships[invIdx].updatedAt = Date()
            }
        }

        sidecar.updatedAt = Date()
        cache[relationship.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Remove a relationship by id. Throws `.relationshipNotFound`
    /// when the id is unknown for the supplied book.
    public func remove(id: UUID, from bookId: UUID) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        guard let idx = sidecar.relationships.firstIndex(where: { $0.id == id }) else {
            throw CharacterRelationshipTrackerError.relationshipNotFound(id: id)
        }
        let removed = sidecar.relationships.remove(at: idx)

        // After removal, any inverse row may no longer be mutual.
        // Re-evaluate `isMutual` for the partner pair.
        for invIdx in sidecar.relationships.indices
        where sidecar.relationships[invIdx].fromCharacterId == removed.toCharacterId
            && sidecar.relationships[invIdx].toCharacterId == removed.fromCharacterId
        {
            let inverseExists = sidecar.relationships.contains { row in
                row.id != sidecar.relationships[invIdx].id
                    && row.fromCharacterId == sidecar.relationships[invIdx].toCharacterId
                    && row.toCharacterId == sidecar.relationships[invIdx].fromCharacterId
            }
            if !inverseExists, sidecar.relationships[invIdx].isMutual {
                sidecar.relationships[invIdx].isMutual = false
                sidecar.relationships[invIdx].updatedAt = Date()
            }
        }

        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// All relationships in a book (= filterable by kind +
    /// character). When both filters are nil, returns every row.
    /// The character filter matches either side of the edge.
    public func list(
        bookId: UUID,
        kind: RelationshipKind? = nil,
        characterId: UUID? = nil
    ) async throws -> [CharacterRelationship] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.relationships.filter { row in
            let kindMatches = kind.map { $0 == row.kind } ?? true
            let characterMatches = characterId.map { id in
                row.fromCharacterId == id || row.toCharacterId == id
            } ?? true
            return kindMatches && characterMatches
        }
        // Stable display order: oldest created first, then
        // updatedAt desc as tiebreaker.
        return filtered.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    /// Build a relationship graph (= nodes = characters with at
    /// least one edge; edges = typed + weighted rows).
    public func graph(bookId: UUID) async throws -> RelationshipGraph {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        var characterSet: Set<UUID> = []
        var edges: [RelationshipGraph.RelationshipEdge] = []
        edges.reserveCapacity(sidecar.relationships.count)
        for row in sidecar.relationships {
            characterSet.insert(row.fromCharacterId)
            characterSet.insert(row.toCharacterId)
            edges.append(RelationshipGraph.RelationshipEdge(
                fromId: row.fromCharacterId,
                toId: row.toCharacterId,
                kind: row.kind,
                weight: Self.weight(for: row.kind)
            ))
        }
        return RelationshipGraph(
            characterIds: Array(characterSet),
            edges: edges
        )
    }

    /// Detect inconsistencies: any character pair declared with
    /// >= 2 conflicting kinds (= e.g. A→B is both `ally` AND
    /// `enemy`). Returns one `RelationshipInconsistency` per
    /// conflicting pair; = the caller can render the list in
    /// the SpecializedTools pane.
    public func inconsistencies(bookId: UUID) async throws -> [RelationshipInconsistency] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        // Group rows by canonical (= from < to) pair id.
        var pairKinds: [PairKey: Set<RelationshipKind>] = [:]
        var pairMessageKeys: [PairKey: (UUID, UUID)] = [:]
        for row in sidecar.relationships {
            let key = Self.canonicalPairKey(
                a: row.fromCharacterId,
                b: row.toCharacterId
            )
            pairKinds[key, default: []].insert(row.kind)
            pairMessageKeys[key] = (key.a, key.b)
        }
        var output: [RelationshipInconsistency] = []
        for (key, kinds) in pairKinds where kinds.count >= 2 {
            let (fromId, toId) = pairMessageKeys[key] ?? (key.a, key.b)
            let sorted = kinds.sorted { $0.rawValue < $1.rawValue }
            let quoted = sorted.map { "`\($0.rawValue)`" }.joined(separator: ", ")
            let message = "Pair \(fromId.uuidString.prefix(8)) ↔ \(toId.uuidString.prefix(8)) has conflicting kinds: \(quoted)"
            output.append(RelationshipInconsistency(
                fromCharacterId: fromId,
                toCharacterId: toId,
                conflictingKinds: sorted,
                message: message
            ))
        }
        return output.sorted { lhs, rhs in
            if lhs.fromCharacterId != rhs.fromCharacterId {
                return lhs.fromCharacterId.uuidString < rhs.fromCharacterId.uuidString
            }
            return lhs.toCharacterId.uuidString < rhs.toCharacterId.uuidString
        }
    }

    /// Suggest relationship arcs.
    ///
    /// Strategy (= mirrors the hermes Python module's
    /// `suggest_arcs` heuristic):
    ///
    ///   - For each canonical pair, collect the timeline of
    ///     chapter ids across all rows (= the union of
    ///     `establishedInChapterId`).
    ///   - When the pair is declared with exactly ONE kind
    ///     across >= `stagnantChapterThreshold` chapters, emit
    ///     an arc suggestion (= "this pair has not evolved").
    ///
    /// Returns zero or more suggestions; = empty when no pair
    /// meets the threshold (= common for early-draft books).
    public func suggestArcs(
        bookId: UUID,
        stagnantChapterThreshold: Int = 3
    ) async throws -> [RelationshipArcSuggestion] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        var pairRows: [PairKey: [CharacterRelationship]] = [:]
        for row in sidecar.relationships {
            let key = Self.canonicalPairKey(a: row.fromCharacterId, b: row.toCharacterId)
            pairRows[key, default: []].append(row)
        }
        let threshold = max(2, stagnantChapterThreshold)
        var output: [RelationshipArcSuggestion] = []
        for (key, rows) in pairRows {
            let uniqueKinds = Set(rows.map { $0.kind })
            guard uniqueKinds.count == 1 else { continue }
            let uniqueChapters = Set(rows.compactMap { $0.establishedInChapterId })
            guard uniqueChapters.count >= threshold else { continue }
            let firstKind = uniqueKinds.first ?? .neutral
            let message = "Pair \(key.a.uuidString.prefix(8)) ↔ \(key.b.uuidString.prefix(8)) has stayed `\(firstKind.rawValue)` across \(uniqueChapters.count) chapter(s); consider evolving the relationship."
            output.append(RelationshipArcSuggestion(
                fromCharacterId: key.a,
                toCharacterId: key.b,
                firstKind: firstKind,
                chapterCount: uniqueChapters.count,
                message: message
            ))
        }
        return output.sorted { lhs, rhs in
            if lhs.chapterCount != rhs.chapterCount {
                return lhs.chapterCount > rhs.chapterCount
            }
            return lhs.fromCharacterId.uuidString < rhs.fromCharacterId.uuidString
        }
    }

    // MARK: - Internals

    /// Canonical pair key: smaller UUID sorts first; the result
    /// is symmetric for `(A, B)` and `(B, A)`.
    struct PairKey: Hashable, Equatable {
        let a: UUID
        let b: UUID
    }

    static func canonicalPairKey(a: UUID, b: UUID) -> PairKey {
        if a.uuidString <= b.uuidString { return PairKey(a: a, b: b) }
        return PairKey(a: b, b: a)
    }

    /// Resolve the sidecar on disk for the given book. Walks the
    /// shelves tree (= same forgiving walk as
    /// `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw CharacterRelationshipTrackerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create an empty one +
    /// persist if missing). Forgiving on corrupt JSON (= returns
    /// an empty sidecar instead of throwing, matching the
    /// kanban / todo / long-form-guardrails convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> CharacterRelationshipSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = CharacterRelationshipSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // the LongFormGuardrails first-load behaviour: only
            // write to disk once the user actually adds a row).
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(CharacterRelationshipSidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: log nothing (= no logger dependency);
            // return an empty sidecar so the caller can keep
            // going. Matches `BookKanbanStore` /
            // `BookTodoStore` load paths.
            let empty = CharacterRelationshipSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors `BookProjectConfigStore.atomicWrite`).
    private func persistSidecar(_ sidecar: CharacterRelationshipSidecar) async throws {
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

    /// Weight table (= per-kind scalar in 0.0 .. 1.0). The
    /// values are deterministic + monotonically increasing with
    /// emotional intensity (= the view can render thicker lines
    /// for stronger kinds). Centralized here so tests can
    /// reference the canonical values.
    public static func weight(for kind: RelationshipKind) -> Double {
        switch kind {
        case .acquaintance: return 0.1
        case .neutral:      return 0.2
        case .ally:         return 0.5
        case .mentor:       return 0.6
        case .family:       return 0.7
        case .rival:        return 0.75
        case .romantic:     return 0.85
        case .enemy:        return 0.95
        }
    }
}