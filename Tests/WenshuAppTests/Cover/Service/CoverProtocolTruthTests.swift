//
//  CoverProtocolTruthTests.swift · Wenshu
//
//  Proves that the settings can tell the truth about WHICH protocol
//  the app speaks.
//
//  The app speaks ONE cover protocol (= MiniMax's image and video
//  endpoints). The resolver already refuses a route that names a
//  provider the app cannot speak to, so the switch does not pretend
//  to work. What the settings must add is the truth: which protocol
//  it is, and a warning when the user points the route at an endpoint
//  that does not look like a cover endpoint.
//
//  The check is a HOST check and not a block: a proxy of the user's
//  own can perfectly well speak the cover protocol on another host.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover protocol truth")
struct CoverProtocolTruthTests {

    @Test("A MiniMax cover endpoint is recognised")
    func aMiniMaxCoverEndpointIsRecognised() {
        #expect(
            CoverProviderCapability.speaksCoverProtocol(
                baseURL: "https://api.minimaxi.com/v1/image_generation"
            )
        )
        #expect(
            CoverProviderCapability.speaksCoverProtocol(
                baseURL: "https://api.minimax.io/v1/video_generation"
            )
        )
    }

    @Test("Another host is not")
    func anotherHostIsNot() {
        #expect(
            CoverProviderCapability.speaksCoverProtocol(
                baseURL: "https://generativelanguage.googleapis.com/v1beta/models"
            ) == false
        )
        #expect(
            CoverProviderCapability.speaksCoverProtocol(
                baseURL: "https://openrouter.ai/api/v1/videos"
            ) == false
        )
    }

    @Test("A route with no endpoint of its own says nothing")
    func aRouteWithNoEndpointOfItsOwnSaysNothing() {
        // The app's own endpoint is a cover endpoint, so there is
        // nothing to mention.
        #expect(CoverProviderCapability.speaksCoverProtocol(baseURL: nil))
    }

    @Test("An endpoint that is not a URL at all says nothing")
    func anEndpointThatIsNotAURLAtAllSaysNothing() {
        // A malformed endpoint is not the protocol's business: the
        // service's own answer is what the user will read.
        #expect(CoverProviderCapability.speaksCoverProtocol(baseURL: "not a url"))
    }
}
