//
//  FileSystemEntityStore.swift
//
//  Per-book entity storage layer, backed by SwiftData (= the
//  WSEntity + WSBody @Model classes in Persistence/) with a
//  FileSystem fallback for actor callers.
//
//  Per boss 2026-10-05 OOB '做 8' (= complete the FileSystem*Store →
//  SwiftData migration). This is commit 3 of #8.
//
//  Apple HIG canonical pattern: WSEntity holds the indexed metadata
//  (id, bookID, kind, name, aliases, tags, description, attributes,
//  kindSpecific) in one row. The body markdown lives in a separate
//  WSBody row (= FK via bodyID). SwiftData stores both as proper
//  relational tables.
//
//  Storage paths (= unchanged at the public API level):
//    <.ws>/shelves/<shelf>/books/<UUID>/entities/<UUID>.md
//    <.ws>/shelves/<shelf>/books/<UUID>/entities.json
//
//  Apple HIG dual-write pattern: when no ModelContainer is wired
//  (= legacy dev-tool path; = actor-based callers that can't reach
//  MainActor), fall back to the legacy FileSystem path
//  (= per-entity .md body + entities.json index).

import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol EntityStoring: Sendable {
    var bookDirectory: URL { get }

    /// Returns the parsed `entities.json` index (= the
    /// structured metadata for every Entity in this Book).
    /// Missing = [], corrupt = [] (Apple HIG forgiving-reset).
    func loadEntities() throws -> [EntityDescriptor]

    /// Persist a new Entity (= creates the .md body + appends to
    /// the index). Throws .entityAlreadyExists if the id is on
    /// disk.
    func saveEntity(_ entity: EntityDescriptor, bodyMarkdown: String) throws

    /// Update an existing Entity in place (= overwrites the .md
    /// body + updates the index row). Throws .entityNotFound.
    func replaceEntity(_ entity: EntityDescriptor, bodyMarkdown: String) throws

    /// Remove an Entity (= deletes the .md + removes from index).
    /// Idempotent: no-op if already gone.
    func deleteEntity(id: EntityID) throws

    /// Read the raw .md body for an entity. Returns nil if the
    /// .md file doesn't exist (= orphan index row).
    func loadEntityBody(id: EntityID) -> String?

    /// Look up a single entity by id. Returns nil if not found.
    func entityExists(id: EntityID) -> Bool
}

// MARK: - Errors

enum EntityStoreError: Error, LocalizedError {
    case entityAlreadyExists(id: String)
    case entityNotFound(id: String)
    case bookDirectoryMissing(path: String)

    var errorDescription: String? {
        switch self {
        case .entityAlreadyExists(let id):
            return "Entity \(id) already exists on disk."
        case .entityNotFound(let id):
            return "Entity \(id) not found on disk."
        case .bookDirectoryMissing(let path):
            return "Book directory does not exist: \(path). Cannot save entities."
        }
    }
}

// MARK: - SwiftData implementation
//
// Same isolation pattern as FileSystemChapterStore + FileSystemReferenceStore:
// @MainActor-isolated (= SwiftData's ModelContext contract). The
// actor-based callers (= CrossRefInject_v2, EntityIngestion) use
// the nonisolated static FileSystem fallback helpers directly
// when they need to avoid the MainActor hop.

@MainActor
struct FileSystemEntityStore: EntityStoring {
    let bookDirectory: URL

    /// SwiftData ModelContainer (= Sendable; = passed to the store
    /// by the caller, who owns the singleton). When nil (= legacy
    /// dev-tool path), the store routes to the FileSystem fallback.
    let modelContainer: ModelContainer?

    private var entitiesDirectory: URL {
        bookDirectory.appendingPathComponent("entities", isDirectory: true)
    }

    private var indexURL: URL {
        bookDirectory.appendingPathComponent("entities.json")
    }

    init(
        bookDirectory: URL,
        modelContainer: ModelContainer? = nil
    ) {
        self.bookDirectory = bookDirectory
        self.modelContainer = modelContainer
    }

    private var modelContext: ModelContext? {
        modelContainer?.mainContext
    }

    // MARK: EntityStoring

    func loadEntities() throws -> [EntityDescriptor] {
        guard modelContainer != nil else {
            return try Self.loadEntitiesFromFileSystem(bookDirectory: bookDirectory)
        }
        guard let context = modelContext else { return [] }
        // The bookID is encoded into the directory structure
        // (= <shelves>/<shelf>/books/<UUID>/). The bookUUID is the
        // directory's last path component.
        let bookID = bookDirectory.lastPathComponent
        let descriptor = FetchDescriptor<WSEntity>(
            predicate: #Predicate { $0.bookID == bookID }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map(Self.toDescriptor)
    }

    func saveEntity(_ entity: EntityDescriptor, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.saveEntityToFileSystem(
                entity: entity,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory
            )
            return
        }
        guard let context = modelContext else {
            throw EntityStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let id = entity.id.rawValue
        let descriptor = FetchDescriptor<WSEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let _ = try? context.fetch(descriptor).first {
            throw EntityStoreError.entityAlreadyExists(id: id)
        }
        // Create the body row (= FK target).
        let bodyRow = WSBody(
            id: UUID().uuidString,
            markdown: bodyMarkdown
        )
        context.insert(bodyRow)
        let row = Self.makeRow(entity: entity, bodyID: bodyRow.id)
        context.insert(row)
        try context.save()
    }

    func replaceEntity(_ entity: EntityDescriptor, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.replaceEntityToFileSystem(
                entity: entity,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory
            )
            return
        }
        guard let context = modelContext else {
            throw EntityStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let id = entity.id.rawValue
        let descriptor = FetchDescriptor<WSEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            throw EntityStoreError.entityNotFound(id: id)
        }
        existing.kind = entity.kind.rawValue
        existing.name = entity.name
        existing.aliasesJoined = entity.aliases.joined(separator: ",")
        existing.tagsJoined = entity.tags.joined(separator: ",")
        existing.description_ = entity.description
        existing.attributesJSON = Self.encodeAttributes(entity.attributes)
        existing.kindSpecificJSON = Self.encodeKindSpecific(entity.kindSpecific)
        existing.updatedAt = Date()
        // Update the body row.
        let bodyID = existing.bodyID
        let bodyDescriptor = FetchDescriptor<WSBody>(
            predicate: #Predicate { $0.id == bodyID }
        )
        if let bodyRow = (try? context.fetch(bodyDescriptor))?.first {
            bodyRow.markdown = bodyMarkdown
            bodyRow.updatedAt = Date()
        }
        try context.save()
    }

    func deleteEntity(id: EntityID) throws {
        guard modelContainer != nil else {
            try Self.deleteEntityFromFileSystem(
                id: id,
                bookDirectory: bookDirectory
            )
            return
        }
        guard let context = modelContext else {
            return
        }
        let idRaw = id.rawValue
        let descriptor = FetchDescriptor<WSEntity>(
            predicate: #Predicate { $0.id == idRaw }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            // Idempotent: silent no-op when not found.
            return
        }
        // Cascade-delete the body row.
        let bodyID = existing.bodyID
        let bodyDescriptor = FetchDescriptor<WSBody>(
            predicate: #Predicate { $0.id == bodyID }
        )
        if let bodyRow = (try? context.fetch(bodyDescriptor))?.first {
            context.delete(bodyRow)
        }
        context.delete(existing)
        try context.save()
    }

    func loadEntityBody(id: EntityID) -> String? {
        guard let context = modelContext else {
            return Self.loadEntityBodyFromFileSystem(
                id: id,
                bookDirectory: bookDirectory
            )
        }
        let idRaw = id.rawValue
        let descriptor = FetchDescriptor<WSEntity>(
            predicate: #Predicate { $0.id == idRaw }
        )
        guard let row = (try? context.fetch(descriptor))?.first else {
            return nil
        }
        let bodyID = row.bodyID
        let bodyDescriptor = FetchDescriptor<WSBody>(
            predicate: #Predicate { $0.id == bodyID }
        )
        return (try? context.fetch(bodyDescriptor).first)?.markdown
    }

    func entityExists(id: EntityID) -> Bool {
        guard let context = modelContext else {
            let url = entitiesDirectory.appendingPathComponent("\(id.rawValue).md")
            return FileManager.default.fileExists(atPath: url.path)
        }
        let idRaw = id.rawValue
        let descriptor = FetchDescriptor<WSEntity>(
            predicate: #Predicate { $0.id == idRaw }
        )
        return ((try? context.fetch(descriptor).first) != nil)
    }

    // MARK: - SwiftData bridging helpers

    private static func makeRow(entity: EntityDescriptor, bodyID: String) -> WSEntity {
        let row = WSEntity(
            id: entity.id.rawValue,
            bookID: entity.bookID.rawValue,
            kind: entity.kind.rawValue,
            name: entity.name,
            aliasesJoined: entity.aliases.joined(separator: ","),
            tagsJoined: entity.tags.joined(separator: ","),
            description: entity.description,
            attributesJSON: encodeAttributes(entity.attributes),
            kindSpecificJSON: encodeKindSpecific(entity.kindSpecific),
            bodyID: bodyID,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        return row
    }

    private static func toDescriptor(_ row: WSEntity) -> EntityDescriptor {
        let attrs: [String: String] = (row.attributesJSON?.data(using: .utf8))
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        let kindSpecific: EntityKindSpecific = (row.kindSpecificJSON?.data(using: .utf8))
            .flatMap { try? JSONDecoder().decode(EntityKindSpecific.self, from: $0) }
            ?? EntityKindSpecific()
        return EntityDescriptor(
            id: EntityID(rawValue: row.id),
            bookID: BookID(rawValue: row.bookID),
            kind: EntityKind(rawValue: row.kind) ?? .person,
            name: row.name,
            aliases: row.aliasesJoined.split(separator: ",").map(String.init),
            tags: row.tagsJoined.split(separator: ",").map(String.init),
            description: row.description_,
            attributes: attrs,
            kindSpecific: kindSpecific,
            bodyExcerpt: "",
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    private static func encodeAttributes(_ attrs: [String: String]) -> String? {
        guard !attrs.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(attrs) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func encodeKindSpecific(_ ks: EntityKindSpecific) -> String? {
        guard let data = try? JSONEncoder().encode(ks) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - FileSystem fallback (actor-safe; = nonisolated statics)

    nonisolated static func loadEntitiesFromFileSystem(
        bookDirectory: URL
    ) throws -> [EntityDescriptor] {
        let indexURL = bookDirectory.appendingPathComponent("entities.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let str = try container.decode(String.self)
                if let d = try? Date(str, strategy: .iso8601.dateTimeSeparator(.standard)) {
                    return d
                }
                if let d = try? Date(str, strategy: .iso8601) {
                    return d
                }
                return Date()
            }
            return try decoder.decode([EntityDescriptor].self, from: data)
        } catch {
            return []
        }
    }

    nonisolated static func loadEntityBodyFromFileSystem(
        id: EntityID,
        bookDirectory: URL
    ) -> String? {
        let url = bookDirectory
            .appendingPathComponent("entities", isDirectory: true)
            .appendingPathComponent("\(id.rawValue).md")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    nonisolated static func saveEntityToFileSystem(
        entity: EntityDescriptor,
        bodyMarkdown: String,
        bookDirectory: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw EntityStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let entitiesDir = bookDirectory.appendingPathComponent("entities", isDirectory: true)
        try ensureEntitiesDirectoryExists(at: entitiesDir)

        let entityURL = entitiesDir.appendingPathComponent("\(entity.id.rawValue).md")
        if FileManager.default.fileExists(atPath: entityURL.path) {
            throw EntityStoreError.entityAlreadyExists(id: entity.id.rawValue)
        }

        try atomicWriteFileSystem(bodyMarkdown.data(using: .utf8) ?? Data(), to: entityURL)

        var current = (try? loadEntitiesFromFileSystem(bookDirectory: bookDirectory)) ?? []
        current.append(entity)
        try writeIndexToFileSystem(current, bookDirectory: bookDirectory)
    }

    nonisolated static func replaceEntityToFileSystem(
        entity: EntityDescriptor,
        bodyMarkdown: String,
        bookDirectory: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw EntityStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let entitiesDir = bookDirectory.appendingPathComponent("entities", isDirectory: true)
        try ensureEntitiesDirectoryExists(at: entitiesDir)

        let entityURL = entitiesDir.appendingPathComponent("\(entity.id.rawValue).md")
        guard FileManager.default.fileExists(atPath: entityURL.path) else {
            throw EntityStoreError.entityNotFound(id: entity.id.rawValue)
        }

        try atomicWriteFileSystem(bodyMarkdown.data(using: .utf8) ?? Data(), to: entityURL)

        var current = (try? loadEntitiesFromFileSystem(bookDirectory: bookDirectory)) ?? []
        guard let idx = current.firstIndex(where: { $0.id == entity.id }) else {
            throw EntityStoreError.entityNotFound(id: entity.id.rawValue)
        }
        current[idx] = entity
        try writeIndexToFileSystem(current, bookDirectory: bookDirectory)
    }

    nonisolated static func deleteEntityFromFileSystem(
        id: EntityID,
        bookDirectory: URL
    ) throws {
        let url = bookDirectory
            .appendingPathComponent("entities", isDirectory: true)
            .appendingPathComponent("\(id.rawValue).md")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var current = (try? loadEntitiesFromFileSystem(bookDirectory: bookDirectory)) ?? []
        current.removeAll { $0.id == id }
        try writeIndexToFileSystem(current, bookDirectory: bookDirectory)
    }

    nonisolated private static func writeIndexToFileSystem(
        _ entities: [EntityDescriptor],
        bookDirectory: URL
    ) throws {
        let indexURL = bookDirectory.appendingPathComponent("entities.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(.iso8601.dateTimeSeparator(.standard)))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entities)
        try atomicWriteFileSystem(data, to: indexURL)
    }

    nonisolated private static func ensureEntitiesDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    nonisolated private static func atomicWriteFileSystem(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
        let fd = open(url.path, O_RDONLY)
        if fd >= 0 {
            fsync(fd)
            close(fd)
        }
    }
}