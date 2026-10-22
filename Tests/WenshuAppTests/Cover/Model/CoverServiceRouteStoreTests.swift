//
//  CoverServiceRouteStoreTests.swift · Wenshu
//
//  Proves the two routes survive a restart, and that they survive it
//  WITHOUT touching the real user defaults.
//
//  The store takes its UserDefaults suite as a parameter, so the test
//  builds one in a throwaway suite name and deletes it afterwards.
//  A test that wrote to `UserDefaults.standard` would leave a route
//  behind in the developer's own app.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover service route store")
struct CoverServiceRouteStoreTests {

    /// A throwaway defaults suite, removed when the test ends.
    private func makeSuite() -> (UserDefaults, String) {
        let name = "wenshu.cover.route.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, name)
    }

    @Test("A route round-trips through the store")
    func routeRoundTrips() {
        let (defaults, name) = makeSuite()
        defer { defaults.removePersistentDomain(forName: name) }

        let store = CoverServiceRouteStore(defaults: defaults)
        let route = CoverServiceRoute(
            kind: .image,
            providerSlug: "openai",
            model: "gpt-image-1",
            baseURL: "https://example.test/v1",
            apiKey: "secret"
        )

        store.imageRoute = route
        let read = store.route(for: .image)

        #expect(read == route)
        #expect(read.kind == .image)
    }

    @Test("The two routes are independent")
    func routesAreIndependent() {
        let (defaults, name) = makeSuite()
        defer { defaults.removePersistentDomain(forName: name) }

        let store = CoverServiceRouteStore(defaults: defaults)
        store.imageRoute = CoverServiceRoute(kind: .image, providerSlug: "openai")
        store.videoRoute = CoverServiceRoute(kind: .video, providerSlug: "minimax-cn")

        #expect(store.imageRoute.providerSlug == "openai")
        #expect(store.videoRoute.providerSlug == "minimax-cn")
    }

    @Test("A missing route reads back as auto")
    func missingRouteIsAuto() {
        let (defaults, name) = makeSuite()
        defer { defaults.removePersistentDomain(forName: name) }

        let store = CoverServiceRouteStore(defaults: defaults)
        let route = store.route(for: .video)

        #expect(route.isAuto)
        #expect(route.kind == .video)
    }

    @Test("The route survives a new store over the same defaults")
    func routeSurvivesANewStore() {
        let (defaults, name) = makeSuite()
        defer { defaults.removePersistentDomain(forName: name) }

        CoverServiceRouteStore(defaults: defaults).imageRoute = CoverServiceRoute(
            kind: .image,
            providerSlug: "minimax-cn",
            model: "image-01"
        )

        // A fresh store = a fresh launch, reading the same defaults.
        let reopened = CoverServiceRouteStore(defaults: defaults).imageRoute

        #expect(reopened.providerSlug == "minimax-cn")
        #expect(reopened.model == "image-01")
    }
}
