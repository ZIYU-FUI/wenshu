//
//  CoverRouteResolverTests.swift · Wenshu
//
//  Proves the route ladder, and above all the ATOMIC ROUTE: a route
//  that names a provider never mixes in another provider's model.
//
//  The resolver is a pure function, so every case here runs with no
//  app, no network, no clock and no disk.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover route resolver")
struct CoverRouteResolverTests {

    @Test("An auto route inherits the app's current provider")
    func autoInheritsTheCurrentProvider() throws {
        let route = CoverServiceRoute(kind: .image)

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: "minimax-cn"
        )

        #expect(resolved.providerSlug == "minimax-cn")
        // The MODEL comes from the kind, never from the provider's
        // chat model list: the image endpoint answers "model not
        // available" for a chat model.
        #expect(resolved.model == "image-01")
    }

    @Test("An explicit route uses its own four fields")
    func explicitRouteWins() throws {
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "openai",
            model: "gpt-image-1",
            baseURL: "https://example.test/v1",
            apiKey: "secret"
        )

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: "minimax-cn"
        )

        #expect(resolved.providerSlug == "openai")
        #expect(resolved.model == "gpt-image-1")
        #expect(resolved.baseURL == "https://example.test/v1")
        #expect(resolved.apiKey == "secret")
    }

    @Test("A route that names a provider does NOT borrow a chat model")
    func explicitProviderDoesNotMixProviders() throws {
        // The provider is set but the model is not. The model must come
        // from the KIND, and must NOT be one of the provider's chat
        // models: the image endpoint answers "model not available" for
        // a chat model.
        let route = CoverServiceRoute(kind: .image, providerSlug: "minimax-cn")

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: "minimax-cn"
        )

        #expect(resolved.providerSlug == "minimax-cn")
        #expect(resolved.model == "image-01")
        #expect(resolved.model != "MiniMax-M3")
        #expect(resolved.model != "MiniMax-M2")
    }

    @Test("The video kind with a provider but no model still fails")
    func videoProviderWithoutModelFails() {
        // A video route needs an explicit model. The video quota is a
        // handful of clips a day, so there is no default to fall back
        // to.
        let route = CoverServiceRoute(kind: .video, providerSlug: "minimax-cn")

        #expect(throws: CoverRouteError.self) {
            try CoverRouteResolver.resolve(route, currentProviderSlug: "minimax-cn")
        }
    }

    @Test("The video kind with nothing configured fails loudly")
    func videoWithNothingConfiguredFails() {
        let route = CoverServiceRoute(kind: .video)

        #expect(throws: CoverRouteError.self) {
            try CoverRouteResolver.resolve(route, currentProviderSlug: nil)
        }
    }

    @Test("The image kind with nothing configured falls back to image-01")
    func imageWithNothingConfiguredFallsBack() throws {
        let route = CoverServiceRoute(kind: .image)

        let resolved = try CoverRouteResolver.resolve(route, currentProviderSlug: nil)

        #expect(resolved.model == "image-01")
    }

    @Test("Replacing the provider clears the other three fields")
    func replacingTheProviderClearsTheRest() {
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "openai",
            model: "gpt-image-1",
            baseURL: "https://example.test/v1",
            apiKey: "secret"
        )

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

    @Test("A reset route inherits again")
    func resetReturnsToAuto() {
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "openai",
            model: "gpt-image-1"
        )

        #expect(route.isAuto == false)
        #expect(route.resetting().isAuto)
        #expect(route.resetting().kind == .image)
    }
}
