//
//  EntityClassifierFacetTests.swift · Wenshu · v2.6 facet model
//
//  Verifies the v2.6 multi-facet EntityClassifier:
//  - classify() returns ClassificationResult (= category + tags + entityType)
//  - keyword pass derives starter tags from the matched category
//    (= "文学" + "I" for category .i, etc.)
//  - LLM pass parses JSON envelope and returns all three facets
//  - LLM pass falls back to keyword result when LLM returns the
//    fallback shape (empty + .z + .other)
//  - tag cap (maxTags = 10) is enforced
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("EntityClassifier multi-facet (v2.6)")
struct EntityClassifierFacetTests {

    @Test("keyword pass returns category + starter tags + .other entityType")
    func keywordReturnsMultiFacet() async {
        let classifier = EntityClassifier()
        let result = await classifier.classify(
            title: "李白诗集",
            summary: "唐诗三百首",
            body: "李白的诗歌"
            // useLLMFallback defaults to true but llmCallback is nil;
            // = only keyword pass runs
        )
        // Strong "李白" + "诗歌" + "唐诗" signal -> category .i (Literature)
        #expect(result.category == .i)
        // Tags are derived from the matched category (= "文学" + "I")
        #expect(result.tags.contains("文学"))
        #expect(result.tags.contains("I"))
        // Keyword pass cannot infer entityType -> defaults to .other
        #expect(result.entityType == .other)
    }

    @Test("keyword pass with no clear winner falls back to .z with derived tags")
    func keywordFallback() async {
        let classifier = EntityClassifier()
        let result = await classifier.classify(
            title: "asdfqwerzxcv",
            summary: "",
            body: ""
        )
        // No keywords matched -> .z (catch-all)
        #expect(result.category == .z)
        // Even for .z, deriveKeywordTags adds the displayName + letter
        #expect(result.tags.contains("其它"))
        #expect(result.tags.contains("Z"))
    }

    @Test("LLM pass parses JSON envelope with category + tags + entity_type")
    func llmParsesJSON() async {
        let classifier = EntityClassifier()
        // Use a title that does NOT match keyword signals (= so the
        // keyword pass returns low confidence and the LLM pass triggers).
        let mockLLM: EntityClassifier.LLMCallback = { _ in
            return "{\"category\":\"I\",\"tags\":[\"诗人\",\"唐朝\",\"浪漫主义\",\"诗仙\"],\"entity_type\":1}"
        }
        let result = await classifier.classify(
            title: "XYZ-1234-doc",  // no CJK / literary signal
            summary: "research artifact",
            body: "",
            llmCallback: mockLLM
        )
        print("[T] llmParsesJSON result = \(result)")
        #expect(result.category == .i)
        #expect(result.tags == ["诗人", "唐朝", "浪漫主义", "诗仙"])
        #expect(result.entityType == .character)
    }

    @Test("LLM pass falls back to keyword when LLM returns empty fallback shape")
    func llmFallsBackToKeyword() async {
        let classifier = EntityClassifier()
        // LLM returns the fallback shape (.z + [] + .other)
        let fallbackLLM: EntityClassifier.LLMCallback = { _ in
            #"{"category":"Z","tags":[],"entity_type":9}"#
        }
        let result = await classifier.classify(
            title: "李白诗集",
            summary: "唐代诗歌",
            body: "",
            llmCallback: fallbackLLM
        )
        // Even though LLM returned fallback, the keyword pass is still
        // strong for "李白 + 诗歌" -> .i wins
        #expect(result.category == .i)
    }

    @Test("tag cap = maxTags (= 10) is enforced on LLM output")
    func tagCapEnforced() async {
        let classifier = EntityClassifier()
        // LLM tries to return 15 tags (= beyond the cap)
        let tooManyTagsLLM: EntityClassifier.LLMCallback = { _ in
            let tags = (1...15).map { "tag\($0)" }
            let tagJSON = tags.map { "\"\($0)\"" }.joined(separator: ",")
            return "{\"category\":\"I\",\"tags\":[\(tagJSON)],\"entity_type\":1}"
        }
        let result = await classifier.classify(
            title: "测试",
            summary: "",
            body: "",
            llmCallback: tooManyTagsLLM
        )
        #expect(result.tags.count == EntityClassifier.maxTags)
        #expect(result.tags.count == 10)
    }

    @Test("LLM pass falls back to legacy 'K 3' format for backward-compat")
    func legacyK3Format() async {
        let classifier = EntityClassifier()
        // Old-style LLM response (= "K 3" = history + event). Use a
        // title without keyword signals so the LLM pass triggers.
        let legacyLLM: EntityClassifier.LLMCallback = { _ in
            return "K 3"
        }
        let result = await classifier.classify(
            title: "ABC-research-doc",
            summary: "",
            body: "",
            llmCallback: legacyLLM
        )
        #expect(result.category == .k)
        #expect(result.entityType == .event)
        #expect(result.tags.isEmpty, "legacy 'K 3' format has no tags")
    }
}