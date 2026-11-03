// BookOutlineTool.swift Per-book outline CRUD tool (= wraps FileSystemOutlineStore).
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// string) for hierarchy; `order` for sort.
import Foundation
import WenshuAgent

// MARK: - OutlineEntryDescriptor

struct OutlineEntryDescriptor: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let bookId: UUID
    let title: String
    let summary: String
    let parent: UUID?
    let order: Int
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        bookId: UUID,
        title: String,
        summary: String,
        parent: UUID?,
        order: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.summary = summary
        self.parent = parent
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(_ entry: OutlineEntry) {
        self.id = entry.id
        self.bookId = entry.bookId
        self.title = entry.title
        self.summary = entry.summary
        self.parent = entry.parent
        self.order = entry.order
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
    }
}

// MARK: - Action enum

enum BookOutlineAction: String, Sendable, Codable, CaseIterable, Equatable {
    case create
    case read
    case update
    case delete
    case list
    case find
}

// MARK: - Errors

enum BookOutlineError: Error, LocalizedError, Sendable, Equatable {
    case emptyTitle
    case entryNotFound(id: UUID)
    case invalidInput(reason: String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "BookOutlineTool: outline title was empty or whitespace-only."
        case .entryNotFound(let id):
            return "BookOutlineTool: outline entry \(id.uuidString) not found."
        case .invalidInput(let reason):
            return "BookOutlineTool: invalid input — \(reason)."
        case .underlying(let msg):
            return "BookOutlineTool: underlying error — \(msg)."
        }
    }
}

// MARK: - Actor

actor BookOutlineActor {
    // / Closure returning the book directory for the current chat
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / mid-conversation without the actor holding a stale root.
    private let bookDirectoryProvider: @Sendable () -> URL?

    /// Closure returning the chat session's currently-bound book.
    /// See BookWorldActor's matching field for the contract.
    let currentChatBookIDProvider: @Sendable () -> UUID?

    init(
        bookDirectoryProvider: @escaping @Sendable () -> URL?,
        currentChatBookIDProvider: @escaping @Sendable () -> UUID? = { nil }
    ) {
        self.bookDirectoryProvider = bookDirectoryProvider
        self.currentChatBookIDProvider = currentChatBookIDProvider
    }

    func readBodyForTest(id: UUID) async -> String? {
        guard let dir = bookDirectoryProvider() else { return nil }
        return FileSystemOutlineStore.loadOutlineBodyFromFileSystem(
            id: id,
            bookDirectory: dir
        )
    }

    // / Resolve the current book directory (= raises `invalidInput`
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / fallback helpers (= actor-safe).
    private func resolveBookDirectory() throws -> URL {
        guard let dir = bookDirectoryProvider() else {
            throw BookOutlineError.invalidInput(
                reason: "no chat session book bound (= scope guard should have caught this earlier)"
            )
        }
        // wt/path-guard-v2-2026-09-25: PathGuard second-line defense (= see
        // BookChapterActor.resolveStore for the rationale).
        try PathGuard.assertInsideLibrary(path: LibraryPath(rawValue: dir.path))
        return dir
    }

    // MARK: - CRUD

    func createOutline(
        bookId: UUID,
        title: String,
        bodyMarkdown: String,
        summary: String = "",
        parent: UUID? = nil,
        order: Int = 0
    ) async throws -> OutlineEntryDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookOutlineError.emptyTitle
        }

        // Silent dedup (see OOB.md #2026-09-25): if an outline with the same title
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // preserves id / createdAt / parent / order). LLM never sees an error.
        if let existing = try await findOutline(bookId: bookId, title: trimmed) {
            return try await updateOutline(
                id: existing.id,
                title: trimmed,
                bodyMarkdown: bodyMarkdown,
                summary: summary.isEmpty ? nil : summary,
                parent: parent,
                order: order == 0 ? nil : order
            )
        }

        let entry = OutlineEntry(
            bookId: bookId,
            title: trimmed,
            summary: summary,
            parent: parent,
            order: order
        )
        do {
            let dir = try resolveBookDirectory()
            try FileSystemOutlineStore.saveOutlineToFileSystem(
                entry: entry,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: dir
            )
        } catch let err as BookOutlineError {
            throw err
        } catch {
            throw BookOutlineError.underlying(String(describing: error))
        }
        return OutlineEntryDescriptor(entry)
    }

    func readOutline(id: UUID) async throws -> (OutlineEntryDescriptor, String?) {
        do {
            let dir = try resolveBookDirectory()
            let entries = try FileSystemOutlineStore.loadOutlinesFromFileSystem(bookDirectory: dir)
            guard let entry = entries.first(where: { $0.id == id }) else {
                throw BookOutlineError.entryNotFound(id: id)
            }
            let body = FileSystemOutlineStore.loadOutlineBodyFromFileSystem(
                id: id,
                bookDirectory: dir
            )
            return (OutlineEntryDescriptor(entry), body)
        } catch let err as BookOutlineError {
            throw err
        } catch {
            throw BookOutlineError.underlying(String(describing: error))
        }
    }

    func updateOutline(
        id: UUID,
        title: String,
        bodyMarkdown: String,
        summary: String? = nil,
        parent: UUID? = nil,
        order: Int? = nil
    ) async throws -> OutlineEntryDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookOutlineError.emptyTitle
        }
        let dir = try resolveBookDirectory()
        let entries: [OutlineEntry]
        do {
            entries = try FileSystemOutlineStore.loadOutlinesFromFileSystem(bookDirectory: dir)
        } catch {
            throw BookOutlineError.underlying(String(describing: error))
        }
        guard let existing = entries.first(where: { $0.id == id }) else {
            throw BookOutlineError.entryNotFound(id: id)
        }
        var updated = existing
        updated.title = trimmed
        if let summary { updated.summary = summary }
        // parent = nil means "don't change"; = to clear parent, send an empty string in
        // the JSON envelope (= parsed below).
        updated.parent = parent ?? existing.parent
        if let order { updated.order = order }
        updated.updatedAt = Date()
        do {
            try FileSystemOutlineStore.replaceOutlineToFileSystem(
                entry: updated,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: dir
            )
        } catch {
            throw BookOutlineError.underlying(String(describing: error))
        }
        return OutlineEntryDescriptor(updated)
    }

    func deleteOutline(id: UUID) async throws {
        do {
            let dir = try resolveBookDirectory()
            try FileSystemOutlineStore.deleteOutlineFromFileSystem(
                id: id,
                bookDirectory: dir
            )
            // A cover is a CHILD of its document: the .md file is
            // gone, so the cover that depicted it goes with it.
            //
            // The removal is TOLERANT: the document delete is the
            // important operation, and a cover that cannot be
            // removed must not stop it.
            await CoverCascade.live().removeCoverTolerantly(
                forBookDocFileAt: dir
                    .appendingPathComponent("outlines", isDirectory: true)
                    .appendingPathComponent("\(id.uuidString).md")
            )
        } catch let err as BookOutlineError {
            throw err
        } catch {
            throw BookOutlineError.underlying(String(describing: error))
        }
    }

    func listOutlines(bookId: UUID) async throws -> [OutlineEntryDescriptor] {
        let dir = try resolveBookDirectory()
        let entries: [OutlineEntry]
        do {
            entries = try FileSystemOutlineStore.loadOutlinesFromFileSystem(bookDirectory: dir)
        } catch {
            throw BookOutlineError.underlying(String(describing: error))
        }
        let filtered = entries.filter { $0.bookId == bookId }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.createdAt < rhs.createdAt
        }
        return sorted.map { OutlineEntryDescriptor($0) }
    }

    func findOutline(bookId: UUID, title: String) async throws -> OutlineEntryDescriptor? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dir = try resolveBookDirectory()
        let entries: [OutlineEntry]
        do {
            entries = try FileSystemOutlineStore.loadOutlinesFromFileSystem(bookDirectory: dir)
        } catch {
            throw BookOutlineError.underlying(String(describing: error))
        }
        let match = entries.first { entry in
            entry.bookId == bookId &&
            entry.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed
        }
        return match.map { OutlineEntryDescriptor($0) }
    }

}

// MARK: - Tool-protocol adapter

actor BookOutlineTool: Tool {
    let name = "book_outline"
    let description = "Create / read / update / delete / list / find outline entries under a book."

    private let actor: BookOutlineActor

    init(actor: BookOutlineActor) {
        self.actor = actor
    }

    func execute(input: String) async throws -> String {
        try await actor.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap

extension BookOutlineTool {
    /// Module-load registration with `ToolRegistry.shared`.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_outline",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "book_outline",
                    description: "Per-book outline CRUD (= wraps FileSystemOutlineStore). LLM-friendly verbs: create / read / update / delete / list / find.",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The outline operation to perform.",
                            enumValues: ["create", "read", "update", "delete", "list", "find"]
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning book id (UUID). Required for create / list / find."
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Outline entry id (UUID). Required for read / update / delete."
                        ),
                        "title": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Outline entry title. Required for create / find."
                        ),
                        "parent": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional parent outline entry id (UUID) for hierarchy. Use 'null' to clear."
                        ),
                        "order": ToolRegistrySchemaProperty(
                            type: "integer",
                            description: "Optional sort order (integer)."
                        ),
                        "summary": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional 1-line summary."
                        ),
                        "markdown": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Full .md body. Alias: 'body'."
                        )
                    ],
                    required: ["action"]
            ),
            handler: LazyTool { BookOutlineTool.shared },
            description: "Per-book outline CRUD.",
            emoji: "🗂"
        )
        }
    }()

    nonisolated static let shared: BookOutlineTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-outline-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return BookOutlineTool(
            actor: BookOutlineActor(
                bookDirectoryProvider: { tmpRoot },
                currentChatBookIDProvider: { nil }
            )
        )
    }()
}
