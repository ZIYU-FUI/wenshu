// DocumentTests.swift · Wenshu (Wenshu) · v0.03.0 (document module)
//
// v53 (= 8/15 17:48 ', show,,,
// need'): the second column of the layout becomes a card
// grid (= FCP Browser filmstrip pattern) of MD documents grouped by
// category. Each card displays the document's title + an auto-
// extracted summary (= the first ~100 chars of the MD body), so the
// user can browse their work without opening every file.
//
// Owner 8/15 15:55: 'needok,, refactor
// '. The shape of Document is locked by these tests. If Document's
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
        // The chapter icon now matches the sidebar folder icon
        // (= one entity = one icon rule). The other categories
        // stay unchanged.
        #expect(BookCategory.chapter.icon == "book.closed.circle")
        #expect(BookCategory.setting.icon == "gearshape.2")
        #expect(BookCategory.research.icon == "books.vertical")
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

    // MARK: - DocumentCrossRefParser (v1.80 health-ticket 1)

    @Test("DocumentCrossRefParser.parse extracts English-prefix @-refs from markdown")
    func parserExtractsEnglishPrefix() {
        let md = "Hero meets @character.zhangsan at @world.rainycity, with @reference.primer1 attached."
        let refs = DocumentCrossRefParser.parse(md)
        #expect(refs.count == 3)
        #expect(refs.contains(where: { $0.kind == .character && $0.name == "zhangsan" }))
        #expect(refs.contains(where: { $0.kind == .world && $0.name == "rainycity" }))
        #expect(refs.contains(where: { $0.kind == .reference && $0.name == "primer1" }))
    }

    @Test("DocumentCrossRefParser.parse maps Chinese prefix @-refs to DocumentRefKind")
    func parserAcceptsChinesePrefix() {
        let md = "@角色.林夕 遇到 @世界观.雨城, with @资料.笔记1"
        let refs = DocumentCrossRefParser.parse(md)
        #expect(refs.contains(where: { $0.kind == .character && $0.name == "林夕" }))
        #expect(refs.contains(where: { $0.kind == .world && $0.name == "雨城" }))
        #expect(refs.contains(where: { $0.kind == .reference && $0.name == "笔记1" }))
    }

    @Test("DocumentCrossRefParser.parse dedupes repeat refs of the same kind+name")
    func parserDedupesRepeatedRefs() {
        let md = "@character.zhangsan walks past. Then @character.zhangsan returns."
        let refs = DocumentCrossRefParser.parse(md)
        #expect(refs.count == 1)
        #expect(refs.first?.kind == .character)
        #expect(refs.first?.name == "zhangsan")
    }

    @Test("DocumentCrossRefParser.resolve maps parsed names to UUID arrays, silently skips unresolved")
    func parserResolveMapsToUuidArrays() {
        let refs: [(kind: DocumentRefKind, name: String)] = [
            (.character, "zhangsan"),
            (.world, "rainycity"),
            (.character, "ghost-person-no-uuid"),
        ]
        let charLookup = ["zhangsan": UUID()]
        let worldLookup = ["rainycity": UUID()]
        let refLookup: [String: UUID] = [:]
        let resolved = DocumentCrossRefParser.resolve(
            refs,
            characterLookup: charLookup,
            worldLookup: worldLookup,
            referenceLookup: refLookup
        )
        #expect(resolved.characterRefIds.count == 1)
        #expect(resolved.worldRefIds.count == 1)
        #expect(resolved.referenceRefIds.isEmpty)
    }

    @Test("DocumentCrossRefParser.parse skips refs with unknown prefix (= kindFromRaw returns nil)")
    func parserSkipsUnknownPrefix() {
        let md = "@unknown.foo and @character.zhangsan"
        let refs = DocumentCrossRefParser.parse(md)
        #expect(refs.count == 1)
        #expect(refs.first?.kind == .character)
        #expect(refs.first?.name == "zhangsan")
    }
}