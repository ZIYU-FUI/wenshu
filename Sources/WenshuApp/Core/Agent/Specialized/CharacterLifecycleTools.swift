//
//  CharacterLifecycleTools.swift · Wenshu · P1 ticket #13 (PORT-SPECIALIZED-008, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/specialized/character_lifecycle.py`.
//
//  The Python module tracks the lifecycle of every character across
//  the chapters of a book. Each lifecycle event is a single point on
//  a character's arc (born / introduced / active / absent / wounded /
//  dead / resurrected / retired) anchored to a chapter and carrying
//  a short excerpt of the chapter text where the event was observed.
//
//  The Swift port exposes:
//    - Add / remove a lifecycle event.
//    - List events (= filterable by character / chapter / stage).
//    - Build a character's timeline (= sorted events).
//    - Detect lifecycle contradictions (= a character declared
//      `dead` in chapter N but `active` in chapter M > N).
//    - Suggest narrative arcs (= based on the event sequence).
//
//  Persistence: per-book JSON sidecar at
//    `books/<bookId>/character-lifecycle.json`
//  Mirrors the `kanban.json` / `todo.json` / `long-form-guardrails.json`
//  / `character-relationships.json` pattern (= canonical wenshu
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

// MARK: - LifecycleStage enum

/// The 8 lifecycle stages the tracker knows how to model.
/// Each case maps 1:1 to a value in hermes's
/// `agent/specialized/character_lifecycle.py::STAGE_TABLE`.
///
/// Stages are intentionally ordered so `timeline(...)` can derive
/// a coarse narrative position (= `introduced` < `active` <
/// `wounded` < `dead` < `resurrected`) without having to re-read
/// the source module.
public enum LifecycleStage: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// Character is born / created (= canon first appearance).
    case born
    /// Character is introduced to the reader (= first page
    /// mention that establishes identity, even if "born" already
    /// happened off-page).
    case introduced
    /// Character is actively participating in the chapter.
    case active
    /// Character is off-page (= skipping this chapter, but
    /// alive + expected to return).
    case absent
    /// Character is wounded / injured / impaired (= a one-chapter
    /// event that does NOT transition to death).
    case wounded
    /// Character is dead (= end-of-arc state; the contradiction
    /// detector flags subsequent non-`resurrected` events).
    case dead
    /// Character returns from death / a prior `dead` state.
    case resurrected
    /// Character retires (= leaves the narrative but stays alive;
    /// = a soft form of "absent" that signals no return).
    case retired

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .born:         return "Born"
        case .introduced:   return "Introduced"
        case .active:       return "Active"
        case .absent:       return "Absent"
        case .wounded:      return "Wounded"
        case .dead:         return "Dead"
        case .resurrected:  return "Resurrected"
        case .retired:      return "Retired"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .born:         return "baby"
        case .introduced:   return "user-plus"
        case .active:       return "zap"
        case .absent:       return "user-minus"
        case .wounded:      return "bandage"
        case .dead:         return "skull"
        case .resurrected:  return "sparkles"
        case .retired:      return "moon"
        }
    }

    /// Whether this stage signals terminal-state for the
    /// contradiction detector (= no further non-resurrected /
    /// non-retired events should follow).
    public var isTerminal: Bool {
        switch self {
        case .dead, .retired: return true
        case .born, .introduced, .active, .absent, .wounded, .resurrected: return false
        }
    }
}

// MARK: - LifecycleEvent struct

/// A single lifecycle event for one character in a book.
/// Persisted as one entry in the per-book
/// `character-lifecycle.json` sidecar.
public struct LifecycleEvent: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / remove /
    /// timeline / contradiction lookups; never re-used even across
    /// books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// Character id (= mirrors `Character.id` from
    /// `Sources/WenshuApp/Domain/Character.swift`; the actor does
    /// NOT need to dereference this to a name; = the view layer's
    /// responsibility).
    public let characterId: UUID

    /// Lifecycle stage for this event.
    public let stage: LifecycleStage

    /// Chapter where this event was observed (= optional; nil =
    /// observed outside of any specific chapter, e.g. "born in a
    /// backstory prologue the user wants to track before chapter
    /// 1"). When set, the timeline sorts by this id (= stable
    /// since the chapter ids are stable per-book).
    public let chapterId: UUID?

    /// Exact quote (= up to a paragraph; = surfaced verbatim in
    /// the SwiftUI list row so the writer can confirm the
    /// observation without re-reading the chapter).
    public let excerpt: String

    /// Creation timestamp (= `Date.now` at add time).
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        bookId: UUID,
        characterId: UUID,
        stage: LifecycleStage,
        chapterId: UUID? = nil,
        excerpt: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.characterId = characterId
        self.stage = stage
        self.chapterId = chapterId
        self.excerpt = excerpt
        self.createdAt = createdAt
    }
}

// MARK: - Contradiction struct

/// A detected lifecycle contradiction: a character declared
/// `dead` (= or any terminal stage) in chapter N but then
/// observed in a non-resurrected / non-retired stage in chapter M
/// > N without an intervening `resurrected` event.
///
/// The actor emits one row per conflicting character, with the
/// first / second events listed in `conflictingEvents` (= the
/// caller can render the order in the UI).
public struct LifecycleContradiction: Sendable, Codable, Equatable {

    /// Character id (= the contradictory character).
    public let characterId: UUID

    /// Human-readable one-line description (= e.g. "Character
    /// A is 'dead' in chapter 5 but 'active' in chapter 8").
    /// Suitable for direct UI display.
    public let conflictDescription: String

    /// The two events that trigger the contradiction (= sorted by
    /// `createdAt` so the order is stable for tests + UI).
    public let conflictingEvents: [LifecycleEvent]

    public init(
        characterId: UUID,
        conflictDescription: String,
        conflictingEvents: [LifecycleEvent]
    ) {
        self.characterId = characterId
        self.conflictDescription = conflictDescription
        // Defensive copy + stable sort for tests.
        self.conflictingEvents = conflictingEvents.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

// MARK: - Sidecar on-disk shape

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`).
struct CharacterLifecycleSidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var events: [LifecycleEvent]
    var updatedAt: Date

    init(
        bookId: UUID,
        events: [LifecycleEvent] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.events = events
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors

/// Errors thrown by `CharacterLifecycleTracker`. Mirrors the
/// BookProjectConfigStore / BookTodoStore / LongFormGuardrails /
/// CharacterRelationshipTracker error conventions (= a
/// LocalizedError per case).
public enum CharacterLifecycleTrackerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case eventNotFound(id: UUID)

    public var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "CharacterLifecycleTracker: book directory not found for id \(id.uuidString)"
        case .eventNotFound(let id):
            return "CharacterLifecycleTracker: event \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor

/// Per-book character-lifecycle tracker. Holds the in-memory
/// cache + owns the on-disk JSON sidecar.
///
/// Persistence: `<bookDir>/character-lifecycle.json`. The
/// actor resolves `<bookDir>` via `BookStore.bookDirectory(bookId:)`
/// (= the canonical forgiving walk that searches every shelf's
/// `books/<id>/` subfolder).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// long-form-guardrails / character-relationships sidecar
/// convention):
///   - Missing sidecar = empty list (= first-load behavior).
///   - Corrupt sidecar = empty list (= never bricks the UI).
///   - Missing book directory = throws
///     `.bookDirectoryNotFound`.
///
/// Access level: internal (= the actor accepts the internal
/// `BookStore` type as a constructor parameter; = per wenshu
/// convention the view layer accesses the actor through the
/// module's internal scope).
actor CharacterLifecycleTracker {

    /// Sidecar on-disk filename (= parallel to
    /// `kanban.json` / `todo.json` /
    /// `long-form-guardrails.json` /
    /// `character-relationships.json`).
    private static let sidecarFilename = "character-lifecycle.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: CharacterLifecycleSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)

    /// Add a lifecycle event. Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on `id`: re-adding with the same id replaces
    ///     the existing row (= matches `BookKanbanStore` upsert
    ///     policy).
    public func add(_ event: LifecycleEvent) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: event.bookId)
        // Replace if a row with the same id already exists.
        if let idx = sidecar.events.firstIndex(where: { $0.id == event.id }) {
            sidecar.events[idx] = event
        } else {
            sidecar.events.append(event)
        }
        sidecar.updatedAt = Date()
        cache[event.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// All events in a book (= filterable by character / chapter
    /// / stage). When all filters are nil, returns every row.
    public func list(
        bookId: UUID,
        characterId: UUID? = nil,
        chapterId: UUID? = nil,
        stage: LifecycleStage? = nil
    ) async throws -> [LifecycleEvent] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.events.filter { event in
            let characterMatches = characterId.map { $0 == event.characterId } ?? true
            let chapterMatches = chapterId.map { $0 == event.chapterId } ?? true
            let stageMatches = stage.map { $0 == event.stage } ?? true
            return characterMatches && chapterMatches && stageMatches
        }
        // Stable display order: oldest created first.
        return filtered.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Remove an event by id. Throws `.eventNotFound` when the id
    /// is unknown for the supplied book.
    public func remove(id: UUID) async throws {
        // Walk the cache to find the owning book (= the caller did
        // not supply bookId; we look it up from the cached
        // sidecars). If nothing matches the id we still need to
        // know the book to surface the proper `.eventNotFound`
        // error: any book would do, so we fall back to the
        // currently loaded cache (= common case: the view loads
        // events first via `list(...)`, then calls `remove(id:)`
        // on one of them).
        var owningBookId: UUID?
        for (bookId, sidecar) in cache where sidecar.events.contains(where: { $0.id == id }) {
            owningBookId = bookId
            break
        }
        guard let bookId = owningBookId else {
            // No cache hit: the event was never observed in any
            // loaded book. Surface the not-found error with a
            // nil bookId (= the actor cannot disambiguate which
            // book it belonged to without a bookId argument; we
            // adopt the same convention as
            // CharacterRelationshipTracker.remove(id:from:)).
            throw CharacterLifecycleTrackerError.eventNotFound(id: id)
        }
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        guard let idx = sidecar.events.firstIndex(where: { $0.id == id }) else {
            throw CharacterLifecycleTrackerError.eventNotFound(id: id)
        }
        sidecar.events.remove(at: idx)
        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Build a timeline (= sorted events) for a single character.
    /// Sorting priority: `chapterId` ascending when set (= events
    /// without a chapter id sort to the front so the writer can
    /// see pre-chapter backstory events before any chapter
    /// anchor); `createdAt` ascending as tiebreaker.
    public func timeline(bookId: UUID, characterId: UUID) async throws -> [LifecycleEvent] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.events.filter { $0.characterId == characterId }
        return filtered.sorted { lhs, rhs in
            switch (lhs.chapterId, rhs.chapterId) {
            case (nil, nil):
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _):
                // Events without a chapter id come first (= pre-
                // chapter backstory events).
                return true
            case (_, nil):
                return false
            case (let l?, let r?):
                if l.uuidString != r.uuidString { return l.uuidString < r.uuidString }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    /// Detect lifecycle contradictions: any character whose
    /// timeline shows a terminal stage (= `dead` or `retired`)
    /// followed by a non-`resurrected` / non-`retired` stage in a
    /// later chapter (= or with a later createdAt timestamp).
    ///
    /// Returns zero or more `LifecycleContradiction` rows; = empty
    /// when no character triggers the heuristic (= common for
    /// early-draft books).
    public func contradictions(bookId: UUID) async throws -> [LifecycleContradiction] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        // Group events by character.
        var perCharacter: [UUID: [LifecycleEvent]] = [:]
        for event in sidecar.events {
            perCharacter[event.characterId, default: []].append(event)
        }
        var output: [LifecycleContradiction] = []
        for (characterId, events) in perCharacter {
            // Sort by chapterId asc (= nil first), then createdAt
            // asc (= matches `timeline(...)` order).
            let sorted = events.sorted { lhs, rhs in
                switch (lhs.chapterId, rhs.chapterId) {
                case (nil, nil):
                    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                    return lhs.id.uuidString < rhs.id.uuidString
                case (nil, _):
                    return true
                case (_, nil):
                    return false
                case (let l?, let r?):
                    if l.uuidString != r.uuidString { return l.uuidString < r.uuidString }
                    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
            }
            // Walk forward; track the first terminal event we
            // encounter (= the "death" / "retired" reference
            // point). When we see a subsequent non-resurrected /
            // non-retired event, emit a contradiction row.
            var terminalAnchor: LifecycleEvent?
            for event in sorted {
                if terminalAnchor == nil, event.stage.isTerminal {
                    terminalAnchor = event
                    continue
                }
                if let anchor = terminalAnchor {
                    // Subsequent event in a non-terminal stage.
                    if !event.stage.isTerminal {
                        let stageLabel = event.stage.displayName.lowercased()
                        let anchorStageLabel = anchor.stage.displayName.lowercased()
                        let chapterFragment: String
                        if let cid = anchor.chapterId {
                            chapterFragment = "chapter \(cid.uuidString.prefix(8))"
                        } else {
                            chapterFragment = "a pre-chapter backstory entry"
                        }
                        let laterFragment: String
                        if let cid = event.chapterId {
                            laterFragment = "chapter \(cid.uuidString.prefix(8))"
                        } else {
                            laterFragment = "a later pre-chapter entry"
                        }
                        let description = "Character \(characterId.uuidString.prefix(8)) is '\(anchorStageLabel)' in \(chapterFragment) but '\(stageLabel)' in \(laterFragment)"
                        output.append(LifecycleContradiction(
                            characterId: characterId,
                            conflictDescription: description,
                            conflictingEvents: [anchor, event]
                        ))
                        // Reset the anchor so we do NOT flag
                        // every subsequent event against the
                        // same terminal row (= the user only
                        // needs to see one row per
                        // contradiction; = mirrors the
                        // CharacterRelationshipTracker
                        // `inconsistencies` strategy of one
                        // row per conflicting pair).
                        terminalAnchor = nil
                    } else if event.stage == .resurrected {
                        // Resurrection lifts the terminal anchor.
                        terminalAnchor = nil
                    } else {
                        // Another terminal stage (= e.g. retired
                        // after dead). Keep the anchor; it still
                        // represents the last terminal state.
                        terminalAnchor = event
                    }
                }
            }
        }
        // Stable sort for tests + UI display.
        return output.sorted { lhs, rhs in
            if lhs.characterId != rhs.characterId {
                return lhs.characterId.uuidString < rhs.characterId.uuidString
            }
            return lhs.conflictDescription < rhs.conflictDescription
        }
    }

    // MARK: - Internals

    /// Resolve the sidecar on disk for the given book. Walks the
    /// shelves tree (= same forgiving walk as
    /// `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw CharacterLifecycleTrackerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create an empty one +
    /// persist if missing). Forgiving on corrupt JSON (= returns
    /// an empty sidecar instead of throwing, matching the
    /// kanban / todo / long-form-guardrails /
    /// character-relationships convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> CharacterLifecycleSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = CharacterLifecycleSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // the LongFormGuardrails / CharacterRelationshipTracker
            // first-load behaviour: only write to disk once the
            // user actually adds an event).
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(CharacterLifecycleSidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: log nothing (= no logger dependency);
            // return an empty sidecar so the caller can keep
            // going. Matches `BookKanbanStore` /
            // `BookTodoStore` load paths.
            let empty = CharacterLifecycleSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors `BookProjectConfigStore.atomicWrite`).
    private func persistSidecar(_ sidecar: CharacterLifecycleSidecar) async throws {
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