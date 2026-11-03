//
//  ChapterFileReaderTests.swift
//  WenshuBoardTests
//
//  The file tier is where a chapter actually lives, so the reader is what the
//  client depends on. These tests build a real `.ws`-shaped book directory on
//  disk and read it back.
//

import Foundation
import Testing
@testable import WenshuBoardKit

@Suite("Reading chapters from the file tier")
struct ChapterFileReaderTests {

    /// A book directory with a `chapters/` folder and the given files.
    private func makeBook(files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-board-test-\(UUID().uuidString)")
        let chapters = root.appendingPathComponent(ChapterFileReader.chaptersFolderName)
        try FileManager.default.createDirectory(at: chapters, withIntermediateDirectories: true)
        for (name, body) in files {
            try body.write(to: chapters.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return root
    }

    @Test("A chapter file becomes a chapter with its own id and title")
    func readsAChapter() throws {
        let book = try makeBook(files: ["1111.md": "# The First Chapter\n\n## Beat one\n"])
        defer { try? FileManager.default.removeItem(at: book) }
        let chapters = try ChapterFileReader.readChapters(inBookDirectory: book)
        #expect(chapters.count == 1)
        #expect(chapters[0].id == "1111")
        #expect(chapters[0].title == "The First Chapter")
        #expect(chapters[0].markdown.contains("Beat one"))
    }

    @Test("The chapters come back in file-name order, and the order is the file name's")
    func ordersByFileName() throws {
        let book = try makeBook(files: ["b.md": "b", "a.md": "a", "c.md": "c"])
        defer { try? FileManager.default.removeItem(at: book) }
        let chapters = try ChapterFileReader.readChapters(inBookDirectory: book)
        #expect(chapters.map(\.id) == ["a", "b", "c"])
    }

    @Test("A file with no heading takes its file name as its title")
    func fallsBackToTheFileName() throws {
        let book = try makeBook(files: ["abc.md": "no heading here"])
        defer { try? FileManager.default.removeItem(at: book) }
        let chapters = try ChapterFileReader.readChapters(inBookDirectory: book)
        #expect(chapters[0].title == "abc")
    }

    @Test("A file that is not Markdown is not a chapter")
    func ignoresOtherFiles() throws {
        let book = try makeBook(files: ["a.md": "a", "notes.txt": "nope"])
        defer { try? FileManager.default.removeItem(at: book) }
        let chapters = try ChapterFileReader.readChapters(inBookDirectory: book)
        #expect(chapters.map(\.id) == ["a"])
    }

    @Test("A chapter file becomes a board and a column of cards")
    func chapterBecomesBoardAndCards() throws {
        let book = try makeBook(files: ["1111.md": "# The Chapter\n\n## Beat one\n\n## Beat two\n"])
        defer { try? FileManager.default.removeItem(at: book) }
        let file = try #require(try ChapterFileReader.readChapters(inBookDirectory: book).first)
        let board = ChapterColumnBuilder.board(for: file)
        #expect(board.kind == .board)
        #expect(board.content.title == "The Chapter")
        let cards = ChapterColumnBuilder.cards(for: file)
        #expect(cards.count == 2)
        #expect(cards.map(\.content.title) == ["Beat one", "Beat two"])
        #expect(cards.allSatisfy { $0.location.parentID == "1111" })
        #expect(cards.map(\.orderKey) == [0, 65_536])
    }

    @Test("A book with no chapters folder reads as no chapters")
    func emptyBook() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-board-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try ChapterFileReader.readChapters(inBookDirectory: root).isEmpty)
    }
}


@Suite("A chapter's title")
struct ChapterTitleTests {

    @Test("The title is the first level-one heading, wherever it is")
    func titleIsFoundAnywhere() {
        // The desktop app scans every line for the heading, so a chapter
        // that opens with a paragraph still has its title on both sides.
        #expect(
            ChapterFileReader.title(in: "a preamble\n\n# The Real Title\n\n## First\n", fallback: "ch-1")
                == "The Real Title"
        )
    }

    @Test("A body with no level-one heading takes the fallback")
    func titleFallsBack() {
        #expect(ChapterFileReader.title(in: "## Only a subheading\n", fallback: "ch-1") == "ch-1")
    }
}
