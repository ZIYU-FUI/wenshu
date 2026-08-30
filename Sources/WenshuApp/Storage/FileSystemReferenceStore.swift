// FileSystemReferenceStore.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Reference-library storage layer (= ticket 006 of the FCP library
// replica spec).
//
// Storage path (= per spec v5):
//   <.ws>/reference-library/
//     library.json                <- ReferenceLibrary metadata
//     <layer>/<ref-uuid>.md       <- per-layer reference body (= LLM Wiki
//                                    4-layer: raw/, entities/,
//                                    abstracts/, indexes/)
//
// Library-level (= ReferenceLibrary is library-public; one instance
// per library; sibling to user-created shelves/). Reference struct
// (ticket 003) holds structured metadata; the .md body holds the
// free-form research material.
//
// Implementation pattern matches FileSystemWorldStore (ticket 004) +
// FileSystemCharacterStore (ticket 005), with the addition of a
// ReferenceLayer-aware subdirectory and a Library-level metadata file.

import Foundation

// MARK: - Protocol

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
    /// Wiki layers. Missing files = [], corrupt = []. v0.26 only
    /// surfaces the `layerRaw` + `layerEntities` entries (= per spec
    /// v5 isUserFacing flag); `layerabstracts` + `layerindexes` are
    /// hidden from the UI.
    func loadAllReferences() throws -> [Reference]

    /// Returns the references in a single layer (= used by the second-
    /// column card grid when user selects a layer tab).
    func loadReferences(layer: ReferenceLayer) throws -> [Reference]

    /// Persist the Reference (= creates the .md body in the layer's
    /// subdirectory + appends to the index). First-save-wins.
    func saveReference(_ reference: Reference, bodyMarkdown: String) throws

    /// Update an existing reference in place.
    func replaceReference(_ reference: Reference, bodyMarkdown: String) throws

    /// Remove a reference. Idempotent.
    func deleteReference(id: UUID) throws

    /// Read the raw .md body for a given reference. Returns nil if
    /// the .md file doesn't exist.
    func loadReferenceBody(id: UUID) -> String?

    /// Look up a single reference by id. Returns nil if not found.
    func referenceExists(id: UUID) -> Bool
}

// MARK: - ReferenceLibrary metadata

/// Metadata for the library's ReferenceLibrary (= the system's default
/// shelf per boss 2026-08-26 OOB). Stored at `<.ws>/reference-library/
/// library.json`.
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

// MARK: - FileSystem implementation

struct FileSystemReferenceStore: ReferenceStoring {
    let referenceLibraryRoot: URL

    private var metadataURL: URL {
        referenceLibraryRoot.appendingPathComponent("library.json")
    }

    /// Layer-specific subdirectory under reference-library/.
    private func layerDirectory(_ layer: ReferenceLayer) -> URL {
        referenceLibraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true)
    }

    // MARK: ReferenceStoring

    func loadMetadata() throws -> ReferenceLibraryMetadata {
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

    func saveMetadata(_ metadata: ReferenceLibraryMetadata) throws {
        try ensureReferenceLibraryRootExists()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try atomicWrite(data, to: metadataURL)
    }

    func loadAllReferences() throws -> [Reference] {
        var all: [Reference] = []
        for layer in ReferenceLayer.allCases {
            all.append(contentsOf: (try? loadReferences(layer: layer)) ?? [])
        }
        return all
    }

    func loadReferences(layer: ReferenceLayer) throws -> [Reference] {
        let indexURL = layerDirectory(layer).appendingPathComponent("\(layer.directoryName).json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            // v0.29 boss 2026-08-30 OOB: support ISO8601 string dates
            // (= how Reference is serialized in entities.json). Swift's
            // default decoder uses Double (= Unix timestamp) which fails
            // for ISO8601. Set .iso8601 strategy so we accept both.
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Reference].self, from: data)
        } catch {
            return []
        }
    }

    func saveReference(_ reference: Reference, bodyMarkdown: String) throws {
        try ensureReferenceLibraryRootExists()
        try ensureLayerDirectoryExists(layer: reference.layer)
        try ensureEntityCategoryDirectoryExists(category: reference.category, layer: reference.layer)

        let refURL = reference.onDiskPath(under: referenceLibraryRoot)
        if FileManager.default.fileExists(atPath: refURL.path) {
            throw ReferenceStoreError.referenceAlreadyExists(id: reference.id)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: refURL)

        var current = (try? loadReferences(layer: reference.layer)) ?? []
        current.append(reference)
        try writeIndex(current, for: reference.layer)
    }

    func replaceReference(_ reference: Reference, bodyMarkdown: String) throws {
        try ensureReferenceLibraryRootExists()
        try ensureLayerDirectoryExists(layer: reference.layer)
        try ensureEntityCategoryDirectoryExists(category: reference.category, layer: reference.layer)

        let refURL = reference.onDiskPath(under: referenceLibraryRoot)
        guard FileManager.default.fileExists(atPath: refURL.path) else {
            throw ReferenceStoreError.referenceNotFound(id: reference.id)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: refURL)

        var current = (try? loadReferences(layer: reference.layer)) ?? []
        guard let idx = current.firstIndex(where: { $0.id == reference.id }) else {
            throw ReferenceStoreError.referenceNotFound(id: reference.id)
        }
        current[idx] = reference
        try writeIndex(current, for: reference.layer)
    }

    func deleteReference(id: UUID) throws {
        // Find which layer contains the reference (= scan all 4
        // layer subdirs for the .md file matching the UUID).
        for layer in ReferenceLayer.allCases {
            let url = layerDirectory(layer)
                .appendingPathComponent("\(id.uuidString).md")
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                break
            }
        }
        // Remove from whichever layer's index contains the id.
        for layer in ReferenceLayer.allCases {
            var current = (try? loadReferences(layer: layer)) ?? []
            let before = current.count
            current.removeAll { $0.id == id }
            if current.count != before {
                try writeIndex(current, for: layer)
            }
        }
    }

    func loadReferenceBody(id: UUID) -> String? {
        for layer in ReferenceLayer.allCases {
            let url = layerDirectory(layer)
                .appendingPathComponent("\(id.uuidString).md")
            if FileManager.default.fileExists(atPath: url.path) {
                return try? String(contentsOf: url, encoding: .utf8)
            }
        }
        return nil
    }

    func referenceExists(id: UUID) -> Bool {
        for layer in ReferenceLayer.allCases {
            let url = layerDirectory(layer)
                .appendingPathComponent("\(id.uuidString).md")
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }
        }
        return false
    }

    // MARK: Private helpers

    private func ensureReferenceLibraryRootExists() throws {
        if !FileManager.default.fileExists(atPath: referenceLibraryRoot.path) {
            throw ReferenceStoreError.referenceLibraryRootMissing(path: referenceLibraryRoot.path)
        }
    }

    private func ensureLayerDirectoryExists(layer: ReferenceLayer) throws {
        let dir = layerDirectory(layer)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// v0.29 boss 2026-08-30 OOB: when saving an entity (= layer == .layerEntities)
    /// with a category, ensure the category subdirectory exists. The category
    /// folder is created LAZILY (= only when the first entity in that category
    /// is saved). This is the "增量" rule (= boss: '分类文件夹随着内容
    /// 逐渐增加, 而不是一下子铺满').
    ///
    /// When category is nil (= raw material OR unclassified entity), no
    /// category dir is created (= falls back to flat layer dir).
    private func ensureEntityCategoryDirectoryExists(
        category: EntityCategory?,
        layer: ReferenceLayer
    ) throws {
        guard layer == .layerEntities, let category = category else { return }
        let categoryDir = referenceLibraryRoot
            .appendingPathComponent("entities")
            .appendingPathComponent(category.directoryName)
        if !FileManager.default.fileExists(atPath: categoryDir.path) {
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
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

    private func writeIndex(_ references: [Reference], for layer: ReferenceLayer) throws {
        let indexURL = layerDirectory(layer).appendingPathComponent("\(layer.directoryName).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(references)
        try atomicWrite(data, to: indexURL)
    }
}