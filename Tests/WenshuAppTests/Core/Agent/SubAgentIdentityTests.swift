//
//  SubAgentIdentityTests.swift · Wenshu · v0.23 ticket 001 (5 sub-agent system prompts)
//
//  Boss 2026-08-23 拍: verify 5 sub-agent identity is defined.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SubAgentIdentity (5 sub-agents)")
struct SubAgentIdentityTests {

    @Test("all 5 sub-agent names have system prompts")
    func allNamesHaveSystemPrompts() {
        for name in SubAgentIdentity.Name.allCases {
            let prompt = SubAgentIdentity.systemPrompt(name: name)
            #expect(!prompt.isEmpty, "missing system prompt for \(name)")
        }
    }

    @Test("all 5 sub-agent names have tool lists")
    func allNamesHaveToolLists() {
        for name in SubAgentIdentity.Name.allCases {
            let tools = SubAgentIdentity.tools(name: name)
            #expect(!tools.isEmpty, "missing tools for \(name)")
        }
    }

    @Test("all 5 sub-agent names have display names")
    func allNamesHaveDisplayNames() {
        for name in SubAgentIdentity.Name.allCases {
            let display = SubAgentIdentity.displayName(name: name)
            #expect(!display.isEmpty, "missing display name for \(name)")
        }
    }

    @Test("Researcher tools = search + web + linkgraph")
    func researcherTools() {
        let tools = SubAgentIdentity.tools(name: .researcher)
        #expect(tools.contains("search"))
        #expect(tools.contains("web"))
        #expect(tools.contains("linkgraph"))
    }

    @Test("Writer tools = composer + template + wordcount")
    func writerTools() {
        let tools = SubAgentIdentity.tools(name: .writer)
        #expect(tools.contains("composer"))
        #expect(tools.contains("template"))
        #expect(tools.contains("wordcount"))
    }

    @Test("Analyst tools = outline + bases + graph")
    func analystTools() {
        let tools = SubAgentIdentity.tools(name: .analyst)
        #expect(tools.contains("outline"))
        #expect(tools.contains("bases"))
        #expect(tools.contains("graph"))
    }

    @Test("Archivist tools = memory + bookmark + backup")
    func archivistTools() {
        let tools = SubAgentIdentity.tools(name: .archivist)
        #expect(tools.contains("memory"))
        #expect(tools.contains("bookmark"))
        #expect(tools.contains("backup"))
    }

    @Test("Auditor tools = memory only (read-only)")
    func auditorTools() {
        let tools = SubAgentIdentity.tools(name: .auditor)
        #expect(tools == ["memory"])
    }

    @Test("system prompts differ across all 5 agents")
    func systemPromptsDiffer() {
        var seen: Set<String> = []
        for name in SubAgentIdentity.Name.allCases {
            let prompt = SubAgentIdentity.systemPrompt(name: name)
            let hash = String(prompt.hashValue)
            #expect(!seen.contains(hash), "duplicate system prompt for \(name)")
            seen.insert(hash)
        }
    }

    @Test("each prompt mentions its agent role")
    func eachPromptMentionsRole() {
        // Researcher prompt should reference "search specialist"
        #expect(SubAgentIdentity.systemPrompt(name: .researcher).contains("search specialist"))
        // Writer
        #expect(SubAgentIdentity.systemPrompt(name: .writer).contains("writing specialist"))
        // Analyst
        #expect(SubAgentIdentity.systemPrompt(name: .analyst).contains("structure-analysis specialist"))
        // Archivist
        #expect(SubAgentIdentity.systemPrompt(name: .archivist).contains("long-term memory specialist"))
        // Auditor
        #expect(SubAgentIdentity.systemPrompt(name: .auditor).contains("quality-gate specialist"))
    }

    @Test("Auditor prompt includes verdict format schema")
    func auditorPromptHasVerdictFormat() {
        let prompt = SubAgentIdentity.systemPrompt(name: .auditor)
        #expect(prompt.contains("pass"))
        #expect(prompt.contains("warn"))
        #expect(prompt.contains("fail"))
        #expect(prompt.contains("verdict"))
    }

    @Test("all prompts have reasonable size (500-3000 chars)")
    func promptsReasonableSize() {
        for name in SubAgentIdentity.Name.allCases {
            let len = SubAgentIdentity.systemPrompt(name: name).count
            #expect(len > 500, "prompt too short for \(name): \(len)")
            #expect(len < 3000, "prompt too long for \(name): \(len)")
        }
    }
}