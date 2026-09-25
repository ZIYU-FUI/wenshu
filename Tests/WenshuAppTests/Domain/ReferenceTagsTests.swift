//
//  ReferenceTagsTests.swift · Wenshu · v2.6 facet model
//
//  Verifies the v2.6 facet model Reference struct changes:
//  - tags: Set<String> field is added (= cross-cutting facet)
//  - subcategory: String? field is removed (= dead field per §11 audit)
//  - Codable migration: legacy entities.json without `tags` defaults
//    to empty set (= no data loss on existing reference libraries)
//
//  Files covered:
//  - Sources/WenshuApp/Domain/Reference.swift (struct + Codable + path)
//  - Tests/WenshuAppTests/Editor/SMC003EditorActionsTests.swift (init
//    constructor call updated to use tags: [])
//  - Tests/WenshuAppTests/UI/Layout/PreviewPaneOpsTests.swift (JSON
//    fixture updated to use tags: [] instead of subcategory: null)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Reference.tags facet (v2.6)")
struct ReferenceTagsTests {

    @Test("tags field defaults to empty set")
    func tagsDefault() {
        let ref = Reference(title: "李白")
        #expect(ref.tags.isEmpty)
    }

    @Test("tags round-trip through Codable encode/decode")
    func tagsRoundTrip() throws {
        let original = Reference(
            title: "李白",
            category: .i,
            tags: ["诗人", "唐朝", "浪漫主义", "诗仙"]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(Reference.self, from: data)
        #expect(decoded.tags == ["诗人", "唐朝", "浪漫主义", "诗仙"])
        #expect(decoded.title == "李白")
        #expect(decoded.category == .i)
    }

    @Test("tags encode in sorted order (= stable on-disk output)")
    func tagsEncodeSorted() throws {
        let ref = Reference(
            title: "李白",
            tags: ["诗仙", "唐朝", "诗人", "浪漫主义"]
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(ref)
        let json = String(data: data, encoding: .utf8) ?? ""
        // Tags must appear in sorted order in the on-disk JSON
        // (= CJK unicode code point order: 唐朝 < 浪漫主义 < 诗人 < 诗仙).
        // Verify by checking the substring directly.
        let expectedSortedJSON = "\"tags\":[\"唐朝\",\"浪漫主义\",\"诗人\",\"诗仙\"]"
        #expect(json.contains(expectedSortedJSON),
                "tags must be sorted on disk for idempotent writes; got: \(json)")
    }

    @Test("legacy entities.json without tags field decodes with empty set")
    func legacyMigration() throws {
        // Pre-v2.6 entities.json has no `tags` field. Reading it must
        // not crash; = tags defaults to empty set (= forward-compat).
        let legacyJSON = """
        {"id":"B5F8E3D6-1234-5678-9ABC-DEF012345678","title":"李白","source":null,"url":null,"layer":"layerEntities","category":"I","entityType":"character","summary":"","characterRefIds":[],"worldRefIds":[],"bookRefIds":[],"createdAt":0,"updatedAt":0}
        """
        let data = legacyJSON.data(using: .utf8)!
        let ref = try JSONDecoder().decode(Reference.self, from: data)
        #expect(ref.title == "李白")
        #expect(ref.tags.isEmpty, "legacy entries without `tags` field must default to empty set")
        #expect(ref.category == .i)
        #expect(ref.entityType == .character)
    }

    @Test("tags contains semantic equality (= Set semantics, not Array)")
    func tagsSetSemantics() {
        var ref = Reference(title: "李白")
        ref.tags.insert("唐朝")
        ref.tags.insert("唐朝")  // duplicate insert is a no-op on Set
        #expect(ref.tags == ["唐朝"])
        #expect(ref.tags.count == 1)
    }

    @Test("subcategory field no longer exists (= compile-time absence)")
    func noSubcategoryField() {
        // This test is compile-time evidence that `subcategory` is gone.
        // If the field is reintroduced, the assignment `ref.subcategory = nil`
        // would still compile (= backward-compat optional). To make this
        // a stricter guard, we check that Reference's Mirror children do not
        // contain a "subcategory" child.
        let ref = Reference(title: "test", tags: ["x"])
        let mirror = Mirror(reflecting: ref)
        let fieldNames = mirror.children.compactMap { $0.label }
        #expect(!fieldNames.contains("subcategory"),
                "subcategory field must be removed; = current children: \(fieldNames)")
        #expect(fieldNames.contains("tags"), "tags field must exist")
    }
}