//
//  Persistence/WSBookmarkTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSBookmark (= bookmarks @Model)")
struct WSBookmarkTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSBookmark init sets docID + title")
    @MainActor
    func initWithDoc() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bm = WSBookmark(id: "bm-001", title: "my doc anchor", docID: "doc-42")
        context.insert(bm)
        try context.save()
        #expect(bm.id == "bm-001")
        #expect(bm.docID == "doc-42")
        #expect(bm.bookID == nil)
        #expect(bm.title == "my doc anchor")
        #expect(bm.note == nil)
        #expect(bm.position == 0)
    }

    @Test("WSBookmark init with bookID (= polymorphic anchor)")
    @MainActor
    func initWithBook() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bm = WSBookmark(id: "bm-002", title: "book anchor", bookID: "book-7")
        context.insert(bm)
        try context.save()
        #expect(bm.docID == nil)
        #expect(bm.bookID == "book-7")
    }

    @Test("WSBookmark hasValidAnchor: docID XOR bookID (= exactly one)")
    @MainActor
    func hasValidAnchor() throws {
        // exactly doc → valid
        let bm1 = WSBookmark(id: "1", title: "t", docID: "d")
        #expect(bm1.hasValidAnchor == true)
        // exactly book → valid
        let bm2 = WSBookmark(id: "2", title: "t", bookID: "b")
        #expect(bm2.hasValidAnchor == true)
        // neither → invalid
        let bm3 = WSBookmark(id: "3", title: "t")
        #expect(bm3.hasValidAnchor == false)
    }

    @Test("WSBookmark id uniqueness enforced")
    @MainActor
    func idUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSBookmark(id: "same", title: "a", docID: "d1")
        let b = WSBookmark(id: "same", title: "b", docID: "d2")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
