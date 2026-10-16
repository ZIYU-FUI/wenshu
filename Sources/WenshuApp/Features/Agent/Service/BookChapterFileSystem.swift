//
//  BookChapterFileSystem.swift
//
//  File-system chapter helpers extracted from BookChapterTool.swift
//  in A100 (= §6.6 600-LOC cap god-class split).
//
//  Why a separate file (= and not in BookChapterTool.swift):
//  BookChapterTool.swift is 1164 LOC = 1.94x the 600-LOC cap.
//  The 120-LOC `extension BookChapterActor { ... }` block
//  (= the static saveFileSystemChapter / writeFileSystemChapter /
//  deleteFileSystemChapter / ensureChaptersDirectoryExists /
//  atomicWrite helpers) is purely a file-system adapter layer;
//  = it doesn't touch the actor's instance state; = it can
//  live in its own file as a pure namespace extension.
//
//  Per the §6.2 4-slot spec: this belongs in Service/ (= already
//  is; = sibling of BookChapterTool.swift in the same Service/
//  dir). File naming follows the §6.5 actual-suffix rule
//  (= Tool/Ops naming; = "FileSystem" suffix describes the
//  file-system adapter concern).
//
//  Privacy note (= the original used `internal static func`
//  for ensureChaptersDirectoryExists + atomicWrite; = now
//  internal `static func` so the new file's extension can
//  reach them; = they're only called by sibling static funcs
//  in the same extension anyway; = no security boundary
//  change).
//

import Foundation
// file hosts the helpers here (= duplicates the storage layer) so the actor doesn't
// need a separate extension file.
extension BookChapterActor {
    /// Write a NEW chapter to the legacy FileSystem path (.md file +
    /// chapters.json index update).
    static func saveFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        try ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        // Append to the chapters.json index (= the legacy list path callers read via
        // loadChaptersFromFileSystem).
        var current = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        current.append(chapter)
        try writeIndex(current, to: indexURL)
    }

    /// Replace an EXISTING chapter (.md body + index row update).
    static func writeFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        try ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        // Update the chapters.json index row.
        var current = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        guard let idx = current.firstIndex(where: { $0.id == chapter.id }) else {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        current[idx] = chapter
        try writeIndex(current, to: indexURL)
    }

    /// Delete a chapter (.md body + index row remove).
    static func deleteFileSystemChapter(
        id: UUID,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            try FileManager.default.removeItem(at: chapterURL)
        }

        // Remove from chapters.json index.
        var current = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        let before = current.count
        current.removeAll { $0.id == id }
        if current.count != before {
            try writeIndex(current, to: indexURL)
        }
    }

    internal static func writeIndex(_ chapters: [Document], to indexURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(chapters)
        try atomicWrite(data, to: indexURL)
    }

    internal static func ensureChaptersDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    internal static func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
        let fd = open(url.path, O_RDONLY)
        if fd >= 0 {
            fsync(fd)
            close(fd)
        }
    }
}
