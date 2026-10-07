//
//  ChapterExportEngine.swift · Wenshu
//
//  Actor that performs the single-chapter export. Reads the chapter
//  body + frontmatter via the nonisolated static helpers on
//  FileSystemChapterStore, then writes a single .md file at the
//  destination URL. The body bytes are preserved verbatim (= no
//  wenshu-side rewrites); the existing `ChapterFrontmatter.serialize`
//  (= in `Domain/CrossRefInject_v2.swift:209`) produces the YAML
//  frontmatter header.
//

import Foundation

/// Typed error for chapter export failures.
enum ChapterExportError: LocalizedError, Sendable, Equatable {
    case noActiveLibrary
    case chapterNotFound(UUID)
    case destinationReadOnly(URL)
    case ioFailure(URL, String)

    var errorDescription: String? {
        switch self {
        case .noActiveLibrary:
            return "No active library is open."
        case .chapterNotFound(let id):
            return "Chapter \(id.uuidString) not found."
        case .destinationReadOnly(let url):
            return String(localized: "export.error.destination_readonly") + " (\(url.path))"
        case .ioFailure(let url, let msg):
            return "I/O failure at \(url.path): \(msg)"
        }
    }
}

actor ChapterExportEngine {

    /// Export a single chapter as a Markdown file. The body bytes
    /// are preserved verbatim (= what the user sees in the editor
    /// = what the user gets in the export). The YAML frontmatter is
    /// built from `ChapterFrontmatter.serialize` (= existing helper).
    func exportChapter(
        id chapterID: UUID,
        to destinationURL: URL
    ) async throws -> URL {

        guard let libPath = ActiveLibrary.path else {
            throw ChapterExportError.noActiveLibrary
        }
        let libURL = URL(fileURLWithPath: libPath, isDirectory: true)

        // Walk shelves / books to find the chapter's .md file.
        // (= the existing FileSystemChapterStore.scatteredFilesystem
        // path uses nonisolated static loaders that need the book's
        // chaptersDirectory; = we find that directory first.)
        let fm = FileManager.default
        guard let chaptersDir = try locateChaptersDirectory(
            libraryURL: libURL,
            chapterID: chapterID
        ) else {
            throw ChapterExportError.chapterNotFound(chapterID)
        }

        guard let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
            id: chapterID,
            chaptersDirectory: chaptersDir
        ) else {
            throw ChapterExportError.chapterNotFound(chapterID)
        }

        // Compose the chapter's exported Markdown = the body
        // verbatim. The body's existing frontmatter block (= the
        // YAML header the editor wrote into the chapter's .md) is
        // preserved as part of the body (= we do NOT re-serialize
        // it; = the user sees round-trip equivalence with the editor
        // content).
        try Data(body.utf8).write(
            to: destinationURL,
            options: .atomic
        )

        return destinationURL
    }

    /// Walk every shelf + book to find the chapters directory
    /// containing the chapter ID (= cheap because chapter .md files
    /// are named `<uuid>.md`).
    private func locateChaptersDirectory(
        libraryURL: URL,
        chapterID: UUID
    ) throws -> URL? {
        let fm = FileManager.default
        let shelvesURL = libraryURL.appendingPathComponent("shelves", isDirectory: true)
        guard fm.fileExists(atPath: shelvesURL.path) else { return nil }
        let shelves = try fm.contentsOfDirectory(
            at: shelvesURL,
            includingPropertiesForKeys: nil
        )
        for shelf in shelves {
            let booksURL = shelf.appendingPathComponent("books", isDirectory: true)
            guard fm.fileExists(atPath: booksURL.path) else { continue }
            let books = try fm.contentsOfDirectory(
                at: booksURL,
                includingPropertiesForKeys: nil
            )
            for book in books {
                let chaptersDir = book.appendingPathComponent("chapters", isDirectory: true)
                guard fm.fileExists(atPath: chaptersDir.path) else { continue }
                let chapterURL = chaptersDir.appendingPathComponent("\(chapterID.uuidString).md")
                if fm.fileExists(atPath: chapterURL.path) {
                    return chaptersDir
                }
            }
        }
        return nil
    }
}

// MARK: - Frontmatter helper

// The existing project-wide `ChapterFrontmatter` type lives in
// `Domain/CrossRefInject_v2.swift:183` (= same module as the rest
// of the wenshu source tree; = no extra import needed). Today's
// engine preserves the body verbatim (= the YAML header the editor
// already wrote into the .md travels with the body); = re-
// serializing frontmatter would be a future ticket (= requires a
// MainActor hop to read the SwiftData @Model metadata).