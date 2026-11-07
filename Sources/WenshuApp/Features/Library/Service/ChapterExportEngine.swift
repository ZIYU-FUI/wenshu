//
//  ChapterExportEngine.swift · Wenshu
//
//  Actor that performs the single-chapter export. Reads the chapter
//  body via the nonisolated static helpers on
//  FileSystemChapterStore, then writes a single .md file at the
//  destination URL. The body bytes are preserved verbatim (= no
//  wenshu-side rewrites).
//

import Foundation

/// Typed error for chapter export failures.
enum ChapterExportError: LocalizedError, Sendable, Equatable {
    case noActiveLibrary
    case chapterNotFound(UUID)
    case destinationReadOnly(URL)
    case ioFailure(URL, String)
    /// The chapter carries no identifier to report (= the export was
    /// asked for a file rather than for an id, = and that file could
    /// not be read).
    case noChapterIdentifier

    var errorDescription: String? {
        switch self {
        case .noActiveLibrary:
            return "No active library is open."
        case let .chapterNotFound(id):
            return "Chapter \(id.uuidString) not found."
        case let .destinationReadOnly(url):
            return String(localized: "export.error.destination_readonly") + " (\(url.path))"
        case let .ioFailure(url, msg):
            return "I/O failure at \(url.path): \(msg)"
        case .noChapterIdentifier:
            return "Chapter not found."
        }
    }
}

actor ChapterExportEngine {
    /// Export a single chapter as a Markdown file. The body bytes
    /// are preserved verbatim (= what the user sees in the editor
<<<<<<< HEAD
    /// = what the user gets in the export). The YAML frontmatter is
    /// built from `ChapterFrontmatter.serialize` (= existing helper).
    ///
    /// The chapter is located by its ID, which finds the `<uuid>.md`
    /// file the actor writes. = the ID entry point for a chapter the
    /// actor created; = the file-based entry point below is the one
    /// the export sheet uses, = because a chapter can also arrive
    /// from the import under a name that is not an id.
=======
    /// = what the user gets in the export). = The body's own
    /// frontmatter block (= a YAML header the body carries) travels
    /// with it (= the editor's round trip).
>>>>>>> 802141b7f (fix(library): the submission manuscript carries no frontmatter, = and the file's stale claim is gone)
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

        try write(body: body, to: destinationURL)
        return destinationURL
    }

    /// Export a single chapter from the file that holds it.
    ///
    /// The ID-based entry point finds `<uuid>.md`, = the name the
    /// actor writes. An imported chapter is named after its title, so
    /// the ID path found nothing for it and the chapter could not be
    /// exported at all. The file is the truth (= the same truth the
    /// book export reads), so the chapter is exported from the file
    /// the resolver handed over.
    func exportChapter(
        fileURL: URL,
        to destinationURL: URL
    ) async throws -> URL {
        guard let body = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw ChapterExportError.noChapterIdentifier
        }
        try write(body: body, to: destinationURL)
        return destinationURL
    }

    /// Write the chapter body to the destination, verbatim.
    private func write(body: String, to destinationURL: URL) throws {
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
    }

    /// Export a single chapter as a SUBMISSION MANUSCRIPT for
    /// `target`: plain text, segmented, and shaped by the target's
    /// measured rules (= Jinjiang's two full-width spaces U+3000 U+3000
    /// at the start of every segment and its blank line between
    /// segments, = Qidian / Tomato's none of either).
    ///
    /// WHY THIS IS A SEPARATE METHOD AND NOT A MODE OF
    /// `exportChapter`
    ///
    /// `exportChapter` preserves the body BYTES (= the editor's
    /// round trip with the file), = and that contract is what a
    /// `.md` export promises. = A submission manuscript is a
    /// different product (= plain text for a platform's editor),
    /// = so it is a different method over the same body.
    ///
    /// The chapter title is NOT written into the file (= it is the
    /// platform's own separate title field, = and Tomato counts the
    /// body without it), = so the caller writes the title and the
    /// body where the platform wants them.
    func exportManuscript(
        id chapterID: UUID,
        to destinationURL: URL,
        target: ManuscriptTarget
    ) async throws -> URL {
        guard let libPath = ActiveLibrary.path else {
            throw ChapterExportError.noActiveLibrary
        }
        let libURL = URL(fileURLWithPath: libPath, isDirectory: true)

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

        let manuscript = ManuscriptShaper.manuscript(body: body, target: target)
        try Data(manuscript.utf8).write(
            to: destinationURL,
            options: .atomic
        )

        return destinationURL
    }

    /// The number of characters the target counts for one chapter.
    ///
    /// = `nil` when the chapter cannot be found, = so the panel can
    /// say nothing rather than say a wrong number. = The count comes
    /// from the same resolver the export uses, = so the number on the
    /// panel is the number the exported file carries.
    func manuscriptWordCount(
        id chapterID: UUID?,
        target: ManuscriptTarget
    ) async -> Int? {
        guard let chapterID else { return nil }
        guard let libPath = ActiveLibrary.path else { return nil }
        let libURL = URL(fileURLWithPath: libPath, isDirectory: true)
        guard let chaptersDir = try? locateChaptersDirectory(
            libraryURL: libURL,
            chapterID: chapterID
        ) else { return nil }
        guard let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
            id: chapterID,
            chaptersDirectory: chaptersDir
        ) else { return nil }
        return ManuscriptShaper.wordCount(of: body)
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

// MARK: - Frontmatter

//
// The `ChapterFrontmatter` type this file once named (= and the
// `Domain/CrossRefInject_v2.swift` file it lived in) = is GONE from
// the tree: = a commit deleted the production types only tests
// reached. = So nothing in the app writes a YAML frontmatter header
// into a chapter's body any more. = A body can still CARRY one
// (= the import path takes "optional frontmatter + free markdown
// body", = `ImportServiceTitleOnlyHelpers.swift:51`), = and the
// Markdown export keeps it verbatim (= the editor's round trip). = The
// MANUSCRIPT export strips it: = a submission carries the author's
// words, = not the file's metadata (= `ManuscriptShaper`).
