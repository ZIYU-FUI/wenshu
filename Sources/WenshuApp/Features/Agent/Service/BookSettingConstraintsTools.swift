// 
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
import Foundation

// MARK: - ConstraintSeverity enum
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / without having to re-read the source module.
enum ConstraintSeverity: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    // / Absolutely cannot be violated (= magic system laws,
    // / physical laws, hard continuity rules).
    case hard
    // / Strongly preferred but can be broken for narrative
    // / reasons (= soften the rule with a beatable excuse).
    case soft
    /// Nice-to-have style preference (= tone / voice target).
    case preference

    var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    var displayName: String {
        switch self {
        case .hard:        return "Hard"
        case .soft:        return "Soft"
        case .preference:  return "Preference"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .hard:        return "exclamationmark.shield"  // Lucide 'shield-alert'
        case .soft:        return "shield"                  // Lucide 'shield'
        case .preference:  return "leaf"                    // Lucide 'feather'
        }
    }
}

// MARK: - ConstraintScope enum
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / `agent/specialized/book_setting_constraints.py::SCOPE_TABLE`.
enum ConstraintScope: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// Applies to entire world (= physics, magic system).
    case world
    /// Applies to a specific character (= abilities, traits).
    case character
    /// Applies to a specific plot (= event rules).
    case plot
    /// Applies to writing style (= POV, tense, vocabulary).
    case style

    var id: String { rawValue }

    /// Human-readable English label (= for the picker).
    var displayName: String {
        switch self {
        case .world:       return "World"
        case .character:   return "Character"
        case .plot:        return "Plot"
        case .style:       return "Style"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .world:       return "globe"                       // Lucide 'globe'
        case .character:   return "person"                      // Lucide 'user'
        case .plot:        return "arrow.triangle.branch"       // Lucide 'git-branch'
        case .style:       return "paintpalette"                // Lucide 'palette'
        }
    }

    // / Whether this scope supports a non-nil `appliesToId` (= a
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / an appliesToId.
    var supportsAppliesTo: Bool {
        switch self {
        case .character, .plot: return true
        case .world, .style:    return false
        }
    }
}

// MARK: - BookSettingConstraint struct
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / sidecar.
struct BookSettingConstraint: Sendable, Codable, Equatable, Identifiable {

    // / Stable identifier (= used by the actor for add / update /
    // / remove / check lookups; never re-used even across books).
    let id: UUID

    // / Owning book (= the actor resolves the on-disk sidecar
    // / through this id).
    let bookId: UUID

    /// Short title (= e.g. "Magic requires eye contact").
    let title: String

    // / 2-3 sentences explaining the rule (= surfaced in the
    // / violations list and the picker tooltip).
    let description: String

    /// How strictly this rule is held (= see ConstraintSeverity).
    let severity: ConstraintSeverity

    /// What surface the rule applies to (= see ConstraintScope).
    let scope: ConstraintScope

    // / Optional target id (= the character or plot the constraint
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / universally).
    let appliesToId: UUID?

    // / Regex or literal phrases that violate this constraint.
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / only; = still useful for soft / preference severities).
    let forbiddenPatterns: [String]

    /// Creation timestamp (= `Date.now` at add time).
    let createdAt: Date

    init(
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
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / the writer to fix).
struct ConstraintViolation: Sendable, Codable, Equatable, Identifiable {

    // / Synthetic identifier (= constraintId + line number +
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / duplicate-key collisions on repeated matches.
    let id: UUID

    /// Constraint id (= the rule that triggered this violation).
    let constraintId: UUID

    // / Constraint title (= copied at violation time so the UI
    // / can render it without dereferencing the constraint).
    let title: String

    /// Severity of the rule (= hard / soft / preference).
    let severity: ConstraintSeverity

    /// Scope of the rule (= world / character / plot / style).
    let scope: ConstraintScope

    // / The actual text that triggered the violation (= first
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / truncated).
    let matchedText: String

    // / 1-indexed line number where the match was found (= nil
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / was on the first logical line).
    let lineNumber: Int?

    /// Suggested fix (= e.g. "Rewrite to maintain eye contact").
    let suggestion: String

    init(
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
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / writes one of these per book (= keyed by `bookId`).
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
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / conventions (= a LocalizedError per case).
enum BookSettingConstraintsError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case constraintNotFound(id: UUID)

    var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "BookSettingConstraints: book directory not found for id \(id.uuidString)"
        case .constraintNotFound(let id):
            return "BookSettingConstraints: constraint \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// /     `.bookDirectoryNotFound`.
actor BookSettingConstraints {

    // / Sidecar on-disk filename (= parallel to
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / `tag-manager.json`).
    private static let sidecarFilename = "setting-constraints.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: BookSettingConstraintsSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // /     policy + the CharacterRelationshipTracker add path).
    func add(_ constraint: BookSettingConstraint) async throws {
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

    // / Update an existing constraint (= matches by id). Throws
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / supplied book.
    func update(_ constraint: BookSettingConstraint) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: constraint.bookId)
        guard let idx = sidecar.constraints.firstIndex(where: { $0.id == constraint.id }) else {
            throw BookSettingConstraintsError.constraintNotFound(id: constraint.id)
        }
        sidecar.constraints[idx] = constraint
        sidecar.updatedAt = Date()
        cache[constraint.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    // / Remove a constraint by id. Walks the cache to find the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / then fall back to scanning shelvesRoot).
    func remove(id: UUID) async throws {
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
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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

    // / All constraints in a book (= filterable by severity /
    // / scope). When all filters are nil, returns every row.
    func list(
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

    // / Check the supplied chapter text against every active
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / drafts).
    func check(
        chapterText: String,
        bookId: UUID
    ) async throws -> [ConstraintViolation] {
        let constraints = try await list(bookId: bookId)
        guard !constraints.isEmpty, !chapterText.isEmpty else { return [] }
        // Pre-compute the line offsets (= byte ranges per
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
                    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                    // patterns (= e.g. "the the").
                    searchRange = range.upperBound..<chapterText.endIndex
                    if searchRange.isEmpty { break }
                }
                // 2. Regex fallback (= try compile; on failure
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / violations at the top of the list.
    private func severityRank(_ severity: ConstraintSeverity) -> Int {
        switch severity {
        case .hard:        return 0
        case .soft:        return 1
        case .preference:  return 2
        }
    }

    // / Compute a 1-indexed line number for a character offset
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / practice).
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

    // / Render the supplied text window around the match range
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / without re-reading the entire chapter.
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

    // / Scan every shelf for a book that owns the supplied
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / has not loaded the constraint into cache yet).
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

    // / Resolve the sidecar on disk for the given book. Walks the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw BookSettingConstraintsError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    // / Load the sidecar from disk (= or create an empty one +
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / ideas / tag-manager convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> BookSettingConstraintsSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = BookSettingConstraintsSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // `BookKanbanStore` load paths.
            let empty = BookSettingConstraintsSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    // / Persist the sidecar to disk (= atomic write via tmp +
    // / rename; mirrors `BookProjectConfigStore.atomicWrite`).
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