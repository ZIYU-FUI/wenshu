//
//  CoverSettingsViewTests.swift · Wenshu
//
//  Proves the settings pane's BEHAVIOUR, not its pixels.
//
//  There is no SwiftUI rendering harness in this project, so the
//  pane's decisions are tested as the route operations they are, and
//  the two rules the pane enforces are tested directly:
//
//  - changing the provider clears the model, the endpoint and the
//    key, because they belonged to the old provider,
//  - "reset to automatic" returns the route to inheriting.
//
//  The atomic-route test is the important one. A pane that let the
//  user change the provider while keeping the old provider's key
//  would produce a route that cannot work, and the symptom would
//  only appear as a failed generation much later.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover settings view")
struct CoverSettingsViewTests {

    @Test("Choosing a provider clears the model, the endpoint and the key")
    func choosingAProviderClearsTheRest() {
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "openai",
            model: "gpt-image-1",
            baseURL: "https://example.test/v1",
            apiKey: "secret"
        )

        // What the provider picker does.
        let changed = route.replacing(
            providerSlug: "minimax-cn",
            model: nil,
            baseURL: nil,
            apiKey: nil
        )

        #expect(changed.providerSlug == "minimax-cn")
        #expect(changed.model == nil)
        #expect(changed.baseURL == nil)
        #expect(changed.apiKey == nil)
    }

    @Test("Reset to automatic returns the route to inheriting")
    func resetReturnsToAutomatic() {
        let route = CoverServiceRoute(
            kind: .video,
            providerSlug: "minimax-cn",
            model: "MiniMax-Hailuo-02"
        )

        let reset = route.resetting()

        #expect(reset.isAuto)
        #expect(reset.providerSlug == nil)
        #expect(reset.model == nil)
        // The reset keeps the KIND, so the row still knows which
        // service it points at.
        #expect(reset.kind == .video)
    }

    @Test("An automatic route has no fields set")
    func automaticRouteHasNoFields() {
        let route = CoverServiceRoute.auto(for: .image)

        #expect(route.isAuto)
        #expect(route.providerSlug == nil)
        #expect(route.model == nil)
        #expect(route.baseURL == nil)
        #expect(route.apiKey == nil)
    }

    @Test("The two rows are the two kinds, and the video kind has no default")
    func theTwoRowsAreTheTwoKinds() {
        #expect(CoverServiceKind.allCases.count == 2)
        #expect(CoverServiceKind.image.defaultModel == "image-01")
        // The video kind has NO default, so a video route that names a
        // provider but no model fails rather than quietly spending the
        // scarce video quota.
        #expect(CoverServiceKind.video.defaultModel == nil)
    }
}
