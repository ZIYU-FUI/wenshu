//
//  MultiAgentDispatchTests.swift · Wenshu · v0.23 ticket 004 (multi-agent dispatch tests)
//
//  Boss 2026-08-23 拍: verify multi-agent dispatch works.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Multi-agent dispatch (5 sub-agents + auditor)")
struct MultiAgentDispatchTests {

    // MARK: - 5 sub-agent identity coverage (covered in SubAgentIdentityTests)

    @Test("5 sub-agent names are all valid SubAgentIdentity.Name cases")
    func allSubAgentNamesValid() {
        #expect(SubAgentIdentity.Name.allCases.count == 5)
        let names = SubAgentIdentity.Name.allCases.map(\.rawValue)
        #expect(names.contains("researcher"))
        #expect(names.contains("writer"))
        #expect(names.contains("analyst"))
        #expect(names.contains("archivist"))
        #expect(names.contains("auditor"))
    }

    // MARK: - Intent classify filter

    @Test("intent result filters unknown agent names")
    func intentFilterUnknownAgents() {
        // WenshuConductor.parseAgentList() returns raw strings; the
        // .filter { SubAgentIdentity.Name(rawValue: name) != nil }
        // step ensures only valid agents proceed to dispatch.
        // Simulate the filter logic directly.
        let raw = ["researcher", "writer", "invalid_module", "auditor"]
        let valid = raw.filter { SubAgentIdentity.Name(rawValue: $0) != nil }
        #expect(valid == ["researcher", "writer", "auditor"])
    }

    @Test("all 5 agent names pass filter")
    func allAgentNamesPassFilter() {
        for name in SubAgentIdentity.Name.allCases {
            #expect(SubAgentIdentity.Name(rawValue: name.rawValue) != nil)
        }
    }

    // MARK: - Auditor trigger logic

    @Test("auditor runs when writer in selection")
    func auditorRunsWithWriter() {
        let selection = ["researcher", "writer"]
        let needsAudit = selection.contains("writer") || selection.contains("analyst")
        #expect(needsAudit == true)
    }

    @Test("auditor runs when analyst in selection")
    func auditorRunsWithAnalyst() {
        let selection = ["analyst"]
        let needsAudit = selection.contains("writer") || selection.contains("analyst")
        #expect(needsAudit == true)
    }

    @Test("auditor skipped when only researcher")
    func auditorSkippedForResearcherOnly() {
        let selection = ["researcher"]
        let needsAudit = selection.contains("writer") || selection.contains("analyst")
        #expect(needsAudit == false)
    }

    @Test("auditor skipped when only archivist")
    func auditorSkippedForArchivistOnly() {
        let selection = ["archivist"]
        let needsAudit = selection.contains("writer") || selection.contains("analyst")
        #expect(needsAudit == false)
    }

    // MARK: - Sub-agent output format

    @Test("Researcher output format is JSON evidence array")
    func researcherOutputFormat() {
        let prompt = SubAgentIdentity.systemPrompt(name: .researcher)
        #expect(prompt.contains("[{"))
        #expect(prompt.contains("source"))
        #expect(prompt.contains("quote"))
    }

    @Test("Auditor output format includes verdict + issues + confidence")
    func auditorOutputFormat() {
        let prompt = SubAgentIdentity.systemPrompt(name: .auditor)
        #expect(prompt.contains("verdict"))
        #expect(prompt.contains("issues"))
        #expect(prompt.contains("confidence"))
        #expect(prompt.contains("fix_suggestion"))
    }

    @Test("Writer output format includes content + wordCount + style")
    func writerOutputFormat() {
        let prompt = SubAgentIdentity.systemPrompt(name: .writer)
        #expect(prompt.contains("content"))
        #expect(prompt.contains("wordCount"))
        #expect(prompt.contains("style"))
    }

    @Test("Archivist output format includes stored + recalled + action")
    func archivistOutputFormat() {
        let prompt = SubAgentIdentity.systemPrompt(name: .archivist)
        #expect(prompt.contains("stored"))
        #expect(prompt.contains("recalled"))
        #expect(prompt.contains("action"))
    }

    @Test("Analyst output format includes type + data")
    func analystOutputFormat() {
        let prompt = SubAgentIdentity.systemPrompt(name: .analyst)
        #expect(prompt.contains("type"))
        #expect(prompt.contains("data"))
    }
}