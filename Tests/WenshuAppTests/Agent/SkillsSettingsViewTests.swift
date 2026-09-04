//
//  SkillsSettingsViewTests.swift · Wenshu · v0.35 ticket 010
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SkillsSettingsView (ticket 010)")
struct SkillsSettingsViewTests {

    @Test("SkillsSettingsView renders without crashing")
    func testViewRenders() {
        let view = SkillsSettingsView()
        _ = view.body
    }

    @Test("Default skills list is empty")
    func testDefaultEmpty() {
        let view = SkillsSettingsView()
        #expect(view.skills.isEmpty)
    }

    @Test("Custom skills list accepted")
    func testCustomSkills() {
        let skill = SkillAdapter.Skill(
            name: "compress",
            description: "Compress context",
            enabled: true
        )
        let view = SkillsSettingsView(skills: [skill])
        #expect(view.skills.count == 1)
        #expect(view.skills[0].name == "compress")
    }
}