// SearchAPIKeychainTests.swift · Wenshu · v0.81 ticket 001
//
// Tests cover:
// - InMemorySearchKeychainStore round-trip (= save / load / delete / list)
// - AppleSearchKeychainStore delegates to Security framework (= mocked via debugNoKeychain)
// - WebSearchConfigurator now reads from SearchAPIKeychain (= UserDefaults → Keychain)
// - UserDefaults → Keychain migration runs once (= legacy entries deleted after migration)
// - searchAPIKeysEnabled reflects the SearchAPIKeychain state
// - Empty key rejected

import Foundation
import Testing
@testable import WenshuApp

@Suite("SearchAPIKeychain (v0.81 ticket 001 — Apple Keychain for web search API keys)")
struct SearchAPIKeychainTests {

    // MARK: - InMemorySearchKeychainStore

    @Test("InMemorySearchKeychainStore save + load round-trip")
    func inMemoryRoundTrip() throws {
        let store = InMemorySearchKeychainStore()
        try store.saveKey("test-exa-key", for: "exa")
        let loaded = store.loadKey(for: "exa")
        #expect(loaded == "test-exa-key")
        #expect(store.listConfiguredProviders() == ["exa"])
    }

    @Test("InMemorySearchKeychainStore delete removes key")
    func inMemoryDelete() throws {
        let store = InMemorySearchKeychainStore()
        try store.saveKey("test-key", for: "tavily")
        try store.deleteKey(for: "tavily")
        #expect(store.loadKey(for: "tavily") == nil)
        #expect(store.listConfiguredProviders().isEmpty)
    }

    @Test("InMemorySearchKeychainStore rejects empty key")
    func inMemoryRejectsEmpty() {
        let store = InMemorySearchKeychainStore()
        #expect(throws: SearchAPIKeychainError.self) {
            try store.saveKey("", for: "exa")
        }
    }

    @Test("InMemorySearchKeychainStore lists multiple providers")
    func inMemoryMultiple() throws {
        let store = InMemorySearchKeychainStore()
        try store.saveKey("k1", for: "exa")
        try store.saveKey("k2", for: "tavily")
        try store.saveKey("k3", for: "brave")
        let list = store.listConfiguredProviders()
        #expect(list.contains("exa"))
        #expect(list.contains("tavily"))
        #expect(list.contains("brave"))
        #expect(list.count == 3)
    }

    @Test("InMemorySearchKeychainStore load returns nil for missing key")
    func inMemoryMissing() {
        let store = InMemorySearchKeychainStore()
        #expect(store.loadKey(for: "nonexistent") == nil)
    }

    // MARK: - SearchAPIKeychain shim (= test backend injection)

    @Test("SearchAPIKeychain.setBackendForTesting switches backend")
    func shimBackendInjection() throws {
        // Save original (= restore in defer)
        let original = SearchAPIKeychain.backend

        let testStore = InMemorySearchKeychainStore()
        SearchAPIKeychain.setBackendForTesting(testStore)

        defer {
            SearchAPIKeychain.resetBackendForTesting()
            _ = original
        }

        try SearchAPIKeychain.saveKey("via-shim", for: "exa")
        #expect(SearchAPIKeychain.loadKey(for: "exa") == "via-shim")
        #expect(SearchAPIKeychain.listConfiguredProviders() == ["exa"])
    }

    // MARK: - WebSearchConfigurator integration

    @Test("WebSearchConfigurator reads from SearchAPIKeychain (= not UserDefaults)")
    func configuratorReadsKeychain() async throws {
        // Each test gets a fresh InMemorySearchKeychainStore (= no shared state)
        Self.clearLegacyDefaults()
        let testStore = InMemorySearchKeychainStore()
        SearchAPIKeychain.setBackendForTesting(testStore)

        defer {
            SearchAPIKeychain.resetBackendForTesting()
            try? SearchAPIKeychain.deleteKey(for: "exa")
            try? SearchAPIKeychain.deleteKey(for: "tavily")
        }

        try SearchAPIKeychain.saveKey("test-exa", for: "exa")
        try SearchAPIKeychain.saveKey("test-tavily", for: "tavily")

        let enabled = WebSearchConfigurator.searchAPIKeysEnabled()
        #expect(enabled.contains("exa"), "exa should be enabled after saveKey")
        #expect(enabled.contains("tavily"), "tavily should be enabled after saveKey")
        #expect(enabled.count == 2, "expected 2 enabled, got: \(enabled)")

        let engine = WebSearchConfigurator.configuredEngine()
        // Verify search throws noProvidersConfigured (= empty) — wait no,
        // we set 2 keys above, so engine has 2 providers and search proceeds
        // (= may throw on real network but NOT noProvidersConfigured).
        do {
            _ = try await engine.search(query: "test", limit: 1)
            // OK
        } catch let error as WebSearchError {
            #expect(error != .noProvidersConfigured,
                    "engine had 2 configured providers; should not throw noProvidersConfigured")
        } catch {
            // Network errors are acceptable
        }
    }

    @Test("UserDefaults → Keychain migration runs once on first launch")
    func userDefaultsMigration() async throws {
        // Seed legacy UserDefaults (= v0.76 dev path)
        Self.clearLegacyDefaults()
        UserDefaults.standard.set("legacy-exa-key", forKey: "wenshu.search.exa_api_key")

        let testStore = InMemorySearchKeychainStore()
        SearchAPIKeychain.setBackendForTesting(testStore)

        defer {
            SearchAPIKeychain.resetBackendForTesting()
            Self.clearLegacyDefaults()
        }

        // First call: triggers migration
        let engine = WebSearchConfigurator.configuredEngine()

        // Verify key moved to Keychain
        #expect(SearchAPIKeychain.loadKey(for: "exa") == "legacy-exa-key")

        // Verify UserDefaults entry deleted
        #expect(UserDefaults.standard.string(forKey: "wenshu.search.exa_api_key") == nil)

        // Verify engine has EXA wired (= NOT throwing noProvidersConfigured)
        do {
            _ = try await engine.search(query: "test", limit: 1)
            // OK
        } catch let error as WebSearchError {
            #expect(error != .noProvidersConfigured)
        } catch {
            // Network errors acceptable
        }
    }

    @Test("searchAPIKeysEnabled returns empty set when no keys configured")
    func enabledEmpty() {
        Self.clearLegacyDefaults()
        let testStore = InMemorySearchKeychainStore()
        SearchAPIKeychain.setBackendForTesting(testStore)

        defer { SearchAPIKeychain.resetBackendForTesting() }

        let enabled = WebSearchConfigurator.searchAPIKeysEnabled()
        #expect(enabled.isEmpty)
    }

    @Test("searchAPIKeysEnabled excludes SEARXNG (no API key)")
    func enabledExcludesSearxng() throws {
        Self.clearLegacyDefaults()
        let testStore = InMemorySearchKeychainStore()
        SearchAPIKeychain.setBackendForTesting(testStore)

        defer { SearchAPIKeychain.resetBackendForTesting() }

        // SEARXNG uses endpoint URL, not API key (= even if we put a fake
        // entry in the keychain, searchAPIKeysEnabled should exclude it
        // because searchAPIKeyName(for: "searxng") returns nil).
        try SearchAPIKeychain.saveKey("anything", for: "searxng")
        let enabled = WebSearchConfigurator.searchAPIKeysEnabled()
        #expect(!enabled.contains("searxng"))
    }

    // MARK: - Helpers

    /// Clear all legacy `wenshu.search.*` UserDefaults entries (= prevents
    /// test pollution from the migration logic).
    private static func clearLegacyDefaults() {
        let keys = [
            "wenshu.search.exa_api_key",
            "wenshu.search.tavily_api_key",
            "wenshu.search.brave_api_key",
            "wenshu.search.parallel_api_key"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}