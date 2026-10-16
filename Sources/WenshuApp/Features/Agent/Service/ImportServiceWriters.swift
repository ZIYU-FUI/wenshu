//
//  ImportServiceWriters.swift
//
//  3 file-write helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: writeFile +
//  writeToBookFolder + writeToReferenceLibrary = 239 LOC moved
//  out of the main file into this dedicated cross-file
//  `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1376 LOC = 2.3x the 600-LOC cap. The 3
//  file-write helpers are a single concern (= "write the .md file
//  to the destination decided by the router"). Putting them in a
//  dedicated file named after the concern (= ImportServiceWriters.swift)
//  lets the next reader find the write logic by name.
//
//  The 3 funcs are instance methods on `ImportService` (as a
//  cross-file extension). The `private func` was relaxed to `func`
//  (= internal scope; = required for the cross-file extension access).
//  The `writeFile` writes to the actor's `writtenURLs` rollback
//  trail (= relaxed to internal in A55; = required for the
//  cross-file access).
//

import Foundation

extension ImportService {
    // MARK: - Phase 4: write

    /// Write the file body to the destination dictated by the routing result.
    /// Branches on `ImportDestination`: - `.bookFolder(folder)` = write to
    ///     `<shelvesRoot>/<shelfId>/books/<bookId>/<folder.directoryName>/<uuid>.md`
    /// (= creates the folder if missing; = uuid is content-addressable so the
    /// same body always lands at the same path; = dedup by content). -
    /// `.referenceLibrary` = delegate to
    ///     `ReferenceLibraryTool.execute(saveReferenceEnvelope)`
    /// (= the existing 4-phase path the e2e scaffold already exercises).
    func writeFile(
        body: String,
        routing: ImportRoutingResult,
        contentHash: String,
        target: ImportTarget,
        sourcePath: String,
        cache: inout [String: CacheEntry],
        router: any ImportRouter,
        tasksBox: TasksBox,
        i: Int
    ) async throws {
        // Dispatch on the LLM-decided destination. The two cases share the
        // Stage 2 LLM content-same check (= "skip if the existing file is
        // already correct"; = the same code shape, slightly different
        // dedup-cache lookup).
        let writtenURL: URL?
        switch routing.destination {
        case .bookFolder(let folder):
            writtenURL = try await writeToBookFolder(
                body: body,
                routing: routing,
                contentHash: contentHash,
                target: target,
                sourcePath: sourcePath,
                router: router,
                tasksBox: tasksBox,
                i: i,
                folder: folder
            )
        case .referenceLibrary:
            // The reference library path also runs the Stage 2 LLM content-same
            // decision (= the reference library dedup was per-file correct,
            // but the user wants the same "LLM 比对" transparency for both
            // destinations; = the `FileSystemReferenceStore.saveReferenceToFileSystem`
            // upserts the file, so "skip" here just means the upsert sees
            // a content-identical file and the idempotent write is a no-op).
            try await writeToReferenceLibrary(
                body: body,
                routing: routing,
                contentHash: contentHash,
                target: target,
                router: router,
                tasksBox: tasksBox,
                i: i
            )
            writtenURL = nil
        }
        if let fileURL = writtenURL {
            // Record the on-disk trail for the cancel-and-rollback path
            // (= the actor keeps a list of every URL it wrote this batch;
            // = the cancel handler deletes them in reverse-order on rollback;
            // = the dedup cache can map two source paths to the same file
            // URL but the cancel handler is idempotent so a double-delete
            // is a no-op).
            writtenURLs.append(fileURL)
        }
        // Record the import in the sidecar cache so the next dedup pass
        // (= a re-import of the same source directory) hits the cache
        // instead of dispatching the LLM + re-writing the file.
        ImportServiceDispatchHelpers.recordInCache(
            contentHash: contentHash,
            sourcePath: sourcePath,
            routing: routing,
            cache: &cache
        )
    }


    /// Write to a book folder (= the `.bookFolder` destination case). Returns
    /// the written URL (= nil if the LLM said "content same" and the file was
    /// skipped; = the caller skips the rollback trail entry for skipped
    /// writes).
    func writeToBookFolder(
        body: String,
        routing: ImportRoutingResult,
        contentHash: String,
        target: ImportTarget,
        sourcePath: String,
        router: any ImportRouter,
        tasksBox: TasksBox,
        i: Int,
        folder: BookFolder
    ) async throws -> URL? {
        // The on-disk filename derives from the LLM-supplied title (= the boss's
        // 2026-10-09 [archived-round] feedback "这个 ID 的事还没有修吗": = the
        // sidebar's BookDoc card title came from the file's filename
        // without extension; = the previous UUID-only filename meant
        // the cards read "023D22E3-1F1D-4A55-83C8-F133156ECEB9"
        // instead of the human-readable title the LLM generated; = a
        // stable, title-based filename makes the sidebar readable on
        // the first pass). The dedup key still lives in the cache (= a
        // re-import of the same body finds the cache entry by source
        // path; = the on-disk filename is a display concern, not a
        // identity concern; = the fileURL still uses the title for the
        // sidebar + the cache for idempotency). Sanitization is rare (= the
        // LLM is instructed to always return a title; = a missing title
        // would indicate a deeper LLM misbehavior worth surfacing as a
        // generic "未命名" rather than a cryptic UUID).
        let uuid = ImportServiceHashing.uuidFromHash(contentHash)
        // (= the boss's 2026-10-09 [archived-round] "强制让用户 分开导入" directive). When the user
        // pinned the reference library, this branch is unreachable (= the
        // LLM already overrode the destination to .referenceLibrary + the
        // orchestrator took the referenceLibrary case). The `bookId!` /
        // `shelfId!` unwraps are safe because the orchestrator's processFile
        // passes the user's chosen target down here; = a destination = .book
        // guarantee that both IDs are populated.
        guard let bookId = target.bookId,
              let shelfId = target.shelfId else {
            throw ImportServiceError.missingBookForBookFolderDestination
        }
        let folderURL = target.shelvesRoot
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent(folder.directoryName)
        let basename = ImportServiceDedup.sanitizeFilename(
            raw: routing.title,
            fallback: String(uuid.uuidString.prefix(8))
        )
        // (= boss 2026-10-09 [archived-round] directive "再次触发 同名实体，只 edit. 不建重名文档"; = the
        // previous per-source-path dedup let the same entity land at
        // multiple paths when the user re-imported after clearing only
        // one source directory; = world/ ended up with 33 duplicate
        // titles + characters/ with 20 duplicates; = the user-visible
        // bug was "一物多份"; = fix is to scan the existing folder for an
        // entity with the same normalized title; = match → overwrite
        // the existing file; = no match → write the new title-derived file).
        let fileURL: URL
        if let existingURL = ImportServiceDedup.findEntityByTitle(in: folderURL, title: routing.title) {
            // A same-titled .md file was found in the destination folder.
            // Before overwriting, run Stage 2 LLM content-same check
            // (= the boss's "需要 检查 对比" requirement; = the LLM
            // returns `isContentSame` + `confidence`; = if same AND
            // confidence >= threshold = skip; = otherwise overwrite).
            let sourceBodyForCompare = try String(
                contentsOfFile: tasksBox.value[i].sourcePath,
                encoding: .utf8
            )
            let existingBody = (try? String(
                contentsOf: existingURL,
                encoding: .utf8
            )) ?? ""
            let sameResult = try await router.isContentSame(
                sourceBody: sourceBodyForCompare,
                existingBody: existingBody,
                sourceTitle: routing.title
            )
            if WCIRHelpers.shouldSkip(result: sameResult) {
                // LLM says same content; = skip (= the existing file is correct).
                NSLog("WSImport: content-same skip title='\(routing.title)' confidence=\(sameResult.confidence) reasoning='\(sameResult.reasoning)'")
                tasksBox.value[i].state = .skipped
                tasksBox.value[i].errorMessage = nil
                tasksBox.value[i].skippedReason = "内容相同 (LLM confidence \(sameResult.confidence)): \(sameResult.reasoning)"
                // Throw sentinel so the outer processFile sees the .skipped
                // state and doesn't overwrite to .done.
                throw ImportServiceError.contentSameSkipped
            } else {
                NSLog("WSImport: content-different overwrite title='\(routing.title)' reasoning='\(sameResult.reasoning)'")
            }
            // Match: overwrite the existing file (= the boss's "edit, not create" rule).
            fileURL = existingURL
            NSLog("WSImport: dedup hit title='\(routing.title)' → \(existingURL.lastPathComponent)")
        } else {
            fileURL = folderURL.appendingPathComponent("\(basename).md")
        }
        // Create the folder if missing (= idempotent; = the bootstrapper
        // seeds the 5 standard folders but if a future folder is added
        // the orchestrator creates it on the fly).
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        // Write the body verbatim (= the orchestrator's job is to put the
        // body at the right path; = the LLM did the structural work upstream).
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }


    /// Write to the reference library (= the `.referenceLibrary` destination
    /// case). The body lands at `<wsRoot>/reference-library/entities/<uuid>.md`
    /// and the Reference is appended to `entities/entities.json`. This path
    /// also runs the Stage 2 LLM content-same check (= same as the book folder
    /// path; = the user wants the same "LLM 比对" transparency for both
    /// destinations).
    func writeToReferenceLibrary(
        body: String,
        routing: ImportRoutingResult,
        contentHash: String,
        target: ImportTarget,
        router: any ImportRouter,
        tasksBox: TasksBox,
        i: Int
    ) async throws {
        let refMdURL = target.wsRoot
            .appendingPathComponent("reference-library")
            .appendingPathComponent("entities")
            .appendingPathComponent("\(ImportServiceHashing.uuidFromHash(contentHash).uuidString).md")
        if FileManager.default.fileExists(atPath: refMdURL.path) {
            // File already exists for this content hash (= the previous
            // import wrote it). Run Stage 2 LLM check.
            let existingBody = (try? String(
                contentsOf: refMdURL,
                encoding: .utf8
            )) ?? ""
            let sameResult = try await router.isContentSame(
                sourceBody: body,
                existingBody: existingBody,
                sourceTitle: routing.title
            )
            if WCIRHelpers.shouldSkip(result: sameResult) {
                NSLog("WSImport: ref-library content-same skip title='\(routing.title)' confidence=\(sameResult.confidence)")
                tasksBox.value[i].state = .skipped
                tasksBox.value[i].errorMessage = nil
                tasksBox.value[i].skippedReason = "内容相同 (LLM confidence \(sameResult.confidence)): \(sameResult.reasoning)"
                throw ImportServiceError.contentSameSkipped
            } else {
                NSLog("WSImport: ref-library content-different overwrite title='\(routing.title)' reasoning='\(sameResult.reasoning)'")
                // Fall through to the standard writeReference (= the upsert
                // overwrites the existing file with the new body).
            }
        }
        // Delegate to the existing reference-write path (= the e2e
        // scaffold's 4-phase walk → reframe → classify → write).
        try await writeReference(
            body: body,
            routing: routing,
            target: target,
            contentHash: contentHash
        )
    }


}
