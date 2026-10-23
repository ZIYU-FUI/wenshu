//
//  LLMRequestTimeoutTests.swift · Wenshu
//
//  Proves that a non-streaming LLM call is not killed at 60 seconds.
//
//  Measured 2026-10-24: a cover whose document took the thinking
//  model longer than a minute died with `NSURLErrorDomain Code=-1001`
//  (= the request timed out), and the card was left marked failed.
//  The same document answered in seconds on a retry, so the request
//  was not too big; it was sometimes slower than `URLSession.shared`'s
//  60-second request timeout.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("LLM request timeout")
struct LLMRequestTimeoutTests {

    @Test("The session waits longer than the default sixty seconds")
    func theSessionWaitsLongerThanTheDefault() {
        let configuration = WenshuAppDelegateLLMHelpers.llmSession.configuration

        #expect(configuration.timeoutIntervalForRequest >= 180)
    }

    @Test("The resource timeout bounds the whole call")
    func theResourceTimeoutBoundsTheWholeCall() {
        let configuration = WenshuAppDelegateLLMHelpers.llmSession.configuration

        // A resource timeout that is not larger than the request
        // timeout would cut the call short anyway.
        #expect(
            configuration.timeoutIntervalForResource
                > configuration.timeoutIntervalForRequest
        )
    }

    @Test("The session is built once, so the connections are pooled")
    func theSessionIsBuiltOnce() {
        #expect(
            WenshuAppDelegateLLMHelpers.llmSession
                === WenshuAppDelegateLLMHelpers.llmSession
        )
    }
}
