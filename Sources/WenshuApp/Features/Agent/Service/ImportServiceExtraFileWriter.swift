//
//  ImportServiceExtraFileWriter.swift
//
//  writeExtraFile extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: the 62-LOC
//  `writeExtraFile` instance method moved out of the main file
//  into a dedicated cross-file `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1487 LOC = 2.5x the 600-LOC cap. The
//  `writeExtraFile` is a single concern (= "write one LLM-suggested
//  split-out file to disk"). Putting it in a dedicated file named
//  after the concern (= ImportServiceExtraFileWriter.swift) lets the
//  next reader find the extra-file writer logic by name.
//
//  The `private func` was relaxed to `func` (= internal scope; =
//  required for the cross-file extension access). The method stays
//  on `ImportService` (as an instance method on the actor) because
//  it doesn't need static semantics.
//

import Foundation

extension ImportService {


    /// ticket 03 (= boss 2026-10-10 "甚至原文 件 A 的内容, 与我们 的 B 模版不符合, 多了 很我非模版的内容,
    /// 我 希望能自动拆出一个文 件, 放在合适的目录中 去" feedback). Write one LLM-suggested split-out
    /// file (= A's non-B content) to disk. Resolves the folder URL from the
    /// `extra.folder` (= LLM decided which BookFolder; = the orchestrator
    /// doesn't override = this is the canonical LLM-routed path). Dedup logic
    /// mirrors the main file: same- title in the target folder = overwrite the
    /// existing .md; = no match = write a new file.
    func writeExtraFile(
        extra: ExtraFile,
        target: ImportTarget,
        tasksBox: TasksBox,
        i: Int,
        extraIndex: Int
    ) async throws {
        guard let bookId = target.bookId,
              let shelfId = target.shelfId else {
            throw ImportServiceError.missingBookForBookFolderDestination
        }
        let folderURL = target.shelvesRoot
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent(extra.folder.directoryName)
        // Sanitize title (= same canonical path as the main file; = path-unsafe chars
        // stripped; = empty / unsafe-only title falls back to a UUID prefix; =
        // the LLM is trusted zero).
        let basename = ImportServiceDedup.sanitizeFilename(
            raw: extra.title,
            fallback: "extra-\(UUID().uuidString.prefix(8))"
        )
        // Dedup against the target folder's existing .md files. Match by normalized title
        // stem (= the .md filename without the .md extension); = the canonical
        // "same content" path. If a match exists, overwrite (= the LLM may
        // have refined the body in a re-import).
        let fm = FileManager.default
        var bodyForFile = extra.body
        if fm.fileExists(atPath: folderURL.appendingPathComponent(basename + ".md").path) {
            NSLog(
                "[wenshu.import] extraFile %d (%@) overwriting existing file in %@",
                extraIndex, basename, extra.folder.directoryName
            )
        } else if fm.fileExists(atPath: folderURL.path) {
            // folder exists; = check for any .md with matching basename stem (= dedup
            // scan across the existing .md files in the folder).
            let existing = (try? fm.contentsOfDirectory(atPath: folderURL.path)) ?? []
            for entry in existing where entry.hasSuffix(".md") {
                let stem = (entry as NSString).deletingPathExtension
                if stem == basename {
                    NSLog(
                        "[wenshu.import] extraFile %d (%@) overwriting existing file in %@",
                        extraIndex, basename, extra.folder.directoryName
                    )
                    break
                }
            }
        }
        // Make sure the folder exists (= create intermediate directories; = safe across
        // multi-level).
        try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        // Write the body (= the LLM-supplied content; = no prepareBodyForWrite = the LLM
        // already produced a complete, focused body for this single-file
        // split-out).
        let fileURL = folderURL.appendingPathComponent(basename + ".md")
        try bodyForFile.write(to: fileURL, atomically: true, encoding: .utf8)
        NSLog(
            "[wenshu.import] extraFile %d wrote %@ -> %@",
            extraIndex, basename, extra.folder.directoryName
        )
    }

}
