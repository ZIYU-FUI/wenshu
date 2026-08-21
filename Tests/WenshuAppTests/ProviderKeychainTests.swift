//
//  ProviderKeychainTests.swift
//
//  Tests inject InMemoryKeychainStore via ProviderKeychain.setBackendForTesting
//  because `swift test` runs as a daemon session (no user-attached console) and
//  Apple Security framework refuses SecItemAdd with errSecInteractionNotAllowed
//  or errSecMissingEntitlement in that context.
//
//  AppleKeychainStore behavior (production path) is exercised manually when
//  operator runs the .app bundle from build/Wenshu.app.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ProviderKeychain (Apple Security framework, multi-provider)")
struct ProviderKeychainTests {

    init() {
        // Each test starts with a clean in-memory backend (no OS Keychain entitlement required).
        ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
    }

    @Test("saveKey then loadKey returns same value")
    func testSaveAndLoad() throws {
        let key = "redacted-sk-\(UUID().uuidString.prefix(8))"
        try ProviderKeychain.saveKeySync(key, for: .openrouter)
        let loaded = ProviderKeychain.loadKeySync(for: .openrouter)
        #expect(loaded == key)
        try ProviderKeychain.deleteKeySync(for: .openrouter)
    }

    @Test("loadKey returns nil when no key stored")
    func testLoadEmpty() throws {
        try ProviderKeychain.deleteKeySync(for: .anthropic)
        let loaded = ProviderKeychain.loadKeySync(for: .anthropic)
        #expect(loaded == nil)
    }

    @Test("empty key throws invalidKeyFormat")
    func testEmptyKeyThrows() {
        #expect(throws: ProviderKeychainError.self) {
            try ProviderKeychain.saveKeySync("", for: .nous)
        }
    }

    @Test("different providers store keys independently")
    func testProviderIsolation() throws {
        let openrouterKey = "redacted-sk-or-\(UUID().uuidString.prefix(8))"
        let nousKey = "redacted-sk-\(UUID().uuidString.prefix(8))"
        try ProviderKeychain.saveKeySync(openrouterKey, for: .openrouter)
        try ProviderKeychain.saveKeySync(nousKey, for: .nous)
        #expect(ProviderKeychain.loadKeySync(for: .openrouter) == openrouterKey)
        #expect(ProviderKeychain.loadKeySync(for: .nous) == nousKey)
        try ProviderKeychain.deleteKeySync(for: .openrouter)
        try ProviderKeychain.deleteKeySync(for: .nous)
    }

    @Test("listProvidersWithKeys lists providers with stored keys")
    func testListProvidersWithKeys() throws {
        // Cleanup fixture: prior minimax-cn key entry must be cleared before assertion
        try ProviderKeychain.deleteKeySync(for: .minimax)
        try ProviderKeychain.deleteKeySync(for: .minimaxCn)
        try ProviderKeychain.deleteKeySync(for: .anthropic)
        #expect(!ProviderKeychain.listProvidersWithKeys().contains("minimax"))
        try ProviderKeychain.saveKeySync("redacted-sk-", for: .minimax)
        #expect(ProviderKeychain.listProvidersWithKeys().contains("minimax"))
        try ProviderKeychain.saveKeySync("redacted-sk-ant-", for: .anthropic)
        #expect(ProviderKeychain.listProvidersWithKeys().contains("anthropic"))
        try ProviderKeychain.deleteKeySync(for: .minimax)
        try ProviderKeychain.deleteKeySync(for: .minimaxCn)
        try ProviderKeychain.deleteKeySync(for: .anthropic)
    }
}