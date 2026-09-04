//
//  PlaceholderScannerTools.swift · Wenshu · P2 ticket #18 (PORT-SPECIALIZED-013, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/specialized/placeholder_scanner.py`.
//
//  The Python module scans chapter text for inline authoring
//  placeholders (= TODO / FIXME / XXX / INSERT / TBD / HERE /
//  custom mustache) and lets the writer add / list / remove /
//  resolve / abandon rows in a per-book tracker. The Swift port
//  exposes the same surface:
//    - Placeholder CRUD (= add / list filtered by status + / or
//      chapter / update / remove).
//    - Status transitions (= any-state-to-any-state, no enforced
//      linear order; matches the loose Python policy).
//    - Built-in pattern table (= 7 default regex patterns, fully
//      overridable at `scan(...)` time).
//    - Chapter scan (= runs the pattern set against a chapter
//      body and returns every match as a `Placeholder` row).
//    - Resolve / abandon helpers (= thin status-setters that
//      delegate to `update` for caller convenience).
//
//  Persistence: per-book JSON sidecar at
//    `books/<bookId>/placeholders.json`
//  Mirrors the `kanban.json` / `todo.json` / `tags.json` /
//  `ideas.json` / `foreshadowings.json` / `setting-constraints.json`
//  pattern (= canonical wenshu per-book JSON convention per
//  AGENTS.md §11).
//
//  Concurrency: actor (= Swift 6 strict concurrency). Reads /
//  writes serialize cleanly across the SpecializedTools pane +
//  any background LLM-side call sites.
//
//  Standards-axis (wenshu house style):
//    S1 (Apple-API-first): Foundation only; no third-party
//        text-analysis deps (= built-in `NSRegularExpression`).
//    S3 (single source of truth for JSON parsing): the actor
//        owns the JSONDecoder / JSONEncoder pair; the view
//        never touches the file system.
//    S4 (no new third-party deps): zero added.
//    S5 (no private types the rest of the app needs): all
//        types public (= matches the ticket spec).
//    S6 (English-only): this file + the docstrings are 100%
//        English per AGENTS.md hard rule.
//

import Foundation

// MARK: - PlaceholderStatus enum

/// The 3 statuses a placeholder can carry in its lifecycle.
/// Each case maps 1:1 to a value in hermes's
/// `agent/specialized/placeholder_scanner.py::STATUS_TABLE`.
///
/// Status flow is intentionally loose (= users can move a
/// placeholder between any two states directly without an
/// enforced linear order; = matches the Python implementation's
/// "free-form transitions" behavior).
public enum PlaceholderStatus: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// The placeholder has not yet been addressed.
    case open
    /// The placeholder has been replaced with real content
    /// (= status terminal success).
    case resolved
    /// The placeholder was abandoned (= the author chose not to
    /// address it; kept for archaeology but no longer in flight).
    case abandoned

    public var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    public var displayName: String {
        switch self {
        case .open:      return "Open"
        case .resolved:  return "Resolved"
        case .abandoned: return "Abandoned"
        }
    }

    /// Lucide icon name (= already wired into wenshu's chrome).
    public var lucideIcon: String {
        switch self {
        case .open:      return "circle"
        case .resolved:  return "check-circle-2"
        case .abandoned: return "circle-x"
        }
    }

    /// Terminal statuses that mean the placeholder is no longer
    /// "in flight" (= the writer does not need to act on it again).
    public var isTerminal: Bool {
        switch self {
        case .resolved, .abandoned: return true
        case .open:                 return false
        }
    }
}

// MARK: - Placeholder struct

/// A single placeholder row in the per-book tracker.
/// Persisted as one entry in the per-book `placeholders.json`
/// sidecar.
///
/// A placeholder carries:
///   - The owning book id (= the actor resolves the on-disk
///     sidecar through this id).
///   - The chapter id where the placeholder was found (= source
///     chapter for a scan, otherwise the chapter the user tags).
///   - A 1-indexed line number within the chapter where the
///     placeholder was found (= matches the Python module's
///     `line_number` field).
///   - A short surrounding text excerpt (= `context`).
///   - The matched pattern string (= the literal text that
///     triggered the match; matches the Python module's
///     `pattern` field).
///   - A lifecycle status (= see PlaceholderStatus).
public struct Placeholder: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / update /
    /// remove lookups; never re-used even across books).
    public let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    public let bookId: UUID

    /// Chapter id where the placeholder was found.
    public let chapterId: UUID

    /// 1-indexed line number of the placeholder within the
    /// chapter text.
    public let lineNumber: Int

    /// Surrounding text excerpt (= the matched line + a small
    /// leading / trailing window). Trimmed at construction time.
    public let context: String

    /// The literal matched text (= e.g. "[TODO: check this]").
    public let pattern: String

    /// Lifecycle status (= see PlaceholderStatus).
    public let status: PlaceholderStatus

    /// Creation timestamp (= `Date.now` at add time).
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        bookId: UUID,
        chapterId: UUID,
        lineNumber: Int = 0,
        context: String = "",
        pattern: String,
        status: PlaceholderStatus = .open,
        createdAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.chapterId = chapterId
        self.lineNumber = max(0, lineNumber)
        self.context = context.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pattern = pattern
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - Sidecar on-disk shape

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`).
///
/// The sidecar holds a single array of placeholders; each row
/// is self-contained (= matches the hermes Python design where
/// `Placeholder` is a flat row, not a relational join with
/// `Chapter`).
struct PlaceholderSidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var placeholders: [Placeholder]
    var updatedAt: Date

    init(
        bookId: UUID,
        placeholders: [Placeholder] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.placeholders = placeholders
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors

/// Errors thrown by `PlaceholderScanner`. Mirrors the
/// ForeshadowingTracker / TagManager / CharacterLifecycleTracker
/// / IdeaLibrary error conventions (= a LocalizedError per case).
public enum PlaceholderScannerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case placeholderNotFound(id: UUID)
    case invalidPattern(pattern: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "PlaceholderScanner: book directory not found for id \(id.uuidString)"
        case .placeholderNotFound(let id):
            return "PlaceholderScanner: placeholder \(id.uuidString) not found"
        case .invalidPattern(let pattern, let underlying):
            return "PlaceholderScanner: invalid regex pattern \(pattern): \(underlying)"
        }
    }
}

// MARK: - Actor

/// Per-book placeholder scanner. Holds the in-memory cache +
/// owns the on-disk JSON sidecar + runs the regex scanner
/// against chapter text.
///
/// Persistence: `<bookDir>/placeholders.json`. The actor
/// resolves `<bookDir>` via `BookStore.bookDirectory(bookId:)`
/// (= the canonical forgiving walk that searches every shelf's
/// `books/<id>/` subfolder).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// tags / lifecycle / relationships / ideas / constraints /
/// foreshadowings sidecar convention):
///   - Missing sidecar = empty list (= first-load behavior).
///   - Corrupt sidecar = empty list (= never bricks the UI).
///   - Missing book directory = throws
///     `.bookDirectoryNotFound`.
///   - Empty / whitespace-only patterns are rejected silently
///     on `add` (= no row is persisted).
public actor PlaceholderScanner {

    /// Sidecar on-disk filename (= parallel to
    /// `kanban.json` / `todo.json` / `tags.json` / `ideas.json`
    /// / `foreshadowings.json` /
    /// `setting-constraints.json`).
    private static let sidecarFilename = "placeholders.json"

    /// Built-in default pattern set. Matches the Python
    /// `DEFAULT_PATTERNS` table (= 7 regex patterns covering
    /// the common authoring-placeholder families + the
    /// mustache / handlebars double-brace family for the
    /// custom-template case).
    ///
    /// Each entry is an `NSRegularExpression`-compatible
    /// pattern string. The 7 patterns are:
    ///
    ///  1. `[TODO ...]`        (TODO with optional body)
    ///  2. `[FIXME ...]`       (FIXME with optional body)
    ///  3. `[XXX ...]`         (XXX with optional body)
    ///  4. `[INSERT ...]`      (INSERT with optional body)
    ///  5. `[TBD ...]`         (TBD with optional body)
    ///  6. `<HERE>`            (literal HERE marker)
    ///  7. `{{...}}`           (mustache / handlebars template)
    public static let defaultPatterns: [String] = [
        #"\[TODO[^\]]*\]"#,
        #"\[FIXME[^\]]*\]"#,
        #"\[XXX[^\]]*\]"#,
        #"\[INSERT[^\]]*\]"#,
        #"\[TBD[^\]]*\]"#,
        #"<HERE>"#,
        #"\{\{[^}]+\}\}"#
    ]

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: PlaceholderSidecar] = [:]

    /// Internal init (= matches `ForeshadowingTracker.init` /
    /// `IdeaLibrary.init` / `BookSettingConstraints.init` /
    /// `CharacterLifecycleTracker.init` house style: the
    /// `BookStore` type itself is internal so the init cannot
    /// be public).
    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - CRUD

    /// Add a new placeholder. Persists + caches.
    ///
    /// Behaviour:
    ///   - Idempotent on `id`: re-adding with the same id replaces
    ///     the existing row (= matches `IdeaLibrary.add` upsert
    ///     policy).
    ///   - Empty / whitespace-only patterns are rejected silently
    ///     (= no row is persisted; matches the tag manager's
    ///     strict policy on empty labels).
    public func add(_ placeholder: Placeholder) async throws {
        guard !placeholder.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var sidecar = try await loadOrCreateSidecar(bookId: placeholder.bookId)
        if let idx = sidecar.placeholders.firstIndex(where: { $0.id == placeholder.id }) {
            sidecar.placeholders[idx] = placeholder
        } else {
            sidecar.placeholders.append(placeholder)
        }
        sidecar.updatedAt = Date()
        cache[placeholder.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Update an existing placeholder (= by id). Persists +
    /// caches.
    ///
    /// Behaviour:
    ///   - Matches the row by `placeholder.id`.
    ///   - Throws `.placeholderNotFound` if no row with the same
    ///     id exists for any cached book.
    ///   - Empty / whitespace-only patterns are rejected silently
    ///     (= no row is persisted).
    public func update(_ placeholder: Placeholder) async throws {
        guard !placeholder.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Load the sidecar (= warms the cache for the owning
        // book) BEFORE the existence check.
        var sidecar = try await loadOrCreateSidecar(bookId: placeholder.bookId)
        guard let idx = sidecar.placeholders.firstIndex(where: { $0.id == placeholder.id }) else {
            throw PlaceholderScannerError.placeholderNotFound(id: placeholder.id)
        }
        sidecar.placeholders[idx] = placeholder
        sidecar.updatedAt = Date()
        cache[placeholder.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Remove a placeholder by id. Throws `.placeholderNotFound`
    /// when the id is unknown for any cached book.
    public func remove(id: UUID) async throws {
        if let bookId = try await getBookId(for: id) {
            var sidecar = try await loadOrCreateSidecar(bookId: bookId)
            guard let idx = sidecar.placeholders.firstIndex(where: { $0.id == id }) else {
                throw PlaceholderScannerError.placeholderNotFound(id: id)
            }
            sidecar.placeholders.remove(at: idx)
            sidecar.updatedAt = Date()
            cache[bookId] = sidecar
            try await persistSidecar(sidecar)
            return
        }
        throw PlaceholderScannerError.placeholderNotFound(id: id)
    }

    // MARK: - Queries

    /// All placeholders in a book, filterable by status and / or
    /// chapter. When both filters are nil, returns every row.
    public func list(
        bookId: UUID,
        status: PlaceholderStatus? = nil,
        chapterId: UUID? = nil
    ) async throws -> [Placeholder] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        let filtered = sidecar.placeholders.filter { row in
            let statusOK = status.map { $0 == row.status } ?? true
            let chapterOK = chapterId.map { $0 == row.chapterId } ?? true
            return statusOK && chapterOK
        }
        // Stable display order: open first, then resolved, then
        // abandoned (= in-flight first, then terminal); line
        // number ascending as the primary tiebreaker (= matches
        // the "earliest in the chapter first" UX), then by
        // creation date.
        return filtered.sorted { lhs, rhs in
            let lhsPriority = PlaceholderScanner.statusDisplayPriority(lhs.status)
            let rhsPriority = PlaceholderScanner.statusDisplayPriority(rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.lineNumber != rhs.lineNumber { return lhs.lineNumber < rhs.lineNumber }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Single-placeholder lookup by id. Returns `nil` (= NOT
    /// throws) when the id is unknown for any cached book (=
    /// matches the view layer's "optional row" idiom).
    public func get(id: UUID) async throws -> Placeholder? {
        guard let bookId = try await getBookId(for: id) else { return nil }
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.placeholders.first { $0.id == id }
    }

    // MARK: - Status helpers

    /// Mark a placeholder as resolved (= convenience wrapper
    /// over `update`).
    public func resolve(id: UUID) async throws {
        try await setStatus(id: id, to: .resolved)
    }

    /// Mark a placeholder as abandoned (= convenience wrapper
    /// over `update`).
    public func abandon(id: UUID) async throws {
        try await setStatus(id: id, to: .abandoned)
    }

    /// Mark a placeholder as open (= convenience wrapper over
    /// `update`; useful for re-opening a previously-resolved
    /// placeholder when the writer discovers the original was
    /// not actually addressed).
    public func reopen(id: UUID) async throws {
        try await setStatus(id: id, to: .open)
    }

    private func setStatus(id: UUID, to newStatus: PlaceholderStatus) async throws {
        guard let existing = try await get(id: id) else {
            throw PlaceholderScannerError.placeholderNotFound(id: id)
        }
        let updated = Placeholder(
            id: existing.id,
            bookId: existing.bookId,
            chapterId: existing.chapterId,
            lineNumber: existing.lineNumber,
            context: existing.context,
            pattern: existing.pattern,
            status: newStatus,
            createdAt: existing.createdAt
        )
        try await update(updated)
    }

    // MARK: - Scan

    /// Scan chapter text for inline authoring placeholders.
    /// Returns one `Placeholder` per match (= same `bookId` +
    /// `chapterId` for every row; `lineNumber` is 1-indexed
    /// within the supplied text).
    ///
    /// - Parameters:
    ///   - chapterText: the chapter body to scan.
    ///   - bookId: the owning book (= written onto every
    ///     returned row).
    ///   - chapterId: the source chapter (= written onto every
    ///     returned row).
    ///   - patterns: optional override pattern table. Defaults
    ///     to `PlaceholderScanner.defaultPatterns` (= the 7
    ///     built-in regex patterns).
    /// - Returns: an array of `Placeholder` (= one per match;
    ///     in `.open` status with a fresh id + `createdAt =
    ///     .now`).
    ///
    /// The returned rows are NOT persisted to the sidecar
    /// (= the caller decides whether to insert them via
    /// `add(...)`; this matches the Python module's `scan`
    /// behavior which returns a list and lets the caller
    /// choose what to persist).
    public func scan(
        chapterText: String,
        bookId: UUID,
        chapterId: UUID,
        patterns: [String]? = nil
    ) async throws -> [Placeholder] {
        let patternSet = patterns ?? Self.defaultPatterns
        let compiled = compilePatterns(patternSet)
        guard !compiled.isEmpty else { return [] }

        // Split the chapter into 1-indexed lines once (= reused
        // across every regex match for context extraction).
        let lines = chapterText.components(separatedBy: .newlines)
        var results: [Placeholder] = []
        results.reserveCapacity(lines.count)

        for (oneBasedLineIdx, line) in lines.enumerated() {
            let lineNumber = oneBasedLineIdx + 1
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            guard fullRange.length > 0 else { continue }
            for regex in compiled {
                let matches = regex.matches(in: line, options: [], range: fullRange)
                for match in matches {
                    let patternText = nsLine.substring(with: match.range)
                    let context = Self.contextWindow(
                        for: line,
                        matchRange: match.range,
                        fullLineRange: fullRange,
                        in: nsLine
                    )
                    let row = Placeholder(
                        bookId: bookId,
                        chapterId: chapterId,
                        lineNumber: lineNumber,
                        context: context,
                        pattern: patternText,
                        status: .open
                    )
                    results.append(row)
                }
            }
        }
        return results
    }

    /// Convenience: scan + persist every match (= callers who
    /// want a one-shot "scan and add all" flow use this).
    /// Returns the rows that were persisted.
    @discardableResult
    public func scanAndAdd(
        chapterText: String,
        bookId: UUID,
        chapterId: UUID,
        patterns: [String]? = nil
    ) async throws -> [Placeholder] {
        let scanned = try await scan(
            chapterText: chapterText,
            bookId: bookId,
            chapterId: chapterId,
            patterns: patterns
        )
        for row in scanned {
            try await add(row)
        }
        return scanned
    }

    // MARK: - Status display priority

    /// Display priority for the `list` sort order: open (= 0)
    /// first, then resolved (= 1), then abandoned (= 2).
    /// Matches the Python module's "show me what still needs
    /// work first" policy.
    private static func statusDisplayPriority(_ status: PlaceholderStatus) -> Int {
        switch status {
        case .open:      return 0
        case .resolved:  return 1
        case .abandoned: return 2
        }
    }

    // MARK: - Internals

    /// Resolve which book a placeholder id belongs to. Walks the
    /// in-memory cache first; on miss, scans every book
    /// directory under `shelvesRoot` until one returns a hit.
    /// Returns `nil` when the id is unknown across the entire
    /// library.
    ///
    /// Performance: cold lookups touch at most N sidecar files
    /// (= one per book in the library). Warm lookups are
    /// O(N_cached_books).
    private func getBookId(for placeholderId: UUID) async throws -> UUID? {
        // Warm path: scan the in-memory cache.
        for (bookId, sidecar) in cache where sidecar.placeholders.contains(where: { $0.id == placeholderId }) {
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
                if sidecar.placeholders.contains(where: { $0.id == placeholderId }) {
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
            throw PlaceholderScannerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create an empty one if
    /// missing). Forgiving on corrupt JSON (= returns an empty
    /// sidecar instead of throwing, matching the kanban / todo /
    /// tags / lifecycle / relationships / ideas / constraints /
    /// foreshadowings convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> PlaceholderSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = PlaceholderSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // the IdeaLibrary / ForeshadowingTracker first-load
            // behavior: only write to disk once the user
            // actually adds a placeholder).
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(PlaceholderSidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: return an empty sidecar so the caller
            // can keep going.
            let empty = PlaceholderSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors `ForeshadowingTracker.persistSidecar` +
    /// `BookProjectConfigStore.atomicWrite`).
    private func persistSidecar(_ sidecar: PlaceholderSidecar) async throws {
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

    /// Compile the supplied pattern table into
    /// `NSRegularExpression` instances. Invalid patterns are
    /// skipped silently (= matches the forgiving Python
    /// behavior; a single bad regex never blocks the scan).
    private func compilePatterns(_ patterns: [String]) -> [NSRegularExpression] {
        var compiled: [NSRegularExpression] = []
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                compiled.append(regex)
            } catch {
                // Skip silently (= invalid patterns are not
                // fatal; matches the Python module's
                // `re.compile` fallback behavior).
                continue
            }
        }
        return compiled
    }

    /// Build the context window around a match. Returns the
    /// entire line (= matches the Python module's "context
    /// = full line containing the match" behavior; no slicing
    /// because chapter lines are usually short).
    private static func contextWindow(
        for line: String,
        matchRange: NSRange,
        fullLineRange: NSRange,
        in nsLine: NSString
    ) -> String {
        // The line itself is the context window. If the
        // match-range is invalid (= off the end of the
        // string for any reason), fall back to the whole
        // line.
        guard matchRange.location != NSNotFound,
              matchRange.location + matchRange.length <= fullLineRange.length else {
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
