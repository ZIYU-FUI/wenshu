//
//  ImportServiceCache.swift
//
//  Cache I/O + dedup hash helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: 3 private funcs
//  = dedupAndHash + readCache + writeCache = 36 LOC moved out of
//  the main file into this dedicated module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1692 LOC = 2.8x the 600-LOC cap. The 3
//  cache helpers are a single concern (= "read the sidecar cache" +
//  "write the sidecar cache" + "compute dedup hash for each task").
//  Putting them in a dedicated file named after the concern
//  (= ImportServiceCache.swift) lets the next reader find the cache
//  logic by name.
//
//  CacheEntry (= was `fileprivate struct` in ImportService) is now
//  `struct CacheEntry` (= internal scope; = the cross-file extension
//  can return it). The new file uses `ImportService.CacheEntry`
//  to disambiguate from any local CacheEntry type.
//

import Foundation

/// Namespace container for the 3 cache I/O + dedup hash helpers.
enum ImportServiceCache {


    /// Phase 2 = read the on-disk cache once and hash every pending task's body
    /// (= the dedup key is the body hash, not the path hash; = renaming a file
    /// does not bypass dedup; = the in-memory cache is the source of truth for
    /// the import batch; = `writeCache` at the end persists the merged result;
    /// = the `if let cached` branch is a no-op per the 2026-10-10 short-circuit
    /// removal directive; = the cache is consulted downstream by the title-only
    /// retry path via `cache[sourcePath].lastTitleOnlyRetriedHash`).
    static func dedupAndHash(
        tasks: inout [ImportTask],
        cacheFile: URL
    ) -> [String: ImportService.CacheEntry] {
        let cache = readCache(cacheFile: cacheFile)
        for i in tasks.indices {
            let hash: String
            do {
                let body = try String(contentsOfFile: tasks[i].sourcePath, encoding: .utf8)
                hash = ImportServiceHashing.sha256(body)
            } catch {
                tasks[i].state = .failed
                tasks[i].errorMessage = "读取文件失败: \(error.localizedDescription)"
                continue
            }
            tasks[i].contentHash = hash
            _ = cache  // consulted downstream by the title-only retry path
        }
        return cache
    }

    // MARK: - Phase 2: cache

    /// Read the sidecar cache (= the actor's serialized state is the lock; =
    /// the orchestrator batches the read once at the start of importFiles).
    static func readCache(cacheFile: URL) -> [String: ImportService.CacheEntry] {
        guard let data = try? Data(contentsOf: cacheFile),
              let decoded = try? JSONDecoder().decode([String: ImportService.CacheEntry].self, from: data)
        else { return [:] }
        return decoded
    }


    /// Persist the cache back (= the orchestrator writes the whole map each
    /// time; = small file size; = the map is in-memory at this point).
    static func writeCache(cacheFile: URL, cache: [String: ImportService.CacheEntry]) {
        // Ensure the cache root exists (= created on the first import; = no-op on
        // subsequent runs).
        try? FileManager.default.createDirectory(
            at: cacheFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheFile, options: [.atomic])
    }


}
