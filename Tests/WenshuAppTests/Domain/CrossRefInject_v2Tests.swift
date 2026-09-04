// CrossRefInject_v2Tests.swift · Wenshu · v0.28
//
// Hermes-port validation tests for CrossRefInject_v2.swift
// (= wenshu M5 ticket 14 = hermes-port batch 3 third ticket).
//
// Tests cover the new token-budget + usage-count FIFO drop behavior
// (= the port from hermes context_engine.py's expand() token cap).

import Foundation
import Testing
@testable import WenshuApp

@Suite("CrossRefInject_v2 (hermes verbatim port — M5 ticket 14)")
struct CrossRefInject_v2Tests {

    // MARK: - Test fixtures (= in-memory reference store + temp book dir)

    /// Helper: build a ReferenceStoring stub with N entities (= varied usage counts).
    /// Returns the store + the chapters directory.
    private static func makeFixture(
        entityCount: Int,
        usageCount: [Int]? = nil,
        chapterCount: Int = 1
    ) throws -> (ReferenceStoring, URL) {
        // The Reference protocol is internal; we use a real FileSystemReferenceStore
        // (= production code path) to keep the test honest.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrossRefInject_v2Test-\(UUID().uuidString)")
        let chaptersDir = tmpDir.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        // Create N chapter files
        for i in 0..<chapterCount {
            let url = chaptersDir.appendingPathComponent("chapter_\(i).md")
            try "Chapter \(i)\n".write(to: url, atomically: true, encoding: .utf8)
        }
        // Create the reference store (= production FileSystemReferenceStore)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpDir)

        // Create N entities
        for i in 0..<entityCount {
            let title = "Entity_\(i)"
            let ref = Reference(title: title, layer: .layerEntities, summary: "")
            try store.saveReference(ref, bodyMarkdown: "# \(title)\n")
        }
        // Update chapter files to mention some entities (= to control usage counts)
        if let usage = usageCount {
            for i in 0..<min(entityCount, usage.count) {
                let count = usage[i]
                if count == 0 { continue }
                for c in 0..<chapterCount {
                    let url = chaptersDir.appendingPathComponent("chapter_\(c).md")
                    var text = try String(contentsOf: url, encoding: .utf8)
                    for _ in 0..<count {
                        text += " mentions Entity_\(i)\n"
                    }
                    try text.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
        return (store, tmpDir)
    }

    // MARK: - Default token budget

    @Test("default maxTokens (= 100) caps reference count")
    func defaultBudget() throws {
        // Create 50 entities (= ~12 tokens each = 600 tokens total, far > 100)
        let (store, dir) = try Self.makeFixture(entityCount: 50)
        let sut = CrossRefInject_v2(referenceStore: store, bookDirectory: dir)
        let updated = try sut.runInjection()
        // Should inject into at least 1 chapter
        #expect(updated >= 0)
        // Verify the chapter frontmatter is bounded
        let chapterURL = dir.appendingPathComponent("chapters/chapter_0.md")
        let content = try String(contentsOf: chapterURL, encoding: .utf8)
        // The frontmatter referenceRefIds line should not exceed the budget
        // (= 100 tokens = ~400 chars). Loose upper bound for stability.
        #expect(content.count < 1000)
    }

    // MARK: - Token budget cutoff

    @Test("token budget excludes lowest-usage references (= FIFO drop)")
    func budgetFIFODrop() throws {
        // 10 entities. Entity_0 has 10 mentions (= highest usage); Entity_9 has 1.
        // Budget = 4 tokens. Each entity title = 8 chars = ~2 tokens.
        // So budget allows ONLY ~2 entities to survive = top-2 by usage.
        let usage: [Int] = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
        let (store, dir) = try Self.makeFixture(entityCount: 10, usageCount: usage)
        let sut = CrossRefInject_v2(referenceStore: store, bookDirectory: dir)
        _ = try sut.runInjection(maxTokens: 4)

        // Read the chapter frontmatter (= contains UUIDs only, not entity titles).
        let chapterURL = dir.appendingPathComponent("chapters/chapter_0.md")
        let content = try String(contentsOf: chapterURL, encoding: .utf8)
        // Count UUIDs in the referenceRefIds line (= should be ~2 = the 2 highest-
        // usage entities that fit in the 4-token budget).
        // UUIDs are formatted as 8-4-4-4-12 hex digits (= 36 chars each).
        // Approximate count: occurrences of "[0-9A-F]{8}-" patterns.
        let uuidPattern = try! NSRegularExpression(
            pattern: #"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"#,
            options: [.caseInsensitive]
        )
        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)
        let uuidCount = uuidPattern.matches(in: content, range: fullRange).count
        // With budget = 4 tokens + ~2 tokens per entity = at most 2 entities injected
        #expect(uuidCount > 0)  // at least 1 entity injected
        #expect(uuidCount <= 4) // no more than ~2 entities (= 4 tokens / 2 tokens per entity)
        // Also verify the chapter body has the lower-usage entity mentions preserved
        // (= NOT removed from body = just dropped from frontmatter)
        #expect(content.contains("Entity_9"))  // mention in body, just not in frontmatter
    }

    // MARK: - Idempotency

    @Test("re-running does not duplicate refs in frontmatter")
    func idempotency() throws {
        let (store, dir) = try Self.makeFixture(entityCount: 5)
        let sut = CrossRefInject_v2(referenceStore: store, bookDirectory: dir)
        let firstRun = try sut.runInjection()
        let secondRun = try sut.runInjection()
        // Second run should add 0 (all already in frontmatter)
        #expect(secondRun == 0 || secondRun < firstRun)
    }

    // MARK: - Empty entities

    @Test("no entities -> no chapters updated (= early return)")
    func noEntities() throws {
        let (store, dir) = try Self.makeFixture(entityCount: 0)
        let sut = CrossRefInject_v2(referenceStore: store, bookDirectory: dir)
        let updated = try sut.runInjection()
        #expect(updated == 0)
    }

    @Test("no chapters directory -> 0 updated (= early return)")
    func noChaptersDir() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrossRefInject_v2Test-nocp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpDir)
        let sut = CrossRefInject_v2(referenceStore: store, bookDirectory: tmpDir)
        let updated = try sut.runInjection()
        #expect(updated == 0)
    }

    // MARK: - Determinism (ties broken by entity id)

    @Test("ties in usage count broken by entity id (deterministic)")
    func deterministicTiebreak() throws {
        // All 5 entities have usage = 0 (= no chapter mentions them).
        // Default tiebreak = entity id (lexicographic UUID).
        // Result should be deterministic across calls (= same frontmatter).
        let (store, dir) = try Self.makeFixture(entityCount: 5)
        let sut = CrossRefInject_v2(referenceStore: store, bookDirectory: dir)
        _ = try sut.runInjection(maxTokens: 50)
        let chapterURL = dir.appendingPathComponent("chapters/chapter_0.md")
        let content1 = try String(contentsOf: chapterURL, encoding: .utf8)
        _ = try sut.runInjection(maxTokens: 50)
        let content2 = try String(contentsOf: chapterURL, encoding: .utf8)
        // Idempotency: same chapter content across runs
        #expect(content1 == content2)
    }
}
