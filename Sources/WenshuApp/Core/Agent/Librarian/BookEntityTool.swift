//
//  BookEntityTool.swift · Wenshu · v2.3 (2026-09-25)
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
}