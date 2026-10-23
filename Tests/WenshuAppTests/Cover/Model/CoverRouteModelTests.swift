//
//  CoverRouteModelTests.swift · Wenshu
//
//  Proves that a cover route can NAME a model, and that the model
//  survives the store.
//
//  The model is what makes a video route resolve at all: the video
//  kind has NO default model on purpose (= the video allowance is a
//  handful of clips a day), and the provider picker replaces the
//  whole route with `model: nil`. So without a model field the user
//  could set a provider and a key and end up with a route that cannot
//  make a clip, and with no field to put the model back.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover route model")
struct CoverRouteModelTests {

    @Test("A route keeps the model it is given")
    func aRouteKeepsTheModelItIsGiven() {
        let route = CoverServiceRoute(
            kind: .video,
            providerSlug: "minimax-cn",
            model: "MiniMax-Hailuo-02",
            baseURL: nil,
            apiKey: nil
        )

        #expect(route.model == "MiniMax-Hailuo-02")
        #expect(route.isAuto == false)
    }

    @Test("Replacing a route writes the model it is given")
    func replacingARouteWritesTheModelItIsGiven() {
        let route = CoverServiceRoute(
            kind: .video,
            providerSlug: "minimax-cn",
            model: "MiniMax-Hailuo-02",
            baseURL: nil,
            apiKey: nil
        )

        let replaced = route.replacing(
            providerSlug: "minimax-cn",
            model: "MiniMax-Hailuo-01",
            baseURL: nil,
            apiKey: nil
        )

        #expect(replaced.model == "MiniMax-Hailuo-01")
    }

    @Test("Replacing a route with no model clears it")
    func replacingARouteWithNoModelClearsIt() {
        let route = CoverServiceRoute(
            kind: .video,
            providerSlug: "minimax-cn",
            model: "MiniMax-Hailuo-02",
            baseURL: nil,
            apiKey: nil
        )

        // The model belonged to the old provider, so it goes with it.
        let replaced = route.replacing(
            providerSlug: "another-provider",
            model: nil,
            baseURL: nil,
            apiKey: nil
        )

        #expect(replaced.model == nil)
    }

    @Test("A route with a model survives the store")
    func aRouteWithAModelSurvivesTheStore() throws {
        let defaults = try #require(
            UserDefaults(suiteName: "CoverRouteModelTests-\(UUID().uuidString)")
        )
        let store = CoverServiceRouteStore(defaults: defaults)
        let route = CoverServiceRoute(
            kind: .video,
            providerSlug: "minimax-cn",
            model: "MiniMax-Hailuo-02",
            baseURL: nil,
            apiKey: nil
        )

        store.videoRoute = route

        #expect(store.videoRoute.model == "MiniMax-Hailuo-02")
        #expect(store.videoRoute.providerSlug == "minimax-cn")
    }

    @Test("A route with a model resolves the model it names")
    func aRouteWithAModelResolvesTheModelItNames() throws {
        let route = CoverServiceRoute(
            kind: .video,
            providerSlug: "minimax-cn",
            model: "MiniMax-Hailuo-02",
            baseURL: nil,
            apiKey: nil
        )

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: nil,
            currentProviderKey: nil,
            keyForProvider: { _ in "a-key" }
        )

        #expect(resolved.model == "MiniMax-Hailuo-02")
    }
}
