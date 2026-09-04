// SmartQueryParserTests.swift · Wenshu (文枢) · v0.27 (FCP library replica)
//
// Contract tests for the SmartQueryPredicate parser + evaluator
// (= ticket 027-02). Mirrors the WorldStoringContractTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("SmartQueryParser contract")
struct SmartQueryParserTests {

    private func makeEngine() -> SmartQueryEngine {
        // Use temp directories for isolation (= per Apple HIG test isolation).
        let root = URL(fileURLWithPath: "/tmp/wenshu-smart-\(UUID().uuidString)", isDirectory: true)
        let bookDir = root.appendingPathComponent("books/test", isDirectory: true)
        let refLib = root.appendingPathComponent("reference-library", isDirectory: true)
        try? FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: refLib, withIntermediateDirectories: true)
        return SmartQueryEngine(
            worldStore: FileSystemWorldStore(bookDirectory: bookDir),
            characterStore: FileSystemCharacterStore(bookDirectory: bookDir),
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: refLib)
        )
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
        let engine = makeEngine()
        let character = Character(bookId: UUID(), name: "张三", role: .protagonist)
        try engine.characterStore.saveCharacter(character, bodyMarkdown: "# 张三\n")
        let query = SmartQuery(name: "找张三", queryJSON: try SmartQueryPredicate.namePattern("张三").encodedJSON())
        let result = try engine.run(query: query)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "张三")
    }

    @Test("evaluator returns world entries matching namePattern")
    func worldNamePatternEvaluate() throws {
        let engine = makeEngine()
        let entry = WorldEntry(bookId: UUID(), type: .geography, name: "Beijing", summary: "首都")
        try engine.worldStore.saveEntry(entry, bodyMarkdown: "# Beijing\n")
        let query = SmartQuery(name: "找北京", queryJSON: try SmartQueryPredicate.namePattern("Beijing").encodedJSON())
        let result = try engine.run(query: query)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "Beijing")
    }

    @Test("evaluator returns references matching layer filter")
    func layerEvaluate() throws {
        let engine = makeEngine()
        let refRaw = Reference(title: "Test Raw", layer: .layerRaw)
        try engine.referenceStore.saveReference(refRaw, bodyMarkdown: "# Raw\n")
        let refEntities = Reference(title: "Test Entity", layer: .layerEntities)
        try engine.referenceStore.saveReference(refEntities, bodyMarkdown: "# Entity\n")
        let query = SmartQuery(name: "raw only", queryJSON: try SmartQueryPredicate.layer(.layerRaw).encodedJSON())
        let result = try engine.run(query: query)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "Test Raw")
    }

    @Test("evaluator returns entity type filtered results")
    func entityTypeEvaluate() throws {
        let engine = makeEngine()
        let character = Character(bookId: UUID(), name: "李四", role: .supporting)
        try engine.characterStore.saveCharacter(character, bodyMarkdown: "# 李四\n")
        let entry = WorldEntry(bookId: UUID(), type: .object, name: "Sword", summary: "")
        try engine.worldStore.saveEntry(entry, bodyMarkdown: "# Sword\n")
        let query = SmartQuery(name: "characters only", queryJSON: try SmartQueryPredicate.entityType(.character).encodedJSON())
        let result = try engine.run(query: query)
        #expect(result.results.count == 1)
        #expect(result.results.first?.name == "李四")
    }

    @Test("invalid JSON returns error result")
    func invalidJSONReturnsError() throws {
        let engine = makeEngine()
        let query = SmartQuery(name: "broken", queryJSON: "not json")
        let result = try engine.run(query: query)
        #expect(result.results.isEmpty)
        #expect(result.error == .invalidPredicateJSON)
    }
}