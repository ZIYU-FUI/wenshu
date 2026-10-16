//
//  ImportServiceDispatchHelpers.swift
//
//  3 small pure helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: filterRetryCandidates
//  + recordInCache + sourceStringFromPath = 30 LOC moved out of the
//  main file into this dedicated module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1646 LOC = 2.7x the 600-LOC cap. The 3
//  helpers are a single concern (= "small in/out helper functions
//  used by the dispatch pipeline that have no instance state
//  coupling"). Putting them in a dedicated file named after the
//  concern (= ImportServiceDispatchHelpers.swift) lets the next
//  reader find these helpers by name.
//
//  These 3 funcs are static (= no instance state; = safe to call
//  from any context). CacheEntry (= was `fileprivate struct` in
//  ImportService) is now `struct CacheEntry` (= internal scope; =
//  the cross-file extension can return it). The new file uses
//  `ImportService.CacheEntry` to disambiguate.
//

import Foundation

/// Namespace container for the 3 small pure dispatch helpers.
enum ImportServiceDispatchHelpers {

    /// Step 1: filter (= only the "读取文件失败" subset; = LLM-routing failures and
    /// write failures are excluded; = the user clicked "重新调研" with the explicit
    /// understanding that this is the "I trust the filename + LLM search alone"
    /// path).
    static func filterRetryCandidates(tasks: [ImportTask]) -> [Int] {
        return tasks.indices.filter { i in
            guard tasks[i].state == .failed else { return false }
            return tasks[i].errorMessage?.hasPrefix("读取文件失败") ?? false
        }
    }


    /// Record the import in the sidecar cache so the next dedup pass (= a
    /// re-import of the same source directory) hits the cache instead of
    /// dispatching the LLM + re-writing the file. (= boss 2026-10-10 (see
    /// OOB.md #2026-10-10) 3 files; = `uuidFromHash("")` returned the SAME
    /// deterministic UUID for all 3 files; = the orchestrator wrote the .md at
    /// the same path for the first file; = the second and third files crashed
    /// with "Reference ... already exists on disk"). The fix: NEVER write an
    /// empty / short contentHash to the cache; = if the input is empty (= the
    /// source file's contentHash was somehow not populated), compute a stable
    /// placeholder (= sha256 of the source path; = unique per file; = the uuid
    /// derives to a unique UUID; = the dedup still works). The previous code
    /// propagated the empty hash verbatim, which led to the "all empty hashes →
    /// same UUID" collision.)
    static func recordInCache(
        contentHash: String,
        sourcePath: String,
        routing: ImportRoutingResult,
        cache: inout [String: ImportService.CacheEntry]
    ) {
        let safeContentHash: String
        if contentHash.isEmpty || contentHash.count < 16 {
            safeContentHash = "orphan-" + ImportServiceHashing.sha256(sourcePath)
        } else {
            safeContentHash = contentHash
        }
        cache[sourcePath] = ImportService.CacheEntry(
            contentHash: safeContentHash,
            destination: routing.destination,
            writtenAt: Date()
        )
    }


    /// Where the reference came from (= used in the Reference.source field; =
    /// "导入: <source dir>" for now; = a future ticket can ask the user to label
    /// the source).
    static func sourceStringFromPath(target: ImportTarget) -> String {
        if let bookId = target.bookId {
            return "导入: \(bookId.uuidString.prefix(8))"
        }
        return "导入: 资料库"
    }


}
