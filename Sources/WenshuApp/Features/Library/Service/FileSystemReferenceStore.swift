// FileSystemReferenceStore.swift Reference-library storage layer, backed by SwiftData (=
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// <.ws>/reference-library/<layer>/<layer>.json
import Foundation
import SwiftData
import WenshuData
import os

// (protocol extracted to FileSystemReferenceStoreTypes.swift in A28; = see that file)
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// canonical implementation.
@MainActor
struct FileSystemReferenceStore: ReferenceStoring {
    let referenceLibraryRoot: URL

    // / SwiftData ModelContainer (= Sendable; = passed to the store
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / FileSystem fallback helpers directly.
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

    // / Resolve the ModelContext (= SwiftData's @MainActor contract).
    // / Returns nil when the store has no ModelContainer wired.
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
        // 2026-10-14: also write the body to its single-file truth location. See the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // SwiftData row).
        try? Self.writeReferenceFileToFileSystem(
            id: id,
            bodyMarkdown: bodyMarkdown,
            referenceLibraryRoot: referenceLibraryRoot
        )
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
        // 2026-10-14: also write the body to its single-file truth location. The doc-
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // edits become a versioned commit.
        try? Self.writeReferenceFileToFileSystem(
            id: id,
            bodyMarkdown: bodyMarkdown,
            referenceLibraryRoot: referenceLibraryRoot
        )
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
        // 2026-10-14: read the file-truth version first when present. The doc-truth-git
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // canonical source until first save writes the file).
        let fileURL = Self.referenceFileURL(
            id: id, referenceLibraryRoot: referenceLibraryRoot
        )
        os_log("[wenshu.reference] loadReferenceBody id=%{public}@ filePath=%{public}@",
               id.uuidString, fileURL.path)
        let fileBody = Self.readReferenceFileFromFileSystem(
            id: id, referenceLibraryRoot: referenceLibraryRoot
        )
        os_log("[wenshu.reference] loadReferenceBody fileBody=%{public}d chars",
               fileBody?.count ?? -1)
        if let fileBody { return fileBody }
        guard let context = modelContext else {
            // FileSystem path: search all layer directories for the .md file. Without
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // fallback helpers.
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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Reference].self, from: data)
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
        // (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The previous
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // sense).
        try ensureReferenceLibraryRootExists(at: referenceLibraryRoot)
        try ensureReferenceLayerDirectoryExists(
            at: referenceLibraryRoot.appendingPathComponent(reference.layer.directoryName, isDirectory: true)
        )

        let mdURL = referenceLibraryRoot
            .appendingPathComponent(reference.layer.directoryName)
            .appendingPathComponent("\(reference.id.uuidString).md")
        if FileManager.default.fileExists(atPath: mdURL.path) {
            // content-diff check (= the user's "完全一至" rule). If the existing .md is byte-
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // without crashing).
            let existingBody = (try? String(contentsOf: mdURL, encoding: .utf8)) ?? ""
            if existingBody == bodyMarkdown {
                // Content unchanged; = this is a re-import of the same source body; = the
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // previous import; = do nothing (= silent success).
                return
            }
            // Content differs; = the user explicitly authorized "edit" in the [archived-round]
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // `replaceReferenceToFileSystem` path).
            try atomicFileSystemWrite(
                bodyMarkdown.data(using: .utf8) ?? Data(),
                to: mdURL
            )
            var current = (try? loadReferencesFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot,
                layer: reference.layer
            )) ?? []
            if let idx = current.firstIndex(where: { $0.id == reference.id }) {
                current[idx] = reference
            } else {
                current.append(reference)
            }
            try writeIndexToFileSystem(current, at: referenceLibraryRoot, layer: reference.layer)
            return
        }
        // original write path (no .md exists at the destination = first time this
        // reference is imported).
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

    // MARK: - Single-file reference body (= doc-truth-git ticket)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / .scratch/2026-10-14-doc-truth-git/ticket.md.
    nonisolated static func readReferenceFileFromFileSystem(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> String? {
        let url = referenceFileURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // / Atomic write of the reference body to its
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / change in a future v1.10 ticket).
    nonisolated static func writeReferenceFileToFileSystem(
        id: UUID,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws {
        let url = referenceFileURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parent, withIntermediateDirectories: true
        )
        try atomicFileSystemWrite(
            bodyMarkdown.data(using: .utf8) ?? Data(),
            to: url
        )
    }

    // / Resolve the canonical single-file path for a
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / `<.ws>/references/<uuid>.md`.
    nonisolated static func referenceFileURL(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> URL {
        let referencesRoot = referenceLibraryRoot
            .deletingLastPathComponent()
            .appendingPathComponent("references", isDirectory: true)
        return referencesRoot.appendingPathComponent(
            "\(id.uuidString).md", isDirectory: false
        )
    }

    // / 2026-10-14: write-through helper used by the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / updated body.
    func replaceReferenceByID(id: UUID, bodyMarkdown: String) throws {
        guard let context = modelContext else { return }
        let idString = id.uuidString
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            // Row missing in SwiftData. The file write already happened (= the editor's
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // silently skip the write here.
            return
        }
        existing.body = bodyMarkdown
        existing.updatedAt = Date()
        try context.save()
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
        // Match the decoder's `.iso8601` strategy (= see `loadReferencesFromFileSystem`
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // save). The fix: keep encoder and decoder on the same strategy.
        encoder.dateEncodingStrategy = .iso8601
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
