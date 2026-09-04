//
//  AgentSettingsViewTests.swift · Wenshu · v0.35 (act-2-fix)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AgentSettingsView (act-2-fix)")
struct AgentSettingsViewTests {

    @Test("AgentSettingsView renders without crashing")
    func testViewRenders() {
        let view = AgentSettingsView()
        _ = view.body
    }

    @Test("Default section is llmConnector")
    func testDefaultSection() {
        let view = AgentSettingsView()
        #expect(view.selectedSection == .llmConnector)
    }

    @Test("3 sections available")
    func testSectionsCount() {
        #expect(AgentSettingsView.AgentSection.allCases.count == 3)
    }
}