//
//  PreviewPaneOpsTests.swift · Wenshu · v1.75 preview-pane-mvvm T1a
//
//  Behavior + source-level tests for `PreviewPaneOps`
//  (= the stateless enum extracted from PreviewPane;
//  = the largest P0 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Coverage (= 11 tests):
//    1.  fileExistsAtCanonicalPath
//    2.  loadAllEntities returns empty LoadEntitiesResult when bookStore is nil
//    3.  loadBooksInShelf returns empty LoadBooksResult when bookStore is nil
//    4.  loadBody returns empty LoadBodyResult when bookStore is nil
//    5.  loadBookDocs returns empty LoadBookDocsResult when bookStore is nil
//    6.  sortBookDocs is a no-op on empty input
//    7.  sortBookDocs preserves count (= no add/remove)
//    8.  sortEntities is a no-op on empty input
//    9.  sortEntities preserves count
//    10. sourceHasSevenPublicStaticFuncs marker
//    11. sourceIsStatelessEnum marker
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 preview-pane-mvvm T1a — PreviewPaneOps (preview-pane business layer)")
@MainActor
struct PreviewPaneOpsTests {

    // MARK: - Path guard

    @Test("PreviewPaneOps.swift exists at the canonical path under UI/Layout/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/UI/Layout/PreviewPaneOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "PreviewPaneOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - nil bookStore paths

    @Test("loadAllEntities returns empty LoadEntitiesResult when bookStore is nil")
    func loadAllEntitiesIgnoresNilBookStore() {
        let r = PreviewPaneOps.loadAllEntities(bookStore: nil)
        #expect(r.entities.isEmpty)
        #expect(r.error != nil)
    }

    @Test("loadBooksInShelf returns empty LoadBooksResult when bookStore is nil")
    func loadBooksInShelfIgnoresNilBookStore() {
        let r = PreviewPaneOps.loadBooksInShelf(bookStore: nil, shelfId: UUID())
        #expect(r.books.isEmpty)
    }

    @Test("loadBody returns empty LoadBodyResult when bookStore is nil")
    func loadBodyIgnoresNilBookStore() {
        let r = PreviewPaneOps.loadBody(bookStore: nil, for: decodeEntities(count: 1)[0])
        #expect(r.body == nil)
    }

    @Test("loadBookDocs returns empty LoadBookDocsResult when bookStore is nil")
    func loadBookDocsIgnoresNilBookStore() {
        let r = PreviewPaneOps.loadBookDocs(bookStore: nil, bookId: UUID(), folderName: nil)
        #expect(r.docs.isEmpty)
    }

    // MARK: - Sort helpers (= pure functions; = testable without bookStore)

    @Test("sortBookDocs is a no-op on empty input")
    func sortBookDocsEmpty() {
        let sorted = PreviewPaneOps.sortBookDocs([], by: .pinyinFirstLetter)
        #expect(sorted.isEmpty)
    }

    @Test("sortBookDocs preserves count (= no add/remove)")
    func sortBookDocsPreservesCount() {
        let docs = [
            BookDoc(
                id: UUID(),
                bookId: UUID(),
                folderName: "drafts",
                fileName: "b.md",
                modifiedAt: Date.distantPast,
                createdAt: Date.distantPast,
                body: "second"
            ),
            BookDoc(
                id: UUID(),
                bookId: UUID(),
                folderName: "drafts",
                fileName: "a.md",
                modifiedAt: Date.distantFuture,
                createdAt: Date.distantFuture,
                body: "first"
            ),
        ]
        let sorted = PreviewPaneOps.sortBookDocs(docs, by: .modifiedAt)
        #expect(sorted.count == docs.count)
    }

    @Test("sortEntities is a no-op on empty input")
    func sortEntitiesEmpty() {
        let sorted = PreviewPaneOps.sortEntities([], by: .pinyinFirstLetter)
        #expect(sorted.isEmpty)
    }

    @Test("sortEntities preserves count on the same entities")
    func sortEntitiesPreservesCount() {
        // Build entities inline via JSON decode path so we don't
        // need to know all Reference init args (Reference has a
        // custom Codable init but synthesised memberwise).
        let entities = decodeEntities(count: 2)
        let sorted = PreviewPaneOps.sortEntities(entities, by: .pinyinFirstLetter)
        #expect(sorted.count == entities.count)
    }

    private func decodeEntities(count: Int) -> [Reference] {
        return (0..<count).map { i in
            // Synthesise minimal Reference from a JSON blob.
            let json = """
            {"id":"\(UUID().uuidString)","title":"title-\(i)","source":null,"url":null,"layer":"layerEntities","category":null,"subcategory":null,"entityType":1,"summary":"","characterRefIds":[],"worldRefIds":[],"bookRefIds":[],"createdAt":0,"updatedAt":0}
            """
            let data = json.data(using: .utf8)!
            return try! JSONDecoder().decode(Reference.self, from: data)
        }
    }

    // MARK: - Source-level markers

    @Test("source-marker: ops file contains 7 public static funcs")
    func sourceHasSevenPublicStaticFuncs() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/UI/Layout/PreviewPaneOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func loadAllEntities"))
        #expect(source.contains("static func loadBooksInShelf"))
        #expect(source.contains("static func loadShelfBooksAsync"))
        #expect(source.contains("static func loadBody"))
        #expect(source.contains("static func loadBookDocs"))
        #expect(source.contains("static func sortBookDocs"))
        #expect(source.contains("static func sortEntities"))
    }

    @Test("ops file is a stateless enum (= no @Observable / @MainActor class)")
    func sourceIsStatelessEnum() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/UI/Layout/PreviewPaneOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum PreviewPaneOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class PreviewPaneOps"))
    }
}