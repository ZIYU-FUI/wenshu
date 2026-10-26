//
//  SubAgentRoleRegistryTests.swift · Wenshu
//
//  The role table's own tests. The table is where a sub-agent role's
//  facts live (= slug, display label, system prompt, tool names, the
//  dispatch capability), so these tests pin the table itself:
//
//    1. the table has exactly one row per role, and every row carries
//       a slug, a label, a prompt and a tool list
//    2. the table's slugs are exactly the five slugs the rest of the
//       app knows, and the mention parser offers the same set
//    3. the table's prompts, labels and tool lists are the ones the
//       identity file returned before the roles moved into the table
//       (= the move is a move: = the facts did not change)
//    4. the table is readable without any global state (= a test can
//       read it directly)
//
//  The two contract suites that already existed
//  (= SubAgentIdentityTests / SubAgentIdentityToolsTests) are NOT
//  touched by this file: they keep asserting the identity accessors.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("SubAgentRoleRegistry (the one role table)")
struct SubAgentRoleRegistryTests {

    // MARK: - The table's shape

    @Test("the table has one row per role, and each row is complete")
    func oneCompleteRowPerRole() {
        #expect(
            SubAgentRoleRegistry.roles.count == SubAgentIdentity.Name.allCases.count,
            "the table must carry exactly one row per role"
        )

        var slugs = Set<String>()
        for row in SubAgentRoleRegistry.roles {
            #expect(!row.slug.isEmpty, "a row must carry a slug")
            #expect(!row.displayLabel.isEmpty, "a row must carry a display label")
            #expect(!row.prompt.isEmpty, "a row must carry a system prompt")
            #expect(slugs.insert(row.slug).inserted, "a slug must name one row only")
        }
    }

    @Test("every role of the identity enum has a row, and every row has a role")
    func tableAndEnumAgree() {
        for name in SubAgentIdentity.Name.allCases {
            let row = SubAgentRoleRegistry.role(forSlug: name.rawValue)
            #expect(row != nil, "\(name.rawValue) must have a row in the table")
            #expect(row?.slug == name.rawValue, "a row's slug must be the enum's raw value")
        }
        for row in SubAgentRoleRegistry.roles {
            #expect(
                SubAgentIdentity.Name(rawValue: row.slug) != nil,
                "\(row.slug) must be a role the identity enum knows"
            )
        }
    }

    // MARK: - The slugs (= the vocabulary the app speaks)

    @Test("the table's slugs are exactly the five the app knows")
    func theFiveSlugs() {
        let expected: Set<String> = [
            "researcher", "writer", "analyst", "archivist", "auditor"
        ]
        #expect(
            Set(SubAgentRoleRegistry.roles.map(\.slug)) == expected,
            "the table's slugs must be exactly the five known slugs"
        )
    }

    @Test("the mention parser offers the table's slugs")
    func mentionParserReadsTheTable() {
        #expect(
            Set(SubAgentMentionParser.availableSlugs) == Set(SubAgentRoleRegistry.roles.map(\.slug)),
            "the mention parser must offer exactly the table's slugs"
        )
        #expect(
            SubAgentMentionParser.availableSlugs.count == SubAgentRoleRegistry.roles.count,
            "the mention parser must not offer a slug the table lacks"
        )
    }

    // MARK: - The facts (= the move is a move)

    @Test("the labels are the ones the app showed before the move")
    func labelsAreUnchanged() throws {
        let expected: [String: String] = [
            "researcher": "Researcher (检索专家)",
            "writer": "Writer (写作专家)",
            "analyst": "Analyst (结构分析师)",
            "archivist": "Archivist (记忆管理员)",
            "auditor": "Auditor (质量审计)"
        ]
        for (slug, label) in expected {
            #expect(
                SubAgentRoleRegistry.role(forSlug: slug)?.displayLabel == label,
                "\(slug)'s display label must not have changed"
            )
            let name = try #require(SubAgentIdentity.Name(rawValue: slug))
            #expect(
                SubAgentIdentity.displayName(name: name) == label,
                "\(slug)'s display name must still read the same"
            )
        }
    }

    @Test("the tool lists are the ones the app sent before the move")
    func toolListsAreUnchanged() throws {
        let expected: [String: [String]] = [
            "researcher": ["web_search", "reference_library"],
            "writer": ["paragraph_ai"],
            "analyst": [],
            "archivist": [],
            "auditor": []
        ]
        for (slug, tools) in expected {
            #expect(
                SubAgentRoleRegistry.role(forSlug: slug)?.toolNames == tools,
                "\(slug)'s tool list must not have changed"
            )
            let name = try #require(SubAgentIdentity.Name(rawValue: slug))
            #expect(
                SubAgentIdentity.tools(name: name) == tools,
                "\(slug)'s tool list must still read the same"
            )
        }
    }

    @Test("the prompts are the ones the app sent before the move")
    func promptsAreUnchanged() {
        // The role sentence each prompt opens with (= the identity
        // line the pre-change prompt constants carried verbatim).
        let identityLines: [String: String] = [
            "researcher": "You are Researcher, a sub-agent of",
            "writer": "You are Writer, a sub-agent of",
            "analyst": "You are Analyst, a sub-agent of",
            "archivist": "You are Archivist, a sub-agent of",
            "auditor": "You are Auditor, a sub-agent of"
        ]
        for (slug, line) in identityLines {
            let row = SubAgentRoleRegistry.role(forSlug: slug)
            #expect(
                row?.prompt.contains(line) == true,
                "\(slug)'s prompt must still open with its identity line"
            )
            #expect(
                row?.systemPrompt.contains(line) == true,
                "\(slug)'s full prompt must still carry its identity line"
            )
        }

        // The composed prompt is the role's own prompt plus the shared
        // tool restrictions (= the pre-change composition).
        for row in SubAgentRoleRegistry.roles {
            #expect(
                row.systemPrompt.hasPrefix(row.prompt),
                "the full prompt must start with the role's own prompt"
            )
            #expect(
                row.systemPrompt.count > row.prompt.count,
                "the full prompt must add the shared tool restrictions"
            )
            #expect(
                row.systemPrompt.contains("You MUST NOT call file.write"),
                "the shared tool restrictions must still be appended"
            )
        }

        // The identity accessor reads the table, so the prompt the
        // runner sends is the table's prompt (= no second copy).
        for name in SubAgentIdentity.Name.allCases {
            let row = SubAgentRoleRegistry.role(forSlug: name.rawValue)
            #expect(
                SubAgentIdentity.systemPrompt(name: name) == row?.systemPrompt,
                "\(name.rawValue)'s prompt must be the table's prompt"
            )
        }
    }

    @Test("each role's dispatch capability names the run it gets")
    func dispatchCapabilities() {
        let expected: [String: SubAgentRoleDispatch] = [
            "researcher": .llmRun,
            "writer": .llmRun,
            "analyst": .llmRun,
            "archivist": .archiveRun,
            "auditor": .auditRun
        ]
        for (slug, dispatch) in expected {
            #expect(
                SubAgentRoleRegistry.role(forSlug: slug)?.dispatch == dispatch,
                "\(slug)'s dispatch capability must not have changed"
            )
        }
    }

    // MARK: - Reachability

    @Test("the table is readable without any global state")
    func tableIsDirectlyReadable() {
        // A plain read (= no actor, no shared singleton, no
        // bootstrapping): the table hands out its facts on its own.
        let rows = SubAgentRoleRegistry.roles
        #expect(rows.count == 5)
        #expect(rows.allSatisfy { !$0.slug.isEmpty })
    }
}
