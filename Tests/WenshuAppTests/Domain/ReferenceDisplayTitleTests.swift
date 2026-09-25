//
//  ReferenceDisplayTitleTests.swift · Wenshu · v2.6
//
//  Verifies the front-end display-title field:
//  - effectiveDisplayTitle returns the explicit field when set,
//    falling back to `title` when nil
//  - ensureDisplayTitle backfills from `title` (= trim, collapse,
//    strip trailing punctuation)
//  - The sanitized result is CJK-safe (= preserves 李白 = 2 chars)
//  - Sibling-title disambiguation appends a 6-char uuid suffix when
//    the loaded layer already has a reference with the same title
//
//  Files covered:
//  - Sources/WenshuApp/Domain/Reference.swift (displayTitle field,
//    effectiveDisplayTitle, ensureDisplayTitle, sanitizeDisplayTitle)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Reference.displayTitle (v2.6)")
struct ReferenceDisplayTitleTests {

    @Test("effectiveDisplayTitle falls back to title when displayTitle is nil")
    func fallbackToTitle() {
        let ref = Reference(title: "李白")
        #expect(ref.effectiveDisplayTitle == "李白")
    }

    @Test("effectiveDisplayTitle returns the explicit displayTitle when set")
    func preferExplicitDisplayTitle() {
        var ref = Reference(title: "李白")
        ref.displayTitle = "李白 (诗人)"
        #expect(ref.effectiveDisplayTitle == "李白 (诗人)")
    }

    @Test("sanitizeDisplayTitle trims + collapses whitespace")
    func trimsAndCollapses() {
        #expect(Reference.sanitizeDisplayTitle("  李白  ") == "李白")
        #expect(Reference.sanitizeDisplayTitle("A    B") == "A B")
        #expect(Reference.sanitizeDisplayTitle("\t李白\n") == "李白")
    }

    @Test("sanitizeDisplayTitle strips trailing ASCII punctuation noise")
    func stripsTrailingPunctuation() {
        #expect(Reference.sanitizeDisplayTitle("李白.") == "李白")
        #expect(Reference.sanitizeDisplayTitle("李白\"") == "李白")
        #expect(Reference.sanitizeDisplayTitle("李白\",,'.)") == "李白")
        #expect(Reference.sanitizeDisplayTitle("李白?") == "李白")
        #expect(Reference.sanitizeDisplayTitle("李白 (test)") == "李白 (test")
    }

    @Test("sanitizeDisplayTitle preserves CJK + Latin + digits intact")
    func preservesContent() {
        #expect(Reference.sanitizeDisplayTitle("李白 诗仙 Tang") == "李白 诗仙 Tang")
        #expect(Reference.sanitizeDisplayTitle("测试123") == "测试123")
    }

    @Test("ensureDisplayTitle writes sanitized displayTitle into the field")
    func ensureSetsField() {
        var ref = Reference(title: "  李白  \".,")
        ref.ensureDisplayTitle()
        #expect(ref.displayTitle == "李白")
        #expect(ref.effectiveDisplayTitle == "李白")
    }

    @Test("ensureDisplayTitle disambiguates with a 6-char uuid suffix when sibling title exists")
    func disambiguateWithSibling() {
        let idA = UUID()
        var ref = Reference(id: idA, title: "李白")
        ref.ensureDisplayTitle(siblingTitles: ["李白"])
        #expect(ref.displayTitle != "李白", "must be disambiguated")
        #expect(ref.displayTitle?.contains("李白") == true)
        let expectedSuffix = String(idA.uuidString.prefix(6))
        #expect(ref.displayTitle?.contains(expectedSuffix) == true,
                "disambiguated title must include the 6-char UUID prefix; got: \(ref.displayTitle ?? "nil")")
    }

    @Test("ensureDisplayTitle leaves title alone when no sibling")
    func noSiblingNoChange() {
        var ref = Reference(title: "李白")
        ref.ensureDisplayTitle(siblingTitles: ["杜甫"])
        #expect(ref.displayTitle == "李白")
    }

    @Test("Codable round-trip preserves displayTitle")
    func codableRoundTrip() throws {
        var ref = Reference(title: "李白")
        ref.displayTitle = "诗仙"
        let data = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(Reference.self, from: data)
        #expect(decoded.displayTitle == "诗仙")
        #expect(decoded.title == "李白")
    }

    @Test("Codable decode defaults displayTitle to nil for legacy entries")
    func legacyDecodeNilDisplayTitle() throws {
        // Build JSON without the displayTitle field (= pre-v2.6 shape).
        let json = """
        {
          "id": "B697164A-0118-4282-BC63-D4E48EBA7565",
          "title": "李白",
          "layer": "layerEntities",
          "tags": [],
          "entityType": 1,
          "summary": "",
          "characterRefIds": [],
          "worldRefIds": [],
          "bookRefIds": [],
          "createdAt": 0,
          "updatedAt": 0
        }
        """
        let ref = try JSONDecoder().decode(Reference.self, from: Data(json.utf8))
        #expect(ref.displayTitle == nil)
        #expect(ref.effectiveDisplayTitle == "李白", "fallback to title must work for legacy data")
    }
}