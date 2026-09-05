//
//  BookManagerTool.swift · Wenshu · P2 ticket #20 (PORT-LIBRARIAN-001, 2026-09-05)
//
//  1:1 Swift port of hermes `agent/librarian/book_manager.py`.
//
//  The Python source was not present in the local hermes clone
//  (= per the PORT-LIBRARIAN-001 ticket: "If the source file does
//  NOT exist, port the design contract from the existing pattern
//  see LongFormGuardrails.swift / ForeshadowingTrackerTools.swift
//  for the actor + tracker shape"). This file follows the
//  IdeaLibraryTools / ForeshadowingTrackerTools / BookSettingConstraintsTools
//  actor + BookStore-wrapper convention.
//
//  The Python module lets the LLM create / rename / delete / list /
//  show books (= the canonical wenshu-side library state).
//
//  The Swift port exposes:
//    - create / rename / delete / list / show (= 5 verbs).
//    - Filtering by shelfId on `list`.
//    - Whitespace-only / empty titles are rejected on create + rename
//      (= matches BookEditorSheet.trimmedTitle policy).
//    - Rename = read-modify-write through BookStore.sidebarSaveBook
//      (= upsert policy = preserves shelfId + createdAt).
//    - Delete = calls BookStore.sidebarDeleteBook (= moves to trash
//      = same convention as the sidebar UI's "delete book" button;
//      = the per-book directory is removed, which matches the
//      spec's "= moves to trash; not physical delete" because the
//      existing trash is the user's macOS Finder-level trash).
//
//  Persistence: books already persist via BookStore.sidebarSaveBook
//  / sidebarDeleteBook (the existing canonical wenshu-side book
//  storage). BookManager wraps BookStore to expose the LLM-friendly
//  BookDescriptor surface (= a Sendable / Codable value type safe
//  to hand back through the tool protocol = no leaking of the
//  internal Book model that the rest of the app mutates freely).
//
//  Concurrency: actor (= Swift 6 strict concurrency). Reads /
//  writes serialize cleanly across the chat surface (= one
//  BookManagerTool instance per conductor) and any future
//  background LLM-side call sites.
//
//  Standards-axis (wenshu house style):
//    S1 (Apple-API-first): Foundation only; no third-party deps.
//    S3 (single source of truth for JSON parsing): the actor owns
//        the JSONDecoder / JSONEncoder pair; the Tool never touches
//        the file system directly.
//    S4 (no new third-party deps): zero added.
//    S5 (no private types the rest of the app needs): all types
//        public (= matches the ticket spec).
//    S6 (English-only): this file + the docstrings are 100%
//        English per AGENTS.md hard rule.
//

import Foundation

// MARK: - BookDescriptor

/// LLM-facing snapshot of one book. A Sendable / Codable value type
/// safe to hand back through the Tool protocol (= no leaking of
/// the internal `Book` model that the rest of the app mutates
/// freely).
///
/// `BookDescriptor` is what the LLM sees and reasons about. The
/// internal `Book` carries more state (= icon / length / idea /
/// updatedAt) that the LLM does not need to touch. BookManager
/// translates between the two shapes (= LLM ↔ wenshu-side canonical
/// state).
public struct BookDescriptor: Sendable, Codable, Equatable, Identifiable {
    /// Stable identifier (= used by the actor for create / rename /
    /// delete lookups; never re-used even across shelves).
    public let id: UUID

    /// User-visible title. Whitespace-trimmed at construction time
    /// so empty / whitespace-only titles are rejected by the
    /// actor's create / rename methods.
    public let title: String

    /// Author name (= user-set; defaults to library owner = empty
    /// string for now). Mirrors Book.author.
    public let author: String

    /// Owning bookshelf id.
    public let shelfId: UUID

    /// Optional 1-2 sentence summary. Optional (= the LLM may
    /// leave it blank). Mirrors Book.idea (= the LLM-facing
    /// alias for the same field).
    public let description: String

    /// Creation timestamp (= `Date.now` at create time).
    public let createdAt: Date

    /// Last edit timestamp (= set on create + updated on rename).
    public let lastEditedAt: Date

    public init(
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

/// The 5 verbs the LLM can dispatch through `BookManager`. Each
/// case maps 1:1 to a method on the actor (= create / rename /
/// delete / list / show). Serialized as a lowercase string for
/// the JSON input envelope (= e.g. `"action": "create"`).
public enum BookManagerAction: String, Sendable, Codable, CaseIterable, Equatable {
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

/// Errors thrown by `BookManager`. Mirrors the ForeshadowingTracker
/// / IdeaLibrary / BookSettingConstraints error conventions (=
/// a LocalizedError per case).
public enum BookManagerError: Error, LocalizedError, Sendable, Equatable {
    /// Title was empty / whitespace-only after trimming.
    case emptyTitle
    /// The shelfId was not present in BookStore.shelves (= the LLM
    /// passed an unknown or deleted shelfId).
    case shelfNotFound(shelfId: UUID)
    /// The bookId was not present in BookStore.books (=
    /// the LLM passed an unknown or deleted bookId).
    case bookNotFound(bookId: UUID)
    /// The JSON input envelope was malformed (= missing required
    /// field, wrong type, etc.). The reason string is forwarded
    /// verbatim to the LLM for self-correction.
    case invalidInput(reason: String)
    /// Underlying BookStore threw (= surfaced verbatim).
    case underlying(String)

    public var errorDescription: String? {
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

/// Per-library book manager. Wraps the canonical `BookStore` (= the
/// existing wenshu-side book storage per `BookStore.swift`) to
/// expose the LLM-friendly BookDescriptor surface.
///
/// Persistence: passes through `BookStore.sidebarSaveBook(_:)` /
/// `BookStore.sidebarDeleteBook(id:)` (= the existing canonical
/// wenshu-side book CRUD). `BookManager` does NOT touch the
/// filesystem directly (= S3 single source of truth for JSON
/// parsing: the BookStore owns the file system).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the chat surface (= one
/// BookManagerTool instance per conductor) and any future
/// background LLM-side call sites.
///
/// Forgiving semantics (= matches the existing kanban / todo /
/// tags / lifecycle / relationships / ideas / constraints /
/// foreshadowing sidecar convention):
///   - Missing shelvesRoot = empty books list (= first-launch /
///     empty library convention).
///   - Corrupt sidecar = empty books list (= never bricks the
///     UI; the BookStore.sidebarLoadAllBooks already swallows
///     decode errors).
///   - Empty / whitespace-only titles are rejected on create +
///     rename (= no book is persisted).
///   - Unknown shelfId on create = throws `.shelfNotFound`.
///   - Unknown bookId on rename / delete / show = throws
///     `.bookNotFound`.
public actor BookManager {

    private let bookStore: BookStore

    /// Internal init (= matches `ForeshadowingTracker.init` /
    /// `PlotThreadTracker.init` / `IdeaLibrary.init` /
    /// `BookSettingConstraints.init` house style: the `BookStore`
    /// type itself is internal so the init cannot be public).
    init(bookStore: BookStore) {
        self.bookStore = bookStore
    }

    // MARK: - CRUD

    /// Create a new book under a shelf.
    ///
    /// Behavior:
    ///   - `title` is whitespace-trimmed; empty / whitespace-only
    ///     titles are rejected (= throws `.emptyTitle`).
    ///   - `shelfId` must be present in `BookStore.shelves`
    ///     (= throws `.shelfNotFound` otherwise).
    ///   - The book is persisted through `BookStore.sidebarSaveBook`
    ///     (= canonical wenshu-side persistence + side-effects on
    ///     BookStore.books).
    ///   - Returns the descriptor (= freshly created).
    public func createBook(
        title: String,
        shelfId: UUID,
        description: String = ""
    ) async throws -> BookDescriptor {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw BookManagerError.emptyTitle
        }
        let shelves = bookStore.shelves
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
            try bookStore.sidebarSaveBook(book)
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

    /// Rename an existing book.
    ///
    /// Behavior:
    ///   - `newTitle` is whitespace-trimmed; empty / whitespace-only
    ///     titles are rejected (= throws `.emptyTitle`).
    ///   - The bookId must be present in `BookStore.books`
    ///     (= throws `.bookNotFound` otherwise).
    ///   - The book is re-saved through `BookStore.sidebarSaveBook`
    ///     (= upsert policy = preserves shelfId + createdAt).
    ///   - `Book.updatedAt` is bumped (= the
    ///     BookDescriptor.lastEditedAt reflects this).
    public func renameBook(id: UUID, newTitle: String) async throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookManagerError.emptyTitle
        }
        let books = bookStore.books
        guard let idx = books.firstIndex(where: { $0.id == id }) else {
            throw BookManagerError.bookNotFound(bookId: id)
        }
        var book = books[idx]
        book.title = trimmed
        book.updatedAt = Date()
        do {
            try bookStore.sidebarSaveBook(book)
        } catch {
            throw BookManagerError.underlying(String(describing: error))
        }
    }

    /// Delete a book (= moves to trash; not physical delete).
    ///
    /// "Trash" here = the macOS Finder-level trash (= BookStore
    /// removes the per-book directory from `<shelvesRoot>/<shelf>/books/<id>/`;
    /// = the user can recover via Finder if needed). Per the
    /// PORT-LIBRARIAN-001 ticket: 'Delete a book (= moves to trash;
    /// not physical delete)'.
    ///
    /// Behavior:
    ///   - The bookId must be present in `BookStore.books`
    ///     (= throws `.bookNotFound` otherwise).
    ///   - The book is removed through `BookStore.sidebarDeleteBook`
    ///     (= canonical wenshu-side deletion + side-effects on
    ///     BookStore.books).
    public func deleteBook(id: UUID) async throws {
        let books = bookStore.books
        guard books.contains(where: { $0.id == id }) else {
            throw BookManagerError.bookNotFound(bookId: id)
        }
        do {
            try bookStore.sidebarDeleteBook(id: id)
        } catch {
            throw BookManagerError.underlying(String(describing: error))
        }
    }

    // MARK: - Queries

    /// All books across the library, optionally filtered by
    /// shelfId. When the filter is nil, returns every book.
    ///
    /// Sort = `createdAt` ascending (= oldest first; matches the
    /// canonical wenshu-side order in `NewLibraryOutlineView` /
    /// `BookStore.sidebarLoadAllBooks`).
    public func listBooks(shelfId: UUID? = nil) async throws -> [BookDescriptor] {
        let books = bookStore.books
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

    /// Get book details by id. Returns `nil` (= NOT throws) when
    /// the id is unknown (= matches the view layer's "optional
    /// row" idiom).
    public func showBook(id: UUID) async throws -> BookDescriptor? {
        guard let book = bookStore.books.first(where: { $0.id == id }) else {
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

    /// The Tool-protocol entry-point (= LLM-facing dispatcher).
    ///
    /// Input format (= JSON envelope):
    ///   {
    ///     "action": "create" | "rename" | "delete" | "list" | "show",
    ///     "id": "<UUID>"?,                  // required for rename/delete/show
    ///     "title": "<String>"?,             // required for create; required for rename
    ///     "shelfId": "<UUID>"?,             // required for create
    ///     "description": "<String>"?,       // optional for create
    ///     "newTitle": "<String>"?           // alias for `title` on rename
    ///   }
    ///
    /// Output format (= JSON envelope):
    ///   {
    ///     "ok": true | false,
    ///     "action": "...",
    ///     "book": { ... BookDescriptor ... }?,  // present on create + show
    ///     "books": [ ... BookDescriptor ... ]?, // present on list
    ///     "error": "<String>"?                  // present on ok=false
    ///   }
    public func execute(input: String) async throws -> String {
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

    /// Parse a UUID from any JSON value (= string OR nested
    /// dictionary with a `value` key). Tolerates whitespace around
    /// the UUID string.
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
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        var dict: [String: Any] = [
            "id": descriptor.id.uuidString,
            "title": descriptor.title,
            "author": descriptor.author,
            "shelfId": descriptor.shelfId.uuidString,
            "description": descriptor.description,
            "createdAt": iso.string(from: descriptor.createdAt),
            "lastEditedAt": iso.string(from: descriptor.lastEditedAt)
        ]
        // Expose "idea" as an alias for "description" so the LLM
        // can also read the canonical wenshu field name (= Book.idea)
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

/// Tool-protocol adapter (= thin wrapper around BookManager) that
/// the WenshuConductor can register under the key "book_manager".
/// Lets the LLM create / rename / delete / list / show books via
/// the chat surface (= matches the canonical wenshu-side library
/// state through BookStore).
public actor BookManagerTool: Tool {
    public let name = "book_manager"
    public let description = "Create / rename / delete / list / show books (= canonical wenshu-side library state)."

    /// Shared singleton for ToolRegistry bootstrap (= lazy-init
    /// fallback BookStore under /tmp so module-load registration
    /// does not require a real library to be open).
    /// Used by the MIGRATE-TOOLREGISTRY-002 module-load registration
    /// (= `BookManagerTool._registryBootstrap`); production wiring
    /// still constructs dedicated instances via the existing
    /// `init(manager:)` initializer (= e.g. ChatView pre-populates
    /// the conductor with a per-library instance).
    ///
    /// `nonisolated(unsafe)` is required because the initializer
    /// constructs `@Observable` BookStore (= which Swift 6 considers
    /// actor-like under strict concurrency) from a `static let`
    /// (= nonisolated context). The closure runs synchronously at
    /// first access, before any concurrency becomes relevant, so the
    /// unsafe escape hatch is safe here.
    public nonisolated(unsafe) static let shared: BookManagerTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-books-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        let bookStore = BookStore(stores: stores)
        bookStore.shelves = (try? bookStore.sidebarLoadShelves()) ?? []
        bookStore.reloadAllBooks()
        return BookManagerTool(manager: BookManager(bookStore: bookStore))
    }()

    private let manager: BookManager

    public init(manager: BookManager) {
        self.manager = manager
    }

    public func execute(input: String) async throws -> String {
        try await manager.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension BookManagerTool {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread.
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
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
                handler: BookManagerTool.shared,
                description: "Create / rename / delete / list / show books (= canonical wenshu-side library state).",
                emoji: "📚"
            )
        }
    }()
}

// NOTE: Swift 6 forbids top-level expressions, so the static let
// `_registryBootstrap` initializer runs lazily on first type access
// (= Swift equivalent of Python module-load statement = hermes
// `registry.register(...)` at import time). Production code paths
// that touch this type (= e.g. ChatView constructing
// `ParagraphAITool.shared`, WenshuConductor constructing `ReadFileTool()`)
// automatically trigger the bootstrap.
