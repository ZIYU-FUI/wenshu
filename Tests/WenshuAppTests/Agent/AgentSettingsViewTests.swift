//
//  AgentSettingsViewTests.swift · Wenshu · v0.35 (act-2-fix)
//
//  Smoke test that AgentSettingsView's body builds without crashing.
//  The view tree composes LLMConnectorSettingsView by default
//  (= selectedSection = .llmConnector), which exercises the
//  ConnectorProfileRow / ConnectorAuthField / ConnectorTestButton
//  stack. SwiftUI body access requires @MainActor: AgentSettingsView
//  body and its descendants use @State + @Binding whose getter and
//  setter are MainActor-isolated, and the body closure is implicitly
//  @MainActor-isolated. Accessing view.body from a non-MainActor
//  context trips _swift_task_checkIsolatedSwift -> dispatch_assert_queue
//  -> SIGTRAP (= signal 5). Marking each test as @MainActor matches
//  the convention used by WordCountBadgeTests, ComposerPanelTests,
//  GraphViewTests, BacklinksPanelTests, RuntimeCWDDisplayChipTests,
//  DropAffordanceTests, DragRegressionTests, etc. (= every other
//  SwiftUI view-body smoke test in this target).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AgentSettingsView (act-2-fix)")
struct AgentSettingsViewTests {

    @Test("AgentSettingsView renders without crashing")
    @MainActor
    func testViewRenders() {
        let view = AgentSettingsView()
        _ = view.body
    }

    @Test("Default section is llmConnector")
    @MainActor
    func testDefaultSection() {
        let view = AgentSettingsView()
        #expect(view.selectedSection == .llmConnector)
    }

    @Test("3 sections available")
    @MainActor
    func testSectionsCount() {
        #expect(AgentSettingsView.AgentSection.allCases.count == 3)
    }
}
