// DocumentTests.swift · Wenshu (Wenshu) · v0.03.0 (document module)
//
// v53 (= boss 8/15 17:48 '在第二栏里, 显示书的所有章节, 设定, 资料库, 这
// 里的文档需要分类'): the second column of the layout becomes a card
// grid (= FCP Browser filmstrip pattern) of MD documents grouped by
// category. Each card displays the document's title + an auto-
// extracted summary (= the first ~100 chars of the MD body), so the
// user can browse their work without opening every file.
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The shape of Document is locked by these tests. If Document's
// fields, identity, or Codable strategy change, these tests fail and
// force the architectural decision to surface.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Document")
struct DocumentTests {

    @Test("id is non-nil and stable across round-trips")
    func idIsStable() throws {
        let id = UUID()
        let bookId = UUID()
        let doc = Document(
            id: id,
            bookId: bookId,
            category: .chapter,
            title: "第一章",
            byteSize: 1024,
            summary: "一个孤独的旅人...",
            createdAt: .now,
            updatedAt: .now
        )
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(Document.self, from: data)
        #expect(decoded.id == id)
    }

    @Test("Equatable: same id = same document, even if title or category change")
    func equalityById() {
        let id = UUID()
        let bookId = UUID()
        let a = Document(
            id: id, bookId: bookId, category: .chapter,
            title: "Foo", byteSize: 100, summary: "x",
            createdAt: .now, updatedAt: .now
        )
        let b = Document(
            id: id, bookId: bookId, category: .setting,
            title: "Bar", byteSize: 200, summary: "y",
            createdAt: .now, updatedAt: .now
        )
        #expect(a == b)
    }

    @Test("Identifiable: id used as SwiftUI List selection")
    func identifiable() {
        let id = UUID()
        let doc = Document(
            id: id, bookId: UUID(), category: .research,
            title: "X", byteSize: 0, summary: "",
            createdAt: .now, updatedAt: .now
        )
        #expect(doc.id == id)
    }

    @Test("filename = id.uuidString + .md (= Apple HIG document-based: id = filesystem identity)")
    func filename() {
        let id = UUID()
        let doc = Document(
            id: id, bookId: UUID(), category: .chapter,
            title: "X", byteSize: 0, summary: "",
            createdAt: .now, updatedAt: .now
        )
        #expect(doc.filename == "\(id.uuidString).md")
    }

    // MARK: - BookCategory (v53.1)

    @Test("BookCategory has three cases: chapter / setting / research")
    func bookCategoryThreeCases() {
        let all = BookCategory.allCases
        #expect(all.count == 3)
        #expect(all.contains(.chapter))
        #expect(all.contains(.setting))
        #expect(all.contains(.research))
    }

    @Test("BookCategory.directoryName = the folder name (= Apple HIG: URL = identity)")
    func categoryDirectoryNames() {
        #expect(BookCategory.chapter.directoryName == "chapters")
        #expect(BookCategory.setting.directoryName == "settings")
        #expect(BookCategory.research.directoryName == "research")
    }

    @Test("BookCategory.displayName = Chinese for the card section header")
    func categoryDisplayNames() {
        #expect(BookCategory.chapter.displayName == "章节")
        #expect(BookCategory.setting.displayName == "设定")
        #expect(BookCategory.research.displayName == "资料库")
    }

    @Test("BookCategory.icon = SF Symbol name for the card")
    func categoryIcons() {
        // SF Symbol names (= the card uses Image(systemName:) with these).
        #expect(BookCategory.chapter.icon == "book.closed")
        #expect(BookCategory.setting.icon == "gearshape.2")
        #expect(BookCategory.research.icon == "books.vertical.fill")
    }

    @Test("BookCategory raw value round-trips (= Codable stable JSON keys)")
    func categoryRawValueStable() throws {
        for c in BookCategory.allCases {
            let data = try JSONEncoder().encode(c)
            let decoded = try JSONDecoder().decode(BookCategory.self, from: data)
            #expect(decoded == c)
        }
    }

    @Test("Document with category + summary round-trips through JSON")
    func documentRoundTrip() throws {
        let doc = Document(
            id: UUID(), bookId: UUID(), category: .setting,
            title: "角色表", byteSize: 4096, summary: "主角: 林夕, 18 岁...",
            createdAt: .now, updatedAt: .now
        )
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(Document.self, from: data)
        #expect(decoded == doc)
        #expect(decoded.category == .setting)
        #expect(decoded.byteSize == 4096)
    }
}