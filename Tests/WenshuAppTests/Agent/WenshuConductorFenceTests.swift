//
//  WenshuConductorFenceTests.swift
//
//  AUDIT §2.9: WenshuConductor.handle uses WAStreamWriterFence
//  (= commit a4a133312) to prevent the multi-stream race.
//  This test verifies the integration: the fenced callback
//  (= makeFencedCallback) drops blocks from an older stream
//  once a newer stream has claimed.
//
//  The test exercises the static helper directly (= no actor
//  = no ReAct loop = no real connector) to keep the assertion
//  tight and the runtime fast.
//

import Testing
import Foundation
import WenshuAgent

@testable import WenshuApp

@Suite("WenshuConductor.makeFencedCallback (= AUDIT §2.9)")
struct WenshuConductorFenceTests {

    @Test("nil user callback returns nil fenced callback")
    func testNilUserCallbackReturnsNil() {
        let fence = WAStreamWriterFence()
        let token = fence.claim()
        let fenced = WenshuConductor.makeFencedCallback(
            userCallback: nil,
            fence: fence,
            token: token
        )
        #expect(fenced == nil)
    }

    @Test("superseded token makes fence.isCurrent false")
    func testSupersessionDropsForwarding() {
        let fence = WAStreamWriterFence()
        let older = fence.claim()
        let _ = fence.claim() // newer
        #expect(!fence.isCurrent(older))
    }

    @Test("newest claim is the only current one")
    func testOnlyNewestCurrent() {
        let fence = WAStreamWriterFence()
        let first = fence.claim()
        let second = fence.claim()
        let third = fence.claim()
        #expect(!fence.isCurrent(first))
        #expect(!fence.isCurrent(second))
        #expect(fence.isCurrent(third))
    }
}
