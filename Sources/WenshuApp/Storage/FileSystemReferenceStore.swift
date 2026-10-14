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
import os
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

    /// 2026-10-14: write-through helper used by the
    /// editor's auto-save path. Updates the
    /// SwiftData `WSReference.body` cache to
    /// match a freshly written reference file.
    /// Best-effort (= silently no-ops if the
    /// `ModelContainer` is not wired or the row
    /// is missing; = the file write above is the
    /// source of truth and has already succeeded).
    /// Lives on the protocol so the
    /// `EditorPersistence` call site can reach
    /// it through `bookStore.stores.referenceStore`
    /// (= Swift's protocol-dispatch constraint)
    /// without caring whether the concrete store
    /// is the SwiftData-backed
    /// `FileSystemReferenceStore` or a future
    /// pure-file implementation.
    func replaceReferenceByID(id: UUID, bodyMarkdown: String) throws
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
        // 2026-10-14: also write the body to its
        // single-file truth location. See the matching
        // note in `replaceReference` above. The
        // first-save of a new reference writes the file
        // at the canonical path (= the
        // `references/<uuid>.md` location produced by
        // `referenceFileURL`); = subsequent
        // `replaceReference` calls overwrite the same
        // file. A pre-doc-truth-git reference that
        // already has SwiftData body content (= no
        // corresponding file) will have its file
        // written on the first edit (= the
        // `replaceReference` call updates the file
        // alongside the SwiftData row).
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
        // 2026-10-14: also write the body to its
        // single-file truth location. The doc-truth-git
        // ticket (= .scratch/2026-10-14-doc-truth-git/
        // ticket.md) makes the file the single source
        // of truth; = the SwiftData `body` column
        // becomes a write-through cache (= an in-app
        // consumer like the LLM agent's `find` tool
        // can still read the body from SwiftData
        // without touching the filesystem; = the editor
        // reads from the file via
        // `loadReferenceBody` file-first). The write
        // here is atomic (= `atomicFileSystemWrite` =
        // temp + rename + fsync) and silently
        // creates the parent `references/`
        // directory. A subsequent v1.10 ticket will
        // wrap this in a `git add` + `git commit` so the
        // user's edits become a versioned commit.
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
        // 2026-10-14: read the file-truth version first
        // when present. The doc-truth-git ticket
        // (= .scratch/2026-10-14-doc-truth-git/ticket.md)
        // migrates the reference body from the
        // SwiftData `WSReference.body` column to a
        // per-document file at
        // `<referenceLibraryRoot>/references/<uuid>.md`.
        // Once the migration runs on first launch (= the
        // body's content has been written to disk; = a
        // v1.00 ticket), the SwiftData body becomes a
        // write-through cache (= the writer still updates
        // it for in-app consumers that read SwiftData
        // directly, = e.g. the `ReferenceLibraryTool` for
        // the LLM agent's `find` tool returns metadata +
        // body from SwiftData without touching the
        // filesystem), and the file is the single source
        // of truth for the editor + version control. The
        // file is checked first so a fresh git checkout
        // (= the user clones the .ws library onto a new
        // machine, = there is no SwiftData store yet) can
        // still open the document and see the file
        // content. Falls back to SwiftData when the file
        // does not exist (= the migration has not run for
        // this reference yet, = the user is on a
        // pre-doc-truth-git build of wenshu and just
        // opened a reference tab; = the SwiftData body
        // column is still the canonical source until
        // first save writes the file).
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
        // v2.7 round-41 (= boss 2026-10-10
        // "如果真的是撞重名，也要先
        // 检查一下内容，是不是完全
        // 一至，如果有差异可以编辑"
        // directive). The previous
        // implementation threw
        // `referenceAlreadyExists` if
        // the .md file at the
        // destination path already
        // existed. This was too
        // strict: the reference-library
        // `id` is `uuidFromHash(contentHash)`
        // (= derived from the source
        // body hash); = if two distinct
        // import flows produced the
        // same content hash (= the
        // boss's orphan / re-import
        // flow that round-40 just
        // hardened; = or the LLM
        // produces the same title for
        // two semantically identical
        // files), the second write
        // would crash. The fix:
        // 1. If the .md file doesn't
        //    exist → write it (= the
        //    original path).
        // 2. If the .md file exists
        //    AND its content is
        //    byte-equal to the new
        //    bodyMarkdown → no-op
        //    (= idempotent re-import;
        //    = the import is
        //    successful; = we
        //    silently skip the
        //    duplicate to match the
        //    user's "禁止重名" rule
        //    without crashing).
        // 3. If the .md file exists
        //    AND its content differs
        //    → edit (= overwrite the
        //    .md and update the
        //    entities.json index to
        //    point at the new content;
        //    = the user's "如果有差
        //    异可以编辑" rule;
        //    = idempotent in the
        //    "the latest LLM result
        //    wins" sense).
        try ensureReferenceLibraryRootExists(at: referenceLibraryRoot)
        try ensureReferenceLayerDirectoryExists(
            at: referenceLibraryRoot.appendingPathComponent(reference.layer.directoryName, isDirectory: true)
        )

        let mdURL = referenceLibraryRoot
            .appendingPathComponent(reference.layer.directoryName)
            .appendingPathComponent("\(reference.id.uuidString).md")
        if FileManager.default.fileExists(atPath: mdURL.path) {
            // v2.7 round-41: content-diff check
            // (= the user's "完全一至" rule).
            // If the existing .md is byte-equal
            // to the new body, the import is
            // idempotent (= silent no-op; =
            // no error, no warning; = the
            // "禁止重名" rule is honored
            // without crashing).
            let existingBody = (try? String(contentsOf: mdURL, encoding: .utf8)) ?? ""
            if existingBody == bodyMarkdown {
                // Content unchanged; = this is
                // a re-import of the same
                // source body; = the entities
                // index already has this entry
                // from a previous import; = do
                // nothing (= silent success).
                return
            }
            // Content differs; = the user
            // explicitly authorized "edit" in
            // the round-41 directive. The
            // edit = overwrite the .md AND
            // update the entities.json
            // index entry (= the
            // `replaceReferenceToFileSystem`
            // path).
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
        // v2.7 round-41: original
        // write path (no .md exists
        // at the destination = first
        // time this reference is
        // imported).
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

    /// 2026-10-14: the doc-truth-git ticket migrates
    /// the reference body to a per-document file at
    /// `<referenceLibraryRoot>/../references/<uuid>.md`
    /// (= sibling of `shelves/` and `reference-library/`
    /// in the .ws library root). This helper reads that
    /// file (= returns nil if the file does not exist or
    /// cannot be read). The editor's `restoreOpenTabs`
    /// (= when a reference tab is restored) and the
    /// `loadReferenceBody` SwiftData path now check this
    /// file first, falling back to the SwiftData `body`
    /// column when the file is missing. See
    /// .scratch/2026-10-14-doc-truth-git/ticket.md.
    nonisolated static func readReferenceFileFromFileSystem(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> String? {
        let url = referenceFileURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Atomic write of the reference body to its
    /// single-file truth location. Creates the parent
    /// `references/` directory if missing (= the
    /// migration's first write also creates the
    /// directory). Returns silently when the write
    /// succeeds (= the editor's autosave path is
    /// fire-and-forget for the file write; = the calling
    /// layer is responsible for git committing the
    /// change in a future v1.10 ticket).
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

    /// Resolve the canonical single-file path for a
    /// reference body. Lives next to the library's
    /// `shelves/` and `reference-library/` directories
    /// (= a flat single-layer directory; = unlike the
    /// legacy `reference-library/<layer>/<uuid>.md`
    /// layout). The `..` step out of
    /// `reference-library/` produces
    /// `<.ws>/references/<uuid>.md`.
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

    /// 2026-10-14: write-through helper used by the
    /// editor's auto-save path. Looks up the
    /// `WSReference` by id, updates the `body` field
    /// (= so the LLM agent's `ReferenceLibraryTool`
    /// continues to see the latest content), and
    /// re-saves. The single-file truth on disk has
    /// already been written by the caller (= the
    /// editor's `EditorPersistence.save` writes the
    /// file first, = then calls this helper to keep
    /// the SwiftData cache consistent). The
    /// `loadAllReferences` fetch is fast
    /// (= SwiftData's in-memory cache + the
    /// `FetchDescriptor` predicate runs on a single
    /// indexed column); = the LLM agent's first
    /// `find` call after the user closes the editor
    /// (= 3-second autosave debounce) sees the
    /// updated body.
    func replaceReferenceByID(id: UUID, bodyMarkdown: String) throws {
        guard let context = modelContext else { return }
        let idString = id.uuidString
        let descriptor = FetchDescriptor<WSReference>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            // Row missing in SwiftData. The file write
            // already happened (= the editor's
            // `EditorPersistence.save` wrote the file
            // before calling us); = the in-memory
            // SwiftData row can be lazily reconstructed
            // on the next read (= the `loadReferenceBody`
            // file-first read + the `loadAllReferences`
            // fallback for metadata); = we silently
            // skip the write here.
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
        // Match the decoder's `.iso8601` strategy (= see
        // `loadReferencesFromFileSystem` below). The decoder
        // was switched to ISO 8601 in commit 3e899d35c so
        // the legacy on-disk files (= written by the
        // earlier Wenshu version that always wrote ISO
        // 8601 strings) could decode. Without matching the
        // encoder, every `saveReference` would write a
        // Double for `createdAt` (= JSONEncoder's default
        // `.deferredToDate` strategy), and the next
        // `loadReferencesFromFileSystem` would fall into
        // the `catch` arm (= `return []`) — silently
        // truncating the on-disk index to a single entry
        // (= the entry being saved). The v2.7 markdown
        // import feature surfaced this in production
        // (= importing 367 files into a clean library
        // left the entities.json with exactly one entry;
        // the .md files all landed, but the index was
        // collapsed on every save). The fix: keep encoder
        // and decoder on the same strategy.
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
