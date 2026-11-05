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

    /// The search index the library publishes its documents to (= the
    /// same index the chapter store writes into; = a reference the
    /// user imported has to be findable by a word in it, or it cannot
    /// constrain the writing that follows).
    let searchIndex: CSSearchableIndexSearch

    /// The index writes this store has scheduled but not yet awaited
    /// (= a save stays synchronous; = `awaitSearchIndexWrites()` waits
    /// for the writes).
    let pendingSearchIndexWrites: PendingSearchIndexWrites

    /// Layer-specific subdirectory under reference-library/.
    private func layerDirectory(_ layer: ReferenceLayer) -> URL {
        referenceLibraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true)
    }

    init(
        referenceLibraryRoot: URL,
        modelContainer: ModelContainer? = nil,
        searchIndex: CSSearchableIndexSearch = .shared,
        pendingSearchIndexWrites: PendingSearchIndexWrites = PendingSearchIndexWrites()
    ) {
        self.referenceLibraryRoot = referenceLibraryRoot
        self.modelContainer = modelContainer
        self.searchIndex = searchIndex
        self.pendingSearchIndexWrites = pendingSearchIndexWrites
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
            scheduleSearchIndex(reference: reference, bodyMarkdown: bodyMarkdown)
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
            referenceLibraryRoot: referenceLibraryRoot,
            layer: reference.layer
        )
        scheduleSearchIndex(reference: reference, bodyMarkdown: bodyMarkdown)
    }

    func replaceReference(_ reference: Reference, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.replaceReferenceToFileSystem(
                reference: reference,
                bodyMarkdown: bodyMarkdown,
                referenceLibraryRoot: referenceLibraryRoot
            )
            scheduleSearchIndex(reference: reference, bodyMarkdown: bodyMarkdown)
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
            referenceLibraryRoot: referenceLibraryRoot,
            layer: reference.layer
        )
        scheduleSearchIndex(reference: reference, bodyMarkdown: bodyMarkdown)
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
            let upserted = try Self.upsertReferenceToFileSystem(
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
            scheduleSearchIndex(reference: upserted, bodyMarkdown: bodyMarkdown)
            return upserted
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
            let updated = Self.toReference(existing)
            scheduleSearchIndex(reference: updated, bodyMarkdown: bodyMarkdown)
            return updated
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
        let created = Self.toReference(row)
        scheduleSearchIndex(reference: created, bodyMarkdown: bodyMarkdown)
        return created
    }

    func deleteReference(id: UUID) throws {
        guard modelContainer != nil else {
            try Self.deleteReferenceFromFileSystem(
                id: id,
                referenceLibraryRoot: referenceLibraryRoot
            )
            Self.removeCoverOfDeletedReference(id)
            scheduleSearchIndexRemoval(id: id)
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
        Self.removeCoverOfDeletedReference(id)
        scheduleSearchIndexRemoval(id: id)
    }

    /// Remove the cover of a reference that has just been deleted.
    ///
    /// A cover is a CHILD of its document: the picture and the clip
    /// exist to depict this reference, so a reference that is gone
    /// leaves a cover that can never be shown again. The cover goes
    /// with it.
    ///
    /// The removal is TOLERANT on purpose. The document delete is the
    /// important operation; a cover that cannot be removed must not
    /// stop it. The reconciler collects the leftovers.
    ///
    /// This is the one chokepoint every reference delete passes
    /// through: the sidebar, the material zone's right-click delete,
    /// the agent's reference-library tool and the LLM-wiki layer
    /// deriver all land here. A cascade hooked only into the UI would
    /// leak a cover every time the wiki rebuilt a layer.
    ///
    /// The cascade reads the app's ACTIVE container, because that is
    /// where the cover rows live (= the store's own container can be
    /// the file-truth fallback, which holds no cover row).
    private static func removeCoverOfDeletedReference(_ id: UUID) {
        CoverCascade.live().removeCoverTolerantly(forReference: id)
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
            // FileSystem path: = the truth location first (= already
            // read above), = and the layer mirror as the fallback. = A
            // library that predates the truth location still has the
            // mirror, = and a reader that ignored it would say the
            // document has no body at all.
            for layer in ReferenceLayer.allCases {
                if let body = ReferenceBodyStore.read(
                    id: id,
                    layer: layer,
                    referenceLibraryRoot: referenceLibraryRoot
                ) {
                    return body
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
    // / 2026-10-14: write-through helper used by the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / updated body.
    func replaceReferenceByID(id: UUID, bodyMarkdown: String) throws {
        guard let context = modelContext else {
            // No SwiftData row (= the file-only library the app runs
            // on): the title comes from the index file, so the
            // document can still be re-published with its new body.
            if let reference = (try? loadAllReferences())?.first(where: { $0.id == id }) {
                scheduleSearchIndex(reference: reference, bodyMarkdown: bodyMarkdown)
            }
            return
        }
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
        // The body the index holds is the body the user sees, so the
        // new body is what gets published.
        scheduleSearchIndex(reference: Self.toReference(existing), bodyMarkdown: bodyMarkdown)
    }

}
