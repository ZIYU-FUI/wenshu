//
//  BookLinkNavigationTests.swift · Wenshu
//
//  Behavior tests for the link path that opens a document inside the
//  open book.
//
//  Why it exists: the boss reported (2026-10-26) that clicking an
//  index entry inside a book left the app and opened a browser. The
//  engine rewrites a markdown link's target to `https://<target>`
//  and hands it to the OS, = so the app can only open it when the
//  link names a document the app knows. Two halves make that work:
//
//    1. The navigation finds the document and says which file it is
//       (= so the editor opens the real file, = not a detached copy).
//    2. The world's index writes its links in the form the engine
//       hands to the app (= the app's own wiki link; = a markdown
//       link leaves the app).
//
//  Coverage (= 7 tests):
//   1. `navigationFindsADocumentInsideTheBook`
//   2. `navigationNamesTheDocumentAndItsPath`
//   3. `navigationReturnsNothingForAnUnknownName`
//   4. `navigationReturnsNothingWithoutABook`
//   5. `theWorldIndexWritesItsLinksInTheFormTheAppOpens`
//   6. `theWorldSkeletonDeclaresItsSixMandatoryDocuments`
//   7. `theWorldSkeletonWritesItsLinksInTheFormTheAppOpens`
//
//  Mock strategy: no mock framework. A real book tree in a
//  temporary directory (= the filesystem IS the target).
//

import Foundation
import Testing

@testable import WenshuApp

@Suite("Book link navigation — an index entry opens in the app")
struct BookLinkNavigationTests {

    private func makeBook() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-book-nav-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("world"),
            withIntermediateDirectories: true
        )
        try "# core\n\nthe core of the world".write(
            to: root.appendingPathComponent("world/core.md"),
            atomically: true,
            encoding: .utf8
        )
        return root
    }

    @Test("a document inside the book is found")
    func navigationFindsADocumentInsideTheBook() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = WikiLinkNavigation.lookupInActiveBook(
            name: "core",
            bookDirectory: root,
            bookId: UUID()
        )

        #expect(result != nil)
        #expect(result?.body.contains("the core of the world") == true)
    }

    @Test("the result names the document and its path inside the book")
    func navigationNamesTheDocumentAndItsPath() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = WikiLinkNavigation.lookupInActiveBook(
            name: "core.md",
            bookDirectory: root,
            bookId: UUID()
        )

        #expect(result?.title == "core")
        if case .bookDocument(_, let relativePath) = result?.source {
            #expect(relativePath == "world/core.md")
        } else {
            Issue.record("the result must name the book's document")
        }
    }

    @Test("an unknown name has no result")
    func navigationReturnsNothingForAnUnknownName() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(WikiLinkNavigation.lookupInActiveBook(
            name: "nowhere",
            bookDirectory: root,
            bookId: UUID()
        ) == nil)
    }

    @Test("no book means no result")
    func navigationReturnsNothingWithoutABook() {
        #expect(WikiLinkNavigation.lookupInActiveBook(
            name: "core",
            bookDirectory: nil,
            bookId: nil
        ) == nil)
    }

    @Test("the world index writes its links in the form the app opens")
    func theWorldIndexWritesItsLinksInTheFormTheAppOpens() throws {
        let sop = try SourceLocator.read("Sources/WenshuApp/Resources/SOPs/ImportWorldPrompt.md")

        // The app's own link form (= the engine hands it to the app).
        #expect(sop.contains("[[核心设定.md]]"))
        // The markdown form leaves the app (= the engine turns its
        // target into a web link), = so it must not be in the index.
        #expect(!sop.contains("](核心设定.md)"))
    }

    @Test("the world skeleton still declares its six mandatory documents")
    func theWorldSkeletonDeclaresItsSixMandatoryDocuments() {
        let sections = ImportSOPTrigger.mandatorySections(for: .world)
        let documents = sections.compactMap { section -> String? in
            if case .document(let name) = section { return name }
            return nil
        }

        #expect(documents.count == 6)
        #expect(documents.contains("核心设定.md"))
        #expect(documents.contains("关键场景种子.md"))
    }

    @Test("the world skeleton writes its links in the form the app opens")
    func theWorldSkeletonWritesItsLinksInTheFormTheAppOpens() throws {
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Agent/Service/ImportDocumentTemplateSkeletons.swift")

        #expect(source.contains("[[核心设定.md]]"))
        #expect(!source.contains("](核心设定.md)"))
    }
}
