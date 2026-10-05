//
//  FileSystemReferenceStore.swift
//
//  Reference-library storage layer, backed by SwiftData (= the
//  WSReference @Model class declared in Persistence/WSReference.swift).
//
//  Per boss 2026-10-05 OOB ' 8' (= complete the FileSystem*Store →
//  SwiftData migration). This is commit 2 of #8.
//
//  Apple HIG canonical pattern: Reference's free-form body markdown
//  lives inline in the WSReference.body field (= replaces the per-
//  layer .md file on disk); the metadata fields (= title, source,
//  url, layer, category, tags, entityType) live as typed SwiftData
//  columns. SwiftData stores the entire reference in a single row.
//
//  Apple HIG dual-write pattern: when no ModelContainer is wired
//  (= legacy dev-tool path; = actor-based callers that can't reach
//  MainActor), fall back to the legacy FileSystem path
//  (= library.json metadata + per-layer .md body + per-layer JSON
//  index file). The protocol methods route to SwiftData when a
//  container is available; otherwise they route to the FileSystem
//  fallback (= preserved for backward compat with the existing test
//  suite + actor callers).
//
//  Storage path (= unchanged at the public API level):
//   <.ws>/reference-library/library.json
//   <.ws>/reference-library/<layer>/<uuid>.md
//   <.ws>/reference-library/<layer>/<layer>.json

import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol ReferenceStoring: Sendable {
    /// The reference-library root URL (= <.ws>/reference-library/).
    var referenceLibraryRoot: URL { get }

    /// Returns the parsed `library.json` (= the ReferenceLibrary metadata).
    /// Missing file = ReferenceLibrary not yet bootstrapped; returns
    /// default metadata (= caller can then call saveMetadata to create
    /// the file). Corrupt JSON = forgiving reset to defaults.
    func loadMetadata() throws -> ReferenceLibraryMetadata

    /// Persist the metadata (= updates library.json atomically).
    func saveMetadata(_ metadata: ReferenceLibraryMetadata) throws

    /// Returns the parsed index of all references, across all 4 LLM
    /// Wiki layers.
    func loadAllReferences() throws -> [Reference]

    /// Returns the references in a single layer.
    func loadReferences(layer: ReferenceLayer) throws -> [Reference]

    /// Persist the Reference (= creates the .md body in the layer's
    /// subdirectory + appends to the index). First-save-wins.
    func saveReference(_ reference: Reference, bodyMarkdown: String) throws

    /// Update an existing reference in place.
    func replaceReference(_ reference: Reference, bodyMarkdown: String) throws

    /// Upsert by title within a layer (= the recurring-research path).
    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: ReferenceLayer,
        category: EntityCategory?,
        source: String?,
        url: String?,
        entityType: EntityType,
        summary: String
    ) throws -> Reference

    /// Upsert-with-tags overload (= the facet-model path).
    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: ReferenceLayer,
        category: EntityCategory?,
        tags: Set<String>?,
        source: String?,
        url: String?,
        entityType: EntityType,
        summary: String
    ) throws -> Reference

    /// Remove a reference. Idempotent.
    func deleteReference(id: UUID) throws

    /// Read the raw .md body for a given reference.
    func loadReferenceBody(id: UUID) -> String?

    /// Look up a single reference by id.
    func referenceExists(id: UUID) -> Bool
}

// MARK: - Errors

enum ReferenceStoreError: Error, LocalizedError {
    case referenceAlreadyExists(id: UUID)
    case referenceNotFound(id: UUID)
    case referenceLibraryRootMissing(path: String)

    var errorDescription: String? {
        switch self {
        case .referenceAlreadyExists(let id):
            return "Reference \(id.uuidString) already exists on disk."
        case .referenceNotFound(let id):
            return "Reference \(id.uuidString) not found on disk."
        case .referenceLibraryRootMissing(let path):
            return "ReferenceLibrary root does not exist: \(path). Cannot save references."
        }
    }
}

// MARK: - ReferenceLibrary metadata

/// Metadata for the library's ReferenceLibrary (= the system's
/// default shelf). Stored at `<.ws>/reference-library/library.json`.
struct ReferenceLibraryMetadata: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let schemaVersion: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        createdAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
    }

    /// Apple HIG defaults (= empty / fresh ReferenceLibrary).
    static let empty = ReferenceLibraryMetadata(
        id: UUID(),
        schemaVersion: 1,
        createdAt: .distantPast
    )
}

// MARK: - SwiftData implementation
//
// NOTE on isolation: SwiftData's ModelContext is MainActor-isolated
// (= Apple HIG requires the context to be touched from the main
// thread). The store struct is therefore marked `@MainActor`; = the
// 5 actor-based callers (ReferenceLibraryTool, LLMWikiTool, LLMWikiOps,
// BookManagerTool, LibraryLifecycleHook) cannot instantiate it
// directly. They use the nonisolated static FileSystem fallback
// helpers (= loadMetadataFromFileSystem, etc.) which match the
// legacy FileSystem path exactly. The protocol surface that
// ReferenceLibraryTool uses (`any ReferenceStoring`) remains
// satisfied because the struct's static methods produce the same
// observable behavior as the legacy FileSystem path.
//
// When the production app wires a ModelContainer (= commit 3 of #8,
// the @MainActor container is held by AppState), the store's
// instance methods route to the SwiftData path. Until then, the
// FileSystem fallback is the canonical implementation.

@MainActor
struct FileSystemReferenceStore: ReferenceStoring {
    let referenceLibraryRoot: URL

    /// SwiftData ModelContainer (= Sendable; = passed to the store
    /// by the caller, who owns the singleton). When nil (= legacy
    /// dev-tool path), the store refuses to read or write via the
    /// SwiftData path; = the actor-based callers use the static
    /// FileSystem fallback helpers directly.
    let modelContainer: ModelContainer?

    /// Layer-specific subdirectory under reference-library/.
    private func layerDirectory(_ layer: ReferenceLayer) -> URL {
        referenceLibraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true)
    }

    init(
        referenceLibraryRoot: URL,
        modelContainer: ModelContainer? = nil
    ) {
        self.referenceLibraryRoot = referenceLibraryRoot
        self.modelContainer = modelContainer
    }

    /// Resolve the ModelContext (= SwiftData's @MainActor contract).
    /// Returns nil when the store has no ModelContainer wired.
    private var modelContext: ModelContext? {
        modelContainer?.mainContext
    }

    // MARK: ReferenceStoring

    func loadMetadata() throws -> ReferenceLibraryMetadata {
        guard let context = modelContext else {
            return try Self.loadMetadataFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot
            )
        }
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.layer == "__metadata__" }
        )
        guard let row = try? context.fetch(descriptor).first else {
            return .empty
        }
        return ReferenceLibraryMetadata(
            id: row.id,
            schemaVersion: 1,
            createdAt: row.createdAt
        )
    }

    func saveMetadata(_ metadata: ReferenceLibraryMetadata) throws {
        guard let context = modelContext else {
            try Self.saveMetadataToFileSystem(
                metadata: metadata,
                referenceLibraryRoot: referenceLibraryRoot
            )
            return
        }
        let id = metadata.id
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id && $0.layer == "__metadata__" }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.createdAt = metadata.createdAt
            existing.updatedAt = Date()
        } else {
            let row = WSReference(
                id: metadata.id,
                title: "ReferenceLibrary metadata",
                layer: "__metadata__",
                entityType: EntityType.other.rawValue
            )
            row.createdAt = metadata.createdAt
            context.insert(row)
        }
        try context.save()
    }

    func loadAllReferences() throws -> [Reference] {
        guard modelContainer != nil else {
            return try Self.loadAllReferencesFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot
            )
        }
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.layer != "__metadata__" }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map(Self.toReference)
    }

    func loadReferences(layer: ReferenceLayer) throws -> [Reference] {
        guard modelContainer != nil else {
            return try Self.loadReferencesFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot,
                layer: layer
            )
        }
        guard let context = modelContext else { return [] }
        let layerRaw = layer.rawValue
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.layer == layerRaw }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map(Self.toReference)
    }

    func saveReference(_ reference: Reference, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.saveReferenceToFileSystem(
                reference: reference,
                bodyMarkdown: bodyMarkdown,
                referenceLibraryRoot: referenceLibraryRoot
            )
            return
        }
        guard let context = modelContext else {
            throw ReferenceStoreError.referenceLibraryRootMissing(path: referenceLibraryRoot.path)
        }
        let id = reference.id
        let layerRaw = reference.layer.rawValue
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id && $0.layer == layerRaw }
        )
        if let _ = try? context.fetch(descriptor).first {
            throw ReferenceStoreError.referenceAlreadyExists(id: reference.id)
        }
        let row = Self.makeRow(reference: reference, bodyMarkdown: bodyMarkdown)
        context.insert(row)
        try context.save()
    }

    func replaceReference(_ reference: Reference, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.replaceReferenceToFileSystem(
                reference: reference,
                bodyMarkdown: bodyMarkdown,
                referenceLibraryRoot: referenceLibraryRoot
            )
            return
        }
        guard let context = modelContext else {
            throw ReferenceStoreError.referenceLibraryRootMissing(path: referenceLibraryRoot.path)
        }
        let id = reference.id
        let layerRaw = reference.layer.rawValue
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id && $0.layer == layerRaw }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            throw ReferenceStoreError.referenceNotFound(id: reference.id)
        }
        existing.title = reference.title
        existing.displayTitle = reference.displayTitle
        existing.source = reference.source
        existing.url = reference.url
        existing.category = reference.category?.rawValue
        existing.tags = Array(reference.tags).sorted()
        existing.entityType = reference.entityType.rawValue
        existing.summary = reference.summary
        existing.body = bodyMarkdown
        existing.characterRefIDs = reference.characterRefIds
        existing.worldRefIDs = reference.worldRefIds
        existing.bookRefIDs = reference.bookRefIds
        existing.updatedAt = Date()
        try context.save()
    }

    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: ReferenceLayer,
        category: EntityCategory?,
        source: String?,
        url: String?,
        entityType: EntityType,
        summary: String
    ) throws -> Reference {
        try upsertReference(
            title: title,
            bodyMarkdown: bodyMarkdown,
            layer: layer,
            category: category,
            tags: nil,
            source: source,
            url: url,
            entityType: entityType,
            summary: summary
        )
    }

    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: ReferenceLayer,
        category: EntityCategory?,
        tags: Set<String>?,
        source: String?,
        url: String?,
        entityType: EntityType,
        summary: String
    ) throws -> Reference {
        guard modelContainer != nil else {
            return try Self.upsertReferenceToFileSystem(
                title: title,
                bodyMarkdown: bodyMarkdown,
                referenceLibraryRoot: referenceLibraryRoot,
                layer: layer,
                category: category,
                tags: tags,
                source: source,
                url: url,
                entityType: entityType,
                summary: summary
            )
        }
        guard let context = modelContext else {
            throw ReferenceStoreError.referenceLibraryRootMissing(path: referenceLibraryRoot.path)
        }
        let layerRaw = layer.rawValue
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.layer == layerRaw && $0.title == normalizedTitle }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.body = bodyMarkdown
            existing.category = category?.rawValue
            existing.source = source
            existing.url = url
            existing.entityType = entityType.rawValue
            existing.summary = summary
            if let tags = tags {
                existing.tags = Array(tags).sorted()
            }
            existing.updatedAt = Date()
            try context.save()
            return Self.toReference(existing)
        }
        let newReference = Reference(
            id: UUID(),
            title: title,
            displayTitle: nil,
            source: source,
            url: url,
            layer: layer,
            category: category,
            tags: tags ?? [],
            entityType: entityType,
            summary: summary
        )
        let row = Self.makeRow(reference: newReference, bodyMarkdown: bodyMarkdown)
        context.insert(row)
        try context.save()
        return Self.toReference(row)
    }

    func deleteReference(id: UUID) throws {
        guard modelContainer != nil else {
            try Self.deleteReferenceFromFileSystem(
                id: id,
                referenceLibraryRoot: referenceLibraryRoot
            )
            return
        }
        guard let context = modelContext else {
            throw ReferenceStoreError.referenceNotFound(id: id)
        }
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            throw ReferenceStoreError.referenceNotFound(id: id)
        }
        context.delete(existing)
        try context.save()
    }

    func loadReferenceBody(id: UUID) -> String? {
        guard let context = modelContext else {
            // FileSystem path: search all layer directories for the .md
            // file. Without layer info (= only the id) we walk all 4
            // layers; = the actor-based callers should pass the layer
            // via the FileSystem fallback helpers.
            for layer in ReferenceLayer.allCases {
                let layerDir = layerDirectory(layer)
                let mdURL = layerDir.appendingPathComponent("\(id.uuidString).md")
                if FileManager.default.fileExists(atPath: mdURL.path) {
                    return try? String(contentsOf: mdURL, encoding: .utf8)
                }
            }
            return nil
        }
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor).first)?.body
    }

    func referenceExists(id: UUID) -> Bool {
        guard let context = modelContext else {
            for layer in ReferenceLayer.allCases {
                let layerDir = layerDirectory(layer)
                let mdURL = layerDir.appendingPathComponent("\(id.uuidString).md")
                if FileManager.default.fileExists(atPath: mdURL.path) {
                    return true
                }
            }
            return false
        }
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id }
        )
        return ((try? context.fetch(descriptor).first) != nil)
    }

    // MARK: - SwiftData bridging helpers

    private static func makeRow(reference: Reference, bodyMarkdown: String) -> WSReference {
        let row = WSReference(
            id: reference.id,
            title: reference.title,
            displayTitle: reference.displayTitle,
            source: reference.source,
            url: reference.url,
            layer: reference.layer.rawValue,
            category: reference.category?.rawValue,
            tags: Array(reference.tags).sorted(),
            entityType: reference.entityType.rawValue,
            summary: reference.summary,
            body: bodyMarkdown,
            characterRefIDs: reference.characterRefIds,
            worldRefIDs: reference.worldRefIds,
            bookRefIDs: reference.bookRefIds,
            trailingNoise: "",
            createdAt: reference.createdAt,
            updatedAt: reference.updatedAt
        )
        return row
    }

    private static func toReference(_ row: WSReference) -> Reference {
        Reference(
            id: row.id,
            title: row.title,
            displayTitle: row.displayTitle,
            source: row.source,
            url: row.url,
            layer: ReferenceLayer(rawValue: row.layer) ?? .layerRaw,
            category: row.category.flatMap { EntityCategory(rawValue: $0) },
            tags: Set(row.tags),
            entityType: EntityType(rawValue: row.entityType) ?? .other,
            summary: row.summary,
            characterRefIds: row.characterRefIDs,
            worldRefIds: row.worldRefIDs,
            bookRefIds: row.bookRefIDs,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    // MARK: - FileSystem fallback (actor-safe; = nonisolated statics)

    nonisolated static func loadMetadataFromFileSystem(
        referenceLibraryRoot: URL
    ) throws -> ReferenceLibraryMetadata {
        let metadataURL = referenceLibraryRoot.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            return try JSONDecoder().decode(ReferenceLibraryMetadata.self, from: data)
        } catch {
            return .empty
        }
    }

    nonisolated static func saveMetadataToFileSystem(
        metadata: ReferenceLibraryMetadata,
        referenceLibraryRoot: URL
    ) throws {
        try ensureReferenceLibraryRootExists(at: referenceLibraryRoot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try atomicFileSystemWrite(data, to: referenceLibraryRoot.appendingPathComponent("library.json"))
    }

    nonisolated static func loadAllReferencesFromFileSystem(
        referenceLibraryRoot: URL
    ) throws -> [Reference] {
        var all: [Reference] = []
        for layer in ReferenceLayer.allCases {
            all.append(contentsOf: (try? loadReferencesFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot,
                layer: layer
            )) ?? [])
        }
        return all
    }

    nonisolated static func loadReferencesFromFileSystem(
        referenceLibraryRoot: URL,
        layer: ReferenceLayer
    ) throws -> [Reference] {
        let indexURL = referenceLibraryRoot
            .appendingPathComponent(layer.directoryName)
            .appendingPathComponent("\(layer.directoryName).json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            return try JSONDecoder().decode([Reference].self, from: data)
        } catch {
            return []
        }
    }

    nonisolated static func loadReferenceBodyFromFileSystem(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> String? {
        let mdURL = referenceLibraryRoot
            .appendingPathComponent(layer.directoryName)
            .appendingPathComponent("\(id.uuidString).md")
        return try? String(contentsOf: mdURL, encoding: .utf8)
    }

    nonisolated static func saveReferenceToFileSystem(
        reference: Reference,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws {
        try ensureReferenceLibraryRootExists(at: referenceLibraryRoot)
        try ensureReferenceLayerDirectoryExists(
            at: referenceLibraryRoot.appendingPathComponent(reference.layer.directoryName, isDirectory: true)
        )

        let mdURL = referenceLibraryRoot
            .appendingPathComponent(reference.layer.directoryName)
            .appendingPathComponent("\(reference.id.uuidString).md")
        if FileManager.default.fileExists(atPath: mdURL.path) {
            throw ReferenceStoreError.referenceAlreadyExists(id: reference.id)
        }
        try atomicFileSystemWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: mdURL)

        var current = (try? loadReferencesFromFileSystem(
            referenceLibraryRoot: referenceLibraryRoot,
            layer: reference.layer
        )) ?? []
        current.append(reference)
        try writeIndexToFileSystem(current, at: referenceLibraryRoot, layer: reference.layer)
    }

    nonisolated static func replaceReferenceToFileSystem(
        reference: Reference,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws {
        try ensureReferenceLibraryRootExists(at: referenceLibraryRoot)
        let mdURL = referenceLibraryRoot
            .appendingPathComponent(reference.layer.directoryName)
            .appendingPathComponent("\(reference.id.uuidString).md")
        guard FileManager.default.fileExists(atPath: mdURL.path) else {
            throw ReferenceStoreError.referenceNotFound(id: reference.id)
        }
        try atomicFileSystemWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: mdURL)

        var current = (try? loadReferencesFromFileSystem(
            referenceLibraryRoot: referenceLibraryRoot,
            layer: reference.layer
        )) ?? []
        guard let idx = current.firstIndex(where: { $0.id == reference.id }) else {
            throw ReferenceStoreError.referenceNotFound(id: reference.id)
        }
        current[idx] = reference
        try writeIndexToFileSystem(current, at: referenceLibraryRoot, layer: reference.layer)
    }

    nonisolated static func upsertReferenceToFileSystem(
        title: String,
        bodyMarkdown: String,
        referenceLibraryRoot: URL,
        layer: ReferenceLayer,
        category: EntityCategory?,
        tags: Set<String>?,
        source: String?,
        url: String?,
        entityType: EntityType,
        summary: String
    ) throws -> Reference {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var existing = (try? loadReferencesFromFileSystem(
            referenceLibraryRoot: referenceLibraryRoot,
            layer: layer
        )) ?? []
        if let idx = existing.firstIndex(where: {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
        }) {
            // Update existing.
            var updated = existing[idx]
            updated.title = title
            updated.source = source
            updated.url = url
            updated.entityType = entityType
            updated.summary = summary
            updated.category = category
            if let tags = tags { updated.tags = tags }
            updated.updatedAt = Date()
            existing[idx] = updated
            try ensureReferenceLayerDirectoryExists(
                at: referenceLibraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true)
            )
            let mdURL = referenceLibraryRoot
                .appendingPathComponent(layer.directoryName)
                .appendingPathComponent("\(updated.id.uuidString).md")
            try atomicFileSystemWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: mdURL)
            try writeIndexToFileSystem(existing, at: referenceLibraryRoot, layer: layer)
            return updated
        } else {
            // Create new.
            let reference = Reference(
                id: UUID(),
                title: title,
                displayTitle: nil,
                source: source,
                url: url,
                layer: layer,
                category: category,
                tags: tags ?? [],
                entityType: entityType,
                summary: summary
            )
            try saveReferenceToFileSystem(
                reference: reference,
                bodyMarkdown: bodyMarkdown,
                referenceLibraryRoot: referenceLibraryRoot
            )
            return reference
        }
    }

    nonisolated static func deleteReferenceFromFileSystem(
        id: UUID,
        referenceLibraryRoot: URL
    ) throws {
        for layer in ReferenceLayer.allCases {
            let mdURL = referenceLibraryRoot
                .appendingPathComponent(layer.directoryName)
                .appendingPathComponent("\(id.uuidString).md")
            if FileManager.default.fileExists(atPath: mdURL.path) {
                try FileManager.default.removeItem(at: mdURL)
            }
            var current = (try? loadReferencesFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot,
                layer: layer
            )) ?? []
            let before = current.count
            current.removeAll { $0.id == id }
            if current.count != before {
                try writeIndexToFileSystem(current, at: referenceLibraryRoot, layer: layer)
            }
        }
    }

    nonisolated private static func writeIndexToFileSystem(
        _ references: [Reference],
        at referenceLibraryRoot: URL,
        layer: ReferenceLayer
    ) throws {
        let indexURL = referenceLibraryRoot
            .appendingPathComponent(layer.directoryName)
            .appendingPathComponent("\(layer.directoryName).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(references)
        try atomicFileSystemWrite(data, to: indexURL)
    }

    nonisolated private static func ensureReferenceLibraryRootExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    nonisolated private static func ensureReferenceLayerDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    nonisolated private static func atomicFileSystemWrite(_ data: Data, to url: URL) throws {
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
