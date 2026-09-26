//
//  WenshuAppDelegateSubAgentDrainLoopTests.swift · Wenshu · v2.7d
//
//  Unit tests for the sub-agent runner drain loop lifecycle on
//  WenshuAppDelegate (= P3 wiring, boss 2026-09-26 '团队链路通').
//
//  What we test:
//    1. stopSubAgentDrainLoop is a no-op when not started
//       (= safe to call from applicationWillTerminate even when
//       startSubAgentDrainLoop was never called; = the AppDelegate
//       shutdown path must be idempotent).
//
//  What we do NOT test (= per Q46 stop-rule on the test budget):
//    - startSubAgentDrainLoop wiring (= creating a background
//      Task.detached inside a Swift Testing test process triggers
//      a swift-concurrency-runtime teardown abort). The start path
//      is fully exercised by the live E2E test
//      E2EMemoryAndLLMFlowTests/delegateResearchPath (= it
//      registers a real BackgroundDelegationHandle, the drain
//      loop runs it, and the handle completes end-to-end).
//    - Drain loop timing (= how often the loop wakes up; = how
//      long a sub-agent takes; = these are Live test concerns).
//
//  Note: this test does NOT call activeLLMConnector() (= it would
//  create an AnthropicConnector instance, = fine). We only test
//  the shutdown-path safety.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuAppDelegate sub-agent drain loop · v2.7d P3 wiring", .serialized)
@MainActor
struct WenshuAppDelegateSubAgentDrainLoopTests {

    @Test("stopSubAgentDrainLoop is a no-op when not started")
    func stopIsNoopWhenNotStarted() {
        // Calling stop without a start must be safe (= no crash, no
        // exception). The static var remains nil. This guards the
        // applicationWillTerminate path (= it must not crash when
        // applicationDidFinishLaunching never started the loop, =
        // e.g. when running the AppDelegate outside a full NSApp).
        WenshuAppDelegate.stopSubAgentDrainLoop()
        WenshuAppDelegate.stopSubAgentDrainLoop()
        // No assertion needed beyond not crashing.
    }

    @Test("multiple sequential stops remain a no-op")
    func multipleStopsAreNoop() {
        // Stop 5 times in a row (= mimics a buggy caller that
        // double-fires applicationWillTerminate). Each call must
        // be safe.
        for _ in 0..<5 {
            WenshuAppDelegate.stopSubAgentDrainLoop()
        }
    }
}