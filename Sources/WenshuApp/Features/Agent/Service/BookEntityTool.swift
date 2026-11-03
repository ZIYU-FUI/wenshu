// BookEntityTool.swift Per-book entity CRUD actor + 5-kind dispatcher. Replaces
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// BookWorldActor in an earlier version.
import Foundation
import WenshuAgent
import WenshuData

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
    // / Closure returning the book directory for the current chat
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / mid-conversation without the actor holding a stale root.
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
        // Per boss 2026-10-05 (see OOB.md #2026-10-05) @MainActor-isolated (= SwiftData
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // nonisolated static FileSystem fallback helpers (= actor-safe).
        return FileSystemEntityStore.loadEntityBodyFromFileSystem(
            id: id,
            bookDirectory: dir
        )
    }

    // / Resolve the current book directory. Throws if the chat
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / surface).
    private func resolveBookDirectory() throws -> URL {
        guard let dir = bookDirectoryProvider() else {
            throw BookEntityError.invalidInput(
                reason: "no chat session book bound (= scope guard should have caught this earlier)"
            )
        }
        // wt/path-guard-v2-2026-09-25: PathGuard second-line defense (= see
        // BookChapterActor.resolveStore for the rationale).
        try PathGuard.assertInsideLibrary(path: LibraryPath(rawValue: dir.path))
        return dir
    }

    // MARK: - CRUD
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / contract).
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

        // Silent dedup: if an entity with the same name already exists in this book (=
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // rewritten even when the caller doesn't pass a fresh bodyMarkdown).
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
            let dir = try resolveBookDirectory()
            try FileSystemEntityStore.saveEntityToFileSystem(
                entity: descriptor,
                bodyMarkdown: body,
                bookDirectory: dir
            )
        } catch let err as BookEntityError {
            throw err
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
        return descriptor
    }

    // / Read an entity by id. Returns the descriptor + the raw
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / these as a tuple).
    func readEntity(id: EntityID) async throws -> (EntityDescriptor, String?) {
        do {
            let dir = try resolveBookDirectory()
            let entities = try FileSystemEntityStore.loadEntitiesFromFileSystem(bookDirectory: dir)
            guard let entity = entities.first(where: { $0.id == id }) else {
                throw BookEntityError.entryNotFound(id: id.rawValue)
            }
            let body = FileSystemEntityStore.loadEntityBodyFromFileSystem(
                id: id,
                bookDirectory: dir
            )
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
        let dir = try resolveBookDirectory()
        let entities: [EntityDescriptor]
        do {
            entities = try FileSystemEntityStore.loadEntitiesFromFileSystem(bookDirectory: dir)
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
            let existingBody = FileSystemEntityStore.loadEntityBodyFromFileSystem(
                id: id,
                bookDirectory: dir
            ) ?? ""
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
            try FileSystemEntityStore.replaceEntityToFileSystem(
                entity: merged,
                bodyMarkdown: newBody,
                bookDirectory: dir
            )
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
        return merged
    }

    /// Delete an entity (= idempotent).
    func deleteEntity(id: EntityID) async throws {
        do {
            let dir = try resolveBookDirectory()
            try FileSystemEntityStore.deleteEntityFromFileSystem(
                id: id,
                bookDirectory: dir
            )
        } catch let err as BookEntityError {
            throw err
        } catch {
            throw BookEntityError.underlying(String(describing: error))
        }
    }

    // / List all entities in a book (= optionally filtered by kind).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / first).
    func listEntities(bookId: UUID, kind: EntityKind? = nil) async throws -> [EntityDescriptor] {
        let dir = try resolveBookDirectory()
        let entities: [EntityDescriptor]
        do {
            entities = try FileSystemEntityStore.loadEntitiesFromFileSystem(bookDirectory: dir)
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
        let dir = try resolveBookDirectory()
        let entities: [EntityDescriptor]
        do {
            entities = try FileSystemEntityStore.loadEntitiesFromFileSystem(bookDirectory: dir)
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

// MARK: - Tool-protocol adapter

actor BookEntityTool: Tool {
    let name = "book_entity"
    let description = "Create / read / update / delete / list / find entities (= person / location / object / ability / event) under a book. Replaces book_world + book_character from previous versions (= kind field selects the schema)."

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
                            description: "Entity name. Required for create / find (= case-insensitive dedup)."
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
            handler: LazyTool { BookEntityTool.shared },
            description: "Per-book entity CRUD (= 5 kinds: person / location / object / ability / event). Replaces book_world + book_character from previous versions.",
            emoji: "🏷️"
        )
        }
    }()

    static let shared: BookEntityTool = {
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
