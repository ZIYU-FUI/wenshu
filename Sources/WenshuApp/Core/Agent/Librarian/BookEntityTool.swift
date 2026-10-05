//
//  BookEntityTool.swift
//
//  Per-book entity CRUD actor + 5-kind dispatcher.
//
//  Replaces BookCharacterActor + BookWorldActor from v2.0/v2.2
//  with a single kind-discriminated actor (= all 5 kinds go
//  through the same 6 actions: create / read / update / delete
//  / list / find).
//
//  Storage: FileSystemEntityStore (= the on-disk JSON index +
//  per-entity .md body file).
//
//  Scope guard (v2.1): every action MUST carry a `book_id` that
//  matches the chat session's currently-bound book. Same
//  BookScopeGuard helper as v2.1.
//
//  Silent dedup (v2.2): if an entity with the same name already
//  exists in this book (= case-insensitive), falls back to
//  in-place update. Same behavior as BookCharacterActor /
//  BookWorldActor in v2.2.

import Foundation

// MARK: - Actions

enum BookEntityAction: String, Sendable {
    case create
    case read
    case update
    case delete
    case list
    case find
}

// MARK: - Errors

enum BookEntityError: Error, LocalizedError {
    case emptyName
    case entryNotFound(id: String)
    case invalidInput(reason: String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "BookEntityTool: entity name was empty or whitespace-only."
        case .entryNotFound(let id):
            return "BookEntityTool: entity \(id) not found."
        case .invalidInput(let reason):
            return "BookEntityTool: invalid input — \(reason)."
        case .underlying(let msg):
            return "BookEntityTool: underlying error — \(msg)."
        }
    }
}

// MARK: - Actor

actor BookEntityActor {
    /// Closure returning the book directory for the current chat
    /// session's bound book (= nil when no chat book is bound).
    /// Resolved on every CRUD call so the user can switch books
    /// mid-conversation without the actor holding a stale root.
    let bookDirectoryProvider: @Sendable () -> URL?

    /// Closure returning the chat session's currently-bound book
    /// (= nil when the chat session has no bound book).
    let currentChatBookIDProvider: @Sendable () -> UUID?

    init(
        bookDirectoryProvider: @escaping @Sendable () -> URL?,
        currentChatBookIDProvider: @escaping @Sendable () -> UUID? = { nil }
    ) {
        self.bookDirectoryProvider = bookDirectoryProvider
        self.currentChatBookIDProvider = currentChatBookIDProvider
    }

    /// Test-only body accessor.
    func readBodyForTest(id: EntityID) async -> String? {
        guard let dir = bookDirectoryProvider() else { return nil }
        let store = FileSystemEntityStore(bookDirectory: dir)
        return store.loadEntityBody(id: id)
    }

    /// Resolve the current book directory. Throws if the chat
    /// session has no bound book (= the scope guard should have
    /// already caught this).
    private func resolveStore() throws -> FileSystemEntityStore {
        guard let dir = bookDirectoryProvider() else {
            throw BookEntityError.invalidInput(
                reason: "no chat session book bound (= scope guard should have caught this earlier)"
            )
        }
        // wt/path-guard-v2-2026-09-25: PathGuard second-line defense
        // (= see BookChapterActor.resolveStore for the rationale).
        try PathGuard.assertInsideLibrary(path: LibraryPath(rawValue: dir.path))
        return FileSystemEntityStore(bookDirectory: dir)
    }

    // MARK: - CRUD

    /// Create a new entity (= falls back to update if an entity
    /// with the same name already exists in this book; = per the
    /// v2.2 silent dedup contract).
    func createEntity(
        bookId: UUID,
        kind: String,
        name: String,
        bodyMarkdown: String? = nil,
        aliases: [String] = [],
        tags: [String] = [],
        description: String = "",
        attributes: [String: String] = [:],
        kindSpecific: EntityKindSpecific = .empty
    ) async throws -> EntityDescriptor {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookEntityError.emptyName
        }
        guard let parsedKind = EntityKind(rawValue: kind) else {
            throw BookEntityError.invalidInput(
                reason: "unknown kind '\(kind)' (expected: person / location / object / ability / event)"
            )
        }

        // Silent dedup (= v2.2 contract): if an entity with the
        // same name already exists in this book (= case-
        // insensitive), silently update in place. The fallback
        // update uses either the caller's bodyMarkdown OR the
        // rendered template (= same default as the fresh-create
        // path; = ensures the body on disk is rewritten even when
        // the caller doesn't pass a fresh bodyMarkdown).
        if let existing = try await findEntity(
            bookId: bookId, kind: parsedKind, name: trimmed
        ) {
            let bodyForUpdate = bodyMarkdown ?? EntityTemplate.render(
                EntityDescriptor(
                    id: existing.id,
                    bookID: existing.bookID,
                    kind: parsedKind,
                    name: trimmed,
                    aliases: aliases,
                    tags: tags,
                    description: description,
                    attributes: attributes,
                    kindSpecific: kindSpecific,
                    bodyExcerpt: existing.bodyExcerpt,
                    createdAt: existing.createdAt,
                    updatedAt: existing.updatedAt
                )
            )
            return try await updateEntity(
                id: existing.id,
                bookId: bookId,
                kind: kind,
                name: trimmed,
                bodyMarkdown: bodyForUpdate,
                aliases: aliases,
                tags: tags,
                description: description,
                attributes: attributes,
                kindSpecific: kindSpecific
            )
        }

        let id = EntityID.newID()
        let bookID = BookID(rawValue: bookId.uuidString)
        let body = bodyMarkdown ?? EntityTemplate.render(
            EntityDescriptor(
                id: id,
                bookID: bookID,
                kind: parsedKind,
                name: trimmed,
                aliases: aliases,
                tags: tags,
                description: description,
                attributes: attributes,
                kindSpecific: kindSpecific
            )
        )
        // Build descriptor with body excerpt = first 200 chars.
        let excerpt = BodyExcerpt.make(from: body)
        let now = Date()
        let descriptor = EntityDescriptor(
            id: id,
            bookID: bookID,
            kind: parsedKind,
            name: trimmed,
            aliases: aliases,
            tags: tags,
            description: description,
            attributes: attributes,
            kindSpecific: kindSpecific,
            bodyExcerpt: excerpt,
            createdAt: now,
            updatedAt: now
        )
        do {
            let store = try resolveStore()
            try store.saveEntity(descriptor, bodyMarkdown: body)
        } catch let err as BookEntityError {
            throw err
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
        return descriptor
    }

    /// Read an entity by id. Returns the descriptor + the raw
    /// body markdown (= the LLM-facing tool return value pairs
    /// these as a tuple).
    func readEntity(id: EntityID) async throws -> (EntityDescriptor, String?) {
        do {
            let store = try resolveStore()
            let entities = try store.loadEntities()
            guard let entity = entities.first(where: { $0.id == id }) else {
                throw BookEntityError.entryNotFound(id: id.rawValue)
            }
            let body = store.loadEntityBody(id: id)
            return (entity, body)
        } catch let err as BookEntityError {
            throw err
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
    }

    /// Update an existing entity in place.
    func updateEntity(
        id: EntityID,
        bookId: UUID,
        kind: String,
        name: String,
        bodyMarkdown: String? = nil,
        aliases: [String]? = nil,
        tags: [String]? = nil,
        description: String? = nil,
        attributes: [String: String]? = nil,
        kindSpecific: EntityKindSpecific? = nil
    ) async throws -> EntityDescriptor {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookEntityError.emptyName
        }
        guard let parsedKind = EntityKind(rawValue: kind) else {
            throw BookEntityError.invalidInput(
                reason: "unknown kind '\(kind)'"
            )
        }
        let store = try resolveStore()
        let entities: [EntityDescriptor]
        do {
            entities = try store.loadEntities()
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
        guard let existing = entities.first(where: { $0.id == id }) else {
            throw BookEntityError.entryNotFound(id: id.rawValue)
        }
        let newBody: String
        if let bodyMarkdown {
            newBody = bodyMarkdown
        } else {
            // No body provided = keep the existing body on disk.
            let existingBody = store.loadEntityBody(id: id) ?? ""
            newBody = existingBody
        }
        // Build updated descriptor with merged fields.
        let merged = EntityDescriptor(
            id: existing.id,
            bookID: existing.bookID,
            kind: parsedKind,
            name: trimmed,
            aliases: aliases ?? existing.aliases,
            tags: tags ?? existing.tags,
            description: description ?? existing.description,
            attributes: attributes ?? existing.attributes,
            kindSpecific: kindSpecific ?? existing.kindSpecific,
            bodyExcerpt: BodyExcerpt.make(from: newBody),
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        do {
            try store.replaceEntity(merged, bodyMarkdown: newBody)
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
        return merged
    }

    /// Delete an entity (= idempotent).
    func deleteEntity(id: EntityID) async throws {
        do {
            let store = try resolveStore()
            try store.deleteEntity(id: id)
        } catch let err as BookEntityError {
            throw err
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
    }

    /// List all entities in a book (= optionally filtered by kind).
    /// Sorted by updatedAt descending (= most-recently-edited
    /// first).
    func listEntities(bookId: UUID, kind: EntityKind? = nil) async throws -> [EntityDescriptor] {
        let store = try resolveStore()
        let entities: [EntityDescriptor]
        do {
            entities = try store.loadEntities()
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
        let filtered = entities.filter { entity in
            entity.bookIDRaw == bookId.uuidString &&
            (kind == nil || entity.kind == kind)
        }
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        return sorted
    }

    /// Find a single entity by name in the given book + kind.
    /// Case-insensitive match.
    func findEntity(
        bookId: UUID, kind: EntityKind, name: String
    ) async throws -> EntityDescriptor? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let store = try resolveStore()
        let entities: [EntityDescriptor]
        do {
            entities = try store.loadEntities()
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
        let match = entities.first { entity in
            entity.bookIDRaw == bookId.uuidString &&
            entity.kind == kind &&
            entity.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed
        }
        return match
    }

    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    /// LLM-facing entry-point: parse JSON envelope + dispatch to
    /// the corresponding CRUD action. Mirrors the BookCharacterActor
    /// / BookWorldActor pattern (= thin JSON dispatcher; = same
    /// scope-guard contract).
    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookEntityError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookEntityError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookEntityError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookEntityAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookEntityError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find)"
                )
            )
        }

        // Scope guard (= v2.1 contract): every action MUST carry a
        // `book_id` matching the chat session's currently-bound book.
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
                error: BookEntityError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let kind = envelope["kind"] as? String ?? ""
                let name = envelope["name"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let aliases = (envelope["aliases"] as? [String]) ?? []
                let tags = (envelope["tags"] as? [String]) ?? []
                let description = envelope["description"] as? String ?? ""
                let attributes = (envelope["attributes"] as? [String: String]) ?? [:]
                let entity = try await createEntity(
                    bookId: bookId,
                    kind: kind,
                    name: name,
                    bodyMarkdown: body,
                    aliases: aliases,
                    tags: tags,
                    description: description,
                    attributes: attributes
                )
                return Self.encodeSuccess(action: action, entity: entity)

            case .read:
                guard let idRaw = envelope["id"] as? String, !idRaw.isEmpty else {
                    throw BookEntityError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let id = EntityID(rawValue: idRaw)
                let (entity, body) = try await readEntity(id: id)
                return Self.encodeSuccessRead(action: action, entity: entity, body: body)

            case .update:
                guard let idRaw = envelope["id"] as? String, !idRaw.isEmpty else {
                    throw BookEntityError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let id = EntityID(rawValue: idRaw)
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "update requires 'book_id' (UUID string)")
                }
                let kind = envelope["kind"] as? String ?? ""
                let name = envelope["name"] as? String ?? ""
                let body = Self.extractMarkdown(envelope).isEmpty ? nil : Self.extractMarkdown(envelope)
                let aliases = envelope["aliases"] as? [String]
                let tags = envelope["tags"] as? [String]
                let description = envelope["description"] as? String
                let attributes = envelope["attributes"] as? [String: String]
                let entity = try await updateEntity(
                    id: id,
                    bookId: bookId,
                    kind: kind,
                    name: name,
                    bodyMarkdown: body,
                    aliases: aliases,
                    tags: tags,
                    description: description,
                    attributes: attributes
                )
                return Self.encodeSuccess(action: action, entity: entity)

            case .delete:
                guard let idRaw = envelope["id"] as? String, !idRaw.isEmpty else {
                    throw BookEntityError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                let id = EntityID(rawValue: idRaw)
                try await deleteEntity(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let kindFilter: EntityKind? = (envelope["kind"] as? String).flatMap(EntityKind.init(rawValue:))
                let entities = try await listEntities(bookId: bookId, kind: kindFilter)
                return Self.encodeSuccessList(action: action, entities: entities)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let kind = envelope["kind"] as? String ?? ""
                let name = envelope["name"] as? String ?? ""
                guard let parsedKind = EntityKind(rawValue: kind) else {
                    throw BookEntityError.invalidInput(
                        reason: "find requires 'kind' (one of: person / location / object / ability / event)"
                    )
                }
                let entity = try await findEntity(bookId: bookId, kind: parsedKind, name: name)
                return Self.encodeSuccessFind(action: action, entity: entity)
            }
        } catch let error as BookEntityError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookEntityError.underlying(String(describing: error))
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

    private static func descriptorToJSON(_ entity: EntityDescriptor) -> [String: Any] {
        return [
            "id": entity.id.rawValue,
            "book_id": entity.bookID.rawValue,
            "kind": entity.kind.rawValue,
            "name": entity.name,
            "aliases": entity.aliases,
            "tags": entity.tags,
            "description": entity.description,
            "attributes": entity.attributes,
            "kind_specific": String(describing: entity.kindSpecific),
            "body_excerpt": entity.bodyExcerpt,
            "created_at": entity.createdAt.formatted(.iso8601),
            "updated_at": entity.updatedAt.formatted(.iso8601)
        ]
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookEntityTool: JSON encode failed\"}"
        }
        return s
    }

    private static func encodeSuccess(
        action: BookEntityAction,
        entity: EntityDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let entity {
            payload["entity"] = descriptorToJSON(entity)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookEntityAction,
        entity: EntityDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "entity": descriptorToJSON(entity),
            "body": body ?? ""
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookEntityAction,
        entities: [EntityDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "entities": entities.map { descriptorToJSON($0) }
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: BookEntityAction,
        entity: EntityDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        payload["entity"] = entity.map { descriptorToJSON($0) } ?? NSNull()
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookEntityAction?,
        error: BookEntityError
    ) -> String {
        var payload: [String: Any] = [
            "ok": false,
            "error_kind": errorKind(for: error),
            "error": error.errorDescription ?? String(describing: error)
        ]
        if let action {
            payload["action"] = action.rawValue
        }
        return encodeJSON(payload)
    }

    private static func encodeFailureScopeViolation(
        action: BookEntityAction,
        error: BookScopeViolation
    ) -> String {
        let payload: [String: Any] = [
            "ok": false,
            "error_kind": "book_scope_violation",
            "error": error.errorDescription ?? String(describing: error)
        ]
        return encodeJSON(payload)
            .replacingOccurrences(of: "{\n", with: "{")
            .replacingOccurrences(of: "}\n", with: "}")
    }

    private static func errorKind(for error: BookEntityError) -> String {
        switch error {
        case .emptyName: return "empty_name"
        case .entryNotFound: return "entry_not_found"
        case .invalidInput: return "invalid_input"
        case .underlying: return "underlying_error"
        }
    }
}

// MARK: - Tool-protocol adapter

actor BookEntityTool: Tool {
    let name = "book_entity"
    let description = "Create / read / update / delete / list / find entities (= person / location / object / ability / event) under a book. Replaces book_world + book_character from v2.0/v2.2 (= kind field selects the schema)."

    private let actor: BookEntityActor

    init(actor: BookEntityActor) {
        self.actor = actor
    }

    func execute(input: String) async throws -> String {
        try await actor.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap

extension BookEntityTool {
    /// Module-load registration with `ToolRegistry.shared`.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_entity",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "book_entity",
                    description: "Per-book entity CRUD (= wraps FileSystemEntityStore + BookEntityActor). LLM-friendly verbs: create / read / update / delete / list / find. The 'kind' field selects one of 5 entity kinds: person / location / object / ability / event.",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The entity operation to perform.",
                            enumValues: ["create", "read", "update", "delete", "list", "find"]
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning book id (UUID). Required for create / list / find."
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Entity id (UUID). Required for read / update / delete."
                        ),
                        "kind": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "EntityKind (one of: person / location / object / ability / event). Required for create / find.",
                            enumValues: ["person", "location", "object", "ability", "event"]
                        ),
                        "name": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Entity name. Required for create / find (= case-insensitive dedup; v2.2 contract)."
                        ),
                        "aliases": ToolRegistrySchemaProperty(
                            type: "array",
                            description: "Optional alternate names for the entity (= e.g. nicknames)."
                        ),
                        "tags": ToolRegistrySchemaProperty(
                            type: "array",
                            description: "Optional tags (= e.g. 'main', 'supporting')."
                        ),
                        "description": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional 1-line summary."
                        ),
                        "attributes": ToolRegistrySchemaProperty(
                            type: "object",
                            description: "Optional free-form attributes (= e.g. age / occupation)."
                        ),
                        "markdown": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Full .md body. Alias: 'body'."
                        )
                    ],
                    required: ["action"]
            ),
            handler: BookEntityTool.shared,
            description: "Per-book entity CRUD (= 5 kinds: person / location / object / ability / event). Replaces book_world + book_character from v2.0/v2.2.",
            emoji: "🏷️"
        )
        }
    }()

    nonisolated static let shared: BookEntityTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-entity-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return BookEntityTool(
            actor: BookEntityActor(
                bookDirectoryProvider: { tmpRoot },
                currentChatBookIDProvider: { nil }
            )
        )
    }()
}