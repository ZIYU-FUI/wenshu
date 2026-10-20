// SmartQueryParserTests.swift · Wenshu () · v0.27 (FCP library replica)
//
// Contract tests for the SmartQueryPredicate parser + evaluator
// (= ticket 027-02). Mirrors the WorldStoringContractTests pattern.

import Testing
import Foundation
import WenshuData
@testable import WenshuApp

@Suite("SmartQueryParser contract")
@MainActor
struct SmartQueryParserTests {

    /// Per-test temp directories for isolation (= per Apple HIG test
    /// isolation).
    private static func makeStores() -> (FileSystemEntityStore, ReferenceStoring) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-smart-\(UUID().uuidString)", isDirectory: true)
        let bookDir = root.appendingPathComponent("books/test", isDirectory: true)
        let refLib = root.appendingPathComponent("reference-library", isDirectory: true)
        try? FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: refLib, withIntermediateDirectories: true)
        return (
            FileSystemEntityStore(bookDirectory: bookDir),
            FileSystemReferenceStore(referenceLibraryRoot: refLib)
        )
    }

    /// Build a SmartQueryIndex from the current store contents.
    /// world + character entries are unified into a single entity
    /// store (= kind-discriminated). The index keeps the legacy
    /// `characters` + `worldEntries` buckets as a facade so the
    /// SmartQueryEvaluator (= which still speaks Character /
    /// WorldEntry) keeps working.
    private func buildIndex(
        entityStore: FileSystemEntityStore,
        referenceStore: ReferenceStoring
    ) throws -> SmartQueryIndex {
        let allEntities = (try? entityStore.loadEntities()) ?? []
        let characters = allEntities
            .filter { $0.kind == .person }
            .map { entity in
                Character(
                    id: UUID(uuidString: entity.id.rawValue) ?? UUID(),
                    bookId: UUID(uuidString: entity.bookIDRaw) ?? UUID(),
                    name: entity.name,
                    age: entity.attributes["age"].flatMap { Int($0) },
                    role: CharacterRole(rawValue: entity.tags.first ?? "other") ?? .other,
                    arc: entity.attributes["arc"],
                    summary: entity.description,
                    createdAt: entity.createdAt,
                    updatedAt: entity.updatedAt
                )
            }
        let worldEntries = allEntities
            .filter { $0.kind == .location }
            .map { entity in
                WorldEntry(
                    id: UUID(uuidString: entity.id.rawValue) ?? UUID(),
                    bookId: UUID(uuidString: entity.bookIDRaw) ?? UUID(),
                    type: WorldEntryType(rawValue: entity.tags.first ?? "other") ?? .other,
                    name: entity.name,
                    summary: entity.description,
                    createdAt: entity.createdAt,
                    updatedAt: entity.updatedAt
                )
            }
        let references = (try? referenceStore.loadAllReferences()) ?? []
        return SmartQueryIndex(
            characters: characters,
            worldEntries: worldEntries,
            references: references
        )
    }

    /// Run a saved query (= returns matching entities).
    private func run(
        query: SmartQuery,
        entityStore: FileSystemEntityStore,
        referenceStore: ReferenceStoring
    ) throws -> SmartQueryRunResult {
        guard let predicate = SmartQueryPredicate.decode(json: query.queryJSON) else {
            return SmartQueryRunResult(query: query, results: [], error: .invalidPredicateJSON)
        }
        let index = try buildIndex(entityStore: entityStore, referenceStore: referenceStore)
        let results = SmartQueryEvaluator(predicate: predicate).evaluate(against: index)
        return SmartQueryRunResult(query: query, results: results, error: nil)
    }

    @Test("namePattern predicate roundtrips through JSON")
    func namePatternRoundtrip() throws {
        let predicate = SmartQueryPredicate.namePattern("张三")
        let json = try predicate.encodedJSON()
        let decoded = SmartQueryPredicate.decode(json: json)
        #expect(decoded == predicate)
    }

    @Test("entityType predicate roundtrips")
    func entityTypeRoundtrip() throws {
        let predicate = SmartQueryPredicate.entityType(.character)
        let json = try predicate.encodedJSON()
        let decoded = SmartQueryPredicate.decode(json: json)
        #expect(decoded == predicate)
    }

    @Test("refIds predicate roundtrips")
    func refIdsRoundtrip() throws {
        let ids = [UUID(), UUID()]
        let predicate = SmartQueryPredicate.refIds(ids)
        let json = try predicate.encodedJSON()
        let decoded = SmartQueryPredicate.decode(json: json)
        #expect(decoded == predicate)
    }

    @Test("layer predicate roundtrips")
    func layerRoundtrip() throws {
        let predicate = SmartQueryPredicate.layer(.layerRaw)
        let json = try predicate.encodedJSON()
        let decoded = SmartQueryPredicate.decode(json: json)
        #expect(decoded == predicate)
    }

    @Test("empty JSON returns nil (= default empty query)")
    func emptyJSONDecodes() {
        let decoded = SmartQueryPredicate.decode(json: "{}")
        #expect(decoded == nil)
    }

    @Test("malformed JSON returns nil")
    func malformedJSONDecodes() {
        let decoded = SmartQueryPredicate.decode(json: "not json {")
        #expect(decoded == nil)
    }

    @Test("evaluator returns characters matching namePattern")
    func namePatternEvaluate() throws {
        let (entityStore, referenceStore) = Self.makeStores()
        let character = Character(bookId: UUID(), name: "张三", role: .protagonist)
        try entityStore.saveEntity(
            EntityDescriptor(
                id: EntityID(rawValue: character.id.uuidString),
                bookID: BookID(rawValue: character.bookId.uuidString),
                kind: .person,
                name: character.name,
                aliases: [],
                tags: [character.role.rawValue],
                description: character.summary,
                attributes: [:],
                kindSpecific: .empty,
                bodyExcerpt: BodyExcerpt.make(from: "# 张三\n"),
                createdAt: character.createdAt,
                updatedAt: character.updatedAt
            ),
            bodyMarkdown: "# 张三\n"
        )
        let query = SmartQuery(name: "找张三", queryJSON: try SmartQueryPredicate.namePattern("张三").encodedJSON())
        let result = try run(query: query, entityStore: entityStore, referenceStore: referenceStore)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "张三")
    }

    @Test("evaluator returns world entries matching namePattern")
    func worldNamePatternEvaluate() throws {
        let (entityStore, referenceStore) = Self.makeStores()
        let entry = WorldEntry(bookId: UUID(), type: .geography, name: "Beijing", summary: "首都")
        try entityStore.saveEntity(
            EntityDescriptor(
                id: EntityID(rawValue: entry.id.uuidString),
                bookID: BookID(rawValue: entry.bookId.uuidString),
                kind: .location,
                name: entry.name,
                aliases: [],
                tags: [entry.type.rawValue],
                description: entry.summary,
                attributes: [:],
                kindSpecific: .empty,
                bodyExcerpt: BodyExcerpt.make(from: "# Beijing\n"),
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            ),
            bodyMarkdown: "# Beijing\n"
        )
        let query = SmartQuery(name: "找北京", queryJSON: try SmartQueryPredicate.namePattern("Beijing").encodedJSON())
        let result = try run(query: query, entityStore: entityStore, referenceStore: referenceStore)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "Beijing")
    }

    @Test("evaluator returns references matching layer filter")
    func layerEvaluate() throws {
        let (entityStore, referenceStore) = Self.makeStores()
        let refRaw = Reference(title: "Test Raw", layer: .layerRaw)
        try referenceStore.saveReference(refRaw, bodyMarkdown: "# Raw\n")
        let refEntities = Reference(title: "Test Entity", layer: .layerEntities)
        try referenceStore.saveReference(refEntities, bodyMarkdown: "# Entity\n")
        let query = SmartQuery(name: "raw only", queryJSON: try SmartQueryPredicate.layer(.layerRaw).encodedJSON())
        let result = try run(query: query, entityStore: entityStore, referenceStore: referenceStore)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "Test Raw")
    }

    @Test("evaluator returns entity type filtered results")
    func entityTypeEvaluate() throws {
        let (entityStore, referenceStore) = Self.makeStores()
        let character = Character(bookId: UUID(), name: "李四", role: .supporting)
        try entityStore.saveEntity(
            EntityDescriptor(
                id: EntityID(rawValue: character.id.uuidString),
                bookID: BookID(rawValue: character.bookId.uuidString),
                kind: .person,
                name: character.name,
                aliases: [],
                tags: [character.role.rawValue],
                description: character.summary,
                attributes: [:],
                kindSpecific: .empty,
                bodyExcerpt: BodyExcerpt.make(from: "# 李四\n"),
                createdAt: character.createdAt,
                updatedAt: character.updatedAt
            ),
            bodyMarkdown: "# 李四\n"
        )
        let entry = WorldEntry(bookId: UUID(), type: .object, name: "Sword", summary: "")
        try entityStore.saveEntity(
            EntityDescriptor(
                id: EntityID(rawValue: entry.id.uuidString),
                bookID: BookID(rawValue: entry.bookId.uuidString),
                kind: .location,
                name: entry.name,
                aliases: [],
                tags: [entry.type.rawValue],
                description: entry.summary,
                attributes: [:],
                kindSpecific: .empty,
                bodyExcerpt: BodyExcerpt.make(from: "# Sword\n"),
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            ),
            bodyMarkdown: "# Sword\n"
        )
        let query = SmartQuery(name: "characters only", queryJSON: try SmartQueryPredicate.entityType(.character).encodedJSON())
        let result = try run(query: query, entityStore: entityStore, referenceStore: referenceStore)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "李四")
    }

    @Test("invalid JSON returns error result")
    func invalidJSONReturnsError() throws {
        let (entityStore, referenceStore) = Self.makeStores()
        let query = SmartQuery(name: "broken", queryJSON: "not json")
        let result = try run(query: query, entityStore: entityStore, referenceStore: referenceStore)
        #expect(result.results.isEmpty)
        #expect(result.error == .invalidPredicateJSON)
    }
}