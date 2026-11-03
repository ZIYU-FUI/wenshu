//
//  ChapterFileReader.swift
//  WenshuBoard
//
//  Where a chapter actually comes from.
//
//  The file tier is the truth. The SwiftData chapter row exists, is in the
//  schema, and holds zero rows on a live library (= the store that would
//  populate it is never instantiated in production, and the table it would
//  populate is the one the migrations left empty). The body of a chapter is a
//  Markdown file under the book's `chapters/` folder, and the index beside
//  it is a `chapters.json` whose writer and reader disagree about the shape.
//
//  So the client reads the files. It does not depend on a row that nothing
//  writes, and it does not depend on an index that decodes to an empty list.
//

import Foundation

/// One chapter, read from the file tier.
public struct ChapterFile: Hashable, Sendable {

    /// The file name without its extension. The chapter's identity in the file
    /// tier, and what a wiki link carries.
    public var id: String
    /// The chapter's own title: the first level-one heading, or the file name
    /// when the body has no heading.
    public var title: String
    /// The body, verbatim.
    public var markdown: String
    /// The file's modification date.
    public var modifiedAt: Date?

    public init(id: String, title: String, markdown: String, modifiedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.markdown = markdown
        self.modifiedAt = modifiedAt
    }
}

/// Reads a book's chapters from the `.ws` file tier.
public enum ChapterFileReader {

    /// The folder inside a book directory that holds the chapter bodies.
    public static let chaptersFolderName = "chapters"

    /// Every chapter body file in a book directory, in file-name order.
    ///
    /// The order is the file name's, and it is stated rather than implied:
    /// the file name is a UUID, so this is UUID order, and the desktop app's
    /// own document list is sorted by the document's last update, newest
    /// first. The two do not agree, and that is a fact about the library
    /// rather than a defect in the reader.
    public static func readChapters(inBookDirectory bookDirectory: URL) throws -> [ChapterFile] {
        let folder = bookDirectory.appendingPathComponent(chaptersFolderName)
        guard FileManager.default.fileExists(atPath: folder.path) else {
            // A book with no chapters folder has no chapters. That is a fact
            // about the book, not a structural error, so it is not thrown.
            return []
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
        return names.compactMap { name in
            let url = folder.appendingPathComponent(name)
            guard let markdown = try? String(contentsOf: url, encoding: .utf8) else {
                return nil
            }
            let id = String(name.dropLast(".md".count))
            return ChapterFile(
                id: id,
                title: title(in: markdown, fallback: id),
                markdown: markdown,
                modifiedAt: try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            )
        }
    }

    /// The first level-one heading of a body, or the fallback.
    ///
    /// The heading is looked for in the WHOLE body, not in its first line: a
    /// chapter that opens with a paragraph still has its title, and the
    /// desktop app reads it the same way.
    public static func title(in markdown: String, fallback: String) -> String {
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.hasPrefix("# ") else { continue }
            let heading = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if !heading.isEmpty { return heading }
        }
        return fallback
    }
}
