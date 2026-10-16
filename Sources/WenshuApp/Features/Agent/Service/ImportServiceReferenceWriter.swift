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
