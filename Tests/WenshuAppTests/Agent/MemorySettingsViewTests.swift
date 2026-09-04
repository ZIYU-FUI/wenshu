//
//  MemorySettingsViewTests.swift · Wenshu · v0.35 ticket 009
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MemorySettingsView (ticket 009)")
struct MemorySettingsViewTests {

    @Test("MemorySettingsView renders without crashing (smoke test)")
    func testViewRenders() {
        let view = MemorySettingsView()
        _ = view.body  // smoke test: view builder should not throw
    }

    @Test("Default scope is perBook")
    func testDefaultScope() {
        let view = MemorySettingsView()
        #expect(view.scope == .perBook)
    }

    @Test("Default retention is 90 days")
    func testDefaultRetention() {
        let view = MemorySettingsView()
        #expect(view.retentionDays == 90)
    }
}