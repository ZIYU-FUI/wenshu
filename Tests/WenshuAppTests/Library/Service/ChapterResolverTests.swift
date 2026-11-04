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

import Testing
import Foundation
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
    func missingFolderResolvesToNothing() throws {
        let bookId = UUID()
        let root = URL(fileURLWithPath: "/tmp/wenshu-chapter-resolver-missing-\(UUID().uuidString)", isDirectory: true)
        let resolved = ChapterResolver.resolveChapters(
            bookId: bookId,
            chaptersDirectory: root.appendingPathComponent("chapters", isDirectory: true),
            indexURL: root.appendingPathComponent("chapters.json")
        )
        #expect(resolved.isEmpty)
    }
}
