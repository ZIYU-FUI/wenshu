//
//  CoverFailureMessageTests.swift · Wenshu
//
//  Proves that the message a card shows for a failure is a SENTENCE.
//
//  Measured 2026-10-24: a transport failure wrote the raw dump of a
//  Foundation error into the card
//
//      Error Domain=NSURLErrorDomain Code=-1001 "timed out"
//      UserInfo={_kCFStreamErrorCodeKey=-2102, ...}
//
//  which reads like a program error. The standing requirement is the
//  opposite: the user must be told what happened in a way they can
//  act on.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover failure message")
struct CoverFailureMessageTests {

    /// An error with a message of its own, like every provider failure.
    private struct SpokenError: LocalizedError {
        var errorDescription: String? { "the account has no quota left" }
    }

    /// A transport error: a Foundation error with no message of its own.
    private func transportError() -> Error {
        NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "The request timed out."]
        )
    }

    @Test("An error with its own message keeps it")
    func anErrorWithItsOwnMessageKeepsIt() {
        #expect(CoverFailureMessage.describe(SpokenError()) == "the account has no quota left")
    }

    @Test("A transport error reads as its localized description")
    func aTransportErrorReadsAsItsLocalizedDescription() {
        let message = CoverFailureMessage.describe(transportError())

        #expect(message == "The request timed out.")
    }

    @Test("A transport error never reads as a dump of its fields")
    func aTransportErrorNeverReadsAsADump() {
        let message = CoverFailureMessage.describe(transportError())

        #expect(!message.contains("Error Domain="))
        #expect(!message.contains("UserInfo="))
        #expect(!message.contains("Code="))
    }

    @Test("The provider failure's sentence survives")
    func theProviderFailuresSentenceSurvives() {
        let failure = CoverImageError.providerFailure(
            CoverProviderFailure(
                kind: .quotaExhausted,
                providerSlug: "minimax-cn",
                detail: "the plan's allowance is used up"
            )
        )

        let message = CoverFailureMessage.describe(failure)

        #expect(message.contains("no quota left"))
        #expect(!message.hasPrefix("providerFailure("))
        #expect(!message.hasPrefix("CoverImageError."))
    }
}
