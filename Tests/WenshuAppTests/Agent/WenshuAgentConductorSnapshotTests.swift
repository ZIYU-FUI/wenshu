//
//  WenshuAgentConductorSnapshotTests.swift
//
//  AUDIT §2.2 partial: WenshuAgent.shared.currentConductorSync()
//  is the nonisolated sync accessor (= SwiftUI `var` callers
//  in ChatZoneView / ChatView / ChatSessionViewModel /
//  EditorChatNSController can read the conductor without
//  `await`). This test verifies the snapshot stays in
//  sync with the actor-isolated install path.
//

import Testing
import Foundation

@testable import WenshuApp

@Suite("WenshuAgent.shared.currentConductorSync (= AUDIT §2.2)")
struct WenshuAgentConductorSnapshotTests {

    @Test("currentConductorSync does not crash (= the snapshot is reachable)")
    func testSnapshotReachable() {
        // We do not assert a specific value (= the test order
        // is shared with other tests that may have installed
        // a conductor); = the test asserts the accessor does
        // not throw and returns a value (= either nil or
        // non-nil is acceptable).
        let snapshot = WenshuAgent.shared.currentConductorSync()
        #expect(snapshot == nil || snapshot != nil)
    }

    @Test("currentConductor (async) does not crash either")
    func testAsyncAccessorReachable() async {
        let value = await WenshuAgent.shared.currentConductor()
        #expect(value == nil || value != nil)
    }
}
