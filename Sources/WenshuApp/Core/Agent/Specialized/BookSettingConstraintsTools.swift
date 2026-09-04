//
//  BookSettingConstraintsTools.swift · Wenshu · P1 ticket #16 (PORT-SPECIALIZED-011, 2026-09-04)
//  FINAL P1 specialized-ticket.
//
//  1:1 Swift port of hermes `agent/specialized/book_setting_constraints.py`.
//
//  The Python module manages the book's hard worldbuilding rules:
//  each constraint is an inviolable rule (= magic system laws,
//  physical laws, character abilities, style preferences) that the
//  writer commits to honoring across every chapter. The tracker
//  exposes CRUD on constraints (= add / update / remove / list)
//  + a chapter-text check that flags any forbidden pattern in
//  the supplied text.
//
//  The Swift port exposes:
//    - ConstraintSeverity: hard / soft / preference (= 3 levels).
//    - ConstraintScope: world / character / plot / style (= 4
//      scopes; = each constraint scopes to the surface it
//      applies to).
//    - BookSettingConstraint: id + bookId + title + description
//      + severity + scope + appliesToId + forbiddenPatterns +
//      createdAt.
//    - ConstraintViolation: constraintId + title + severity +
//      matchedText + lineNumber + suggestion (= emitted per
//      forbidden-pattern hit in the chapter text).
//    - BookSettingConstraints actor: add / update / remove /
//      list (= filterable by severity / scope) + check(= scans
//      chapter text against every active constraint's
//      forbiddenPatterns).
//
//  Persistence: per-book JSON sidecar at
//    `books/<bookId>/setting-constraints.json`
//  Mirrors the `kanban.json` / `todo.json` /
//  `long-form-guardrails.json` / `character-relationships.json`
//  / `character-lifecycle.json` / `ideas.json` / `tag-manager.json`
//  pattern (= canonical wenshu per-book JSON convention per
//  AGENTS.md §11).
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

// MARK: - ConstraintSeverity enum

/// The 3 severity levels the tracker knows how to model.
/// Each case maps 1:1 to a value in hermes's
/// `agent/specialized/book_setting_constraints.py::SEVERITY_TABLE`.
///
/// Severities are intentionally ordered so the picker renders
/// from strictest (= `.hard`) to most lenient (= `.preference`)
/// without having to re-read the source module.
public enum ConstraintSeverity: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// Absolutely cannot be violated (= magic system laws,
    /// physical laws, hard continuity rules).
    case hard
    /// Strongly preferred but can be broken for narrative
    /// reasons (= soften the rule with a beatable excuse).
    case soft
    /// Nice-to-have style preference (= tone / voice target).
    case preference

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .hard:        return "Hard"
        case .soft:        return "Soft"
        case .preference:  return "Preference"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .hard:        return "shield-alert"
        case .soft:        return "shield"
        case .preference:  return "feather"
        }
    }

    /// Whether violations of this severity should block
    /// shipping the chapter (= = hard only; soft + preference
    /// are advisory).
    public var blocksPublish: Bool {
        switch self {
        case .hard:        return true
        case .soft:        return false
        case .preference:  return false
        }
    }
}

// MARK: - ConstraintScope enum

/// The 4 scopes a constraint can apply to. Each case maps 1:1
/// to a value in hermes's
/// `agent/specialized/book_setting_constraints.py::SCOPE_TABLE`.
public enum ConstraintScope: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// Applies to entire world (= physics, magic system).
    case world
    /// Applies to a specific character (= abilities, traits).
    case character
    /// Applies to a specific plot (= event rules).
    case plot
    /// Applies to writing style (= POV, tense, vocabulary).
    case style

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker).
    public var displayName: String {
        switch self {
        case .world:       return "World"
        case .character:   return "Character"
        case .plot:        return "Plot"
        case .style:       return "Style"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .world:       return "globe"
        case .character:   return "user"
        case .plot:        return "git-branch"
        case .style:       return "palette"
        }
    }

    /// Whether this scope supports a non-nil `appliesToId` (= a
    /// specific character or plot). World + style do NOT require
    /// an appliesToId.
    public var supportsAppliesTo: Bool {
        switch self {
        case .character, .plot: return true
        case .world, .style:    return false
        }
    }
}

// MARK: - BookSettingConstraint struct

/// A single worldbuilding constraint for one book. Persisted
/// as one entry in the per-book `setting-constraints.json`
/// sidecar.
public struct BookSettingConstraint: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / update /
    /// remove / check lookups; never re-used even across books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// Short title (= e.g. "Magic requires eye contact").
    public let title: String

    /// 2-3 sentences explaining the rule (= surfaced in the
    /// violations list and the picker tooltip).
    public let description: String

    /// How strictly this rule is held (= see ConstraintSeverity).
    public let severity: ConstraintSeverity

    /// What surface the rule applies to (= see ConstraintScope).
    public let scope: ConstraintScope

    /// Optional target id (= the character or plot the constraint
    /// applies to). Nil for world + style scopes (= they apply
    /// universally).
    public let appliesToId: UUID?

    /// Regex or literal phrases that violate this constraint.
    /// Empty = no forbidden patterns (= description-level rule
    /// only; = still useful for soft / preference severities).
    public let forbiddenPatterns: [String]

    /// Creation timestamp (= `Date.now` at add time).
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        bookId: UUID,
        title: String,
        description: String = "",
        severity: ConstraintSeverity = .soft,
        scope: ConstraintScope = .world,
        appliesToId: UUID? = nil,
        forbiddenPatterns: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.description = description
        self.severity = severity
        self.scope = scope
        self.appliesToId = appliesToId
        self.forbiddenPatterns = forbiddenPatterns
        self.createdAt = createdAt
    }
}

// MARK: - ConstraintViolation struct

/// A single chapter-text violation: a constraint whose
/// `forbiddenPatterns` matched somewhere in the supplied text.
///
/// The actor emits one row per forbidden-pattern hit (= the
/// caller can render them inline with the matched snippet for
/// the writer to fix).
public struct ConstraintViolation: Sendable, Codable, Equatable, Identifiable {

    /// Synthetic identifier (= constraintId + line number +
    /// matchedText hash) so SwiftUI lists can iterate without
    /// duplicate-key collisions on repeated matches.
    public let id: UUID

    /// Constraint id (= the rule that triggered this violation).
    public let constraintId: UUID

    /// Constraint title (= copied at violation time so the UI
    /// can render it without dereferencing the constraint).
    public let title: String

    /// Severity of the rule (= hard / soft / preference).
    public let severity: ConstraintSeverity

    /// Scope of the rule (= world / character / plot / style).
    public let scope: ConstraintScope

    /// The actual text that triggered the violation (= first
    /// 80 chars of the matched region, suffixed with "…" when
    /// truncated).
    public let matchedText: String

    /// 1-indexed line number where the match was found (= nil
    /// when the text does not contain any newlines or the match
    /// was on the first logical line).
    public let lineNumber: Int?

    /// Suggested fix (= e.g. "Rewrite to maintain eye contact").
    public let suggestion: String

    public init(
        id: UUID = UUID(),
        constraintId: UUID,
        title: String,
        severity: ConstraintSeverity,
        scope: ConstraintScope,
        matchedText: String,
        lineNumber: Int?,
        suggestion: String
    ) {
        self.id = id
        self.constraintId = constraintId
        self.title = title
        self.severity = severity
        self.scope = scope
        self.matchedText = matchedText
        self.lineNumber = lineNumber
        self.suggestion = suggestion
    }
}

// MARK: - Sidecar on-disk shape

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`).
struct BookSettingConstraintsSidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var constraints: [BookSettingConstraint]
    var updatedAt: Date

    init(
        bookId: UUID,
        constraints: [BookSettingConstraint] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.constraints = constraints
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors

/// Errors thrown by `BookSettingConstraints`. Mirrors the
/// BookProjectConfigStore / BookTodoStore / LongFormGuardrails /
/// CharacterRelationshipTracker / CharacterLifecycleTracker error
/// conventions (= a LocalizedError per case).
public enum BookSettingConstraintsError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case constraintNotFound(id: UUID)

    public var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "BookSettingConstraints: book directory not found for id \(id.uuidString)"
        case .constraintNotFound(let id):
            return "BookSettingConstraints: constraint \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor

/// Per-book setting-constraints tracker. Holds the in-memory
/// cache + owns the on-disk JSON sidecar.
///
/// Persistence: `<bookDir>/setting-constraints.json`. The
/// actor resolves `<bookDir>` via `BookStore.bookDirectory(bookId:)`
/// (= the canonical forgiving walk that searches every shelf's
/// `books/<id>/` subfolder).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// long-form-guardrails / character-relationships /
/// character-lifecycle / ideas / tag-manager sidecar
/// convention):
///   - Missing sidecar = empty list (= first-load behavior).
///   - Corrupt sidecar = empty list (= never bricks the UI).
///   - Missing book directory = throws
///     `.bookDirectoryNotFound`.
actor BookSettingConstraints {

    /// Sidecar on-disk filename (= parallel to
    /// `kanban.json` / `todo.json` /
    /// `long-form-guardrails.json` /
    /// `character-relationships.json` /
    /// `character-lifecycle.json` / `ideas.json` /
    /// `tag-manager.json`).
    private static let sidecarFilename = "setting-constraints.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: BookSettingConstraintsSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)

    /// Add a constraint. Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on `id`: re-adding with the same id replaces
    ///     the existing row (= matches `BookKanbanStore` upsert
    ///     policy + the CharacterRelationshipTracker add path).
    public func add(_ constraint: BookSettingConstraint) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: constraint.bookId)
        // Replace if a row with the same id already exists.
        if let idx = sidecar.constraints.firstIndex(where: { $0.id == constraint.id }) {
            sidecar.constraints[idx] = constraint
        } else {
            sidecar.constraints.append(constraint)
        }
        sidecar.updatedAt = Date()
        cache[constraint.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Update an existing constraint (= matches by id). Throws
    /// `.constraintNotFound` when the id is unknown for the
    /// supplied book.
    public func update(_ constraint: BookSettingConstraint) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: constraint.bookId)
        guard let idx = sidecar.constraints.firstIndex(where: { $0.id == constraint.id }) else {
            throw BookSettingConstraintsError.constraintNotFound(id: constraint.id)
        }
        sidecar.constraints[idx] = constraint
        sidecar.updatedAt = Date()
        cache[constraint.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Remove a constraint by id. Walks the cache to find the
    /// owning book (= the caller does not always supply a
    /// bookId; we look it up from the cached sidecars first,
    /// then fall back to scanning shelvesRoot).
    public func remove(id: UUID) async throws {
        // Cache hit (= the view loaded constraints first via
        // `list(...)`, then calls `remove(id:)`).
        for (bookId, sidecar) in cache where sidecar.constraints.contains(where: { $0.id == id }) {
            var updated = sidecar
            updated.constraints.removeAll { $0.id == id }
            updated.updatedAt = Date()
            cache[bookId] = updated
            try await persistSidecar(updated)
            return
        }
        // Fallback: scan every shelf for a book that owns this
        // constraint. Same forgiving walk BookStore uses to
        // resolve bookDirectory(=).
        if let found = try await findConstraintAcrossBooks(id: id) {
            var updated = try await loadOrCreateSidecar(bookId: found.bookId)
            updated.constraints.removeAll { $0.id == id }
            updated.updatedAt = Date()
            cache[found.bookId] = updated
            try await persistSidecar(updated)
            return
        }
        throw BookSettingConstraintsError.constraintNotFound(id: id)
    }

    /// All constraints in a book (= filterable by severity /
    /// scope). When all filters are nil, returns every row.
    public func list(
        bookId: UUID,
        severity: ConstraintSeverity? = nil,
        scope: ConstraintScope? = nil
    ) async throws -> [BookSettingConstraint] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.constraints.filter { constraint in
            let severityMatches = severity.map { $0 == constraint.severity } ?? true
            let scopeMatches = scope.map { $0 == constraint.scope } ?? true
            return severityMatches && scopeMatches
        }
        // Stable display order: severity ascending (= hard first),
        // then title asc, then createdAt asc.
        return filtered.sorted { lhs, rhs in
            let lhsSeverityOrder = severityRank(lhs.severity)
            let rhsSeverityOrder = severityRank(rhs.severity)
            if lhsSeverityOrder != rhsSeverityOrder {
                return lhsSeverityOrder < rhsSeverityOrder
            }
            if lhs.title != rhs.title {
                return lhs.title < rhs.title
            }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Check the supplied chapter text against every active
    /// constraint's `forbiddenPatterns`. Empty chapter text =
    /// empty violations (= forgiving). Empty constraint set =
    /// empty violations.
    ///
    /// The match strategy:
    ///   - Literal substring match (= case-insensitive) first;
    ///     if found, emit a violation with the surrounding
    ///     text snippet (= up to 80 chars).
    ///   - Regex match (= compile with `.caseInsensitive` +
    ///     `.dotMatchesLineSeparators`) as a fallback for
    ///     patterns that contain regex metacharacters (= ^,
    ///     $, ., *, +, ?, [, ], (, ), {, }, |, \\). Compile
    ///     failures are ignored (= forgiving; the pattern is
    ///     treated as a literal that did not match).
    ///   - Line number = 1-indexed within the supplied text.
    ///
    /// Returns zero or more `ConstraintViolation` rows; = empty
    /// when no forbidden pattern matches (= common for early
    /// drafts).
    public func check(
        chapterText: String,
        bookId: UUID
    ) async throws -> [ConstraintViolation] {
        let constraints = try await list(bookId: bookId)
        guard !constraints.isEmpty, !chapterText.isEmpty else { return [] }
        // Pre-compute the line offsets (= byte ranges per
        // 1-indexed line number) so we can report a lineNumber
        // for each match.
        let lines = chapterText.components(separatedBy: "\n")
        var lineOffsets: [Int] = []
        var runningOffset = 0
        for line in lines {
            lineOffsets.append(runningOffset)
            runningOffset += line.count + 1 // +1 for the newline
        }

        var violations: [ConstraintViolation] = []
        for constraint in constraints {
            for pattern in constraint.forbiddenPatterns where !pattern.isEmpty {
                let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                // 1. Literal substring match.
                var searchRange = chapterText.startIndex..<chapterText.endIndex
                while let range = chapterText.range(
                    of: trimmed,
                    options: .caseInsensitive,
                    range: searchRange
                ) {
                    let lineNumber = computeLineNumber(for: range.lowerBound, in: chapterText, lineOffsets: lineOffsets)
                    let snippet = makeSnippet(around: range, in: chapterText)
                    let suggestion = "Rewrite to comply with \"\(constraint.title)\"."
                    violations.append(ConstraintViolation(
                        constraintId: constraint.id,
                        title: constraint.title,
                        severity: constraint.severity,
                        scope: constraint.scope,
                        matchedText: snippet,
                        lineNumber: lineNumber,
                        suggestion: suggestion
                    ))
                    // Advance the search range past this match
                    // so we don't infinite-loop on overlapping
                    // patterns (= e.g. "the the").
                    searchRange = range.upperBound..<chapterText.endIndex
                    if searchRange.isEmpty { break }
                }
                // 2. Regex fallback (= try compile; on failure
                // skip silently). Use NSRegularExpression for
                // portability with Swift 6 strict concurrency.
                if let regex = try? NSRegularExpression(
                    pattern: trimmed,
                    options: [.caseInsensitive, .dotMatchesLineSeparators]
                ) {
                    let nsRange = NSRange(chapterText.startIndex..., in: chapterText)
                    let matches = regex.matches(in: chapterText, range: nsRange)
                    for match in matches {
                        guard let swiftRange = Range(match.range, in: chapterText) else { continue }
                        let lineNumber = computeLineNumber(for: swiftRange.lowerBound, in: chapterText, lineOffsets: lineOffsets)
                        let snippet = makeSnippet(around: swiftRange, in: chapterText)
                        let suggestion = "Rewrite to comply with \"\(constraint.title)\"."
                        violations.append(ConstraintViolation(
                            constraintId: constraint.id,
                            title: constraint.title,
                            severity: constraint.severity,
                            scope: constraint.scope,
                            matchedText: snippet,
                            lineNumber: lineNumber,
                            suggestion: suggestion
                        ))
                    }
                }
            }
        }
        // Stable sort for tests + UI display: by line number
        // asc, then severity rank asc, then title asc.
        let sorted = violations.sorted { lhs, rhs in
            let lhsLine = lhs.lineNumber ?? 0
            let rhsLine = rhs.lineNumber ?? 0
            if lhsLine != rhsLine { return lhsLine < rhsLine }
            let lhsSeverityOrder = severityRank(lhs.severity)
            let rhsSeverityOrder = severityRank(rhs.severity)
            if lhsSeverityOrder != rhsSeverityOrder {
                return lhsSeverityOrder < rhsSeverityOrder
            }
            return lhs.title < rhs.title
        }
        // Dedupe: literal and regex matchers may both fire on
        // the same forbidden phrase (= a literal string is also
        // a valid regex). Collapse duplicates with the same
        // (constraintId, matchedText, lineNumber) tuple so the
        // writer sees one row per actual violation.
        var seen: Set<String> = []
        var deduped: [ConstraintViolation] = []
        for v in sorted {
            let key = "\(v.constraintId.uuidString)|\(v.matchedText)|\(v.lineNumber ?? -1)"
            if seen.insert(key).inserted {
                deduped.append(v)
            }
        }
        return deduped
    }

    // MARK: - Internals

    /// Map a severity to a stable rank for sort order:
    /// hard (= 0) < soft (= 1) < preference (= 2). Hard rules
    /// surface first so the writer sees the most blocking
    /// violations at the top of the list.
    private func severityRank(_ severity: ConstraintSeverity) -> Int {
        switch severity {
        case .hard:        return 0
        case .soft:        return 1
        case .preference:  return 2
        }
    }

    /// Compute a 1-indexed line number for a character offset
    /// (= the lower bound of a match range) using the precomputed
    /// line offsets. Returns nil when the offset is past the
    /// computed offsets (= safety net; should not happen in
    /// practice).
    private func computeLineNumber(for index: String.Index, in text: String, lineOffsets: [Int]) -> Int? {
        let offset = index.utf16Offset(in: text)
        // Binary-search the offset list for the largest line
        // offset <= the match offset.
        var low = 0
        var high = lineOffsets.count - 1
        var candidate = -1
        while low <= high {
            let mid = (low + high) / 2
            if lineOffsets[mid] <= offset {
                candidate = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return candidate >= 0 ? candidate + 1 : nil
    }

    /// Render the supplied text window around the match range
    /// (= truncated to 80 chars max with a leading / trailing
    /// ellipsis as needed) so the writer can confirm the hit
    /// without re-reading the entire chapter.
    private func makeSnippet(around range: Range<String.Index>, in text: String) -> String {
        let prefix = 30
        let suffix = 30
        let start = text.index(
            range.lowerBound,
            offsetBy: -prefix,
            limitedBy: text.startIndex
        ) ?? text.startIndex
        let end = text.index(
            range.upperBound,
            offsetBy: suffix,
            limitedBy: text.endIndex
        ) ?? text.endIndex
        var snippet = String(text[start..<end])
        if start > text.startIndex { snippet = "…" + snippet }
        if end < text.endIndex { snippet = snippet + "…" }
        if snippet.count > 80 {
            snippet = String(snippet.prefix(80)) + "…"
        }
        return snippet
    }

    /// Scan every shelf for a book that owns the supplied
    /// constraint id (= used by `remove(id:)` when the caller
    /// has not loaded the constraint into cache yet).
    private func findConstraintAcrossBooks(id: UUID) async throws -> BookSettingConstraint? {
        let shelvesRoot = bookStore.stores.shelvesRoot
        guard fileManager.fileExists(atPath: shelvesRoot.path) else { return nil }
        let shelfURLs = try fileManager.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for shelfURL in shelfURLs {
            let booksDir = shelfURL.appendingPathComponent("books", isDirectory: true)
            guard fileManager.fileExists(atPath: booksDir.path) else { continue }
            let bookURLs = try fileManager.contentsOfDirectory(
                at: booksDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for bookURL in bookURLs {
                let sidecarURL = bookURL.appendingPathComponent(Self.sidecarFilename)
                guard fileManager.fileExists(atPath: sidecarURL.path) else { continue }
                guard let data = try? Data(contentsOf: sidecarURL) else { continue }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                guard let sidecar = try? decoder.decode(BookSettingConstraintsSidecar.self, from: data) else { continue }
                if let match = sidecar.constraints.first(where: { $0.id == id }) {
                    return match
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
            throw BookSettingConstraintsError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create an empty one +
    /// persist if missing). Forgiving on corrupt JSON (= returns
    /// an empty sidecar instead of throwing, matching the
    /// kanban / todo / long-form-guardrails /
    /// character-relationships / character-lifecycle /
    /// ideas / tag-manager convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> BookSettingConstraintsSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = BookSettingConstraintsSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // the LongFormGuardrails / CharacterRelationshipTracker
            // / CharacterLifecycleTracker first-load behaviour:
            // only write to disk once the user actually adds a
            // constraint).
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(BookSettingConstraintsSidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: log nothing (= no logger dependency);
            // return an empty sidecar so the caller can keep
            // going. Matches `BookKanbanStore` /
            // `BookTodoStore` load paths.
            let empty = BookSettingConstraintsSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors `BookProjectConfigStore.atomicWrite`).
    private func persistSidecar(_ sidecar: BookSettingConstraintsSidecar) async throws {
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