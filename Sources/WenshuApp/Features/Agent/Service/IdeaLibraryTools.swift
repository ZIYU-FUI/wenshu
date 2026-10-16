// 
// … (= 46 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// MARK: - IdeaStatus enum
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / "free-form transitions" behavior).
enum IdeaStatus: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
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

    var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    var displayName: String {
        switch self {
        case .seedling:    return "Seedling"
        case .developing:  return "Developing"
        case .mature:      return "Mature"
        case .planted:     return "Planted"
        case .discarded:   return "Discarded"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .seedling:    return "leaf"               // Lucide 'sprout'
        case .developing:  return "leaf"               // Lucide 'leaf'
        case .mature:      return "tree"               // Lucide 'tree-deciduous'
        case .planted:     return "camera.macro"       // Lucide 'flower-2'
        case .discarded:   return "xmark.circle"       // Lucide 'xmark.circle'
        }
    }
}

// MARK: - IdeaLinkTarget enum
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / entity (= view-layer responsibility).
enum IdeaLinkTarget: String, Sendable, Codable, CaseIterable, Identifiable, Equatable {
    case chapter
    case character
    case plotThread

    var id: String { rawValue }

    /// Human-readable English label (= for the picker / list rows).
    var displayName: String {
        switch self {
        case .chapter:     return "Chapter"
        case .character:   return "Character"
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
        case .plotThread:  return "arrow.triangle.branch"       // Lucide 'git-branch'
        }
    }
}

// MARK: - IdeaLink struct
// … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / user-authored.
struct IdeaLink: Sendable, Codable, Equatable, Identifiable {
    /// Stable identifier (= used by the actor for unlink + dedupe;
    /// never re-used even across books).
    let id: UUID

    /// What kind of entity the idea is linked to (= chapter /
    /// character / plot-thread).
    let target: IdeaLinkTarget

    // / The entity id the idea is linked to. Interpretation
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / plotThreadId).
    let targetId: UUID

    // / 1-sentence description of where the idea appears in the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / construction time.
    let context: String

    init(
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
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / in the per-book `ideas.json` sidecar.
struct Idea: Sendable, Codable, Equatable, Identifiable {

    // / Stable identifier (= used by the actor for add / update /
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / books).
    let id: UUID

    /// Owning book (= the actor resolves the on-disk sidecar
    /// through this id).
    let bookId: UUID

    // / Short, human-readable label (= e.g. "The Mirror Motif").
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `add` / `update` methods.
    let title: String

    /// 2-3 sentence description of the idea. Trimmed at
    /// construction time.
    let description: String

    /// Lifecycle status (= seedling / developing / mature /
    /// planted / discarded).
    let status: IdeaStatus

    // / Free-form, user-supplied labels (= e.g. "mirror",
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / time.
    let tags: [String]

    /// Where this idea has been planted (= chapter / character /
    /// plot-thread triples + 1-sentence context).
    let links: [IdeaLink]

    /// Creation timestamp (= `Date.now` at add time).
    let createdAt: Date

    /// Last update timestamp (= `Date.now` at update time; = the
    /// actor bumps this on every `update`).
    let updatedAt: Date

    init(
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
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
// … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / where `Idea.links` is a per-idea list, not a separate table).
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
// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / LocalizedError per case).
enum IdeaLibraryError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case ideaNotFound(id: UUID)

    var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "IdeaLibrary: book directory not found for id \(id.uuidString)"
        case .ideaNotFound(let id):
            return "IdeaLibrary: idea \(id.uuidString) not found"
        }
    }
}

// MARK: - Actor
// … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / module's internal scope).
actor IdeaLibrary {

    // / Sidecar on-disk filename (= parallel to
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `character-lifecycle.json`).
    private static let sidecarFilename = "ideas.json"

    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: IdeaLibrarySidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     strict policy on empty labels).
    func add(_ idea: Idea) async throws {
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

    // / Update an existing idea (= by id). Persists + caches.
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     (= no row is persisted).
    func update(_ idea: Idea) async throws {
        guard !idea.title.isEmpty else { return }
        // Load the sidecar (= warms the cache for the owning
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // rows written by an earlier `add` call.
        var sidecar = try await loadOrCreateSidecar(bookId: idea.bookId)
        guard let idx = sidecar.ideas.firstIndex(where: { $0.id == idea.id }) else {
            throw IdeaLibraryError.ideaNotFound(id: idea.id)
        }
        // Bump `updatedAt` to "now" (= callers should already do
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    // / Remove an idea by id. Throws `.ideaNotFound` when the id
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / table to clean up).
    func remove(id: UUID) async throws {
        // Cold-cache: we have no bookId, so walk every cached
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    func list(
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

    // / Text search across title + description (= case-
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / UX).
    func search(bookId: UUID, query: String) async throws -> [Idea] {
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

    // / Single-idea lookup by id. Returns `nil` (= NOT throws)
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / view layer's "optional row" idiom).
    func get(id: UUID) async throws -> Idea? {
        guard let bookId = try await getBookId(for: id) else { return nil }
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.ideas.first { $0.id == id }
    }

    // / Link an idea to an entity (= record a new `IdeaLink` on
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   - Throws `.ideaNotFound` if no idea with that id exists.
    func link(ideaId: UUID, link: IdeaLink) async throws {
        // The caller always supplies `bookId` via the
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    // / Unlink an idea from an entity (= remove the matching
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the idea has no matching link.
    func unlink(ideaId: UUID, link: IdeaLink) async throws {
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // UI's "recently updated" ordering).
        if idea.links.count != originalCount {
            sidecar.ideas[idx] = idea
            sidecar.updatedAt = Date()
            cache[bookId] = sidecar
            try await persistSidecar(sidecar)
        }
    }

    // / Suggest ideas for a context keyword (= pure in-memory
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / descending.
    func suggest(bookId: UUID, context: String) async throws -> [Idea] {
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
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "loose keyword" behavior expected by `suggest`).
    static func tokenize(_ raw: String) -> [String] {
        raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    // / Resolve which book an idea id belongs to. Walks the
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / O(N_cached_books).
    private func getBookId(for ideaId: UUID) async throws -> UUID? {
        // Warm path: scan the in-memory cache.
        for (bookId, sidecar) in cache where sidecar.ideas.contains(where: { $0.id == ideaId }) {
            return bookId
        }
        // Cold path: walk every book directory under
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    // / Resolve the sidecar on disk for the given book. Walks the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `BookStore.bookDirectory(bookId:)`).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw IdeaLibraryError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    // / Load the sidecar from disk (= or create an empty one if
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / tags / lifecycle / relationships convention).
    private func loadOrCreateSidecar(bookId: UUID) async throws -> IdeaLibrarySidecar {
        if let cached = cache[bookId] { return cached }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            let fresh = IdeaLibrarySidecar(bookId: bookId)
            cache[bookId] = fresh
            // Do NOT persist a brand-new empty sidecar (= match
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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