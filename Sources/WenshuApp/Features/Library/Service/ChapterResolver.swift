//
//  ChapterResolver.swift · Wenshu
//
//  One reader for the `chapters/` folder.
//
//  `chapters/` has two writers and two contracts:
//
//  1. The chapter actor writes `<uuid>.md` and maintains a row in the
//     folder's index file.
//  2. The import writes `<title>.md` and touches no index.
//
//  The user's promoted drafts land in `chapters/` too, carrying their
//  row in `drafts.json` (= the row follows the file only when the
//  actor rewrites it).
//
//  So the folder on disk holds the truth, and the index holds at
//  best a partial view of it. A reader that consults only the index
//  therefore reports chapters the user cannot see:
//
//  - the book card grid scans the directory (= it shows every
//    chapter, indexed or not);
//  - the export read the index (= it dropped every imported chapter
//    and every promoted draft).
//
//  Two readers of one folder, two answers. The user saw the chapter
//  in the app and the export did not carry it.
//
//  This resolver is the single reader both surfaces use. It scans the
//  directory for the files (= the truth) and consults the index only
//  to enrich a file that already exists (= the index cannot add a
//  chapter that has no body, and cannot hide one that does).
//
//  Body text is read from the file's OWN name, not from `<id>.md`.
//  An index row's id and a file's name are independent: the import
//  names files after the chapter title, and the actor names them
//  after the id. Reading the body by id found nothing for every
//  imported chapter.
//

import Foundation

/// One chapter resolved from the `chapters/` folder.
struct ResolvedChapter: Identifiable, Sendable {
    /// The document's identity. For an indexed file this is the index
    /// row's id (= the actor's id). For an unindexed file it is
    /// derived from the file's path (= stable across reads, so the
    /// export sheet's selection survives a reload).
    let id: UUID
    /// The chapter's title (= the index row's title when the file is
    /// indexed; = the file's first heading, else its name without the
    /// extension).
    let title: String
    /// The file that holds the body.
    let fileURL: URL
    /// The chapter's body text (= read from `fileURL`).
    let body: String
}

enum ChapterResolver {

    /// Resolve every chapter in a book's `chapters/` folder.
    ///
    /// - Parameters:
    ///   - bookId: the book's id (= the owner of every resolved
    ///     document).
    ///   - chaptersDirectory: the `chapters/` folder.
    ///   - indexURL: the folder's index file (= `chapters.json`). The
    ///     index is optional: a book whose chapters were all imported
    ///     has no index at all.
    /// - Returns: one entry per `.md` file in the folder. The
    ///   chapters the index describes come first, = in the index's
    ///   order (= the order the user created them in); = the imported
    ///   ones, = which no index describes, = follow by file name.
    static func resolveChapters(
        bookId: UUID,
        chaptersDirectory: URL,
        indexURL: URL
    ) -> [ResolvedChapter] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: chaptersDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        // The index, keyed by the file name it describes (= the index
        // row's id names its file, = `<id>.md`).
        //
        // The index's OWN order is kept, = because that order is the
        // order the writer appended the rows in, = which is the order
        // the user created the chapters in. = Sorting the whole set
        // by file name would reorder every chapter of every book
        // whose files are named after their ids, = because a uuid
        // sorts by nothing a reader recognises.
        let indexedRows: [Document] = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: chaptersDirectory.deletingLastPathComponent(),
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        var indexedByFileName: [String: Document] = [:]
        var indexOrder: [String: Int] = [:]
        for (position, row) in indexedRows.enumerated() {
            indexedByFileName[row.filename] = row
            indexOrder[row.filename] = position
        }

        var resolved: [ResolvedChapter] = []
        for url in entries where url.pathExtension.lowercased() == "md" {
            let fileName = url.lastPathComponent
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let indexRow = indexedByFileName[fileName]

            resolved.append(ResolvedChapter(
                id: indexRow?.id ?? derivedId(bookId: bookId, fileURL: url),
                title: indexRow?.title ?? titleFromBody(body, fallbackFileName: fileName),
                fileURL: url,
                body: body
            ))
        }

        // The order a book reads in:
        //
        // - The chapters the index describes come first, = in the
        //   index's order, = which is the order the user created
        //   them in.
        // - The chapters the index does not describe (the imported
        //   ones, = whose files carry no index row) follow, = by
        //   file name, = so their order is at least stable.
        //
        // The imported chapters cannot be placed in creation order,
        // = because nothing records it: = the import writes the file
        // and touches no index. = Sorting by file name is the honest
        // answer, = and it is stable.
        return resolved.sorted { lhs, rhs in
            let lhsFile = lhs.fileURL.lastPathComponent
            let rhsFile = rhs.fileURL.lastPathComponent
            let lhsIndex = indexOrder[lhsFile]
            let rhsIndex = indexOrder[rhsFile]
            switch (lhsIndex, rhsIndex) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhsFile < rhsFile
            }
        }
    }

    // MARK: - Identity

    /// A stable id for a file the index does not describe.
    ///
    /// The card grid derives its ids the same way (= a hash of the
    /// path), so the same file carries the same id on both surfaces.
    /// A random id would change on every read, and the export sheet's
    /// chapter selection would reset each time the sheet reloads.
    private static func derivedId(bookId: UUID, fileURL: URL) -> UUID {
        BookDocIDFactory.make(
            bookId: bookId,
            folderName: fileURL.deletingLastPathComponent().lastPathComponent,
            fileName: fileURL.lastPathComponent
        )
    }

    // MARK: - Title

    /// The title of a file the index does not describe.
    ///
    /// The first heading wins (= the chapter's own name, as the card
    /// grid shows it); = the file's name without the extension is the
    /// fallback (= an untitled file still reads as something).
    private static func titleFromBody(_ body: String, fallbackFileName: String) -> String {
        let fallback = (fallbackFileName as NSString).deletingPathExtension
        for line in body.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("# ") {
                let heading = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !heading.isEmpty { return heading }
            }
        }
        return fallback
    }
}
