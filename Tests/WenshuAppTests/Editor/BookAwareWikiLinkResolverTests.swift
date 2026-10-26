//
//  BookAwareWikiLinkResolverTests.swift · Wenshu
//
//  Behavior tests for `BookAwareWikiLinkResolver` (= the resolver the
//  editor hands to the markdown engine).
//
//  Why it exists: the engine makes a wiki link clickable only when
//  the resolver says the target exists. A link into the open book
//  (= the index an import writes) had no answer, = so it stayed
//  grey and the click never reached the app. This resolver answers
//  for the book and falls through to the library for everything
//  else (= the library's own links keep behaving exactly as before).
//
//  Coverage (= 5 tests):
//   1. `resolverResolvesADocumentInsideTheBook`
//   2. `resolverNamesTheBookDocumentBackFromItsID`
//   3. `resolverFallsThroughToTheLibraryForALibraryName`
//   4. `resolverAnswersNothingForAnUnknownName`
//   5. `resolverFingerprintChangesWithTheBook`
//
//  Mock strategy: no mock framework. The library half is a tiny
//  in-file stub that satisfies `WikiLinkResolver`; the book half is a
//  real directory tree in a temporary location.
//

import Foundation
import MarkdownEngine
import Testing

@testable import WenshuApp

/// The library half of the resolver (= answers for one known name).
private struct StubLibraryResolver: WikiLinkResolver {
    let known: String
    let id: String

    func resolve(displayName: String, range: NSRange) -> WikiLinkResolution? {
        displayName == known
            ? WikiLinkResolution(id: id, exists: true)
            : nil
    }

    func name(forID id: String) -> String? {
        id == self.id ? known : nil
    }
}

@Suite("BookAwareWikiLinkResolver — a link into the open book")
struct BookAwareWikiLinkResolverTests {

    private func makeBook() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-book-resolver-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("world"),
            withIntermediateDirectories: true
        )
        try "# core".write(
            to: root.appendingPathComponent("world/core.md"),
            atomically: true,
            encoding: .utf8
        )
        return root
    }

    @Test("a document inside the book resolves")
    func resolverResolvesADocumentInsideTheBook() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let resolver = BookAwareWikiLinkResolver(
            library: StubLibraryResolver(known: "a-library-entry", id: "lib-1"),
            bookDirectory: root
        )

        let resolution = resolver.resolve(displayName: "core", range: NSRange(location: 0, length: 0))

        #expect(resolution?.exists == true)
        #expect(resolution?.id == "world/core.md")
    }

    @Test("the book's id names the document back")
    func resolverNamesTheBookDocumentBackFromItsID() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let resolver = BookAwareWikiLinkResolver(
            library: StubLibraryResolver(known: "a-library-entry", id: "lib-1"),
            bookDirectory: root
        )

        #expect(resolver.name(forID: "world/core.md") == "core")
    }

    @Test("a library name still resolves through the library")
    func resolverFallsThroughToTheLibraryForALibraryName() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let resolver = BookAwareWikiLinkResolver(
            library: StubLibraryResolver(known: "a-library-entry", id: "lib-1"),
            bookDirectory: root
        )

        let resolution = resolver.resolve(
            displayName: "a-library-entry",
            range: NSRange(location: 0, length: 0)
        )

        #expect(resolution?.exists == true)
        #expect(resolution?.id == "lib-1")
    }

    @Test("an unknown name has no answer")
    func resolverAnswersNothingForAnUnknownName() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let resolver = BookAwareWikiLinkResolver(
            library: StubLibraryResolver(known: "a-library-entry", id: "lib-1"),
            bookDirectory: root
        )

        #expect(resolver.resolve(displayName: "nowhere", range: NSRange(location: 0, length: 0)) == nil)
    }

    @Test("the fingerprint follows the book")
    func resolverFingerprintChangesWithTheBook() throws {
        let root = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let resolver = BookAwareWikiLinkResolver(
            library: StubLibraryResolver(known: "a-library-entry", id: "lib-1"),
            bookDirectory: root
        )
        let before = resolver.fingerprint()

        try "# more".write(
            to: root.appendingPathComponent("world/more.md"),
            atomically: true,
            encoding: .utf8
        )
        let after = BookAwareWikiLinkResolver(
            library: StubLibraryResolver(known: "a-library-entry", id: "lib-1"),
            bookDirectory: root
        ).fingerprint()

        #expect(before != after)
    }
}
