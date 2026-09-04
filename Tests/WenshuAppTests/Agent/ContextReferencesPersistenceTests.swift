//
//  ContextReferencesPersistenceTests.swift · Wenshu · HERMES-PARTIAL-014 (2026-09-04)
//
//  Round-trip tests for the ContextReferences extensions (= hermes
//  context_references.py = 598 LOC):
//    1. testParseFileRef                — parse @file:/path
//    2. testParseMultiRef               — parse multiple @-references
//    3. testOnDiskPersistRoundTrip      — persist + reload
//    4. testCrossSessionGraph           — session A + session B share a file
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ContextReferencesPersistence (HERMES-PARTIAL-014)")
struct ContextReferencesPersistenceTests {

    // MARK: - Test 1: Parse file reference

    @Test("parseContextReferences extracts @file:/path from a message")
    func testParseFileRef() {
        let refs = ContextReferenceParser.parse("see @file:/tmp/foo.md for context")
        #expect(refs.count == 1)
        #expect(refs.first?.sourceFile.path == "/tmp/foo.md")
    }

    // MARK: - Test 2: Multiple references

    @Test("parseContextReferences extracts multiple @-references")
    func testParseMultiRef() {
        let refs = ContextReferenceParser.parse("""
            Read @file:/tmp/a.md and @file:/tmp/b.md then
            summarize @url:https://example.com/docs
            """)
        #expect(refs.count == 3)
    }

    // MARK: - Test 3: On-disk persist round-trip

    @Test("persist() + reload round-trip preserves all references")
    func testOnDiskPersistRoundTrip() async throws {
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-context-refs-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        // Phase 1: write some references.
        let store1 = ContextReferences(persistencePath: tmpFile)
        let id1 = UUID()
        let id2 = UUID()
        await store1.add(
            ContextReference(
                messageID: id1,
                sourceFile: URL(fileURLWithPath: "/a.md"),
                sectionAnchor: "intro"
        ), session: "session-1")
        await store1.add(
            ContextReference(
                messageID: id2,
                sourceFile: URL(fileURLWithPath: "/b.md")
        ), session: "session-1")
        try await store1.persist()

        // Phase 2: load in a fresh actor.
        let store2 = ContextReferences(persistencePath: tmpFile)
        let ref1 = await store2.reference(for: id1)
        let ref2 = await store2.reference(for: id2)
        #expect(ref1?.sourceFile.path == "/a.md")
        #expect(ref1?.sectionAnchor == "intro")
        #expect(ref2?.sourceFile.path == "/b.md")
    }

    // MARK: - Test 4: Cross-session graph

    @Test("sessions(for:) returns the cross-session reference graph")
    func testCrossSessionGraph() async {
        let store = ContextReferences()
        let id1 = UUID()
        let id2 = UUID()
        await store.add(
            ContextReference(
                messageID: id1,
                sourceFile: URL(fileURLWithPath: "/shared.md")
        ), session: "session-A")
        await store.add(
            ContextReference(
                messageID: id2,
                sourceFile: URL(fileURLWithPath: "/shared.md")
        ), session: "session-B")
        // Both sessions reference the same file.
        let sessions = await store.sessions(for: URL(fileURLWithPath: "/shared.md"))
        #expect(sessions.contains("session-A"))
        #expect(sessions.contains("session-B"))
    }
}