//
//  FileSystemEntityStore.swift
//
//  Per-book entity storage layer (= replaces
//  FileSystemCharacterStore + FileSystemWorldStore from v2.0).
//
//  Storage path:
//    <.ws>/shelves/<shelf-uuid>/books/<book-uuid>/
//      entities/
//        <entity-uuid>.md      ← body markdown per entity
//        <entity-uuid>.md      ← one file per entity
//      entities.json           ← index = [EntityDescriptor]
//
//  Pattern follows FileSystemCharacterStore (= atomic writes via
//  tmp + replaceItemAt; Codable JSON index; id-based filesystem
//  identity).
//
//  What differs from v2.0:
//  - One folder (= entities/) replaces characters/ + world/.
//  - One index format (= [EntityDescriptor]) replaces the
//    per-source-type [Character] + [WorldEntry] indexes.
//  - Kind discriminator on the descriptor (= .person /
//    .location / ...) replaces the role / type string field.
//

import Foundation

// MARK: - Protocol

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

// MARK: - FileSystem implementation

struct FileSystemEntityStore: EntityStoring {
    let bookDirectory: URL

    private var entitiesDirectory: URL {
        bookDirectory.appendingPathComponent("entities", isDirectory: true)
    }

    private var indexURL: URL {
        bookDirectory.appendingPathComponent("entities.json")
    }

    init(bookDirectory: URL) {
        self.bookDirectory = bookDirectory
    }

    // MARK: EntityStoring

    func loadEntities() throws -> [EntityDescriptor] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let str = try container.decode(String.self)
                // Try the fractional-seconds form first; fall back to
                // plain iso8601 (= forgiving for old data written
                // before the v2.3 schema). Apple HIG canonical
                // ISO-8601 parsing via Date.ISO8601FormatStyle
                // (= macOS 12+; = the Swift-native ISO8601DateFormatter
                // equivalent).
                if let d = try? Date(str, strategy: .iso8601.dateTimeSeparator(.standard)) {
                    return d
                }
                if let d = try? Date(str, strategy: .iso8601) {
                    return d
                }
                // Last-resort fallback (= shouldn't happen but avoids
                // throwing a decoder error that the whole load would
                // recover from by returning []).
                return Date()
            }
            return try decoder.decode([EntityDescriptor].self, from: data)
        } catch {
            // Corrupt JSON = forgiving reset (= per v2.0 pattern;
            // = same behavior as FileSystemCharacterStore).
            return []
        }
    }

    func saveEntity(_ entity: EntityDescriptor, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw EntityStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureEntitiesDirectoryExists()

        let entityURL = entitiesDirectory.appendingPathComponent("\(entity.id.rawValue).md")
        if FileManager.default.fileExists(atPath: entityURL.path) {
            throw EntityStoreError.entityAlreadyExists(id: entity.id.rawValue)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: entityURL)

        var current = (try? loadEntities()) ?? []
        current.append(entity)
        try writeIndex(current)
    }

    func replaceEntity(_ entity: EntityDescriptor, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw EntityStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureEntitiesDirectoryExists()

        let entityURL = entitiesDirectory.appendingPathComponent("\(entity.id.rawValue).md")
        guard FileManager.default.fileExists(atPath: entityURL.path) else {
            throw EntityStoreError.entityNotFound(id: entity.id.rawValue)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: entityURL)

        var current = (try? loadEntities()) ?? []
        guard let idx = current.firstIndex(where: { $0.id == entity.id }) else {
            throw EntityStoreError.entityNotFound(id: entity.id.rawValue)
        }
        current[idx] = entity
        try writeIndex(current)
    }

    func deleteEntity(id: EntityID) throws {
        let url = entitiesDirectory.appendingPathComponent("\(id.rawValue).md")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var current = (try? loadEntities()) ?? []
        current.removeAll { $0.id == id }
        try writeIndex(current)
    }

    func loadEntityBody(id: EntityID) -> String? {
        let url = entitiesDirectory.appendingPathComponent("\(id.rawValue).md")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func entityExists(id: EntityID) -> Bool {
        let url = entitiesDirectory.appendingPathComponent("\(id.rawValue).md")
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: Private helpers

    private func ensureEntitiesDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: entitiesDirectory.path) {
            try FileManager.default.createDirectory(
                at: entitiesDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
    }

    private func writeIndex(_ entities: [EntityDescriptor]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(f.string(from: date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entities)
        try atomicWrite(data, to: indexURL)
    }
}