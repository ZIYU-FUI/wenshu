//
//  ImportServiceDedup.swift
//
//  Static dedup + filename helpers extracted from ImportService.swift
//  (= §6.6 god-class split: 3 pure static funcs = findEntityByTitle +
//  normalizeTitle + sanitizeFilename = ~67 LOC moved out of the main
//  file into this dedicated module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1889 LOC = 3.15x the 600-LOC cap. The 3
//  static dedup helpers are a single concern (= "is this newly-imported
//  file already on disk under a different name?" + "normalize the
//  title for fuzzy comparison" + "strip path-unsafe chars from
//  filenames"). Putting them in a dedicated file named after the
//  concern (= ImportServiceDedup.swift) lets the next reader find
//  the dedup logic by name.
//
//  These 3 funcs are pure (= no instance state; = safe to call as
//  `ImportServiceDedup.findEntityByTitle(...)` from any context).
//

import Foundation

/// Namespace container for the 3 static dedup + filename helpers.
enum ImportServiceDedup {
    /// lookup (= scan an existing bookFolder for a .md whose first H1 heading
    /// matches the LLM-supplied title; = used by the orchestrator to decide
    /// between "create" (= no match) and "edit" (= match found) when writing a
    /// new .md file; = the boss's 2026-10-09 [archived-round] directive "再次触发同名实体，只
    /// edit. 不建重名文档"). Why scan the file body instead of trusting the filename:
    /// the filename derives from the title via `sanitizeFilename` (=
    /// path-unsafe chars stripped; = truncated to 80 chars; = the LLM might
    /// rephrase the title slightly between runs); = the FIRST H1 in the body is
    /// the canonical identity (= the LLM's most stable output; = survives
    /// filename normalization drift). Performance: O(n) over the folder's .md
    /// files; = n is bounded by the 5-way parallel import (= 456 files max in
    /// the boss's test corpus; = the folder scan is ~5-50 ms on a fast SSD; =
    /// 5-way parallel can amortize this if needed but a sync scan is acceptable
    /// for now; = the 5-way parallelism is in the LLM dispatch, not the file
    /// writes).
    static func findEntityByTitle(in folderURL: URL, title: String) -> URL? {
        let normalized = ImportServiceDedup.normalizeTitle(title)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        ) else { return nil }
        for entry in entries where entry.pathExtension == "md" {
            // 1) First H1 in the body (= the canonical case for newly-imported files; =
            // the LLM body and the LLM title are consistent so the first
            // H1 matches the routing title).
            if let body = try? String(contentsOf: entry, encoding: .utf8) {
                for line in body.split(separator: "\n").prefix(20) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("# ") {
                        let h1 = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                        if ImportServiceDedup.normalizeTitle(h1) == normalized {
                            return entry
                        }
                        break
                    }
                }
            }
            // 2) Filename heuristic fallback (= the boss sometimes hand-edits a file to
            // remove the H1 (= the boss's 2026-10-09 [archived-round] "还有 3 个重名"
            // feedback); = the file has no H1; = the dedup lookup would
            // return nil; = a re-import of the same entity would create a
            // duplicate file. The fallback strips the .md extension and
            // normalizes the filename (= a file named "五道将军民俗神档案.md"
            // normalizes to "五道将军民俗神档案"; = the LLM title "五道将军民俗神档案"
            // matches; = dedup hits even without an H1).
            let filenameNoExt = entry.deletingPathExtension().lastPathComponent
            if ImportServiceDedup.normalizeTitle(filenameNoExt) == normalized {
                return entry
            }
        }
        return nil
    }


    /// Normalize a title for dedup comparison (= the canonical "trim + collapse
    /// whitespace + lowercase" transform; = matches the import's LLM output
    /// even when the LLM varies whitespace or capitalization across runs).
    static func normalizeTitle(_ s: String) -> String {
        let collapsed = s.replacingOccurrences(
            of: "[\\s]+",
            with: " ",
            options: .regularExpression
        )
        return collapsed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// filename basename (= the previous UUID-only filename made the sidebar
    /// cards unreadable).
    static func sanitizeFilename(raw: String, fallback: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
        var stripped: String = ""
        stripped.reserveCapacity(raw.unicodeScalars.count)
        for scalar in raw.unicodeScalars where !unsafe.contains(scalar) {
            stripped.unicodeScalars.append(scalar)
        }
        stripped = stripped.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty { return fallback }
        if stripped.count > 80 {
            stripped = String(stripped.prefix(80))
        }
        return stripped
    }


}
