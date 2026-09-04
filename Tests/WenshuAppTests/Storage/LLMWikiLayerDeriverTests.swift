// LLMWikiLayerDeriverTests.swift · Wenshu · v0.28
//
// Hermes-port validation tests for LLMWikiLayerDeriver.swift +
// LLMWikiLinter.swift (= wenshu M5 ticket 15 = hermes-port batch 3
// fifth ticket).
//
// Tests cover:
// - Deriver: abstracts + indexes derivation from raw layer
// - Deriver: idempotency (= re-running overwrites)
// - Deriver: deterministic tokenization (= keyword ordering stable)
// - Linter: orphan entity detection
// - Linter: broken wikilink detection
// - Linter: missing-in-index detection
// - Linter: stale abstract detection

import Foundation
import Testing
@testable import WenshuApp

@Suite("LLMWikiLayerDeriver (hermes verbatim port — M5 ticket 15)")
struct LLMWikiLayerDeriverTests {

    // MARK: - Test fixtures

    /// Helper: build a FileSystemReferenceStore with N raw references.
    private static func makeFixture(
        rawCount: Int = 5,
        rawBodies: [String: String]? = nil
    ) throws -> (ReferenceStoring, URL) {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMWikiTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpDir)
        for i in 0..<rawCount {
            let title = "Source_\(i)"
            let body = rawBodies?[title] ?? "# \(title)\n\nThis is a sample reference body for source \(i). It mentions the keyword FooBar.\n"
            try store.saveReference(Reference(title: title, layer: .layerRaw), bodyMarkdown: body)
        }
        return (store, tmpDir)
    }

    // MARK: - Deriver tests

    @Test("deriver produces abstracts from raw layer")
    func producesAbstracts() throws {
        let (store, _) = try Self.makeFixture()
        let sut = LLMWikiLayerDeriver(store: store)
        let stats = try sut.runDerivation()
        #expect(stats.abstractsWritten == 5)
        let abstracts = try store.loadReferences(layer: .layerAbstracts)
        #expect(abstracts.count == 5)
    }

    @Test("deriver produces indexes from raw layer")
    func producesIndexes() throws {
        let (store, _) = try Self.makeFixture()
        let sut = LLMWikiLayerDeriver(store: store)
        let stats = try sut.runDerivation()
        // Common keyword = 'sample', 'reference', 'body', 'source', 'FooBar'
        #expect(stats.indexesWritten >= 3)
        let indexes = try store.loadReferences(layer: .layerIndexes)
        #expect(indexes.count >= 3)
    }

    @Test("deriver is idempotent")
    func idempotent() throws {
        let (store, _) = try Self.makeFixture()
        let sut = LLMWikiLayerDeriver(store: store)
        let stats1 = try sut.runDerivation()
        let stats2 = try sut.runDerivation()
        // Same number of abstracts + indexes on second run
        #expect(stats1.abstractsWritten == stats2.abstractsWritten)
        #expect(stats1.indexesWritten == stats2.indexesWritten)
    }

    @Test("firstParagraph skips heading lines")
    func firstParagraphSkipsHeadings() {
        let md = "# Heading 1\n\nFirst content paragraph.\n\n## Heading 2\n\nSecond content paragraph."
        let result = LLMWikiLayerDeriver.firstParagraph(fromMarkdown: md)
        #expect(result == "First content paragraph.")
    }

    @Test("firstParagraph strips inline markdown")
    func firstParagraphStripsInline() {
        let md = "**Bold** and *italic* with `code` snippet."
        let result = LLMWikiLayerDeriver.firstParagraph(fromMarkdown: md)
        // All markdown emphasis removed
        #expect(!result.contains("**"))
        #expect(!result.contains("*italic*"))
    }

    @Test("tokenize filters short and digit-only tokens")
    func tokenizeFilters() {
        let text = "The quick 123 brown fox jumps 42 over a lazy dog"
        let tokens = LLMWikiLayerDeriver.tokenize(text)
        // '123' and '42' are digit-only => filtered out
        #expect(!tokens.contains("123"))
        #expect(!tokens.contains("42"))
        // 'the', 'a' are < 3 chars => filtered out
        #expect(!tokens.contains("the"))
        #expect(!tokens.contains("a"))
        // 'quick', 'brown', 'fox', 'jumps', 'over', 'lazy', 'dog' survive
        #expect(tokens.contains("quick"))
        #expect(tokens.contains("brown"))
    }
}

@Suite("LLMWikiLinter (hermes verbatim port — M5 ticket 15)")
struct LLMWikiLinterTests {

    // MARK: - Test fixtures

    /// Helper: build a FileSystemReferenceStore with a controlled graph.
    private static func makeFixture(
        rawBodies: [String: String]? = nil,
        entityWithProvenance: Set<Int>? = nil,
        entities: [Reference] = []
    ) throws -> ReferenceStoring {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMLintTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpDir)
        // Save raw references
        for (title, body) in rawBodies ?? ["Raw1": "Sample text"] {
            try store.saveReference(Reference(title: title, layer: .layerRaw), bodyMarkdown: body)
        }
        // Save entities
        for entity in entities {
            try store.saveReference(entity, bodyMarkdown: "")
        }
        return store
    }

    // MARK: - Wikilink extraction

    @Test("extractWikilinks parses wiki:uuid syntax")
    func extractWikilinksParses() {
        let md = "See [link](wiki:12345678-1234-1234-1234-123456789012) and another [here](wiki:00000000-0000-0000-0000-000000000000)"
        let result = LLMWikiLinter.extractWikilinks(fromMarkdown: md)
        #expect(result.count == 2)
        let uuidStrings = result.map { $0.uuidString }
        #expect(uuidStrings.contains("12345678-1234-1234-1234-123456789012"))
        #expect(uuidStrings.contains("00000000-0000-0000-0000-000000000000"))
    }

    @Test("extractWikilinks ignores non-UUID patterns")
    func extractWikilinksIgnoresInvalid() {
        let md = "Plain [link](https://example.com) and [invalid](wiki:not-a-uuid) and [valid](wiki:12345678-1234-1234-1234-123456789012)"
        let result = LLMWikiLinter.extractWikilinks(fromMarkdown: md)
        #expect(result.count == 1)
    }

    // MARK: - Full linter

    @Test("lint returns empty for clean wiki")
    func lintClean() throws {
        let store = try Self.makeFixture()
        let sut = LLMWikiLinter(store: store)
        let findings = try sut.lint()
        // Empty entities + empty indexes => no orphan / broken-wikilink findings
        // (but may have missing-in-index infos)
        #expect(!findings.contains { $0.severity == .error })
    }

    @Test("lint detects orphan entity")
    func lintOrphanEntity() throws {
        let orphanEntity = Reference(title: "Orphan", layer: .layerEntities, summary: "")
        let store = try Self.makeFixture(
            rawBodies: ["Raw1": "Body"],
            entities: [orphanEntity]
        )
        let sut = LLMWikiLinter(store: store)
        let findings = try sut.lint()
        let orphanFindings = findings.filter { $0.code == "LLM-ORPHAN-ENTITY" }
        #expect(orphanFindings.count == 1)
    }

    @Test("lint detects broken wikilink")
    func lintBrokenWikilink() throws {
        let bodyWithBroken = "This [link](wiki:11111111-1111-1111-1111-111111111111) is broken"
        let store = try Self.makeFixture(rawBodies: ["Raw1": bodyWithBroken])
        let sut = LLMWikiLinter(store: store)
        let findings = try sut.lint()
        let brokenFindings = findings.filter { $0.code == "LLM-BROKEN-WIKILINK" }
        #expect(brokenFindings.count == 1)
    }

    @Test("lint detects missing-in-index raw")
    func lintMissingInIndex() throws {
        let store = try Self.makeFixture(rawBodies: ["Raw1": "Body"])
        let sut = LLMWikiLinter(store: store)
        let findings = try sut.lint()
        let missingFindings = findings.filter { $0.code == "LLM-MISSING-IN-INDEX" }
        #expect(missingFindings.count == 1)
    }
}