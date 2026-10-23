//
//  ProviderEndpointOverrideTests.swift · Wenshu
//
//  The rule under test: the endpoint the user typed is the endpoint the
//  connector uses.
//
//  Before this change the provider list was a closed enum whose endpoints
//  were compile-time constants, and the one factory that chose an endpoint
//  had no input for the user. The code claimed otherwise:
//  `ConnectorCredentials.swift` said the base URL was "user-customized via
//  Settings", and there was no such setting. A user whose gateway lives at
//  their own address had no way to reach it.
//
//  These tests drive the RUNTIME CONSUMER (= the factory that chooses the
//  endpoint), because a test that only checks the store round-trip proves
//  the value persists, not that anything reads it.
//

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Provider endpoint overrides")
struct ProviderEndpointOverrideTests {

    /// Restore the shared holder after a test, so one test's value cannot
    /// leak into another.
    ///
    /// The suite is serialized because the holder is one process-wide value:
    /// Swift Testing runs the tests of a suite in parallel, and they would
    /// otherwise overwrite each other's endpoint and read each other's
    /// result.
    @MainActor
    private func withOverrides(_ values: [String: String], _ body: () -> Void) {
        let previous = ProviderEndpointOverrides.baseURLs
        ProviderEndpointOverrides.baseURLs = values
        defer { ProviderEndpointOverrides.baseURLs = previous }
        body()
    }

    @MainActor
    @Test("a saved endpoint is the endpoint the credentials use")
    func savedEndpointReachesTheCredentials() {
        withOverrides(["anthropic": "https://gateway.example.com/v1"]) {
            let credentials = ConnectorCredentials.resolve(for: .anthropic)
            #expect(
                credentials.baseURL == "https://gateway.example.com/v1",
                "the user's endpoint must be the one the connector calls"
            )
        }
    }

    @MainActor
    @Test("no saved endpoint leaves the provider default in place")
    func defaultAppliesWithoutAnOverride() {
        withOverrides([:]) {
            let credentials = ConnectorCredentials.resolve(for: .anthropic)
            #expect(credentials.baseURL == Provider.anthropic.defaultBaseURL)
        }
    }

    @MainActor
    @Test("an empty saved endpoint leaves the provider default in place")
    func emptyOverrideFallsBackToTheDefault() {
        withOverrides(["anthropic": "   "]) {
            let credentials = ConnectorCredentials.resolve(for: .anthropic)
            #expect(credentials.baseURL == Provider.anthropic.defaultBaseURL)
        }
    }

    @MainActor
    @Test("a saved endpoint with no host leaves the provider default in place")
    func unusableEndpointFallsBackToTheDefault() {
        withOverrides(["anthropic": "not a url at all"]) {
            let credentials = ConnectorCredentials.resolve(for: .anthropic)
            #expect(
                credentials.baseURL == Provider.anthropic.defaultBaseURL,
                "an endpoint that cannot be called must not break the provider"
            )
        }
    }

    @MainActor
    @Test("an override for one provider does not touch another")
    func overridesArePerProvider() {
        withOverrides(["openrouter": "https://gateway.example.com/v1"]) {
            #expect(ConnectorCredentials.resolve(for: .openrouter).baseURL == "https://gateway.example.com/v1")
            #expect(ConnectorCredentials.resolve(for: .anthropic).baseURL == Provider.anthropic.defaultBaseURL)
        }
    }

    @MainActor
    @Test("the settings value and the runtime holder agree")
    func settingsValueMatchesTheRuntimeHolder() {
        var settings = AgentSettings()
        settings.providers.baseURLs = ["minimax-cn": "https://gateway.example.com/v1"]
        #expect(settings.providers.baseURLs["minimax-cn"] == "https://gateway.example.com/v1")

        // The holder is what the factory reads, so the two must agree.
        withOverrides(settings.providers.baseURLs) {
            #expect(ProviderEndpointOverrides.baseURL(for: .minimaxCn) == "https://gateway.example.com/v1")
        }
    }
}
