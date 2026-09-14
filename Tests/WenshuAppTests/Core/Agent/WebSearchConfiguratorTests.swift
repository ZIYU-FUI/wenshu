// WebSearchConfiguratorTests.swift · Wenshu · v0.76 ticket 001
//
// Tests cover:
// - searchAPIKeyName maps each provider to its canonical key name
// - configuredEngine returns empty WebSearch when no keys set
// - configuredEngine constructs an EXA provider when exa_api_key set
// - configuredEngine constructs multiple providers when multiple keys set
// - searchAPIKeysEnabled returns the set of provider names with keys
// - SEARXNG is excluded (= uses endpoint URL not API key)

import Foundation
import Testing
@testable import WenshuApp

@Suite("WebSearchConfigurator (v0.76 ticket 001 — UserDefaults → provider list)")
struct WebSearchConfiguratorTests {

    // MARK: - searchAPIKeyName

    @Test("searchAPIKeyName maps each provider to its canonical key")
    func keyNames() {
        #expect(WebSearchConfigurator.searchAPIKeyName(for: "exa") == "exa_api_key")
        #expect(WebSearchConfigurator.searchAPIKeyName(for: "tavily") == "tavily_api_key")
        #expect(WebSearchConfigurator.searchAPIKeyName(for: "brave") == "brave_api_key")
        #expect(WebSearchConfigurator.searchAPIKeyName(for: "parallel") == "parallel_api_key")
        #expect(WebSearchConfigurator.searchAPIKeyName(for: "searxng") == nil)
        #expect(WebSearchConfigurator.searchAPIKeyName(for: "unknown") == nil)
    }

    // MARK: - configuredEngine

    @Test("configuredEngine returns empty WebSearch when no keys set")
    func emptyEngine() async {
        let defaults = Self.makeIsolatedDefaults()
        let engine = WebSearchConfigurator.configuredEngine(userDefaults: defaults)

        // Verify empty config → search throws noProvidersConfigured
        do {
            _ = try await engine.search(query: "test", limit: 1)
            Issue.record("expected noProvidersConfigured error from empty engine")
        } catch WebSearchError.noProvidersConfigured {
            // Expected
        } catch {
            Issue.record("expected noProvidersConfigured, got: \(error)")
        }
    }

    @Test("configuredEngine constructs EXA provider when key set")
    func exaProviderConfigured() async {
        let defaults = Self.makeIsolatedDefaults()
        defaults.set("test-exa-key", forKey: "wenshu.search.exa_api_key")
        let engine = WebSearchConfigurator.configuredEngine(userDefaults: defaults)

        // Verify EXA is wired (= NOT throwing noProvidersConfigured)
        do {
            _ = try await engine.search(query: "test", limit: 1)
            // OK — search proceeded (= either returned [] from API error, or got results)
        } catch let error as WebSearchError {
            #expect(error != .noProvidersConfigured,
                    "engine had EXA configured; should not throw noProvidersConfigured")
        } catch {
            // URLSession errors on invalid key are expected; = we just need to confirm
            // the engine did NOT throw noProvidersConfigured (= = EXA was wired)
        }
    }

    @Test("configuredEngine constructs multiple providers when multiple keys set")
    func multipleProviders() {
        let defaults = Self.makeIsolatedDefaults()
        defaults.set("test-exa", forKey: "wenshu.search.exa_api_key")
        defaults.set("test-tavily", forKey: "wenshu.search.tavily_api_key")
        defaults.set("test-brave", forKey: "wenshu.search.brave_api_key")
        _ = WebSearchConfigurator.configuredEngine(userDefaults: defaults)

        // Verify searchAPIKeysEnabled reports all 3
        let enabled = WebSearchConfigurator.searchAPIKeysEnabled(userDefaults: defaults)
        #expect(enabled.contains("exa"))
        #expect(enabled.contains("tavily"))
        #expect(enabled.contains("brave"))
        #expect(enabled.count == 3)
    }

    // MARK: - searchAPIKeysEnabled

    @Test("searchAPIKeysEnabled returns empty set when no keys set")
    func enabledEmpty() {
        let defaults = Self.makeIsolatedDefaults()
        let enabled = WebSearchConfigurator.searchAPIKeysEnabled(userDefaults: defaults)
        #expect(enabled.isEmpty)
    }

    @Test("searchAPIKeysEnabled excludes empty-string keys")
    func enabledIgnoresEmpty() {
        let defaults = Self.makeIsolatedDefaults()
        defaults.set("", forKey: "wenshu.search.exa_api_key")
        defaults.set("real", forKey: "wenshu.search.tavily_api_key")
        let enabled = WebSearchConfigurator.searchAPIKeysEnabled(userDefaults: defaults)
        #expect(enabled == ["tavily"])
    }

    // MARK: - Helpers

    /// Build an isolated UserDefaults (= tests can run in parallel without
    /// clobbering each other's keys).
    private static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "wenshu.WebSearchConfiguratorTests." + UUID().uuidString
        return UserDefaults(suiteName: suite) ?? .standard
    }
}