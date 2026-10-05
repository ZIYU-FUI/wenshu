//
//  EntityMigration.swift
//
//  One-shot legacy → v2.3 migration helper.
//
//  v2.0/v2.2 stored entities in two separate per-book folders:
//  - characters/<uuid>.md + characters/_index.json
//  - world/<uuid>.md + world/_index.json
//
//  v2.3 unifies these into a single per-book `entities/` folder
//  with a kind-discriminated `EntityDescriptor` schema. This
//  helper reads the legacy character + world folders once,
//  rewrites them into the unified `entities/` folder, and
//  leaves the original character/world files in place (= per
//  the wenshu-pollution-defense principle "never mutate user
//  state without explicit consent"; = the legacy folders stay
//  on disk but become orphaned; = users can manually delete
//  them after confirming the migration succeeded).
//
//  Idempotent: calling `migrateFromLegacyIfNeeded()` twice on
//  the same book directory is a no-op the second time (= the
//  flag file `entities/.v23-migrated` is written after the
//  first successful migration).

import Foundation

enum EntityMigrationError: Error, LocalizedError {
    case bookDirectoryMissing(path: String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .bookDirectoryMissing(let path):
            return "EntityMigration: book directory missing at \(path)."
        case .underlying(let msg):
            return "EntityMigration: underlying error — \(msg)."
        }
    }
}

/// Result of a single migration pass.
struct EntityMigrationResult: Sendable {
    let charactersImported: Int
    let worldEntriesImported: Int
    let totalEntitiesAfter: Int
    let wasAlreadyMigrated: Bool
}

enum EntityMigration {
    /// Sentinel file written to the `entities/` folder once the
    /// migration runs (= the second call becomes a no-op).
    private static let migratedFlagFileName = ".v23-migrated"

    /// Run the v2.0/v2.2 → v2.3 entity migration for one book.
    /// Idempotent (= safe to call repeatedly).
    @MainActor
    static func migrateFromLegacyIfNeeded(
        bookDirectory: URL
    ) throws -> EntityMigrationResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: bookDirectory.path) else {
            throw EntityMigrationError.bookDirectoryMissing(path: bookDirectory.path)
        }

        let entitiesDir = bookDirectory.appendingPathComponent("entities", isDirectory: true)
        try fm.createDirectory(at: entitiesDir, withIntermediateDirectories: true)

        let flagURL = entitiesDir.appendingPathComponent(migratedFlagFileName)
        let store = FileSystemEntityStore(bookDirectory: bookDirectory)
        let existing = (try? store.loadEntities()) ?? []

        if fm.fileExists(atPath: flagURL.path) {
            return EntityMigrationResult(
                charactersImported: 0,
                worldEntriesImported: 0,
                totalEntitiesAfter: existing.count,
                wasAlreadyMigrated: true
            )
        }

        // Lazy-import from the legacy character/world folders.
        let charactersDir = bookDirectory.appendingPathComponent("characters", isDirectory: true)
        let worldDir = bookDirectory.appendingPathComponent("world", isDirectory: true)

        let characterImport = importLegacyCharacters(
            charactersDir: charactersDir,
            existingEntities: existing
        )
        let worldImport = importLegacyWorldEntries(
            worldDir: worldDir,
            existingEntities: characterImport.entities
        )

        // Stamp the flag file (= idempotency token).
        try? Data("v2.3-migrated at \(Date().formatted(.iso8601))\n".utf8)
            .write(to: flagURL, options: .atomic)

        return EntityMigrationResult(
            charactersImported: characterImport.count,
            worldEntriesImported: worldImport.count,
            totalEntitiesAfter: worldImport.entities.count,
            wasAlreadyMigrated: false
        )
    }

    /// Private helper struct to thread the running entity list
    /// through the two legacy-import passes.
    private struct ImportOutcome: Sendable {
        var entities: [EntityDescriptor]
        var count: Int
    }

    @MainActor
    private static func importLegacyCharacters(
        charactersDir: URL,
        existingEntities: [EntityDescriptor]
    ) -> ImportOutcome {
        let fm = FileManager.default
        guard fm.fileExists(atPath: charactersDir.path) else {
            return ImportOutcome(entities: existingEntities, count: 0)
        }
        let indexURL = charactersDir.appendingPathComponent("_index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return ImportOutcome(entities: existingEntities, count: 0)
        }
        var entities = existingEntities
        var imported = 0
        for rawEntry in raw {
            guard let idStr = rawEntry["id"] as? String,
                  let name = rawEntry["name"] as? String,
                  let bookIdStr = rawEntry["bookId"] as? String
            else { continue }
            let summary = rawEntry["summary"] as? String ?? ""
            let role = rawEntry["role"] as? String ?? "other"
            let age = rawEntry["age"] as? Int
            let arc = rawEntry["arc"] as? String
            var attributes: [String: String] = [:]
            if let age { attributes["age"] = String(age) }
            if let arc { attributes["arc"] = arc }

            let id = EntityID(rawValue: idStr)
            let bookID = BookID(rawValue: bookIdStr)
            // Skip if an entity with this id already exists (= the
            // user already re-imported or created the entry under
            // the new schema; = the legacy row is silently skipped).
            if entities.contains(where: { $0.id == id }) { continue }

            let bodyFile = charactersDir.appendingPathComponent("\(idStr).md")
            let body = (try? String(contentsOf: bodyFile, encoding: .utf8)) ?? ""

            let now = Date()
            let descriptor = EntityDescriptor(
                id: id,
                bookID: bookID,
                kind: .person,
                name: name,
                aliases: [],
                tags: [role],
                description: summary,
                attributes: attributes,
                kindSpecific: .empty,
                bodyExcerpt: BodyExcerpt.make(from: body),
                createdAt: parseISODate(rawEntry["createdAt"] as? String) ?? now,
                updatedAt: parseISODate(rawEntry["updatedAt"] as? String) ?? now
            )
            let store = FileSystemEntityStore(bookDirectory: charactersDir.deletingLastPathComponent())
            try? store.saveEntity(descriptor, bodyMarkdown: body)
            entities.append(descriptor)
            imported += 1
        }
        return ImportOutcome(entities: entities, count: imported)
    }

    @MainActor
    private static func importLegacyWorldEntries(
        worldDir: URL,
        existingEntities: [EntityDescriptor]
    ) -> ImportOutcome {
        let fm = FileManager.default
        guard fm.fileExists(atPath: worldDir.path) else {
            return ImportOutcome(entities: existingEntities, count: 0)
        }
        let indexURL = worldDir.appendingPathComponent("_index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return ImportOutcome(entities: existingEntities, count: 0)
        }
        var entities = existingEntities
        var imported = 0
        for rawEntry in raw {
            guard let idStr = rawEntry["id"] as? String,
                  let name = rawEntry["name"] as? String,
                  let bookIdStr = rawEntry["bookId"] as? String
            else { continue }
            let summary = rawEntry["summary"] as? String ?? ""
            let type = rawEntry["type"] as? String ?? "other"

            let id = EntityID(rawValue: idStr)
            let bookID = BookID(rawValue: bookIdStr)
            if entities.contains(where: { $0.id == id }) { continue }

            let bodyFile = worldDir.appendingPathComponent("\(idStr).md")
            let body = (try? String(contentsOf: bodyFile, encoding: .utf8)) ?? ""

            let now = Date()
            let descriptor = EntityDescriptor(
                id: id,
                bookID: bookID,
                kind: .location,
                name: name,
                aliases: [],
                tags: [type],
                description: summary,
                attributes: [:],
                kindSpecific: .empty,
                bodyExcerpt: BodyExcerpt.make(from: body),
                createdAt: parseISODate(rawEntry["createdAt"] as? String) ?? now,
                updatedAt: parseISODate(rawEntry["updatedAt"] as? String) ?? now
            )
            let store = FileSystemEntityStore(bookDirectory: worldDir.deletingLastPathComponent())
            try? store.saveEntity(descriptor, bodyMarkdown: body)
            entities.append(descriptor)
            imported += 1
        }
        return ImportOutcome(entities: entities, count: imported)
    }

    /// Forgiving ISO 8601 parser (= returns nil for malformed
    /// input rather than crashing the migration).
    private static func parseISODate(_ s: String?) -> Date? {
        guard let s else { return nil }
        // Apple HIG canonical ISO-8601 parsing via
        // Date.ISO8601FormatStyle (= macOS 12+; = the Swift-native
        // ISO8601DateFormatter equivalent). The plain format
        // (no fractional seconds) is tried first; if that fails
        // (= the input carries sub-second precision), retry with
        // the fractional-seconds variant.
        if let d = try? Date(s, strategy: .iso8601) { return d }
        if let d = try? Date(s, strategy: .iso8601.dateTimeSeparator(.standard)) { return d }
        return nil
    }
}