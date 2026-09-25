//
//  ReferenceLibraryToolTests.swift · Wenshu · v2.0 (2026-09-25)
//
//  Round-trip tests for ReferenceLibraryActor + ReferenceLibraryTool:
//    1. testCreateReference_persistsBody
//    2. testReadReference_returnsBodyAndMetadata
//    3. testUpdateReference_replacesBodyAndMetadata
//    4. testDeleteReference_removesBodyAndIndex
//    5. testListReferences_filtersByLayerAndDefaultsToUserFacing
//    6. testFindReference_resolvesByCaseInsensitiveTitle
//    7. testUpsert_existingTitleUpdatesSameDocument (= CORE boss directive)
//    8. testUpsert_newTitleCreatesNewDocument
//    9. testExecute_upsertAction_parsesAndRuns
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReferenceLibraryTool (v2.0)")
struct ReferenceLibraryToolTests {

    // MARK: - Helpers

    private static func makeReferenceStore() throws -> FileSystemReferenceStore {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-v2-reference-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return FileSystemReferenceStore(referenceLibraryRoot: tmpRoot)
    }

    private static func makeActor() throws -> ReferenceLibraryActor {
        try ReferenceLibraryActor(referenceStore: makeReferenceStore())
    }

    // MARK: - Test 1: create

    @Test func testCreateReference_persistsBody() async throws {
        let actor = try Self.makeActor()
        let descriptor = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nKey concepts.",
            layer: "raw",
            summary: "Tax records"
        )
        #expect(descriptor.title == "Ming tax system")
        #expect(descriptor.layer == "raw")
        #expect(descriptor.summary == "Tax records")

        let body = await actor.readBodyForTest(id: descriptor.id)
        #expect(body == "# Ming tax\n\nKey concepts.")
    }

    // MARK: - Test 2: read

    @Test func testReadReference_returnsBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createReference(
            title: "Beijing history",
            bodyMarkdown: "# Beijing\n\nCity history."
        )
        let (reference, body) = try await actor.readReference(id: created.id)
        #expect(reference.id == created.id)
        #expect(reference.title == "Beijing history")
        #expect(body == "# Beijing\n\nCity history.")
    }

    // MARK: - Test 3: update

    @Test func testUpdateReference_replacesBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createReference(
            title: "Topic",
            bodyMarkdown: "# Topic\n\nDraft."
        )
        let updated = try await actor.updateReference(
            id: created.id,
            title: "Topic (revised)",
            bodyMarkdown: "# Topic (revised)\n\nRevised.",
            summary: "Now revised"
        )
        #expect(updated.title == "Topic (revised)")
        #expect(updated.summary == "Now revised")

        let (_, body) = try await actor.readReference(id: created.id)
        #expect(body == "# Topic (revised)\n\nRevised.")
    }

    // MARK: - Test 4: delete

    @Test func testDeleteReference_removesBodyAndIndex() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createReference(
            title: "Scrapped",
            bodyMarkdown: "# Scrapped"
        )
        try await actor.deleteReference(id: created.id)

        await #expect(throws: ReferenceLibraryError.entryNotFound(id: created.id)) {
            try await actor.readReference(id: created.id)
        }
    }

    // MARK: - Test 5: list

    @Test func testListReferences_filtersByLayerAndDefaultsToUserFacing() async throws {
        let store = try Self.makeReferenceStore()
        let actor = ReferenceLibraryActor(referenceStore: store)
        _ = try await actor.createReference(title: "Raw1", bodyMarkdown: "r1", layer: "raw")
        _ = try await actor.createReference(title: "Raw2", bodyMarkdown: "r2", layer: "raw")
        _ = try await actor.createReference(title: "Ent1", bodyMarkdown: "e1", layer: "entities")

        // Default = user-facing layers only (= raw + entities).
        let allUserFacing = try await actor.listReferences()
        #expect(allUserFacing.count == 3)

        // Filter by layer.
        let rawOnly = try await actor.listReferences(layer: "raw")
        #expect(rawOnly.count == 2)

        let entitiesOnly = try await actor.listReferences(layer: "entities")
        #expect(entitiesOnly.count == 1)
        #expect(entitiesOnly.first?.title == "Ent1")

        // LLM-derived layers stay hidden (= abstracts / indexes
        // silently return 0 results even if asked).
        let abstracts = try await actor.listReferences(layer: "abstracts")
        #expect(abstracts.isEmpty)
    }

    // MARK: - Test 6: find

    @Test func testFindReference_resolvesByCaseInsensitiveTitle() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createReference(
            title: "Qing Dynasty Salt Policy",
            bodyMarkdown: "# Salt"
        )
        let found = try await actor.findReference(title: "  qing dynasty salt policy  ")
        #expect(found?.id == created.id)

        let missing = try await actor.findReference(title: "Ming")
        #expect(missing == nil)
    }

    // MARK: - Test 7: CORE boss directive — upsert updates the existing doc

    @Test func testUpsert_existingTitleUpdatesSameDocument() async throws {
        let store = try Self.makeReferenceStore()
        let actor = ReferenceLibraryActor(referenceStore: store)

        // First call: creates the document.
        let first = try await actor.upsertReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nInitial research.",
            layer: "raw"
        )
        #expect(first.title == "Ming tax system")

        // Second call with the same title (= case + whitespace
        // variations): must update the SAME document (= id preserved).
        let second = try await actor.upsertReference(
            title: "  MING TAX SYSTEM  ",
            bodyMarkdown: "# Ming tax\n\nFollow-up research.",
            layer: "raw",
            summary: "Updated"
        )
        #expect(second.id == first.id)
        #expect(second.summary == "Updated")

        // Verify only ONE document exists in the layer.
        let all = try await actor.listReferences(layer: "raw")
        #expect(all.count == 1)
        let body = await actor.readBodyForTest(id: first.id)
        #expect(body == "# Ming tax\n\nFollow-up research.")
    }

    // MARK: - Test 8: upsert with a new title creates a fresh doc

    @Test func testUpsert_newTitleCreatesNewDocument() async throws {
        let actor = try Self.makeActor()
        let first = try await actor.upsertReference(
            title: "Topic A",
            bodyMarkdown: "# A",
            layer: "raw"
        )
        let second = try await actor.upsertReference(
            title: "Topic B",
            bodyMarkdown: "# B",
            layer: "raw"
        )
        #expect(second.id != first.id)
        let all = try await actor.listReferences(layer: "raw")
        #expect(all.count == 2)
    }

    // MARK: - Test 9: LLM dispatcher (upsert action)

    @Test func testExecute_upsertAction_parsesAndRuns() async throws {
        let store = try Self.makeReferenceStore()
        let actor = ReferenceLibraryActor(referenceStore: store)
        let tool = ReferenceLibraryTool(actor: actor)
        let input = """
        {"action":"upsert","title":"Ming tax","markdown":"# Ming tax","layer":"raw"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":true"))
        #expect(output.contains("\"action\":\"upsert\""))
        #expect(output.contains("\"title\":\"Ming tax\""))
        #expect(output.contains("\"created\":true"))
    }
}