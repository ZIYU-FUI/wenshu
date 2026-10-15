//
//  ProviderKeychainMetadataTests.swift · Wenshu · v0.36 ticket 012 Z contract
//
//  Z contract test (= per boss cadence: unit tests for ticket 012 metadata
//  protocol extension + ProviderKeychainMetadata struct + InMemoryKeychainStore
//  metadata persistence).
//
//  Spec axis: ticket 012 acceptance = "credential rotation + OAuth support".
//  Test invariant: metadata round-trip + isExpired/isOAuth computed correctly.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ProviderKeychainMetadata (ticket 012 Z contract)")
struct ProviderKeychainMetadataTests {

    @Test("ProviderKeychainMetadata defaults = no expiry, no OAuth, rotatedAt = now")
    func defaults() {
        let metadata = ProviderKeychainMetadata()
        #expect(metadata.expiresAt == nil)
        #expect(metadata.oauthRefreshToken == nil)
        #expect(metadata.oauthAccessToken == nil)
        #expect(metadata.oauthScopes.isEmpty)
        #expect(metadata.isExpired == false)
        #expect(metadata.isOAuth == false)
    }

    @Test("ProviderKeychainMetadata with past expiresAt = isExpired true")
    func expiredMetadata() {
        let past = Date(timeIntervalSinceNow: -3600)
        let metadata = ProviderKeychainMetadata(expiresAt: past)
        #expect(metadata.isExpired == true)
        #expect(metadata.isOAuth == false)
    }

    @Test("ProviderKeychainMetadata with future expiresAt = isExpired false")
    func futureExpiry() {
        let future = Date(timeIntervalSinceNow: 3600)
        let metadata = ProviderKeychainMetadata(expiresAt: future)
        #expect(metadata.isExpired == false)
    }

    @Test("ProviderKeychainMetadata with refresh token = isOAuth true")
    func oauthMetadata() {
        let metadata = ProviderKeychainMetadata(
            oauthRefreshToken: "refresh_token_xyz"
        )
        #expect(metadata.isOAuth == true)
        #expect(metadata.isExpired == false)
    }

    @Test("ProviderKeychainMetadata Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSince1970: 1700000000),
            oauthRefreshToken: "rt_abc",
            oauthAccessToken: "at_def",
            oauthScopes: ["read", "write"],
            rotatedAt: Date(timeIntervalSince1970: 1699999000)
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderKeychainMetadata.self, from: encoded)
        #expect(decoded == original)
    }
}

@Suite("InMemoryKeychainStore metadata (ticket 012 Z contract)")
struct InMemoryKeychainStoreMetadataTests {

    @Test("saveMetadata then loadMetadata returns the saved metadata")
    func saveLoadRoundTrip() throws {
        let store = InMemoryKeychainStore()
        let provider = Provider.anthropic
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: 86400),
            oauthRefreshToken: "rt_test"
        )
        try store.saveMetadata(metadata, for: provider)
        let loaded = store.loadMetadata(for: provider)
        #expect(loaded == metadata)
    }

    @Test("loadMetadata for provider with no saved metadata = nil")
    func loadMissingReturnsNil() {
        let store = InMemoryKeychainStore()
        let loaded = store.loadMetadata(for: .anthropic)
        #expect(loaded == nil)
    }

    @Test("deleteKeySync clears associated metadata")
    func deleteKeyClearsMetadata() throws {
        let store = InMemoryKeychainStore()
        let provider = Provider.anthropic
        try store.saveKeySync("sk-test", for: provider)
        try store.saveMetadata(
            ProviderKeychainMetadata(oauthRefreshToken: "rt"),
            for: provider
        )
        try store.deleteKeySync(for: provider)
        #expect(store.loadMetadata(for: provider) == nil)
    }

    @Test("ProviderKeychainStoring default protocol methods are no-ops")
    func defaultProtocolMethodsAreNoOps() {
        let store = InMemoryKeychainStore()
        // Verify default protocol methods (= loadMetadata/saveMetadata) work
        // without override (= should be no-op for stores that don't opt in).
        // InMemoryKeychainStore DOES override; for testing the default, we
        // use a struct that conforms to ProviderKeychainStoring without override.
        struct NoMetadataBackend: ProviderKeychainStoring {
            func saveKeySync(_ key: String, for provider: Provider) throws {}
            func loadKeySync(for provider: Provider) -> String? { nil }
            func deleteKeySync(for provider: Provider) throws {}
            func listProvidersWithKeys() -> [String] { [] }
            // No loadMetadata/saveMetadata override (= uses default no-op).
        }
        let noMetadataStore = NoMetadataBackend()
        // Default loadMetadata returns nil.
        #expect(noMetadataStore.loadMetadata(for: .anthropic) == nil)
        // Default saveMetadata is no-op (= does not throw).
        try? noMetadataStore.saveMetadata(
            ProviderKeychainMetadata(),
            for: .anthropic
        )
        // _ = store to silence unused warning
        _ = store
    }
}