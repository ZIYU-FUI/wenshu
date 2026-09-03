//
//  SkillAdapterTests.swift · Wenshu · v0.35 ticket 010
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SkillAdapter (ticket 010)")
struct SkillAdapterTests {

    @Test("parseSlashCommand extracts /skill + remainder")
    func testParseSlashCommand() {
        let parsed = SkillAdapter.parseSlashCommand("/compress focus on chapter 3")
        #expect(parsed?.skillName == "compress")
        #expect(parsed?.remainder == "focus on chapter 3")
    }

    @Test("parseSlashCommand handles /skill with no remainder")
    func testParseSlashCommandNoRemainder() {
        let parsed = SkillAdapter.parseSlashCommand("/help")
        #expect(parsed?.skillName == "help")
        #expect(parsed?.remainder == "")
    }

    @Test("parseSlashCommand returns nil for non-slash messages")
    func testParseSlashCommandNonSlash() {
        let parsed = SkillAdapter.parseSlashCommand("hello world")
        #expect(parsed == nil)
    }

    @Test("parseSlashCommand returns nil for / with no skill name")
    func testParseSlashCommandEmpty() {
        let parsed = SkillAdapter.parseSlashCommand("/")
        #expect(parsed == nil)
    }

    @Test("listSkills returns empty in sub-step 1 stub")
    func testListSkillsStub() async {
        let adapter = SkillAdapter()
        let skills = await adapter.listSkills()
        #expect(skills.isEmpty)
    }
}