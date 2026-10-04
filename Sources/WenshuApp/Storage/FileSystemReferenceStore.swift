// FileSystemReferenceStore.swift · WenshuApp · v2.6
//
// Reference-library storage layer.
//
// Storage path:
//   <.ws>/reference-library/
//     library.json                <- ReferenceLibrary metadata
//     <layer>/<ref-uuid>.md       <- per-layer reference body (LLM Wiki
//                                    4-layer: raw/, entities/,
//                                    abstracts/, indexes/)
//
// Library-level (= ReferenceLibrary is library-public; one instance
// per library; sibling to user-created shelves/). Reference struct
// holds structured metadata; the .md body holds the free-form
// research material.

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
    /// Wiki layers. Missing files = [], corrupt = []. Only
    /// `layerRaw` + `layerEntities` are surfaced to the UI; the
    /// `layerabstracts` + `layerindexes` entries are hidden.
    func loadAllReferences() throws -> [Reference]

    /// Returns the references in a single layer (= used by the second-
    /// column card grid when user selects a layer tab).
    func loadReferences(layer: ReferenceLayer) throws -> [Reference]

    /// Persist the Reference (= creates the .md body in the layer's
    /// subdirectory + appends to the index). First-save-wins.
    func saveReference(_ reference: Reference, bodyMarkdown: String) throws

    /// Update an existing reference in place.
    func replaceReference(_ reference: Reference, bodyMarkdown: String) throws

    /// Upsert by title within a layer (= the recurring-research path:
    /// same topic research edits existing doc, not creates new).
    ///
    /// Behavior:
    ///   - Looks up an existing reference whose `title` (case-insensitive
    ///     trimmed) matches the given title in the given layer.
    ///   - If found: calls `replaceReference` (= updates the .md body
    ///     and bumps the index row's updatedAt).
    ///   - If not found: creates a new reference with the given title
    ///     (= a fresh UUID; = caller does not need to coordinate).
    ///
    /// Returns the resulting Reference (= new or updated).
    /// `category` is only consulted for `.layerEntities` (= the
    /// category subdirectory); = ignored for `.layerRaw` and the
    /// LLM-derived layers.
    ///
    /// Note: the protocol method intentionally has no default args
    /// (= Swift 6 forbids default values on protocol method
    /// declarations). Callers that want the convenience of
    /// defaults should call the FileSystemReferenceStore extension
    /// (= which forwards to this entry point with the default
    /// values filled in).
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

    /// Upsert-with-tags overload (= the facet-model path). When
    /// `tags` is non-nil, it replaces the existing tags (= the
    /// caller is expected to have done the merge already in the
    /// agent layer). When `tags` is nil, the existing tags are
    /// preserved (= the legacy upsert path). See
    /// `FileSystemReferenceStore.upsertReference` for the
    /// implementation.
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

    /// Read the raw .md body for a given reference. Returns nil if
    /// the .md file doesn't exist.
    func loadReferenceBody(id: UUID) -> String?

    /// Look up a single reference by id. Returns nil if not found.
    func referenceExists(id: UUID) -> Bool
}

// MARK: - ReferenceLibrary metadata

/// Metadata for the library's ReferenceLibrary (= the system's default
/// shelf). Stored at `<.ws>/reference-library/library.json`.
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
        // Idempotent migration from the pre-facet-model layout
        // (`entities/<category>/<uuid>.md`) to the flat layout
        // (`entities/<uuid>.md`). The entities.json index already
        // carries each entry's `category` as metadata, so the file
        // move does not lose classification data.
        if layer == .layerEntities {
            migrateLegacyEntitySubdirectoryLayoutIfNeeded()
        }
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            // Accept BOTH date encodings on read: writeIndex emits a
            // Unix-timestamp Double (= the JSONEncoder default), but
            // some external seed scripts write ISO8601 strings.
            // The default `.iso8601` strategy only accepts ISO8601
            // strings and would silently fail the save→load
            // roundtrip for files written by writeIndex. Try
            // ISO8601 first, fall back to a Unix Double.
            let decoder = JSONDecoder()
            let isoStyleWithFrac = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            let isoStyleNoFrac = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
            decoder.dateDecodingStrategy = .custom { dec in
                let container = try dec.singleValueContainer()
                if let double = try? container.decode(Double.self) {
                    return Date(timeIntervalSince1970: double)
                }
                let raw = try container.decode(String.self)
                if let d = try? Date(raw, strategy: isoStyleWithFrac) { return d }
                if let d = try? Date(raw, strategy: isoStyleNoFrac) { return d }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Date string '\(raw)' is neither ISO8601 nor numeric"
                )
            }
            let references = try decoder.decode([Reference].self, from: data)
            // Normalize nil category to .z so unclassified references
            // always show up in the sidebar under the catch-all
            // category. The on-disk file remains unchanged (= category
            // field still serialized as null); only the in-memory
            // representation gets .z.
            return references.map { ref in
                var normalized = ref
                if normalized.layer == .layerEntities && normalized.category == nil {
                    normalized.category = .z
                }
                // Backfill displayTitle for legacy / freshly-loaded
                // references (= set once on read; = persist back to
                // entities.json on next save via writeIndex).
                // The disambiguation suffix is NOT applied here (= the
                // siblingTitles set isn't yet known at this layer);
                // use the basic sanitization only.
                if normalized.displayTitle == nil {
                    normalized.ensureDisplayTitle()
                }
                return normalized
            }
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

        // No sibling-titles lookup needed here: reference-library
        // entities are unique by title (= the upsert path dedupes by
        // case-insensitive trimmed title; = two references sharing
        // a title are merged, not duplicated).
        var referenceToStore = reference
        if referenceToStore.displayTitle == nil {
            referenceToStore.ensureDisplayTitle()
        }

        var current = (try? loadReferences(layer: reference.layer)) ?? []
        current.append(referenceToStore)
        try writeIndex(current, for: reference.layer)

        // Auto-call the LLM Wiki derivation pipeline when a new raw
        // reference lands. RATIONALE: Task.detached keeps the
        // synchronous saveReference caller from blocking on the
        // derivation (= a large library may take seconds to walk
        // raw/ and write abstracts/).
        if reference.layer == .layerRaw {
            let storeSnapshot = self
            Task.detached(priority: .utility) {
                do {
                    _ = try await LLMWikiOps.runDerivation(store: storeSnapshot)
                } catch {
                    NSLog("[wenshu.llm_wiki.auto] derivation failed after save: %@", String(describing: error))
                }
            }
        }

        // Bootstrap the new reference into the Spotlight index so
        // Cmd-F surfaces references alongside chapters + bookmarks.
        let refID = reference.id.uuidString
        let refTitle = reference.title
        let refBody = reference.summary
        Task.detached(priority: .utility) {
            do {
                try await CSSearchableIndexSearch.shared.index(
                    docId: refID,
                    title: refTitle,
                    body: refBody
                )
            } catch {
                NSLog("[wenshu.spotlight.auto] index failed after reference save: %@", String(describing: error))
            }
        }
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

    /// Upsert by title within a layer (= (see OOB.md #2026-09-25) directive:
    /// "same topic research edits existing doc, not creates new").
    /// If an entry with the same case-insensitive trimmed title
    /// already exists in the layer, its body + updatedAt are refreshed;
    /// otherwise a new reference is created.
    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: ReferenceLayer,
        category: EntityCategory? = nil,
        source: String? = nil,
        url: String? = nil,
        entityType: EntityType = .other,
        summary: String = ""
    ) throws -> Reference {
        // Legacy entry point (= no `tags` param). The agent layer
        // calls the overload below when tags are part of the
        // payload; = here we preserve the existing tags.
        return try upsertReference(
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

    /// Upsert by title within a layer (= the recurring-research path).
    /// If an entry with the same case-insensitive trimmed title
    /// already exists in the layer, its body + summary + source +
    /// url + tags + updatedAt are refreshed in place; = otherwise a
    /// new reference is created.
    ///
    /// When `tags` is nil (= the legacy agent path), existing tags
    /// are preserved. When `tags` is non-nil (= the facet-model
    /// path), the supplied tag set replaces the existing one (= the
    /// agent layer is expected to have done a union-merge if it wants
    /// monotonic growth).
    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: ReferenceLayer,
        category: EntityCategory? = nil,
        tags: Set<String>? = nil,
        source: String? = nil,
        url: String? = nil,
        entityType: EntityType = .other,
        summary: String = ""
    ) throws -> Reference {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = trimmed.lowercased()

        // 1. Look up existing by case-insensitive trimmed title.
        let existing = (try? loadReferences(layer: layer)) ?? []
        if let match = existing.first(where: { ref in
            ref.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
        }) {
            // 2. Update existing; preserve id + createdAt; bump updatedAt.
            var updated = match
            updated.title = trimmed
            updated.summary = summary
            if let source { updated.source = source }
            if let url { updated.url = url }
            if layer == .layerEntities, let category { updated.category = category }
            if let tags { updated.tags = tags }
            updated.updatedAt = Date()
            try replaceReference(updated, bodyMarkdown: bodyMarkdown)
            return updated
        }

        // 3. Create new.
        let newRef = Reference(
            title: trimmed,
            source: source,
            url: url,
            layer: layer,
            category: layer == .layerEntities ? category : nil,
            tags: tags ?? [],
            entityType: entityType,
            summary: summary
        )
        try saveReference(newRef, bodyMarkdown: bodyMarkdown)
        // saveReference backfills displayTitle; re-read to surface
        // the post-backfill value to the caller.
        let reloaded = (try? loadReferences(layer: layer))?.first(where: { $0.id == newRef.id })
        return reloaded ?? newRef
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

    /// When saving an entity (= layer == .layerEntities) with a category,
    /// ensure the category subdirectory exists. The category folder is
    /// created lazily (= only when the first entity in that category
    /// is saved).
    ///
    /// When category is nil (= unclassified entity OR raw material
    /// that the user hasn't tagged), route to the `.z` catch-all
    /// category instead of falling back to the flat layer dir.
    /// Unclassified entities with nil category would otherwise be
    /// invisible in the sidebar but still counted (= hidden count).
    private func ensureEntityCategoryDirectoryExists(
        category: EntityCategory?,
        layer: ReferenceLayer
    ) throws {
        guard layer == .layerEntities else { return }
        // Nil category routes to .z so unclassified entities have a
        // visible sidebar bucket.
        let effectiveCategory = category ?? .z
        let categoryDir = referenceLibraryRoot
            .appendingPathComponent("entities")
            .appendingPathComponent(effectiveCategory.directoryName)
        if !FileManager.default.fileExists(atPath: categoryDir.path) {
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        }
    }

    /// Migrate from the pre-facet-model layout
    /// (`entities/<category>/<uuid>.md`) to the flat layout
    /// (`entities/<uuid>.md`). Move uses `replaceItemAt` so the
    /// operation is atomic on the same volume; = if any move fails,
    /// the legacy file remains in place (= safe to retry on next
    /// launch).
    ///
    /// After migration, the now-empty category subdirs are removed
    /// (= no orphan directories). Idempotent — when called twice,
    /// the second call finds no legacy files and returns immediately.
    private func migrateLegacyEntitySubdirectoryLayoutIfNeeded() {
        let entitiesDir = referenceLibraryRoot
            .appendingPathComponent("entities")
        guard FileManager.default.fileExists(atPath: entitiesDir.path) else {
            return
        }
        // Iterate the subdirs of entities/ (= each is a category
        // directory like `i/` or `k/`). If a subdir contains .md files,
        // move each .md to the flat entities/ dir.
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: entitiesDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        for entry in contents {
            // Only descend into directories (= skip entities.json, etc.).
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            // The flat-uuid .md files we already migrated would land
            // at entities/<uuid>.md (= top-level); = we don't recurse.
            // Only files inside a category subdir need moving.
            guard let subEntries = try? FileManager.default.contentsOfDirectory(
                at: entry,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for subEntry in subEntries where subEntry.pathExtension == "md" {
                let flatDestination = entitiesDir.appendingPathComponent(subEntry.lastPathComponent)
                // If the flat destination already exists (= the same
                // reference was migrated in a prior run, OR a new save
                // landed at the flat path), skip (= avoid clobber).
                if FileManager.default.fileExists(atPath: flatDestination.path) {
                    // Best-effort cleanup of the legacy copy.
                    try? FileManager.default.removeItem(at: subEntry)
                    continue
                }
                do {
                    try FileManager.default.moveItem(at: subEntry, to: flatDestination)
                } catch {
                    // Move failed (cross-device? permission?); = leave
                    // the legacy file in place so a future retry can
                    // complete the migration.
                    continue
                }
            }
            // After moving all .md files out of the category subdir,
            // best-effort remove the now-empty dir. If non-empty
            // (= contains other index/cache files), the remove fails
            // silently and the subdir is left for the user.
            if let remaining = try? FileManager.default.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil),
               remaining.isEmpty {
                try? FileManager.default.removeItem(at: entry)
            }
        }
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
        // Force the kernel to flush both the file's data and its parent
        // directory's directory-entry update to stable storage before
        // we return. Without this, a subsequent `fileExists` / open /
        // `Data(contentsOf:)` from a sibling call (= e.g. the immediate
        // `loadReferences(layer:)` right after `saveReference` calls
        // `writeIndex`) can race against the kernel's deferred-write
        // pipeline and see stale state (= file not yet visible, or
        // contents empty) on macOS. fsync on the file + the parent
        // directory's fd closes the race for callers that depend on
        // causal write-then-read ordering.
        let fd = open(url.path, O_RDONLY)
        if fd >= 0 {
            fsync(fd)
            close(fd)
        }
        let parentDir = url.deletingLastPathComponent().path
        let parentFd = open(parentDir, O_RDONLY)
        if parentFd >= 0 {
            fsync(parentFd)
            close(parentFd)
        }
    }

    private func writeIndex(_ references: [Reference], for layer: ReferenceLayer) throws {
        let indexURL = layerDirectory(layer).appendingPathComponent("\(layer.directoryName).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(references)
        try atomicWrite(data, to: indexURL)
    }
}