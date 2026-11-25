//
//  BookContinuityReaderTests.swift · Wenshu
//
//  A book, read and checked, and the report it produces.
//
//  The fixtures carry the book's own Chinese lines, = = because the
//  production reader splits on the book's own punctuation and a
//  fixture written in English would not prove the two agree.
//
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("BookContinuityReader (= a book, read and checked)")
struct BookContinuityReaderTests {
    /// A book directory with the given documents and chapters.
    private static func makeBook(
        world: [String: String] = [:],
        characters: [String: String] = [:],
        chapters: [(title: String, body: String)] = []
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-continuity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        for (folder, documents) in [("world", world), ("characters", characters)] {
            guard !documents.isEmpty else { continue }
            let folderDirectory = directory.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(
                at: folderDirectory,
                withIntermediateDirectories: true
            )
            for (name, text) in documents {
                try text.write(
                    to: folderDirectory.appendingPathComponent("\(name).md"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        }
        if !chapters.isEmpty {
            let chaptersDirectory = directory.appendingPathComponent("chapters", isDirectory: true)
            try FileManager.default.createDirectory(
                at: chaptersDirectory,
                withIntermediateDirectories: true
            )
            // The index is written the way the app writes it: = the
            // real `Document` encoded, = = so the fixture cannot drift
            // from the shape the store reads.
            let bookID = UUID(uuidString: directory.lastPathComponent) ?? UUID()
            var index: [Document] = []
            for chapter in chapters {
                let id = UUID()
                try chapter.body.write(
                    to: chaptersDirectory.appendingPathComponent("\(id.uuidString).md"),
                    atomically: true,
                    encoding: .utf8
                )
                index.append(Document(
                    id: id,
                    bookId: bookID,
                    category: .chapter,
                    title: chapter.title,
                    byteSize: chapter.body.utf8.count
                ))
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(index)
            try data.write(to: directory.appendingPathComponent("chapters.json"))
        }
        return directory
    }

    @Test("a book with no documents and no chapters reports nothing")
    func anEmptyBookReportsNothing() throws {
        let directory = try Self.makeBook()
        let report = BookContinuityReader(bookDirectory: directory).report()
        #expect(report.isEmpty)
        #expect(report.worldContext.isEmpty)
        #expect(report.foreshadowContext.isEmpty)
    }

    @Test("a book's chapters produce its broken threads")
    func aBooksChaptersProduceItsBrokenThreads() throws {
        let directory = try Self.makeBook(chapters: [
            (
                "第一章",
                """
                ## 伏笔

                - **埋设**: 左手的旧疤。
                """
            ),
            ("第二章", """
            ## 伏笔

            - **兑现**: 北门下的旧疤，源自第 1 章。
            """),
        ])
        let report = BookContinuityReader(bookDirectory: directory).report()
        #expect(report.brokenThreads.isEmpty)
    }

    @Test("a thread nobody pays off is one break")
    func anUnpaidThreadIsOneBreak() throws {
        let directory = try Self.makeBook(chapters: [
            ("第一章", """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
        ])
        let report = BookContinuityReader(bookDirectory: directory).report()
        #expect(report.brokenThreads.count == 1)
        #expect(report.brokenThreads.first?.chapter == 1)
        #expect(report.brokenThreads.first?.kind == "plant-never-paid-off")
    }

    @Test("a payoff that names a chapter the book does not have is one break")
    func aPayoffNamingAMissingChapterIsOneBreak() throws {
        let directory = try Self.makeBook(chapters: [
            ("第一章", """
            ## 伏笔

            - **兑现**: 北门下的旧疤，源自第 9 章。
            """),
        ])
        let report = BookContinuityReader(bookDirectory: directory).report()
        #expect(report.brokenThreads.count == 1)
        #expect(report.brokenThreads.first?.kind == "payoff-names-a-missing-chapter")
    }

    @Test("a break names the chapter it happens in, so the writer can find it")
    func aBreakNamesItsChapter() throws {
        let directory = try Self.makeBook(chapters: [
            (
                "第一章",
                """
                ## 伏笔

                - **埋设**: 左手的旧疤。
                """
            ),
            ("第二章", """
            ## 伏笔

            - **埋设**: 北门的铜钥匙。
            """),
        ])
        let report = BookContinuityReader(bookDirectory: directory).report()
        #expect(report.foreshadowContext.count == 2)
        #expect(report.foreshadowContext.allSatisfy { $0.contains("chapter ") })
    }

    @Test("a book's documents produce no conflict until a rule names the property")
    func aBooksDocumentsProduceNoConflictWithoutARule() throws {
        // The documents state things, = = but the rules are the
        // caller's, = = and no rule names the property the documents
        // state, = = so the book reports no conflict.
        let directory = try Self.makeBook(world: [
            "张铁牛": """
            # 张铁牛

            - 年龄: 42
            """,
        ])
        let report = BookContinuityReader(bookDirectory: directory).report()
        #expect(report.worldConflicts.isEmpty)
    }

    @Test("two documents about one subject are weighed together")
    func twoDocumentsAboutOneSubjectAreWeighedTogether() throws {
        // A book's world sheet and its character sheet can both be about
        // one subject, = = and the two must be weighed together: = = the
        // subject stays what both documents are about, = = so the kernel
        // sees one subject with two values.
        let directory = try Self.makeBook(
            world: [
                "张铁牛": """
                # 张铁牛

                - 年龄: 42
                """,
            ],
            characters: [
                "张铁牛": """
                # 张铁牛

                - 年龄: 45
                """,
            ]
        )
        let report = BookContinuityReader(bookDirectory: directory).report()
        #expect(report.worldConflicts.count == 1)
        let row = report.worldContext[0]
        #expect(row.contains("张铁牛"))
        // The two claims name the two documents, = = so the writer can
        // open the one that says the other.
        #expect(row.contains("world/张铁牛.md"))
        #expect(row.contains("characters/张铁牛.md"))
    }

    @Test("a claim names the document it came from, so the writer can find it")
    func aClaimNamesItsDocument() throws {
        // Two documents that share a name would give their claims the
        // same name, = = and a report pointing at a name two files hold
        // is a report the writer cannot locate. = = So each claim names
        // the document it came from.
        let directory = try Self.makeBook(
            world: [
                "张铁牛": """
                # 张铁牛

                - 年龄: 42
                """,
            ],
            characters: [
                "张铁牛": """
                # 张铁牛

                - 年龄: 45
                """,
            ]
        )
        let report = BookContinuityReader(bookDirectory: directory).report()
        let row = report.worldContext[0]
        let names = row
            .split(separator: "(")
            .last?
            .trimmingCharacters(in: CharacterSet(charactersIn: " )"))
            .split(separator: ", ")
            .map(String.init) ?? []
        #expect(names.count == 2)
        #expect(Set(names).count == 2)
    }

    @Test("the reader writes nothing")
    func theReaderWritesNothing() throws {
        let directory = try Self.makeBook(world: [
            "张铁牛": """
            # 张铁牛

            - 年龄: 42
            """,
        ], chapters: [
            (
                "第一章",
                """
                ## 伏笔

                - **埋设**: 左手的旧疤。
                """
            ),
        ])
        let before = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        ).sorted()
        _ = BookContinuityReader(bookDirectory: directory).report()
        let after = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        ).sorted()
        #expect(before == after)
    }
}
