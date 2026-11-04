//
//  ImportServiceReferenceWriter.swift
//
//  writeReference extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: the 44-LOC
//  `writeReference` instance method moved out of the main file
//  into a dedicated cross-file `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1418 LOC = 2.4x the 600-LOC cap. The
//  `writeReference` is a single concern (= "write the file to the
//  reference library"). Putting it in a dedicated file named after
//  the concern (= ImportServiceReferenceWriter.swift) lets the next
//  reader find the reference-library writer by name.
//
//  The `private func` was relaxed to `func` (= internal scope; =
//  required for the cross-file extension access). The method stays
//  on `ImportService` (as an instance method on the actor) because
//  it doesn't need static semantics.
//

import Foundation

extension ImportService {

    /// The document in the library that already carries this title.
    ///
    /// The lookup is a pure question about the library's contents, =
    /// so it is a static function on a type of its own: = the writer
    /// is an actor's method, = and a decision that can be tested
    /// without an actor is a decision that gets tested.
    @MainActor
    static func existingDocument(
        in store: any ReferenceStoring,
        title: String
    ) -> Reference? {
        let all = (try? store.loadAllReferences()) ?? []
        return Reference.firstMatchingTitle(in: all, title: title, layer: .layerEntities)
    }

    /// Write the file to the reference library. Reuses the existing
    /// `FileSystemReferenceStore.saveReferenceToFileSystem` (= see the e2e
    /// scaffold's 4-phase pattern; = the LLM-supplied category + tags +
    /// entityType are encoded into the Reference envelope).
    func writeReference(
        body: String,
        routing: ImportRoutingResult,
        target: ImportTarget,
        contentHash: String
    ) async throws {
        // uuid = content-hash-prefixed (= the same body always lands at the same
        // reference-library file; = idempotent re-import dedup).
        let uuid = ImportServiceHashing.uuidFromHash(contentHash)
        // Build a Reference struct from the routing result (= the LLM supplies the
        // metadata; = the orchestrator maps ImportRoutingResult onto the
        // existing Reference struct).
        let reference = Reference(
            id: uuid,
            title: routing.title,
            source: ImportServiceDispatchHelpers.sourceStringFromPath(target: target),
            layer: .layerEntities,
            category: routing.category.flatMap { EntityCategory(rawValue: $0) },
            tags: routing.tags,
            entityType: EntityType.fromPromptNumber(Int(routing.entityType) ?? 0),
            summary: routing.summary
        )
        // The identity rule, = the same one every other writer uses.
        //
        // The import used to write by CONTENT HASH alone, = so an
        // import of a document whose title already existed landed a
        // SECOND document with the same title. = The corpus said "one
        // document, = one identity", = and the import was the writer
        // that did not honour it. = The rule lives in
        // `Reference.titlesMatch`, = and this writer reads it like the
        // others.
        let existing = await Self.existingDocument(in: target.referenceStore, title: routing.title)

        if existing != nil {
            // The document is already in the library. = Update that one
            // rather than adding a second copy of the same name, =
            // which is what the tool's create path refuses to do.
            let updated = try await MainActor.run {
                try target.referenceStore.upsertReference(
                    title: routing.title,
                    bodyMarkdown: body,
                    layer: .layerEntities,
                    category: routing.category.flatMap { EntityCategory(rawValue: $0) },
                    tags: routing.tags,
                    source: reference.source,
                    url: nil,
                    entityType: reference.entityType,
                    summary: routing.summary
                )
            }
            writtenURLs.append(
                target.wsRoot
                    .appendingPathComponent("reference-library")
                    .appendingPathComponent("entities")
                    .appendingPathComponent("\(updated.id.uuidString).md")
            )
            return
        }

        // Write through the existing storage layer (= the FileSystemReferenceStore
        // handles the index file at `entities/entities.json`).
        try await MainActor.run { try target.referenceStore.saveReference(reference, bodyMarkdown: body) }
        // Record the on-disk trail for the cancel-and-rollback path (= the reference-
        // library .md file lives at the same path the
        // `FileSystemReferenceStore` just wrote; = we reconstruct the URL from
        // the same source-of-truth = no race with the storage layer's index
        // file). The rollback handler deletes these .md files in reverse order
        // and restores the prior `entities.json` from the snapshot taken at
        // `importFiles` start.
        let refMdURL = target.wsRoot
            .appendingPathComponent("reference-library")
            .appendingPathComponent("entities")
            .appendingPathComponent("\(uuid.uuidString).md")
        writtenURLs.append(refMdURL)
    }

}
