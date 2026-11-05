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
    ///
    /// **⇒ This one is FORGIVING**: = a layer whose index file cannot
    /// be read is reported as an empty layer. = **⇒ Do not use it to
    /// decide whether the library HOLDS a document** = = it cannot
    /// tell "the library does not hold it" from "the library could
    /// not be read", = and the librarian's report is exactly that
    /// question.
    func loadAllReferences() throws -> [Reference]

    /// Returns the parsed index of all references, = and says so when
    /// the corpus cannot be read.
    ///
    /// **⇒ The difference from `loadAllReferences()` is the whole
    /// point.** = A layer whose index file is MISSING is empty (= the
    /// library has not been bootstrapped there, = which is a fact
    /// about the corpus). = A layer whose index file EXISTS and
    /// cannot be decoded is UNREADABLE (= which is a fact about the
    /// READER, = and a report that says "the library does not hold
    /// this document" would be a fact the reader never got).
    ///
    /// **⇒ So this throws**, = and the caller can say "the library
    /// could not be read" instead of "the document is not there".
    func loadAllReferencesReportingFailure() throws -> [Reference]

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

// MARK: - The strict read's default

extension ReferenceStoring {
    /// **⇒ The default answer is "I cannot say".**
    ///
    /// **⇒ NOT the forgiving read.** = A store that delegates to
    /// `loadAllReferences()` here inherits that method's habit of
    /// turning a read failure into an empty layer, = and a caller
    /// asking "does the library hold this document" then hears "no"
    /// for a document it never looked for. = **⇒ So the default
    /// THROWS**, = and a store has to say which it is:
    ///
    /// - a store that CAN tell (= the filesystem one) = overrides this
    ///   and reports a real read failure;
    /// - a store that CANNOT tell (= one holding its documents in
    ///   memory) = overrides this and returns its documents, = because
    ///   for it "the corpus is empty" and "the corpus is unreadable"
    ///   are the same true statement.
    ///
    /// **⇒ The default is the one that cannot lie**, = and it is the
    /// default on purpose: = a store added later must decide, = rather
    /// than inherit a behaviour nobody chose.
    func loadAllReferencesReportingFailure() throws -> [Reference] {
        throw ReferenceStoreError.storeCannotReportReadFailure
    }
}

// MARK: - Errors

enum ReferenceStoreError: Error, LocalizedError {
    case referenceAlreadyExists(id: UUID)
    case referenceNotFound(id: UUID)
    case referenceLibraryRootMissing(path: String)

    /// A layer's index file is there, = and it cannot be read.
    ///
    /// **⇒ This is a different fact from "the layer is empty".** = An
    /// empty layer is a fact about the corpus; = this is a fact about
    /// the reader. = A report that cannot tell them apart says "the
    /// library does not hold this document" about a document it never
    /// managed to look for.
    case referenceIndexUnreadable(layer: ReferenceLayer, path: String, reason: String)

    /// This store cannot tell "the corpus is empty" from "the corpus
    /// could not be read".
    case storeCannotReportReadFailure

    var errorDescription: String? {
        switch self {
        case let .referenceAlreadyExists(id):
            return "Reference \(id.uuidString) already exists on disk."
        case let .referenceNotFound(id):
            return "Reference \(id.uuidString) not found on disk."
        case let .referenceLibraryRootMissing(path):
            return "ReferenceLibrary root does not exist: \(path). Cannot save references."
        case let .referenceIndexUnreadable(layer, path, reason):
            return "The \(layer.displayName) index at \(path) could not be read: \(reason)"
        case .storeCannotReportReadFailure:
            return "This library store cannot report whether the corpus could be read."
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
