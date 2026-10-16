// 
// … (= 42 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// MARK: - PlaceholderStatus enum
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / "free-form transitions" behavior).
enum PlaceholderStatus: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    /// The placeholder has not yet been addressed.
    case open
    /// The placeholder has been replaced with real content
    /// (= status terminal success).
    case resolved
    /// The placeholder was abandoned (= the author chose not to
    /// address it; kept for archaeology but no longer in flight).
    case abandoned

    var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    var displayName: String {
        switch self {
        case .open:      return "Open"
        case .resolved:  return "Resolved"
        case .abandoned: return "Abandoned"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .open:      return "circle"                // Lucide 'circle'
        case .resolved:  return "checkmark.circle"      // Lucide 'check-circle-2'
        case .abandoned: return "xmark.circle"          // Lucide 'xmark.circle'
        }
    }

    /// Terminal statuses that mean the placeholder is no longer
    /// "in flight" (= the writer does not need to act on it again).
    var isTerminal: Bool {
        switch self {
        case .resolved, .abandoned: return true
        case .open:                 return false
        }
    }
}

// MARK: - Placeholder struct
// … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
// /   - A lifecycle status (= see PlaceholderStatus).
struct Placeholder: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier (= used by the actor for add / update /
    /// remove lookups; never re-used even across books).
    let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    let bookId: UUID

    /// Chapter id where the placeholder was found.
    let chapterId: UUID

    /// 1-indexed line number of the placeholder within the
    /// chapter text.
    let lineNumber: Int

    /// Surrounding text excerpt (= the matched line + a small
    /// leading / trailing window). Trimmed at construction time.
    let context: String

    /// The literal matched text (= e.g. "[TODO: check this]").
    let pattern: String

    /// Lifecycle status (= see PlaceholderStatus).
    let status: PlaceholderStatus

    /// Creation timestamp (= `Date.now` at add time).
    let createdAt: Date

    init(
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
// … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `Chapter`).
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
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / / IdeaLibrary error conventions (= a LocalizedError per case).
enum PlaceholderScannerError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case placeholderNotFound(id: UUID)
    case invalidPattern(pattern: String, underlying: String)

    var errorDescription: String? {
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
// … (= 21 rationale lines collapsed; = A112 docblock collapse per §1.8)
// /     on `add` (= no row is persisted).
actor PlaceholderScanner {

    // / Sidecar on-disk filename (= parallel to
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `setting-constraints.json`).
    private static let sidecarFilename = "placeholders.json"

    // / Built-in default pattern set. Matches the Python
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /  7. `{{...}}`           (mustache / handlebars template)
    static let defaultPatterns: [String] = [
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

    // / Internal init (= matches `ForeshadowingTracker.init` /
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / be public).
    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - CRUD
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     strict policy on empty labels).
    func add(_ placeholder: Placeholder) async throws {
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

    // / Update an existing placeholder (= by id). Persists +
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     (= no row is persisted).
    func update(_ placeholder: Placeholder) async throws {
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
    func remove(id: UUID) async throws {
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
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / chapter. When both filters are nil, returns every row.
    func list(
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
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    // / Single-placeholder lookup by id. Returns `nil` (= NOT
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / matches the view layer's "optional row" idiom).
    func get(id: UUID) async throws -> Placeholder? {
        guard let bookId = try await getBookId(for: id) else { return nil }
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.placeholders.first { $0.id == id }
    }

    // MARK: - Status helpers
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / over `update`).
    func resolve(id: UUID) async throws {
        try await setStatus(id: id, to: .resolved)
    }

    /// Mark a placeholder as abandoned (= convenience wrapper
    /// over `update`).
    func abandon(id: UUID) async throws {
        try await setStatus(id: id, to: .abandoned)
    }

    // / Mark a placeholder as open (= convenience wrapper over
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / not actually addressed).
    func reopen(id: UUID) async throws {
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
    // … (= 22 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / choose what to persist).
    func scan(
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

    // / Convenience: scan + persist every match (= callers who
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Returns the rows that were persisted.
    @discardableResult
    func scanAndAdd(
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
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / work first" policy.
    private static func statusDisplayPriority(_ status: PlaceholderStatus) -> Int {
        switch status {
        case .open:      return 0
        case .resolved:  return 1
        case .abandoned: return 2
        }
    }

    // MARK: - Internals
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / O(N_cached_books).
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

    // / Resolve the sidecar on disk for the given book. Walks
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw PlaceholderScannerError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    // / Load the sidecar from disk (= or create an empty one if
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / foreshadowings convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> PlaceholderSidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = PlaceholderSidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    // / Persist the sidecar to disk (= atomic write via tmp +
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `BookProjectConfigStore.atomicWrite`).
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

    // / Compile the supplied pattern table into
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / behavior; a single bad regex never blocks the scan).
    private func compilePatterns(_ patterns: [String]) -> [NSRegularExpression] {
        var compiled: [NSRegularExpression] = []
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                compiled.append(regex)
            } catch {
                // Skip silently (= invalid patterns are not
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // `re.compile` fallback behavior).
                continue
            }
        }
        return compiled
    }

    // / Build the context window around a match. Returns the
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / because chapter lines are usually short).
    private static func contextWindow(
        for line: String,
        matchRange: NSRange,
        fullLineRange: NSRange,
        in nsLine: NSString
    ) -> String {
        // The line itself is the context window. If the
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // line.
        guard matchRange.location != NSNotFound,
              matchRange.location + matchRange.length <= fullLineRange.length else {
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
