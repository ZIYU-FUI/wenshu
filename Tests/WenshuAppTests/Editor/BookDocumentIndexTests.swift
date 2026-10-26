//
//  BookDocumentIndexTests.swift · Wenshu
//
//  Behavior tests for `BookDocumentIndex` (= the one reader that
//  tells the app which documents a book holds).
//
//  Why it exists: the boss reported (2026-10-26) that clicking an
//  index entry inside a book left the app and opened a browser. The
//  engine rewrites a markdown link's target to `https://<target>`
//  and hands it to the OS, = so only the app's own wiki link can
//  open in the app. Two readers need the same answer then:
//  the wiki-link resolver (= does the target exist?) and the link
//  navigation (= which file does it mean?). `BookDocumentIndex` is
//  that shared answer, so the two cannot disagree.
//
//  Coverage (= 6 tests):
//   1. `indexFindsADocumentByItsFileName`
//   2. `indexFindsADocumentWhenTheNameCarriesTheSuffix`
//   3. `indexMatchesTheNameWithoutCase`
//   4. `indexNamesTheDocumentByItsPathInsideTheBook`
//   5. `indexResolvesAnIDBackToItsDocument`
//   6. `indexIsEmptyWithoutABook`
//
//  Mock strategy: no mock framework (= the filesystem IS the target).
//  A real book tree in a temporary directory (= world/ + characters/).
//

import Foundation
import Testing

@testable import WenshuApp

@Suite("BookDocumentIndex — the documents a book holds")
struct BookDocumentIndexTests {

    /// A book root with one document in `world/` and one in
    /// `characters/`.
    private func makeBook() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-book-index-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("world"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("characters"),
            withIntermediateDirectories: true
        )
        try "# core".write(
            to: root.appendingPathComponent("world/core.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# wanderer".write(
            to: root.appendingPathComponent("characters/wanderer.md"),
            atomically: true,
            encoding: .utf8
        )
        return root
    }

    @Test("a document is found by its file name")
    func indexFindsADocumentByItsFileName() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let index = BookDocumentIndex(bookDirectory: root)

        #expect(index.document(named: "core") != nil)
        #expect(index.document(named: "wanderer") != nil)
    }

    @Test("a document is found when the name carries the suffix")
    func indexFindsADocumentWhenTheNameCarriesTheSuffix() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let index = BookDocumentIndex(bookDirectory: root)

        #expect(index.document(named: "core.md") != nil)
        #expect(index.document(named: "core.md")?.name == "core")
    }

    @Test("the name matches without case")
    func indexMatchesTheNameWithoutCase() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let index = BookDocumentIndex(bookDirectory: root)

        #expect(index.document(named: "CORE") != nil)
        #expect(index.document(named: "Core.md") != nil)
    }

    @Test("a document knows its path inside the book")
    func indexNamesTheDocumentByItsPathInsideTheBook() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let index = BookDocumentIndex(bookDirectory: root)

        #expect(index.document(named: "core")?.relativePath == "world/core.md")
        #expect(index.document(named: "wanderer")?.relativePath == "characters/wanderer.md")
    }

    @Test("the link id names the document too")
    func indexAnswersToTheLinkID() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let index = BookDocumentIndex(bookDirectory: root)

        // The engine asks the resolver twice: with the name the user
        // sees, and with the id it handed back.
        #expect(index.document(named: "world/core.md")?.name == "core")
        #expect(index.document(named: "world/core.md")?.relativePath == "world/core.md")
    }

    @Test("an id resolves back to its document")
    func indexResolvesAnIDBackToItsDocument() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let index = BookDocumentIndex(bookDirectory: root)

        #expect(index.document(withID: "world/core.md")?.name == "core")
        #expect(index.document(withID: "nowhere.md") == nil)
    }

    @Test("no book means no documents")
    func indexIsEmptyWithoutABook() {
        let index = BookDocumentIndex(bookDirectory: nil)

        #expect(index.documents.isEmpty)
        #expect(index.document(named: "core") == nil)
    }
}
