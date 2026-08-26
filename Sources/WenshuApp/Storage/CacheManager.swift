// CacheManager.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Cache directory manager (= spec v5 ticket 020). Holds thumbnails +
// search index + export temp under `<.ws>/cache/`. v0.26 ships the
// cache directory scaffolding (= create-on-launch if missing); full
// thumbnail generation + search index population land in v0.27+.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 020.

import Foundation

/// Manages the .ws library's cache/ directory. v0.26 = scaffolding only
/// (= ensure-on-launch + cleanup-old-files helper); thumbnail
/// generation + search index wiring land in v0.27+.
struct CacheManager: Sendable {
    let cacheDirectory: URL

    /// Initialize with the .ws root (= manages `<.ws>/cache/`).
    init(wsRoot: URL) {
        self.cacheDirectory = wsRoot.appendingPathComponent("cache", isDirectory: true)
    }

    /// Ensure the cache/ directory exists (= idempotent; safe to call
    /// on every launch). Called by LibraryBootstrapper (ticket 021).
    func ensureCacheDirectoryExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory.path) {
            try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    /// Delete files in cache/ older than the given age. v0.26 helper
    /// (= Apple HIG 'manageable cache' pattern; v0.27+ can call this
    /// from a periodic background task).
    func cleanupFiles(olderThan age: TimeInterval) throws {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-age)
        guard let enumerator = fm.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = values.contentModificationDate,
                  modDate < cutoff else { continue }
            try? fm.removeItem(at: fileURL)
        }
    }
}