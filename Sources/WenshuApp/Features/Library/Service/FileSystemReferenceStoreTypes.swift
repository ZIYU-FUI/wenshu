//
//  FileSystemReferenceStoreTypes.swift
//
//  Pure types extracted from FileSystemReferenceStore.swift (= §6.6
//  god-class split: 3 supporting types = the `ReferenceStoring`
//  protocol + `ReferenceStoreError` enum + `ReferenceLibraryMetadata`
//  struct = 122 LOC of pure data moved out of the SwiftData
//  implementation file). The types are stateless (= the protocol
//  is `@MainActor`-isolated; = the error + metadata types are
//  Sendable) and have no dependency on the SwiftData-backed
//  implementation (= they describe the contract, not the storage).
//

import Foundation

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

