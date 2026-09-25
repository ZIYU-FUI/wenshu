//
//  BookWorldTool.swift · Wenshu · v2.0 (2026-09-25)
//
//  Per-book world-building CRUD tool (= wraps FileSystemWorldStore).
//  Mirrors BookManagerTool pattern (= Actor + Tool-protocol adapter +
//  ToolRegistry module-load bootstrap).
//
//  LLM-friendly verbs: create / read / update / delete / list / find
//  (= find resolves a name to an id within a book, since LLM tends to
//  reference world entries by name rather than UUID).
//
//  Standard-axis S3: the actor owns JSON parsing (single source of
//  truth); the Tool struct is a thin adapter (= execute forwards to
//  the actor).
//
//  Per-book scope: every verb requires a `book_id` (= UUID string)
//  matching the book whose `world/` directory is the target.
//

import Foundation

// MARK: - WorldEntryDescriptor

/// LLM-facing snapshot of one world entry. Sendable + Codable value
/// type safe to hand back through the Tool protocol (= no leaking of
/// the internal `WorldEntry` model that the rest of the app mutates
/// freely).
///
/// `WorldEntryDescriptor` is what the LLM sees and reasons about.
/// `BookWorldActor` translates between the two shapes (= LLM-friendly
/// surface ↔ wenshu-side canonical state).
struct WorldEntryDescriptor: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let bookId: UUID
    let type: String
    let name: String
    let summary: String
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        bookId: UUID,
        type: String,
        name: String,
        summary: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.bookId = bookId
        self.type = type
        self.name = name
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convenience init from canonical WorldEntry (domain layer).
    init(_ entry: WorldEntry) {
        self.id = entry.id
        self.bookId = entry.bookId
        self.type = entry.type.rawValue
        self.name = entry.name
        self.summary = entry.summary
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
    }
}

// MARK: - Action enum

/// The 6 verbs the LLM can dispatch through `BookWorldTool`.
enum BookWorldAction: String, Sendable, Codable, CaseIterable, Equatable {
    /// Create a new world entry under a book.
    case create
    /// Read a single entry by id (returns the .md body too).
    case read
    /// Update an existing entry in place (= .md body + index row).
    case update
    /// Remove an entry's .md file + index row.
    case delete
    /// List all entries under a book.
    case list
    /// Find an entry by name (case-insensitive trim). Returns id
    /// when found; the LLM then chains to read/update/delete by id.
    case find
}

// MARK: - Errors

enum BookWorldError: Error, LocalizedError, Sendable, Equatable {
    case emptyName
    case bookNotFound(bookId: UUID)
    case entryNotFound(id: UUID)
    case invalidInput(reason: String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "BookWorldTool: entry name was empty or whitespace-only."
        case .bookNotFound(let id):
            return "BookWorldTool: book \(id.uuidString) not found."
        case .entryNotFound(let id):
            return "BookWorldTool: world entry \(id.uuidString) not found."
        case .invalidInput(let reason):
            return "BookWorldTool: invalid input — \(reason)."
        case .underlying(let msg):
            return "BookWorldTool: underlying error — \(msg)."
        }
    }
}

// MARK: - Actor

/// Per-book world entry manager. Wraps FileSystemWorldStore (=
/// canonical wenshu-side world storage) to expose the LLM-friendly
/// WorldEntryDescriptor surface.
///
/// Persistence: passes through `FileSystemWorldStore` (= S3 single
/// source of truth: the store owns the file system; the actor owns
/// JSON parsing). Per book-private scope.
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads / writes
/// serialize cleanly across the chat surface (= one BookWorldActor
/// instance per conductor) and any future background LLM-side call
/// sites.
///
/// Forgiving semantics (= matches the FileSystemWorldStore contract):
///   - Missing books directory = empty entries list.
///   - Empty / whitespace-only names rejected on create + update.
///   - Unknown book_id = throws `.bookNotFound`.
///   - Unknown id on read / update / delete / find = throws
///     `.entryNotFound` / returns nil for find.
actor BookWorldActor {
    /// Closure returning the book directory for the current chat
    /// session's bound book (= nil when no chat book is bound).
    /// Resolved on every CRUD call so the user can switch books
    /// mid-conversation without the actor holding a stale root.
    ///
    /// `nil` from the provider means the chat session has no bound
    /// book (= onboarding or a chat predating v1.79). The actor
    /// surfaces this as an `invalidInput` (= the scope guard
    /// catches the cross-book case earlier).
    private let bookDirectoryProvider: @Sendable () -> URL?

    /// Closure returning the chat session's currently-bound book
    /// (= nil when the chat session has no bound book). The actor
    /// reads this on every execute(input:) call so the latest
    /// sidebar selection is always honored.
    private let currentChatBookIDProvider: @Sendable () -> UUID?

    init(
        bookDirectoryProvider: @escaping @Sendable () -> URL?,
        currentChatBookIDProvider: @escaping @Sendable () -> UUID? = { nil }
    ) {
        self.bookDirectoryProvider = bookDirectoryProvider
        self.currentChatBookIDProvider = currentChatBookIDProvider
    }

    /// Test-only: re-construct a FileSystemWorldStore rooted at the
    /// current chat session's book directory (= the provider's
    /// current value) and read the .md body for an entry id.
    /// Lives on the actor (not a free function) so the test can call
    /// it without breaking actor isolation on the store.
    func readBodyForTest(id: UUID) async -> String? {
        guard let dir = bookDirectoryProvider() else { return nil }
        let store = FileSystemWorldStore(bookDirectory: dir)
        return store.loadEntryBody(id: id)
    }

    /// Resolve the current book directory (= raises `invalidInput`
    /// if the chat session has no bound book, which the scope guard
    /// should already have rejected). Then construct a fresh
    /// FileSystemWorldStore rooted at that directory.
    private func resolveStore() throws -> FileSystemWorldStore {
        guard let dir = bookDirectoryProvider() else {
            throw BookWorldError.invalidInput(
                reason: "no chat session book bound (= scope guard should have caught this earlier)"
            )
        }
        return FileSystemWorldStore(bookDirectory: dir)
    }

    // MARK: - CRUD

    func createEntry(
        bookId: UUID,
        name: String,
        bodyMarkdown: String,
        type: String = "other",
        summary: String = ""
    ) async throws -> WorldEntryDescriptor {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookWorldError.emptyName
        }
        let parsedType = WorldEntryType(rawValue: type) ?? .other
                let entry = WorldEntry(
                    bookId: bookId,
                    type: parsedType,
                    name: trimmed,
                    summary: summary
                )
                do {
                    let store = try resolveStore()
                    try store.saveEntry(entry, bodyMarkdown: bodyMarkdown)
                } catch let err as BookWorldError {
                    throw err
                } catch {
                    throw BookWorldError.underlying(String(describing: error))
                }
                return WorldEntryDescriptor(entry)
            }

            func readEntry(id: UUID) async throws -> (WorldEntryDescriptor, String?) {
                do {
                    let store = try resolveStore()
                    let entries = try store.loadWorld()
                    guard let entry = entries.first(where: { $0.id == id }) else {
                        throw BookWorldError.entryNotFound(id: id)
                    }
                    let body = store.loadEntryBody(id: id)
                    return (WorldEntryDescriptor(entry), body)
                } catch let err as BookWorldError {
                    throw err
                } catch {
                    throw BookWorldError.underlying(String(describing: error))
                }
            }

            func updateEntry(
                id: UUID,
                name: String,
                bodyMarkdown: String,
                type: String? = nil,
                summary: String? = nil
            ) async throws -> WorldEntryDescriptor {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw BookWorldError.emptyName
                }
                let store = try resolveStore()
                let entries: [WorldEntry]
                do {
                    entries = try store.loadWorld()
                } catch {
                    throw BookWorldError.underlying(String(describing: error))
                }
                guard let existing = entries.first(where: { $0.id == id }) else {
                    throw BookWorldError.entryNotFound(id: id)
                }
                let updatedType: WorldEntryType
                if let type, let parsed = WorldEntryType(rawValue: type) {
                    updatedType = parsed
                } else {
                    updatedType = existing.type
                }
                let updatedSummary = summary ?? existing.summary
                var updated = existing
                updated.name = trimmed
                updated.type = updatedType
                updated.summary = updatedSummary
                updated.updatedAt = Date()
                do {
                    try store.replaceEntry(updated, bodyMarkdown: bodyMarkdown)
                } catch {
                    throw BookWorldError.underlying(String(describing: error))
                }
                return WorldEntryDescriptor(updated)
            }

            func deleteEntry(id: UUID) async throws {
                do {
                    let store = try resolveStore()
                    try store.deleteEntry(id: id)
                } catch let err as BookWorldError {
                    throw err
                } catch {
                    throw BookWorldError.underlying(String(describing: error))
                }
            }

            func listEntries(bookId: UUID) async throws -> [WorldEntryDescriptor] {
                let store = try resolveStore()
                let entries: [WorldEntry]
                do {
                    entries = try store.loadWorld()
                } catch {
                    throw BookWorldError.underlying(String(describing: error))
                }
                let filtered = entries.filter { $0.bookId == bookId }
                let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
                return sorted.map { WorldEntryDescriptor($0) }
            }

            func findEntry(bookId: UUID, name: String) async throws -> WorldEntryDescriptor? {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let store = try resolveStore()
                let entries: [WorldEntry]
                do {
                    entries = try store.loadWorld()
                } catch {
                    throw BookWorldError.underlying(String(describing: error))
                }
                let match = entries.first { entry in
                    entry.bookId == bookId &&
                    entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed
                }
                return match.map { WorldEntryDescriptor($0) }
            }

    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    /// Input format (JSON envelope):
    /// ```
    /// {
    ///   "action": "create" | "read" | "update" | "delete" | "list" | "find",
    ///   "book_id": "<UUID>",
    ///   "id": "<UUID>"?,
    ///   "name": "<String>"?,
    ///   "type": "<String>"?,
    ///   "summary": "<String>"?,
    ///   "body": "<String>"?,
    ///   "markdown": "<String>"?
    /// }
    /// ```
    ///
    /// Output format (JSON envelope):
    /// ```
    /// {
    ///   "ok": true | false,
    ///   "action": "...",
    ///   "entry": { ... WorldEntryDescriptor ... }?,
    ///   "entries": [ ... WorldEntryDescriptor ... ]?,
    ///   "body": "<String>"?,
    ///   "error": "<String>"?
    /// }
    /// ```
    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookWorldError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookWorldError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookWorldError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookWorldAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookWorldError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find)"
                )
            )
        }

        // Scope guard: every action MUST carry a `book_id` that matches
        // the chat session's currently-bound book. Validated once here
        // (= before any disk write) so cross-book writes are blocked
        // before reaching the storage layer.
        do {
            try BookScopeGuard.validate(
                providedBookID: Self.parseUUID(envelope["book_id"]),
                currentChatBookIDProvider: currentChatBookIDProvider
            )
        } catch let violation as BookScopeViolation {
            return Self.encodeFailureScopeViolation(action: action, error: violation)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookWorldError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookWorldError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let name = envelope["name"] as? String ?? ""
                let type = envelope["type"] as? String ?? "other"
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let entry = try await createEntry(
                    bookId: bookId,
                    name: name,
                    bodyMarkdown: body,
                    type: type,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, entry: entry)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookWorldError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (entry, body) = try await readEntry(id: id)
                return Self.encodeSuccessRead(action: action, entry: entry, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookWorldError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let name = envelope["name"] as? String ?? ""
                let type = envelope["type"] as? String
                let summary = envelope["summary"] as? String
                let body = Self.extractMarkdown(envelope)
                let entry = try await updateEntry(
                    id: id,
                    name: name,
                    bodyMarkdown: body,
                    type: type,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, entry: entry)

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookWorldError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteEntry(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookWorldError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let entries = try await listEntries(bookId: bookId)
                return Self.encodeSuccessList(action: action, entries: entries)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookWorldError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let name = envelope["name"] as? String ?? ""
                let entry = try await findEntry(bookId: bookId, name: name)
                return Self.encodeSuccessFind(action: action, entry: entry)
            }
        } catch let error as BookWorldError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookWorldError.underlying(String(describing: error))
            )
        }
    }

    // MARK: - JSON helpers

    /// Accept either `body` or `markdown` key for the .md content.
    private static func extractMarkdown(_ envelope: [String: Any]) -> String {
        if let m = envelope["markdown"] as? String, !m.isEmpty { return m }
        if let b = envelope["body"] as? String { return b }
        return ""
    }

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
        action: BookWorldAction,
        entry: WorldEntryDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let entry {
            payload["entry"] = descriptorToJSON(entry)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookWorldAction,
        entry: WorldEntryDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "entry": descriptorToJSON(entry),
            "body": body ?? ""
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: BookWorldAction,
        entry: WorldEntryDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": entry != nil]
        if let entry {
            payload["entry"] = descriptorToJSON(entry)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookWorldAction,
        entries: [WorldEntryDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "entries": entries.map { descriptorToJSON($0) }
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookWorldAction?,
        error: BookWorldError
    ) -> String {
        var payload: [String: Any] = [
            "ok": false,
            "error": error.errorDescription ?? "unknown error"
        ]
        if let action {
            payload["action"] = action.rawValue
        }
        return encodeJSON(payload)
    }

    /// Encode a BookScopeViolation into the standard failure envelope.
    /// Kept separate from encodeFailure(BookWorldError) so future
    /// maintenance can give scope violations distinct telemetry
    /// (= e.g. log every cross-book attempt).
    private static func encodeFailureScopeViolation(
        action: BookWorldAction,
        error: BookScopeViolation
    ) -> String {
        let payload: [String: Any] = [
            "ok": false,
            "action": action.rawValue,
            "error": error.errorDescription ?? "unknown error",
            "error_kind": "book_scope_violation"
        ]
        return encodeJSON(payload)
    }

    private static func descriptorToJSON(_ d: WorldEntryDescriptor) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return [
            "id": d.id.uuidString,
            "book_id": d.bookId.uuidString,
            "type": d.type,
            "name": d.name,
            "summary": d.summary,
            "createdAt": iso.string(from: d.createdAt),
            "updatedAt": iso.string(from: d.updatedAt)
        ]
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookWorldTool: JSON encode failed\"}"
        }
        return s
    }
}

// MARK: - BookWorldTool (Tool-protocol adapter)

/// Tool-protocol adapter (= thin wrapper around BookWorldActor).
/// Wired into the WenshuConductor under the key "book_world".
actor BookWorldTool: Tool {
    let name = "book_world"
    let description = "Create / read / update / delete / list / find world-building entries under a book (= geography / lore / event / object / other)."

    private let actor: BookWorldActor

    init(actor: BookWorldActor) {
        self.actor = actor
    }

    func execute(input: String) async throws -> String {
        try await actor.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap

extension BookWorldTool {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1).
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_world",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "book_world",
                    description: "Per-book world-building CRUD (= wraps FileSystemWorldStore). LLM-friendly verbs: create / read / update / delete / list / find.",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The world-entry operation to perform.",
                            enumValues: ["create", "read", "update", "delete", "list", "find"]
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning book id (UUID). Required for create / list / find."
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "World entry id (UUID). Required for read / update / delete."
                        ),
                        "name": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Entry name. Required for create / find; for update replaces the entry name."
                        ),
                        "type": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "WorldEntryType (geography / lore / event / object / other). Defaults to other."
                        ),
                        "summary": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional 1-line summary."
                        ),
                        "markdown": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Full .md body for create / update. Alias: 'body'."
                        )
                    ],
                    required: ["action"]
            ),
            handler: BookWorldTool.shared,
            description: "Per-book world-building CRUD.",
            emoji: "🌍"
        )
        }
    }()

    /// Shared singleton for ToolRegistry bootstrap (= lazy-init
    /// fallback FileSystemWorldStore under /tmp so module-load
    /// registration does not require a real library to be open).
    nonisolated static let shared: BookWorldTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-world-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return BookWorldTool(
            actor: BookWorldActor(
                bookDirectoryProvider: { tmpRoot },
                currentChatBookIDProvider: { nil }
            )
        )
    }()
}