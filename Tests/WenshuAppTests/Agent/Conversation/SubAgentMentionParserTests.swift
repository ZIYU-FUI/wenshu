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
//    7. testDispatchReceipt_namesNoRole — the chat-area receipt names
//       the handle and no role
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

    /// The chat area is where the user talks to Wenshu, so the
    /// receipt for a dispatched background task names the handle and
    /// never the role. The board and the activity feed keep the role
    /// identity.
    @Test("the dispatch receipt names the handle and no role")
    func testDispatchReceipt_namesNoRole() {
        let handleID = "ab12cd34"
        let receipt = ChatSubAgentReceipt.dispatched(handleID: handleID, bundle: .module)

        // The handle is the user's only reference to the background
        // task (= it survives into the receipt).
        #expect(receipt.contains(handleID))
        // The receipt is the localized value, not the raw key (= a
        // missing catalog entry would render the key itself).
        #expect(receipt != "chatview.subagent.dispatched")
        // No role name reaches the chat area (= the five wenshu
        // sub-agent slugs).
        for slug in ["researcher", "writer", "analyst", "archivist", "auditor"] {
            #expect(!receipt.contains(slug))
        }
        #expect(!receipt.contains("Sub-agent"))

        // The failure receipt names no role either, even when the
        // underlying error does (= the role stays on the board).
        let raw = AsyncDelegationError.unknownSubAgent(name: "writer")
        // Positive control: the raw error text names the role, so
        // the receipt below proves the mapping dropped it.
        #expect(raw.errorDescription?.contains("writer") == true)
        let failure = ChatSubAgentReceipt.failed(error: raw, bundle: .module)
        // The cause is the role-free user-facing text.
        let cause = UserFacingError.from(raw).errorDescription ?? ""
        #expect(!cause.isEmpty)
        #expect(failure.contains(cause))
        for slug in ["researcher", "writer", "analyst", "archivist", "auditor"] {
            #expect(!failure.contains(slug))
        }
        #expect(!failure.contains("Sub-agent"))

        // Both locales carry the receipt, and neither names a role.
        for language in ["en", "zh-Hans"] {
            let strings = StringCatalogReader.strings(language: language)
            for key in ["chatview.subagent.dispatched", "chatview.subagent.dispatch_failed"] {
                let value = strings[key] ?? ""
                #expect(!value.isEmpty, "expected \(key) in \(language)")
                #expect(value.contains("%@"), "expected \(key) in \(language) to keep the %@ placeholder")
                for slug in ["researcher", "writer", "analyst", "archivist", "auditor"] {
                    #expect(!value.contains(slug), "expected \(key) in \(language) to name no role")
                }
            }
        }
    }
}
