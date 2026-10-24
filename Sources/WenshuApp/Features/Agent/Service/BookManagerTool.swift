// 
// … (= 50 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation
import WenshuAgent
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "bookmanagertool")

// MARK: - BookDescriptor
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / state).
struct BookDescriptor: Sendable, Codable, Equatable, Identifiable {
    /// Stable identifier (= used by the actor for create / rename /
    /// delete lookups; never re-used even across shelves).
    let id: UUID

    // / User-visible title. Whitespace-trimmed at construction time
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / actor's create / rename methods.
    let title: String

    /// Author name (= user-set; defaults to library owner = empty
    /// string for now). Mirrors Book.author.
    let author: String

    /// Owning bookshelf id.
    let shelfId: UUID

    // / Optional 1-2 sentence summary. Optional (= the LLM may
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / alias for the same field).
    let description: String

    /// Creation timestamp (= `Date.now` at create time).
    let createdAt: Date

    /// Last edit timestamp (= set on create + updated on rename).
    let lastEditedAt: Date

    init(
        id: UUID,
        title: String,
        author: String,
        shelfId: UUID,
        description: String,
        createdAt: Date,
        lastEditedAt: Date
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.shelfId = shelfId
        self.description = description
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
    }
}

// MARK: - BookManagerAction
// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / the JSON input envelope (= e.g. `"action": "create"`).
enum BookManagerAction: String, Sendable, Codable, CaseIterable, Equatable {
    /// Create a new book under a shelf.
    case create
    /// Rename an existing book.
    case rename
    /// Delete a book (= moves to trash; not physical delete).
    case delete
    /// List all books (= filterable by shelfId).
    case list
    /// Get book details.
    case show
}

// MARK: - Actor errors
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / a LocalizedError per case).
enum BookManagerError: Error, LocalizedError, Sendable, Equatable {
    /// Title was empty / whitespace-only after trimming.
    case emptyTitle
    /// The shelfId was not present in BookStore.shelves (= the LLM
    /// passed an unknown or deleted shelfId).
    case shelfNotFound(shelfId: UUID)
    /// The bookId was not present in BookStore.books (=
    /// the LLM passed an unknown or deleted bookId).
    case bookNotFound(bookId: UUID)
    // / The JSON input envelope was malformed (= missing required
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / verbatim to the LLM for self-correction.
    case invalidInput(reason: String)
    /// Underlying BookStore threw (= surfaced verbatim).
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "BookManager: title was empty or whitespace-only."
        case .shelfNotFound(let id):
            return "BookManager: shelf \(id.uuidString) not found."
        case .bookNotFound(let id):
            return "BookManager: book \(id.uuidString) not found."
        case .invalidInput(let reason):
            return "BookManager: invalid input — \(reason)."
        case .underlying(let msg):
            return "BookManager: underlying error — \(msg)."
        }
    }
}

// MARK: - Actor
// … (= 27 rationale lines collapsed; = A112 docblock collapse per §1.8)
// /     `.bookNotFound`.
actor BookManager {

    private let bookStore: BookStore

    // / Internal init (= matches `ForeshadowingTracker.init` /
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / type itself is internal so the init cannot be public).
    init(bookStore: BookStore) {
        self.bookStore = bookStore
    }

    // MARK: - CRUD
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   - Returns the descriptor (= freshly created).
    func createBook(
        title: String,
        shelfId: UUID,
        description: String = ""
    ) async throws -> BookDescriptor {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw BookManagerError.emptyTitle
        }
        let shelves = await MainActor.run { bookStore.shelves }
        guard shelves.contains(where: { $0.id == shelfId }) else {
            throw BookManagerError.shelfNotFound(shelfId: shelfId)
        }
        let now = Date()
        let book = Book(
            title: trimmedTitle,
            shelfId: shelfId,
            idea: description.isEmpty ? nil : description,
            createdAt: now,
            updatedAt: now
        )
        do {
            try await MainActor.run { try bookStore.sidebarSaveBook(book) }
        } catch {
            throw BookManagerError.underlying(String(describing: error))
        }
        return BookDescriptor(
            id: book.id,
            title: book.title,
            author: book.author,
            shelfId: book.shelfId,
            description: description,
            createdAt: book.createdAt,
            lastEditedAt: book.updatedAt
        )
    }

    // / Rename an existing book.
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     BookDescriptor.lastEditedAt reflects this).
    func renameBook(id: UUID, newTitle: String) async throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookManagerError.emptyTitle
        }
        let books = await MainActor.run { bookStore.books }
        guard let idx = books.firstIndex(where: { $0.id == id }) else {
            throw BookManagerError.bookNotFound(bookId: id)
        }
        var book = books[idx]
        book.title = trimmed
        book.updatedAt = Date()
        do {
            try await MainActor.run { try bookStore.sidebarSaveBook(book) }
        } catch {
            throw BookManagerError.underlying(String(describing: error))
        }
    }

    // / Delete a book (= moves to trash; not physical delete).
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     BookStore.books).
    func deleteBook(id: UUID) async throws {
        let books = await MainActor.run { bookStore.books }
        guard books.contains(where: { $0.id == id }) else {
            throw BookManagerError.bookNotFound(bookId: id)
        }
        do {
            try await MainActor.run { try bookStore.sidebarDeleteBook(id: id) }
        } catch {
            throw BookManagerError.underlying(String(describing: error))
        }
    }

    // MARK: - Queries
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `BookStore.sidebarLoadAllBooks`).
    func listBooks(shelfId: UUID? = nil) async throws -> [BookDescriptor] {
        let books = await MainActor.run { bookStore.books }
        let filtered = books.filter { book in
            shelfId.map { $0 == book.shelfId } ?? true
        }
        let sorted = filtered.sorted { $0.createdAt < $1.createdAt }
        return sorted.map { book in
            BookDescriptor(
                id: book.id,
                title: book.title,
                author: book.author,
                shelfId: book.shelfId,
                description: book.idea ?? "",
                createdAt: book.createdAt,
                lastEditedAt: book.updatedAt
            )
        }
    }

    // / Get book details by id. Returns `nil` (= NOT throws) when
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / row" idiom).
    func showBook(id: UUID) async throws -> BookDescriptor? {
        guard let book = await MainActor.run(body: { bookStore.books.first(where: { $0.id == id }) }) else {
            return nil
        }
        return BookDescriptor(
            id: book.id,
            title: book.title,
            author: book.author,
            shelfId: book.shelfId,
            description: book.idea ?? "",
            createdAt: book.createdAt,
            lastEditedAt: book.updatedAt
        )
    }

    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)
    // … (= 19 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   }
    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookManagerError.invalidInput(
                    reason: "input must be a JSON object"
                )
            }
            envelope = parsed
        } catch let error as BookManagerError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookManagerError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }
        let actionRaw = envelope["action"] as? String
        guard let actionRaw, let action = BookManagerAction(rawValue: actionRaw) else {
            return Self.encodeFailure(
                action: nil,
                error: BookManagerError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / rename / delete / list / show)"
                )
            )
        }
        do {
            switch action {
            case .create:
                let title = envelope["title"] as? String ?? ""
                guard let shelfId = Self.parseUUID(envelope["shelfId"]) else {
                    throw BookManagerError.invalidInput(
                        reason: "create requires 'shelfId' (UUID string)"
                    )
                }
                let description = envelope["description"] as? String ?? ""
                let book = try await createBook(
                    title: title,
                    shelfId: shelfId,
                    description: description
                )
                return Self.encodeSuccess(action: action, book: book)
            case .rename:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookManagerError.invalidInput(
                        reason: "rename requires 'id' (UUID string)"
                    )
                }
                // Accept either `title` or `newTitle` for ergonomics.
                let newTitle = (envelope["newTitle"] as? String)
                    ?? (envelope["title"] as? String)
                    ?? ""
                try await renameBook(id: id, newTitle: newTitle)
                return Self.encodeSuccess(action: action)
            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookManagerError.invalidInput(
                        reason: "delete requires 'id' (UUID string)"
                    )
                }
                try await deleteBook(id: id)
                return Self.encodeSuccess(action: action)
            case .list:
                let shelfId = Self.parseUUID(envelope["shelfId"])
                let books = try await listBooks(shelfId: shelfId)
                return Self.encodeSuccessList(action: action, books: books)
            case .show:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookManagerError.invalidInput(
                        reason: "show requires 'id' (UUID string)"
                    )
                }
                guard let book = try await showBook(id: id) else {
                    throw BookManagerError.bookNotFound(bookId: id)
                }
                return Self.encodeSuccess(action: action, book: book)
            }
        } catch let error as BookManagerError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookManagerError.underlying(String(describing: error))
            )
        }
    }

    // MARK: - JSON helpers
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the UUID string.
    private static func parseUUID(_ any: Any?) -> UUID? {
        if let s = any as? String {
            return UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let dict = any as? [String: Any], let s = dict["value"] as? String {
            return UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func encodeSuccess(
        action: BookManagerAction,
        book: BookDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue
        ]
        if let book {
            payload["book"] = descriptorToJSON(book)
        }
        return Self.encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookManagerAction,
        books: [BookDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "books": books.map { descriptorToJSON($0) }
        ]
        return Self.encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookManagerAction?,
        error: BookManagerError
    ) -> String {
        var payload: [String: Any] = [
            "ok": false,
            "error": error.errorDescription ?? "unknown error"
        ]
        if let action {
            payload["action"] = action.rawValue
        }
        return Self.encodeJSON(payload)
    }

    private static func descriptorToJSON(_ descriptor: BookDescriptor) -> [String: Any] {
                var dict: [String: Any] = [
            "id": descriptor.id.uuidString,
            "title": descriptor.title,
            "author": descriptor.author,
            "shelfId": descriptor.shelfId.uuidString,
            "description": descriptor.description,
            "createdAt": descriptor.createdAt.formatted(.iso8601),
            "lastEditedAt": descriptor.lastEditedAt.formatted(.iso8601)
        ]
        // Expose "idea" as an alias for "description" so the LLM
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // back if it asked for it.
        dict["idea"] = descriptor.description
        return dict
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ),
              let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookManager: JSON encode failed\"}"
        }
        return s
    }
}

// MARK: - BookManagerTool (Tool-protocol adapter)
// … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / state through BookStore).
actor BookManagerTool: Tool {
    let name = "book_manager"
    let description = "Create / rename / delete / list / show books (= canonical wenshu-side library state)."

    // / Shared singleton for ToolRegistry bootstrap (= lazy-init
    // … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / static-let initializer is itself `@MainActor`.
    @MainActor static let shared: BookManagerTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-books-\(UUID().uuidString)", isDirectory: true)
        // surface createDirectory failures via wenshuLogger.info((= was silent `try?`).
        do {
            try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        } catch {
            wenshuLogger.info("[wenshu.BookManagerTool] failed to create tmp root \(tmpRoot.path): \("\(error)")")
        }
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        // P1-04 (audit 2026-09-24): BookStore is now @MainActor. The
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // explicitly, which is the desired fail-loud behavior).
        let bookStore = MainActor.assumeIsolated { BookStore(stores: stores) }
        MainActor.assumeIsolated {
            bookStore.shelves = (try? bookStore.sidebarLoadShelves()) ?? []
            bookStore.reloadAllBooks()
        }
        return BookManagerTool(manager: BookManager(bookStore: bookStore))
    }()

    private let manager: BookManager

    init(manager: BookManager) {
        self.manager = manager
    }

    func execute(input: String) async throws -> String {
        try await manager.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension BookManagerTool {
    // / Module-load registration with `ToolRegistry.shared` (= hermes
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `register(...)` call off the init thread.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_manager",
                toolset: "meta",
                schema: ToolRegistrySchema(
                    name: "book_manager",
                    description: "Create / rename / delete / list / show books in the user's wenshu library (= canonical wenshu-side library state through BookStore).",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The book operation to perform.",
                            enumValues: ["create", "rename", "delete", "list", "show"]
                        ),
                        "title": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Title for create / rename."
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Book identifier for rename / delete / show."
                        ),
                        "shelf_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning shelf id for create / list filter."
                        ),
                        "description": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional 1-2 sentence summary for create."
                        )
                    ],
                    required: []
                ),
                handler: LazyTool { await BookManagerTool.shared },
                description: "Create / rename / delete / list / show books (= canonical wenshu-side library state).",
                emoji: "📚"
            )
        }
    }()
}

// NOTE: Swift 6 forbids top-level expressions, so the static let
// … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
// automatically trigger the bootstrap.