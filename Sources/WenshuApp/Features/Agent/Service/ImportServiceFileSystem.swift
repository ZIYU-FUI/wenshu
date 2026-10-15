//
//  ImportServiceFileSystem.swift
//
//  File-system walker extracted from ImportService.swift
//  (= §6.6 god-class split: the 33-LOC `walkSourceDir` private func
//  moved out of the main file into this dedicated module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1794 LOC = 3x the 600-LOC cap. The
//  `walkSourceDir` is a single concern (= "scan the source dir for
//  .md files matching the configured extensions"). Putting it in
//  a dedicated file named after the concern (= ImportServiceFileSystem.swift)
//  lets the next reader find the walker logic by name.
//
//  This func is pure (= no instance state; = safe to call as
//  `ImportServiceFileSystem.walkSourceDir(...)` from any context).
//

import Foundation

/// Namespace container for the file-system walker. Wrapped in an enum
/// (= same pattern as A19's `enum WCIRHelpers` for WenshuConductorImportRouter
/// and A56's `enum ImportServiceDedup` for the dedup + filename helpers).
enum ImportServiceFileSystem {
    // MARK: - Phase 1: walk

    /// Walk the source directory recursively. Returns files whose extension is
    /// in the `extensions` set (sorted for deterministic order; = the sheet's
    /// per-file strip renders in the same order every re-import). Apple
    /// canonical pattern: the match site is a single `Set.contains(...)` call
    /// so a new file type is a one-line change at the enum-definition site (=
    /// the orchestrator never hard-codes a single extension). (= boss
    /// 2026-10-10 "现在 有个问题, 我 们只能选目 录, 而不能 选择单文件" directive). The walker now
    /// accepts BOTH a directory (= the old behavior) AND a single file (= a
    /// file the user picked directly from the open panel; = the walker returns
    /// just that one file; = the import pipeline (= walk + dedup + LLM + write)
    /// is unchanged; = the user can pick a single file OR a directory; = the
    /// orchestrator's 5-way parallel TaskGroup still runs, but with only 1
    /// task).
    static func walkSourceDir(
        _ source: URL,
        extensions: Set<String>
    ) -> [(path: String, url: URL)] {
        let fm = FileManager.default
        // if `source` is a regular file (= the user picked a single file from the open
        // panel), return it directly (after validating the extension matches).
        if let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]),
           values.isRegularFile == true {
            guard extensions.contains(source.pathExtension.lowercased()) else { return [] }
            return [(source.path, source)]
        }
        // the old walk = recursive enumerator. The caller can pass a directory; the
        // walker recurses and filters by extension.
        guard let enumerator = fm.enumerator(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var out: [(String, URL)] = []
        for case let url as URL in enumerator {
            // Apple canonical: skip directories and symlinks pointing outside the source
            // tree.
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .nameKey]),
                  values.isRegularFile == true else { continue }
            guard extensions.contains(url.pathExtension.lowercased()) else { continue }
            out.append((url.path, url))
        }
        // Sort by path (= the same sort the e2e scaffold uses; = deterministic order
        // across re-imports).
        out.sort { $0.0 < $1.0 }
        return out
    }

}
