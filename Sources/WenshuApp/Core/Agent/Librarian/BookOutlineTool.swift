//
//  BookOutlineTool.swift
//
//  Per-book outline CRUD tool (= wraps FileSystemOutlineStore).
//  Mirrors BookWorldTool / BookCharacterTool / BookChapterTool
//  patterns.
//
//  LLM-friendly verbs: create / read / update / delete / list / find.
//  Optional `parent` (= UUID string) for hierarchy; `order` for sort.
//

import Foundation

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
    /// Closure returning the book directory for the current chat
    /// session's bound book (= nil when no chat book is bound).
    /// Resolved on every CRUD call so the user can switch books
    /// mid-conversation without the actor holding a stale root.
    private let bookDirectoryProvider: @Sendable () -> URL?

    /// Closure returning the chat session's currently-bound book.
    /// See BookWorldActor's matching field for the contract.
    private let currentChatBookIDProvider: @Sendable () -> UUID?

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

    /// Resolve the current book directory (= raises `invalidInput`
    /// if the chat session has no bound book, which the scope guard
    /// should already have rejected).
    ///
    /// Per boss 2026-10-05 OOB '做 8': FileSystemOutlineStore is
    /// @MainActor-isolated (= SwiftData ModelContext contract); =
    /// the actor (= this) can't instantiate it. We resolve to the
    /// book directory URL and use the nonisolated static FileSystem
    /// fallback helpers (= actor-safe).
    private func resolveBookDirectory() throws -> URL {
        guard let dir = bookDirectoryProvider() else {
            throw BookOutlineError.invalidInput(
                reason: "no chat session book bound (= scope guard should have caught this earlier)"
            )
        }
        // wt/path-guard-v2-2026-09-25: PathGuard second-line defense
        // (= see BookChapterActor.resolveStore for the rationale).
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

        // Silent dedup (= v2.2, 2026-09-25): if an outline with
        // the same title already exists in this book, fall back to
        // an in-place update (= preserves id / createdAt /
        // parent / order). LLM never sees an error.
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
        // parent = nil means "don't change"; = to clear parent, send
        // an empty string in the JSON envelope (= parsed below).
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

    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookOutlineError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookOutlineError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookOutlineError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookOutlineAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookOutlineError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find)"
                )
            )
        }

        // Scope guard: see BookWorldActor (= identical contract).
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
                error: BookOutlineError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookOutlineError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String ?? ""
                let parent = Self.parseOptionalUUID(envelope["parent"])
                let order = (envelope["order"] as? Int) ?? 0
                let body = Self.extractMarkdown(envelope)
                let outline = try await createOutline(
                    bookId: bookId,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary,
                    parent: parent,
                    order: order
                )
                return Self.encodeSuccess(action: action, outline: outline)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookOutlineError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (outline, body) = try await readOutline(id: id)
                return Self.encodeSuccessRead(action: action, outline: outline, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookOutlineError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String
                let parentRaw = envelope["parent"]
                let parent: UUID? = (parentRaw is NSNull)
                    ? nil
                    : Self.parseOptionalUUID(parentRaw)
                let order = envelope["order"] as? Int
                let body = Self.extractMarkdown(envelope)
                let outline = try await updateOutline(
                    id: id,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary,
                    parent: parent,
                    order: order
                )
                return Self.encodeSuccess(action: action, outline: outline)

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookOutlineError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteOutline(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookOutlineError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let outlines = try await listOutlines(bookId: bookId)
                return Self.encodeSuccessList(action: action, outlines: outlines)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookOutlineError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let outline = try await findOutline(bookId: bookId, title: title)
                return Self.encodeSuccessFind(action: action, outline: outline)
            }
        } catch let error as BookOutlineError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookOutlineError.underlying(String(describing: error))
            )
        }
    }

    // MARK: - JSON helpers

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

    /// parseOptionalUUID: returns nil when the value is missing OR
    /// is the literal string "null" (= sentinels from the LLM). Use
    /// this for fields where nil means "no change".
    private static func parseOptionalUUID(_ any: Any?) -> UUID? {
        if any == nil { return nil }
        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t.lowercased() == "null" { return nil }
            return UUID(uuidString: t)
        }
        return nil
    }

    private static func encodeSuccess(
        action: BookOutlineAction,
        outline: OutlineEntryDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let outline {
            payload["outline"] = descriptorToJSON(outline)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookOutlineAction,
        outline: OutlineEntryDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "outline": descriptorToJSON(outline),
            "body": body ?? ""
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: BookOutlineAction,
        outline: OutlineEntryDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": outline != nil]
        if let outline {
            payload["outline"] = descriptorToJSON(outline)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookOutlineAction,
        outlines: [OutlineEntryDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "outlines": outlines.map { descriptorToJSON($0) }
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookOutlineAction?,
        error: BookOutlineError
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
    /// See BookWorldTool.encodeFailureScopeViolation for the matching
    /// contract.
    private static func encodeFailureScopeViolation(
        action: BookOutlineAction,
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

    private static func descriptorToJSON(_ d: OutlineEntryDescriptor) -> [String: Any] {
                var dict: [String: Any] = [
            "id": d.id.uuidString,
            "book_id": d.bookId.uuidString,
            "title": d.title,
            "summary": d.summary,
            "order": d.order,
            "createdAt": d.createdAt.formatted(.iso8601),
            "updatedAt": d.updatedAt.formatted(.iso8601)
        ]
        if let parent = d.parent {
            dict["parent"] = parent.uuidString
        }
        return dict
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookOutlineTool: JSON encode failed\"}"
        }
        return s
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
            handler: BookOutlineTool.shared,
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