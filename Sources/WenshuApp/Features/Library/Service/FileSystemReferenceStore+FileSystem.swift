//
//  FileSystemReferenceStore+FileSystem.swift
//
//  The reference library's actor-safe FileSystem fallback: the statics
//  that read and write the library's index files without an actor.
//
//  Why: the fallback is the store's own concern (= the store decides
//  when to fall back), but it is a whole cluster of its own, and the
//  store's file was over the file-size cap.
//
import Foundation

extension FileSystemReferenceStore {
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
        try AtomicFileWrite.write(data, to: referenceLibraryRoot.appendingPathComponent("library.json"))
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
            // The index has been written by two encoders over the app's
            // life: the ISO8601 writer and the default JSONEncoder (which
            // writes a Date as a Double). `createdAt`/`updatedAt` are
            // non-optional Dates, so ONE wrong date strategy makes the
            // whole decode throw -- and the catch below turned that into
            // an empty library, which reads as "the reference metadata was
            // lost". Try ISO8601 first, then the default strategy.
            let iso = JSONDecoder()
            iso.dateDecodingStrategy = .iso8601
            if let references = try? iso.decode([Reference].self, from: data) {
                return references
            }
            let legacy = JSONDecoder()
            return (try? legacy.decode([Reference].self, from: data)) ?? []
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
            try AtomicFileWrite.write(
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
        try AtomicFileWrite.write(bodyMarkdown.data(using: .utf8) ?? Data(), to: mdURL)

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
        try AtomicFileWrite.write(bodyMarkdown.data(using: .utf8) ?? Data(), to: mdURL)

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

    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / .scratch/2026-10-14-doc-truth-git/ticket.md.
    nonisolated static func readReferenceFileFromFileSystem(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> String? {
        let url = referenceFileURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// / Atomic write of the reference body to its
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / change in a future v1.10 ticket).
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
        try AtomicFileWrite.write(
            bodyMarkdown.data(using: .utf8) ?? Data(),
            to: url
        )
    }

    /// / Resolve the canonical single-file path for a
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / `<.ws>/references/<uuid>.md`.
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
        var existing = (try? loadReferencesFromFileSystem(
            referenceLibraryRoot: referenceLibraryRoot,
            layer: layer
        )) ?? []
        if let idx = existing.firstIndex(where: {
            Reference.titlesMatch($0.title, title)
        }) {
            // Update existing.
            var updated = existing[idx]
            updated.title = title
            updated.source = source
            updated.url = url
            updated.entityType = entityType
            updated.summary = summary
            updated.category = category
            if let tags = tags {
                updated.tags = tags
            }
            updated.updatedAt = Date()
            existing[idx] = updated
            try ensureReferenceLayerDirectoryExists(
                at: referenceLibraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true)
            )
            let mdURL = referenceLibraryRoot
                .appendingPathComponent(layer.directoryName)
                .appendingPathComponent("\(updated.id.uuidString).md")
            try AtomicFileWrite.write(bodyMarkdown.data(using: .utf8) ?? Data(), to: mdURL)
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

    private nonisolated static func writeIndexToFileSystem(
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
        try AtomicFileWrite.write(data, to: indexURL)
    }

    private nonisolated static func ensureReferenceLibraryRootExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private nonisolated static func ensureReferenceLayerDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
