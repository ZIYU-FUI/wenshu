//
//  SubAgentMentionParserTests.swift · Wenshu ·  (2026-09-04)
//
//  Round-trip tests for SubAgentMentionParser (= `@subagent_slug <task>`
//  syntax in chat input).
//
//  Acceptance (= boss OOB 'B' /  spec):
//    1. testParse_singleMention — single `@slug task` parses
//    2. testParse_noMention_returnsNil — plain text returns nil
//    3. testParseAll_multipleMentions — multi-mention parseAll
//    4. testParse_syntax_atWriterDraftChapter — quoted spec example
//    5. testParse_invalidSyntax_returnsNil — @wrongslug / @WRITER (caps)
//       / @writerly (no boundary) all return nil / unmatched
//    6. testAvailableSlugs_includesCommonSubAgents — 5 wenshu slugs
//
// swift test --filter SubAgentMentionParser
//

import Testing
import Foundation
@testable import WenshuApp

@Suite(" — @-mention subagent parser")
struct SubAgentMentionParserTests {

    /// 
    /// the slug and task.
    @Test("parse single @mention returns ParsedMention")
    func testParse_singleMention() {
        let parsed = SubAgentMentionParser.parse("@writer draft chapter 3")
        #expect(parsed != nil)
        #expect(parsed?.subagentSlug == "writer")
        #expect(parsed?.task == "draft chapter 3")
    }

    /// 
    @Test("parse plain text returns nil")
    func testParse_noMention_returnsNil() {
        #expect(SubAgentMentionParser.parse("hello world") == nil)
        #expect(SubAgentMentionParser.parse("just a normal message") == nil)
        #expect(SubAgentMentionParser.parse("") == nil)
    }

    /// 
    /// ParsedMentions (= the user can dispatch a writer + a reviewer
    /// in one message).
    @Test("parseAll returns multiple mentions")
    func testParseAll_multipleMentions() {
        let parsed = SubAgentMentionParser.parseAll(
            "@writer draft this AND @researcher find references for it"
        )
        #expect(parsed.count == 2)
        #expect(parsed[0].subagentSlug == "writer")
        #expect(parsed[0].task == "draft this AND")
        #expect(parsed[1].subagentSlug == "researcher")
        #expect(parsed[1].task == "find references for it")
    }

    /// 
    @Test("parse @writer draft chapter 1 (spec example)")
    func testParse_syntax_atWriterDraftChapter() {
        let parsed = SubAgentMentionParser.parse("@writer draft chapter 1")
        #expect(parsed != nil)
        #expect(parsed?.subagentSlug == "writer")
        #expect(parsed?.task == "draft chapter 1")
    }

    /// 
    /// case, missing task, longer slug that contains a known one as
    /// prefix but isn't a separate identity).
    @Test("parse invalid syntax returns nil or unmatched")
    func testParse_invalidSyntax_returnsNil() {
        // Unknown slug
        #expect(SubAgentMentionParser.parse("@nonexistent do something") == nil)
        // Wrong case (= wenshu slugs are lowercase raw values; @WRITER
        // does NOT match "writer")
        #expect(SubAgentMentionParser.parse("@WRITER do something") == nil)
        // @-symbol with no slug after it
        #expect(SubAgentMentionParser.parse("@ do something") == nil)
        // slug is a prefix of a longer word (= @writerly does NOT match
        // "writer" because there's no word boundary). Parser should
        // either return nil OR match nothing — the test asserts the
        // strict behavior of no-match.
        let longer = SubAgentMentionParser.parse("@writerly draft chapter 3")
        // The parse function returns the first match; if the regex
        // correctly enforces word boundary, longer is nil.
        #expect(longer == nil)
    }

    /// 
    /// (= hermes has "editor" / "reviewer" too, but wenshu does not —
    /// per AGENTS.md §11.3 wenshu-side-wins, only the 5 wenshu
    /// sub-agents are recognized).
    @Test("availableSlugs includes common sub-agents")
    func testAvailableSlugs_includesCommonSubAgents() {
        let slugs = SubAgentMentionParser.availableSlugs
        // All 5 wenshu sub-agents (= SubAgentIdentity.Name.allCases rawValues).
        #expect(slugs.contains("researcher"))
        #expect(slugs.contains("writer"))
        #expect(slugs.contains("analyst"))
        #expect(slugs.contains("archivist"))
        #expect(slugs.contains("auditor"))
        // wenshu does NOT have hermes' "editor" or "reviewer"
        // (= per AGENTS.md §11.3 wenshu-side-wins; only the 5 above).
        #expect(!slugs.contains("editor"))
        #expect(!slugs.contains("reviewer"))
        // Slugs are sorted alphabetically (= deterministic order).
        #expect(slugs == slugs.sorted())
    }
}
