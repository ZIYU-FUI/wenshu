//
//  ProviderKeychainTests.swift · v0.21 ticket 02
//
//  Tests inject InMemoryKeychainStore via ProviderKeychain.setBackendForTesting
//  because `swift test` runs as a daemon session (no user-attached console) and
//  Apple Security framework refuses SecItemAdd with errSecInteractionNotAllowed
//  or errSecMissingEntitlement in that context.
//
//  AppleKeychainStore behavior (production path) is exercised manually when
//  老板 runs the .app bundle from /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ProviderKeychain (Apple Security framework 多 provider 真值)")
struct ProviderKeychainTests {

    init() {
        // Each test starts with a clean in-memory backend (no OS Keychain entitlement required).
        ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
    }

    @Test("saveKey 后 loadKey 返一致")
    func testSaveAndLoad() throws {
        let key = "«redacted:sk-…»\(UUID().uuidString.prefix(8))"
        try ProviderKeychain.saveKeySync(key, for: .openrouter)
        let loaded = ProviderKeychain.loadKeySync(for: .openrouter)
        #expect(loaded == key)
        try ProviderKeychain.deleteKeySync(for: .openrouter)
    }

    @Test("没 key 时 loadKey 返 nil")
    func testLoadEmpty() throws {
        try ProviderKeychain.deleteKeySync(for: .anthropic)
        let loaded = ProviderKeychain.loadKeySync(for: .anthropic)
        #expect(loaded == nil)
    }

    @Test("空 key 抛 invalidKeyFormat")
    func testEmptyKeyThrows() {
        #expect(throws: ProviderKeychainError.self) {
            try ProviderKeychain.saveKeySync("", for: .nous)
        }
    }

    @Test("不同 provider key 独立存储")
    func testProviderIsolation() throws {
        let openrouterKey = "«redacted:sk-or-…»\(UUID().uuidString.prefix(8))"
        let nousKey = "«redacted:sk-…»\(UUID().uuidString.prefix(8))"
        try ProviderKeychain.saveKeySync(openrouterKey, for: .openrouter)
        try ProviderKeychain.saveKeySync(nousKey, for: .nous)
        #expect(ProviderKeychain.loadKeySync(for: .openrouter) == openrouterKey)
        #expect(ProviderKeychain.loadKeySync(for: .nous) == nousKey)
        try ProviderKeychain.deleteKeySync(for: .openrouter)
        try ProviderKeychain.deleteKeySync(for: .nous)
    }

    @Test("listProvidersWithKeys 列出有 key 的 provider")
    func testListProvidersWithKeys() throws {
        try ProviderKeychain.deleteKeySync(for: .minimax)
        try ProviderKeychain.deleteKeySync(for: .minimaxCn)
        try ProviderKeychain.deleteKeySync(for: .anthropic)
        #expect(!ProviderKeychain.listProvidersWithKeys().contains("minimax"))
        try ProviderKeychain.saveKeySync("«redacted:sk-…»", for: .minimax)
        #expect(ProviderKeychain.listProvidersWithKeys().contains("minimax"))
        try ProviderKeychain.saveKeySync("«redacted:sk-…»", for: .anthropic)
        #expect(ProviderKeychain.listProvidersWithKeys().contains("anthropic"))
        try ProviderKeychain.deleteKeySync(for: .minimax)
        try ProviderKeychain.deleteKeySync(for: .minimaxCn)
        try ProviderKeychain.deleteKeySync(for: .anthropic)
    }
}