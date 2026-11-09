//
//  ChapterResolverTests.swift · Wenshu
//
//  The chapters a book exports.
//
//  `chapters/` has two writers with two contracts: the chapter actor
//  writes `<uuid>.md` and maintains an index row; the import writes
//  `<title>.md` and no row at all. The reader that consulted only the
//  index therefore reported chapters the user could see in the card
//  grid and the export did not carry.
//
//  These tests pin the reader to the folder on disk.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterResolver · the chapters a book exports")
struct ChapterResolverTests {
    // MARK: - Helpers

    /// A book's `chapters/` folder under a temp root.
    private static func makeBook() throws -> (bookId: UUID, chaptersDir: URL, indexURL: URL) {
        let bookId = UUID()
        let root = URL(fileURLWithPath: "/tmp/wenshu-chapter-resolver-\(UUID().uuidString)", isDirectory: true)
        let chaptersDir = root.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        return (bookId, chaptersDir, root.appendingPathComponent("chapters.json"))
    }

    private static func write(_ body: String, to url: URL) throws {
        try body.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Write an index row the way the actor does (= the row's id
    /// names the file, = `<id>.md`).
    private static func writeIndex(
        _ documents: [Document],
        to indexURL: URL
    ) throws {
        let data = try JSONEncoder().encode(documents)
        try data.write(to: indexURL)
    }

    // MARK: - The imported chapter

    @Test("an imported chapter (= a file with no index row) is resolved")
    func importedChapterIsResolved() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        // The import's shape: = a title-named file, = no index file at
        // all.
        try Self.write(
            "# 赤壁之战\n\n建安十三年。",
            to: chaptersDir.appendingPathComponent("赤壁之战.md")
        )

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(resolved.count == 1, "the imported chapter must be resolved")
        #expect(resolved[0].title == "赤壁之战", "the title comes from the heading")
        #expect(resolved[0].body.contains("建安十三年"), "the body must be the file's text")
    }

    @Test("an imported chapter's body is read from its own file, not from `<id>.md`")
    func importedChapterBodyComesFromItsFile() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        try Self.write(
            "# 章节正文\n\n唯一的一段。",
            to: chaptersDir.appendingPathComponent("章节正文.md")
        )

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(resolved.count == 1)
        #expect(
            resolved[0].body.contains("唯一的一段"),
            "the body must be the file's text; = a reader that looked up `<id>.md` found nothing here"
        )
    }

    // MARK: - The indexed chapter

    @Test("an indexed chapter keeps its index row's id and title")
    func indexedChapterKeepsItsIdentity() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        let chapterId = UUID()
        let fileURL = chaptersDir.appendingPathComponent("\(chapterId.uuidString).md")
        try Self.write("# 第一章\n\n正文。", to: fileURL)
        try Self.writeIndex(
            [Document(id: chapterId, bookId: bookId, category: .chapter, title: "第一章")],
            to: indexURL
        )

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(resolved.count == 1)
        #expect(resolved[0].id == chapterId, "an indexed chapter keeps the actor's id")
        #expect(resolved[0].title == "第一章", "an indexed chapter keeps the index's title")
    }

    // MARK: - Both kinds together

    @Test("indexed and imported chapters are resolved together")
    func bothKindsAreResolved() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        let chapterId = UUID()
        try Self.write(
            "# 第一章\n\n正文。",
            to: chaptersDir.appendingPathComponent("\(chapterId.uuidString).md")
        )
        try Self.write(
            "# 第二章\n\n导入的正文。",
            to: chaptersDir.appendingPathComponent("第二章.md")
        )
        try Self.writeIndex(
            [Document(bookId: bookId, category: .chapter, title: "第一章")],
            to: indexURL
        )

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(resolved.count == 2, "both chapters must be resolved; = got \(resolved.count)")
        #expect(
            resolved.map(\.title) == ["第一章", "第二章"],
            "the chapters must come back in file-name order"
        )
    }

    // MARK: - The index cannot invent or hide chapters

    @Test("an index row without a body file adds no chapter")
    func anIndexRowWithoutAFileAddsNoChapter() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        // The row exists; the file does not.
        try Self.writeIndex(
            [Document(bookId: bookId, category: .chapter, title: "幽灵章节")],
            to: indexURL
        )

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(
            resolved.isEmpty,
            "an index row with no body file is not a chapter; = it would export as an empty page"
        )
    }

    @Test("a non-markdown file in the folder is not a chapter")
    func nonMarkdownFilesAreIgnored() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        try Self.write("not a chapter", to: chaptersDir.appendingPathComponent("notes.txt"))

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(resolved.isEmpty, "only `.md` files are chapters")
    }

    // MARK: - Stability

    @Test("an unindexed chapter's id is stable across reads")
    func unindexedChapterIdIsStable() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        try Self.write("# 稳定\n\n正文。", to: chaptersDir.appendingPathComponent("稳定.md"))

        let first = ChapterResolver.resolveChapters(
            bookId: bookId, chaptersDirectory: chaptersDir, indexURL: indexURL
        )
        let second = ChapterResolver.resolveChapters(
            bookId: bookId, chaptersDirectory: chaptersDir, indexURL: indexURL
        )

        #expect(first.count == 1 && second.count == 1)
        #expect(
            first[0].id == second[0].id,
            "the id must not change between reads; = the export sheet's chapter selection would reset"
        )
    }

    @Test("an empty folder resolves to no chapters")
    func emptyFolderResolvesToNothing() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId, chaptersDirectory: chaptersDir, indexURL: indexURL
        )
        #expect(resolved.isEmpty)
    }

    @Test("a missing folder resolves to no chapters")
    func missingFolderResolvesToNothing() {
        let bookId = UUID()
        let root = URL(fileURLWithPath: "/tmp/wenshu-chapter-resolver-missing-\(UUID().uuidString)", isDirectory: true)
        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: root.appendingPathComponent("chapters", isDirectory: true),
            indexURL: root.appendingPathComponent("chapters.json")
        )
        #expect(resolved.isEmpty)
    }

    // MARK: - The order

    @Test("the chapters the index describes keep the index's order (= the order they were created in)")
    func indexedChaptersKeepTheIndexOrder() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()

        // Three actor-written chapters, = named after their ids, = and
        // their ids are chosen so that the UUID order is NOT the
        // creation order. = Otherwise this test would pass for the
        // wrong reason.
        let first = try #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001"))
        let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let third = try #require(UUID(uuidString: "88888888-0000-0000-0000-000000000003"))

        for id in [first, second, third] {
            try Self.write("# Chapter \(id.uuidString)", to: chaptersDir.appendingPathComponent("\(id.uuidString).md"))
        }
        try Self.writeIndex([
            Document(id: first, bookId: bookId, category: .chapter, title: "First"),
            Document(id: second, bookId: bookId, category: .chapter, title: "Second"),
            Document(id: third, bookId: bookId, category: .chapter, title: "Third"),
        ], to: indexURL)

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        // The file names sort as third, second, first (= the uuid
        // order); = the index says first, second, third. = A reader
        // that sorts by file name would reorder the book.
        #expect(resolved.map(\.title) == ["First", "Second", "Third"])
    }

    @Test("an imported chapter follows the indexed ones, = and the imported ones keep a stable order among themselves")
    func importedChaptersFollowTheIndexedOnes() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()

        let indexed = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        try Self.write("# Indexed", to: chaptersDir.appendingPathComponent("\(indexed.uuidString).md"))
        try Self.writeIndex([
            Document(id: indexed, bookId: bookId, category: .chapter, title: "Indexed"),
        ], to: indexURL)

        // Two imported chapters, = title-named, = no index row.
        try Self.write("# Imported A", to: chaptersDir.appendingPathComponent("Imported A.md"))
        try Self.write("# Imported B", to: chaptersDir.appendingPathComponent("Imported B.md"))

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(resolved.count == 3)
        // The indexed chapter leads, = because the user created it
        // through the app. = The imported ones follow.
        #expect(resolved.first?.title == "Indexed")
        #expect(resolved.map(\.title).dropFirst() == ["Imported A", "Imported B"])
    }

    // MARK: - The file the export writes

    /// An imported chapter's file is ITS OWN file, = not `<id>.md`.
    ///
    /// = The import names a file after the chapter's title, = so the
    /// id's file name does not exist. = This is the fact the export
    /// depends on: = a reader that rebuilt the name from the id would
    /// find nothing.
    @Test("an imported chapter's file is its own file, not `<id>.md`")
    func importedChapterFileIsItsOwnFile() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        let chapterFile = chaptersDir.appendingPathComponent("赤壁之战.md")
        try Self.write("# 赤壁之战\n\n建安十三年。", to: chapterFile)

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        #expect(resolved.count == 1)
        #expect(
            resolved[0].fileURL.standardizedFileURL == chapterFile.standardizedFileURL,
            "the resolved file must be the file on disk (= the import named it after the title)"
        )
        #expect(
            resolved[0].fileURL.lastPathComponent != "\(resolved[0].id.uuidString).md",
            "the resolved file must not be a name rebuilt from the id (= an imported chapter has none)"
        )
    }

    /// The export sheet's selection hands over the resolver's FILE.
    ///
    /// = The selection is where the imported chapter's identity lives,
    /// = and the rule is that the file comes from the resolver and = =
    /// NOT from the id's file name. = So a sheet that rebuilt the name
    /// would export nothing: = the file it named does not exist.
    ///
    /// MUTATION: = rebuild the name from the id
    /// (= `chaptersDirectory.appendingPathComponent("\(id).md")`) = =
    /// would hand over a file that does not exist, = and this test
    /// goes red.
    @Test("the sheet's selection hands over the resolver's own file")
    func theSelectionHandsOverTheResolversFile() throws {
        let (bookId, chaptersDir, indexURL) = try Self.makeBook()
        let chapterFile = chaptersDir.appendingPathComponent("我的第一章.md")
        try Self.write("# 我的第一章\n\n第一段。", to: chapterFile)

        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )
        #expect(resolved.count == 1)
        let chapter = resolved[0]

        let selected = ResolvedChapter.fileURL(for: chapter.id, in: resolved)

        #expect(
            selected?.standardizedFileURL == chapterFile.standardizedFileURL,
            "the sheet must hand over the file the resolver gave (= the imported chapter's own file)"
        )
        #expect(
            selected?.lastPathComponent == "我的第一章.md",
            "the handed-over file must be the chapter's own, = and not a name rebuilt from the id"
        )
    }

    /// With nothing selected, = the export has no file to write.
    @Test("no selection = no file for the export")
    func noSelectionMeansNoFile() {
        let chapter = ResolvedChapter(
            id: UUID(),
            title: "某章",
            fileURL: URL(fileURLWithPath: "/tmp/某章.md"),
            body: "正文。"
        )
        #expect(ResolvedChapter.fileURL(for: nil, in: [chapter]) == nil)
        #expect(ResolvedChapter.fileURL(for: UUID(), in: [chapter]) == nil)
    }

    /// The SHEET hands the seam's file over, = and does not rebuild the
    /// name from the id.
    ///
    /// = The seam itself is pinned above (= = mutating
    /// `ResolvedChapter.fileURL` turns that suite red), = = but nothing
    /// drove the SHEET's own line: = = the sheet could stop calling the
    /// seam and rebuild `<id>.md` instead, = = and the export would
    /// write nothing for an imported chapter again (= = the original
    /// defect), = = with no test failing.
    ///
    /// MUTATION: = `ExportSheet.swift` rebuilds the name from the id
    /// (= `chaptersDirectory.appendingPathComponent("\(id).md")`) = =
    /// leaves this assertion red.
    @Test("the sheet hands over the resolver's file, = and does not rebuild the name")
    func theSheetHandsOverTheResolversFile() throws {
        // = = ⇒ THE SHEET IS A GROUP NOW, = = = = and the mutation this
        // = = = = assertion holds must be caught in EITHER file: = = = =
        // = = = = the sheet's own code and the save panel that runs the
        // = = = = export both live under the `ExportSheet` stem, = = = =
        // = = = = and a reader that took only the parent would answer
        // = = = = about half of what it is about.
        let source = try SourceLocator.readGroup(prefixed: "ExportSheet")
        let sheet = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
            .joined(separator: "\n")

        #expect(
            sheet.contains("ResolvedChapter.fileURL(for: selectedChapterID, in: chapters)"),
            "the sheet must hand the export the file the resolver gave (= an imported chapter's own file)"
        )
        #expect(
            !sheet.contains("appendingPathComponent(\"\\(selectedChapterID"),
            "the sheet must not rebuild the file name from the id (= an imported chapter is named after its title)"
        )
    }
}
