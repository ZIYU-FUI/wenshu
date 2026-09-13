//
//  Persistence/WSChapterTests.swift + WSOutlineNodeTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSChapter + WSOutlineNode (= outline @Model)")
struct WSChapterTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSBookShelf.self, WSChapter.self, WSOutlineNode.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSChapter init sets title + position + status")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let ch = WSChapter(id: "ch-001", bookID: "book-1", title: "Chapter 1", position: 0)
        context.insert(ch)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSChapter>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "ch-001")
        #expect(fetched[0].bookID == "book-1")
        #expect(fetched[0].title == "Chapter 1")
        #expect(fetched[0].position == 0)
        #expect(fetched[0].wordCount == 0)
        #expect(fetched[0].status == "draft")
    }

    @Test("WSOutlineNode init sets title + parentID")
    @MainActor
    func outlineInitSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let root = WSOutlineNode(id: "n-root", chapterID: "ch-1", title: "Root", lineNumber: 1)
        context.insert(root)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSOutlineNode>())
        #expect(fetched.count == 1)
        #expect(fetched[0].title == "Root")
        #expect(fetched[0].parentID == nil)
    }

    @Test("WSOutlineNode recursive children (= 2-level tree)")
    @MainActor
    func outlineRecursiveChildren() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let root = WSOutlineNode(id: "root", chapterID: "ch-1", title: "Root")
        let child = WSOutlineNode(id: "child", chapterID: "ch-1", title: "Child", parentID: "root")
        context.insert(root)
        context.insert(child)
        child.parent = root
        try context.save()
        #expect(root.children.count == 1)
        #expect(root.children.first?.id == "child")
        #expect(child.parent?.id == "root")
    }

    @Test("WSOutlineNode id uniqueness enforced")
    @MainActor
    func outlineIDUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSOutlineNode(id: "same", chapterID: "ch", title: "a")
        let b = WSOutlineNode(id: "same", chapterID: "ch", title: "b")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
