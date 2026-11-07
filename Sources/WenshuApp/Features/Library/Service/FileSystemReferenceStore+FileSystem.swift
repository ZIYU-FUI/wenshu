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
            let rows = (try? loadReferencesFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot,
                layer: layer
            )) ?? []
            // **⇒ The MEMBERSHIP is what is on disk, = not the index
            // alone.** = See the strict read above for why (= a body
            // the index does not list is still a document in the
            // layer). = **⇒ The UI reads the same answer the corpus
            // check reads**, = because two reads of "what does the
            // library hold" that can disagree are how a document ends
            // up visible in one and missing from the other.
            all.append(contentsOf: ReferenceLayerMembership.members(
                indexRows: rows,
                layer: layer,
                referenceLibraryRoot: referenceLibraryRoot
            ))
        }
        return all
    }

    /// Read every layer's index, = and SAY when one cannot be read.
    ///
    /// **⇒ This is the strict counterpart of
    /// `loadAllReferencesFromFileSystem`.** = The forgiving one turns
    /// every failure into an empty layer, = and a caller that asks
    /// "does the library hold this document" then hears "no" for a
    /// document it never looked for. = **⇒ Here a layer whose index
    /// file EXISTS and cannot be decoded throws**, = and a layer whose
    /// index file is MISSING is empty (= the library has not been
    /// bootstrapped there, = which is a fact about the corpus).
    ///
    /// **⇒ The two date strategies are both tried** (= the index has
    /// been written by two encoders over the app's life), = and only
    /// when BOTH fail is the layer unreadable.
    nonisolated static func loadAllReferencesReportingFailureFromFileSystem(
        referenceLibraryRoot: URL
    ) throws -> [Reference] {
        var all: [Reference] = []
        for layer in ReferenceLayer.allCases {
            let rows = try loadReferencesReportingFailureFromFileSystem(
                referenceLibraryRoot: referenceLibraryRoot,
                layer: layer
            )
            // **⇒ The MEMBERSHIP is what is on disk, = not the index
            // alone.** = A crash between the body write and the index
            // write leaves a body the index does not list, = and a
            // corpus that reads as "the library does not hold it"
            // about a document that IS there is a lie. = **⇒ So the
            // rows the index holds are joined with the bodies the
            // layer holds** (= the metadata and the membership are two
            // different questions).
            all.append(contentsOf: ReferenceLayerMembership.members(
                indexRows: rows,
                layer: layer,
                referenceLibraryRoot: referenceLibraryRoot
            ))
        }
        return all
    }

    /// One layer's index, = or an error when the file is there and
    /// unreadable.
    nonisolated static func loadReferencesReportingFailureFromFileSystem(
        referenceLibraryRoot: URL,
        layer: ReferenceLayer
    ) throws -> [Reference] {
        let indexURL = referenceLibraryRoot
            .appendingPathComponent(layer.directoryName)
            .appendingPathComponent("\(layer.directoryName).json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        let data: Data
        do {
            data = try Data(contentsOf: indexURL)
        } catch {
            throw ReferenceStoreError.referenceIndexUnreadable(
                layer: layer,
                path: indexURL.path,
                reason: String(describing: error)
            )
        }
        let iso = JSONDecoder()
        iso.dateDecodingStrategy = .iso8601
        if let references = try? iso.decode([Reference].self, from: data) {
            return references
        }
        let legacy = JSONDecoder()
        do {
            return try legacy.decode([Reference].self, from: data)
        } catch {
            throw ReferenceStoreError.referenceIndexUnreadable(
                layer: layer,
                path: indexURL.path,
                reason: String(describing: error)
            )
        }
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

    /// Read a body's text.
    ///
    /// **⇒ The TRUTH first** (= `<ws>/references/<uuid>.md`), = and the
    /// layer copy only when the truth is absent. = The corpus had two
    /// copies of every body, = and a reader that picked one at random
    /// read a document the agent had just written as the older text.
    nonisolated static func loadReferenceBodyFromFileSystem(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> String? {
        ReferenceBodyStore.read(
            id: id,
            layer: layer,
            referenceLibraryRoot: referenceLibraryRoot
        )
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
            //
            // **⇒ The comparison reads the TRUTH**, = not the mirror.
            // = The user edits the document in the editor, = which
            // writes the truth location, = and the mirror is stale.
            // = A comparison against the stale mirror said "the
            // content is unchanged" = and the write was SKIPPED, = so
            // the agent's new body never reached the truth either.
            let existingBody = ReferenceBodyStore.read(
                id: reference.id,
                layer: reference.layer,
                referenceLibraryRoot: referenceLibraryRoot
            ) ?? ""
            if existingBody == bodyMarkdown {
                // Content unchanged; = this is a re-import of the same source body; = the
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // previous import; = do nothing (= silent success).
                return
            }
            // Content differs; = the user explicitly authorized "edit" in the [archived-round]
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // `replaceReferenceToFileSystem` path).
            try ReferenceBodyStore.write(
                id: reference.id,
                layer: reference.layer,
                bodyMarkdown: bodyMarkdown,
                referenceLibraryRoot: referenceLibraryRoot
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
        //
        // **⇒ Both locations.** = The agent's write has to land where
        // the READ path looks first (= the truth), = or a document the
        // agent just wrote reads back as the older text.
        try ReferenceBodyStore.write(
            id: reference.id,
            layer: reference.layer,
            bodyMarkdown: bodyMarkdown,
            referenceLibraryRoot: referenceLibraryRoot
        )

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
        try ReferenceBodyStore.write(
            id: reference.id,
            layer: reference.layer,
            bodyMarkdown: bodyMarkdown,
            referenceLibraryRoot: referenceLibraryRoot
        )

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
        referenceLibraryRoot: URL,
        layer: ReferenceLayer = .layerEntities
    ) throws {
        // **⇒ One write, = two locations.** = The truth
        // (`<ws>/references/<uuid>.md`) = and the layer mirror beside
        // it. = They are read by different readers, = so a write that
        // touched one of them left the other stale. = Measured on the
        // real library: = six documents, = six divergent pairs.
        try ReferenceBodyStore.write(
            id: id,
            layer: layer,
            bodyMarkdown: bodyMarkdown,
            referenceLibraryRoot: referenceLibraryRoot
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
            // **⇒ Both locations.** = The truth (= where the read
            // path looks first) = and the layer mirror. = Writing only
            // the mirror left the truth holding the PREVIOUS body, =
            // and the reader (= truth first) read the old text: = the
            // update was invisible.
            try ReferenceBodyStore.write(
                id: updated.id,
                layer: layer,
                bodyMarkdown: bodyMarkdown,
                referenceLibraryRoot: referenceLibraryRoot
            )
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
        // **⇒ The truth location too.** = A delete that removed only
        // the layer copy left the body on disk at
        // `<ws>/references/<uuid>.md`, = and the read path prefers
        // that one. = **⇒ A delete that leaves the body on disk is
        // not a delete.**
        for layer in ReferenceLayer.allCases {
            ReferenceBodyStore.remove(
                id: id,
                layer: layer,
                referenceLibraryRoot: referenceLibraryRoot
            )
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
