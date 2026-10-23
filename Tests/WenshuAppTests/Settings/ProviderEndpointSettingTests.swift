//
//  ProviderEndpointSettingTests.swift
//
//  The persistence half of the custom endpoint: what the user saved in the
//  models pane is what the app reads back, and what the app hands to the
//  package. The runtime half (= the connector factory reading the value) is
//  proven in the package suite, `ProviderEndpointOverrideTests`.
//

import Foundation
import Testing
@testable import WenshuApp
import WenshuAgent

@Suite("Provider endpoint setting")
struct ProviderEndpointSettingTests {

    @MainActor
    private func freshStore() -> (AgentSettingsStore, String) {
        let suite = "wenshu.provider.endpoint.tests.\(UUID().uuidString)"
        return (AgentSettingsStore(defaults: UserDefaults(suiteName: suite)!), suite)
    }

    @MainActor
    @Test("a saved endpoint is read back")
    func savedEndpointIsReadBack() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.providers.baseURLs = ["anthropic": "https://gateway.example.com/v1"]
        store.save(settings)

        #expect(store.load().providers.baseURLs["anthropic"] == "https://gateway.example.com/v1")
    }

    @MainActor
    @Test("no saved endpoint reads as the empty map")
    func noSavedEndpointReadsEmpty() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        #expect(store.load().providers.baseURLs.isEmpty)
    }

    @MainActor
    @Test("a cleared endpoint is gone from the map")
    func clearedEndpointIsRemoved() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.providers.baseURLs = ["anthropic": "https://gateway.example.com/v1"]
        store.save(settings)

        settings.providers.baseURLs.removeValue(forKey: "anthropic")
        store.save(settings)

        #expect(store.load().providers.baseURLs.isEmpty)
    }

    @MainActor
    @Test("endpoints for different providers do not collide")
    func endpointsArePerProvider() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.providers.baseURLs = [
            "anthropic": "https://one.example.com/v1",
            "openrouter": "https://two.example.com/v1"
        ]
        store.save(settings)

        let loaded = store.load().providers.baseURLs
        #expect(loaded["anthropic"] == "https://one.example.com/v1")
        #expect(loaded["openrouter"] == "https://two.example.com/v1")
    }

    @MainActor
    @Test("a value that is not a string is ignored rather than crashing the screen")
    func nonStringValueIsIgnored() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        UserDefaults.standard.set(["anthropic": 42], forKey: "wenshu.agent.providers.baseURLs")

        #expect(store.load().providers.baseURLs.isEmpty)
    }
}
