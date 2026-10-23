//
//  CoverRouteResolverTests.swift · Wenshu
//
//  Proves the route ladder, and above all the ATOMIC ROUTE: a route
//  that names a provider never mixes in another provider's model.
//
//  The resolver is a pure function, so every case here runs with no
//  app, no network, no clock and no disk.
//
//  The ladder changed on 2026-10-23 and the change matters: an auto
//  route names the BUILT-IN image service, not the app's chat
//  provider. A chat key cannot pay for a picture, so the old ladder
//  pointed the chat provider's key at the picture endpoint, which
//  cannot work.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover route resolver")
struct CoverRouteResolverTests {

    /// A key reader that answers from a map.
    private func keys(_ map: [String: String]) -> @Sendable (String) -> String? {
        { slug in map[slug] }
    }

    /// A key reader that has a key for the built-in image service.
    private var imageServiceKeys: @Sendable (String) -> String? {
        keys(["minimax-cn": "image-service-key"])
    }

    @Test("An auto route names the built-in image service")
    func autoNamesTheBuiltInImageService() throws {
        let route = CoverServiceRoute(kind: .image)

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: "minimax-cn",
            keyForProvider: imageServiceKeys
        )

        #expect(resolved.providerSlug == "minimax-cn")
        // The MODEL comes from the kind, never from the provider's
        // chat model list: the image endpoint answers "model not
        // available" for a chat model.
        #expect(resolved.model == "image-01")
    }

    @Test("An auto route ignores the app's chat provider")
    func autoIgnoresTheChatProvider() throws {
        // The chat provider cannot make a picture, so its key is not
        // the key that pays for one. The auto route names the service
        // that does the work.
        let route = CoverServiceRoute(kind: .image)

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: "anthropic",
            currentProviderKey: "chat-key",
            keyForProvider: imageServiceKeys
        )

        #expect(resolved.providerSlug == "minimax-cn")
        #expect(resolved.apiKey == "image-service-key")
    }

    @Test("An auto route with no key for the image service fails loudly")
    func autoWithNoKeyFailsLoudly() {
        let route = CoverServiceRoute(kind: .image)

        #expect(throws: CoverRouteError.self) {
            try CoverRouteResolver.resolve(
                route,
                currentProviderSlug: "anthropic",
                keyForProvider: keys([:])
            )
        }
    }

    @Test("An explicit route uses its own four fields")
    func explicitRouteWins() throws {
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "openai",
            model: "gpt-image-1",
            baseURL: "https://example.test/v1",
            apiKey: "route-key"
        )

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: "minimax-cn",
            currentProviderKey: "provider-key"
        )

        #expect(resolved.providerSlug == "openai")
        #expect(resolved.model == "gpt-image-1")
        #expect(resolved.baseURL == "https://example.test/v1")
        // The route's own key wins: the route named a provider, and
        // that provider's key is the one the route carries.
        #expect(resolved.apiKey == "route-key")
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
            currentProviderSlug: "minimax-cn",
            keyForProvider: imageServiceKeys
        )

        #expect(resolved.providerSlug == "minimax-cn")
        #expect(resolved.model == "image-01")
        #expect(resolved.model != "MiniMax-M3")
        #expect(resolved.model != "MiniMax-M2")
    }

    @Test("A route naming a chat provider cannot make covers")
    func aRouteNamingAChatProviderCannotMakeCovers() {
        // The chat provider publishes no picture endpoint in the cover
        // protocol, so a route that points at it and names no service
        // of its own would be sent to the built-in endpoint, which it
        // does not serve. The switch stops here and says what to
        // configure.
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "anthropic",
            model: "claude-sonnet-4"
        )

        #expect(throws: CoverRouteError.self) {
            try CoverRouteResolver.resolve(
                route,
                currentProviderSlug: "anthropic",
                keyForProvider: imageServiceKeys
            )
        }
    }

    @Test("A route naming a chat provider WITH its own service is used as it is")
    func aRouteWithItsOwnServiceIsUsedAsItIs() {
        // The user pointed the cover at a service of their own. The
        // app calls it and reports what it says.
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "custom",
            model: "some-image-model",
            baseURL: "https://example.test/v1/images/generations",
            apiKey: "route-key"
        )

        let resolved = try? CoverRouteResolver.resolve(
            route,
            currentProviderSlug: "anthropic",
            keyForProvider: imageServiceKeys
        )

        #expect(resolved?.baseURL == "https://example.test/v1/images/generations")
        #expect(resolved?.apiKey == "route-key")
    }

    @Test("The video kind with a provider but no model still fails")
    func videoProviderWithoutModelFails() {
        // A video route needs an explicit model. The video quota is a
        // handful of clips a day, so there is no default to fall back
        // to.
        let route = CoverServiceRoute(kind: .video, providerSlug: "minimax-cn")

        #expect(throws: CoverRouteError.self) {
            try CoverRouteResolver.resolve(
                route,
                currentProviderSlug: "minimax-cn",
                keyForProvider: imageServiceKeys
            )
        }
    }

    @Test("The video kind with nothing configured fails loudly")
    func videoWithNothingConfiguredFails() {
        let route = CoverServiceRoute(kind: .video)

        #expect(throws: CoverRouteError.self) {
            try CoverRouteResolver.resolve(
                route,
                currentProviderSlug: nil,
                keyForProvider: imageServiceKeys
            )
        }
    }

    @Test("The image kind with nothing configured falls back to image-01")
    func imageWithNothingConfiguredFallsBack() throws {
        let route = CoverServiceRoute(kind: .image)

        let resolved = try CoverRouteResolver.resolve(
            route,
            currentProviderSlug: nil,
            keyForProvider: imageServiceKeys
        )

        #expect(resolved.model == "image-01")
    }

    @Test("Replacing the provider clears the other three fields")
    func replacingTheProviderClearsTheRest() {
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "openai",
            model: "gpt-image-1",
            baseURL: "https://example.test/v1",
            apiKey: "route-key"
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

    @Test("The route's fields cannot be changed one at a time")
    func routeFieldsAreImmutable() throws {
        // The route's whole point is that its four fields travel
        // together, so the fields are `let` and `replacing(...)` is the
        // only way to change one. A setter would let a caller name a
        // new provider and keep the old endpoint.
        let source = try String(
            contentsOfFile: SourceLocator.path(
                "Sources/WenshuApp/Features/Cover/Model/CoverServiceRoute.swift"
            ),
            encoding: .utf8
        )

        for field in ["providerSlug", "model", "baseURL", "apiKey"] {
            #expect(!source.contains("var \(field): String?"))
            #expect(source.contains("let \(field): String?"))
        }
    }
}
