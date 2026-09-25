//
//  ReferenceLibraryToolTagsTests.swift · Wenshu · v2.6 facet model
//
//  Verifies the ReferenceLibraryTool envelope accepts `tags` and
//  round-trips them through the descriptor. Covers:
//  - create action with tags -> descriptor.tags populated
//  - upsert action with tags -> tags merged with existing (union)
//  - upsert action without tags -> existing tags preserved (= legacy)
//  - empty tags -> empty tags (no crash)
//  - tags emitted sorted on the wire (= idempotent descriptor output)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReferenceLibraryTool tags facet (v2.6)")
struct ReferenceLibraryToolTagsTests {

    private func makeTool() throws -> (ReferenceLibraryTool, URL) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-tool-tags-\(UUID().uuidString)")
            .appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmp)
        let actor = ReferenceLibraryActor(referenceStore: store)
        let tool = ReferenceLibraryTool(actor: actor)
        return (tool, tmp)
    }

    @Test("create action accepts tags array")
    func createWithTags() async throws {
        let (tool, _) = try makeTool()
        let envelope = """
        {"action":"create","title":"李白","layer":"entities","category":"I","tags":["诗人","唐朝","浪漫主义"],"entity_type":"character","summary":"唐代浪漫主义诗人","body":"# 李白"}
        """
        let result = try await tool.execute(input: envelope)
        let json = try #require(JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        #expect(json["ok"] as? Bool == true)
        let reference = try #require(json["reference"] as? [String: Any])
        let tags = try #require(reference["tags"] as? [String])
        #expect(Set(tags) == ["诗人", "唐朝", "浪漫主义"])
        // Tags are emitted sorted for stable on-the-wire output.
        #expect(tags == tags.sorted())
    }

    @Test("create action with no tags defaults to empty list")
    func createWithoutTags() async throws {
        let (tool, _) = try makeTool()
        let envelope = """
        {"action":"create","title":"李白","layer":"entities","category":"I","entity_type":"character","summary":"唐代浪漫主义诗人","body":"# 李白"}
        """
        let result = try await tool.execute(input: envelope)
        let json = try #require(JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        let reference = try #require(json["reference"] as? [String: Any])
        #expect(reference["tags"] as? [String] == [])
    }

    @Test("upsert action merges tags with existing (= union, not replace)")
    func upsertMergesTags() async throws {
        let (tool, _) = try makeTool()
        // First create with tags A, B
        _ = try await tool.execute(input: """
        {"action":"create","title":"李白","layer":"entities","category":"I","tags":["诗人","唐朝"],"entity_type":"character","summary":"v1","body":"v1"}
        """)
        // Upsert with tags B, C (= B is shared; = union is {A, B, C})
        let upsertResult = try await tool.execute(input: """
        {"action":"upsert","title":"李白","layer":"entities","category":"I","tags":["唐朝","诗仙"],"entity_type":"character","summary":"v2","body":"v2"}
        """)
        let json = try #require(JSONSerialization.jsonObject(with: Data(upsertResult.utf8)) as? [String: Any])
        let reference = try #require(json["reference"] as? [String: Any])
        let tags = try #require(reference["tags"] as? [String])
        #expect(Set(tags) == ["诗人", "唐朝", "诗仙"],
                "upsert must merge tags with existing (= union), got: \(tags)")
    }

    @Test("upsert action without tags preserves existing tags")
    func upsertWithoutTagsPreserves() async throws {
        let (tool, _) = try makeTool()
        _ = try await tool.execute(input: """
        {"action":"create","title":"李白","layer":"entities","category":"I","tags":["诗人","唐朝"],"entity_type":"character","summary":"v1","body":"v1"}
        """)
        // Upsert without `tags` key in envelope (= legacy path) ->
        // existing tags must survive.
        let result = try await tool.execute(input: """
        {"action":"upsert","title":"李白","layer":"entities","category":"I","entity_type":"character","summary":"v2","body":"v2"}
        """)
        let json = try #require(JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        let reference = try #require(json["reference"] as? [String: Any])
        let tags = try #require(reference["tags"] as? [String])
        #expect(Set(tags) == ["诗人", "唐朝"],
                "upsert without tags payload must preserve existing tags; got: \(tags)")
    }

    @Test("create descriptor tags field exists in JSON output")
    func descriptorTagsAlwaysPresent() async throws {
        let (tool, _) = try makeTool()
        let result = try await tool.execute(input: """
        {"action":"create","title":"李白","layer":"entities","category":"I","tags":["诗仙"],"entity_type":"character","summary":"","body":""}
        """)
        let json = try #require(JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        let reference = try #require(json["reference"] as? [String: Any])
        // The descriptor MUST always include the tags key (= forward-
        // compat: consumers don't need to handle missing-key vs nil).
        #expect(reference.keys.contains("tags"))
    }
}