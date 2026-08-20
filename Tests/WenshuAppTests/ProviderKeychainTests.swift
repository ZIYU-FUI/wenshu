//
//  ProviderKeychainTests.swift · v0.21 ticket 02
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ProviderKeychain (Apple Security framework 多 provider 真值)")
struct ProviderKeychainTests {

    @Test("saveKey 后 loadKey 返一致")
    func testSaveAndLoad() throws {
        let key = "sk-cp-test-\(UUID().uuidString.prefix(8))"
        // 重试 saveKey (Keychain SecItemDelete 异步完成, 直接 SecItemAdd 可能 errSecDuplicateItem)
        for attempt in 0..<3 {
            do {
                try ProviderKeychain.saveKeySync(key, for: .openrouter)
                break
            } catch {
                if attempt == 2 { throw error }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
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
        let openrouterKey = "sk-or-test-\(UUID().uuidString.prefix(8))"
        let nousKey = "sk-nous-test-\(UUID().uuidString.prefix(8))"
        for attempt in 0..<3 {
            do {
                try ProviderKeychain.saveKeySync(openrouterKey, for: .openrouter)
                try ProviderKeychain.saveKeySync(nousKey, for: .nous)
                break
            } catch {
                if attempt == 2 { throw error }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        #expect(ProviderKeychain.loadKeySync(for: .openrouter) == openrouterKey)
        #expect(ProviderKeychain.loadKeySync(for: .nous) == nousKey)
        try ProviderKeychain.deleteKeySync(for: .openrouter)
        try ProviderKeychain.deleteKeySync(for: .nous)
    }

    @Test("listProvidersWithKeys 列出有 key 的 provider")
    func testListProvidersWithKeys() throws {
        try ProviderKeychain.deleteKeySync(for: .minimax)
        try ProviderKeychain.deleteKeySync(for: .anthropic)
        #expect(!ProviderKeychain.listProvidersWithKeys().contains("minimax"))
        try ProviderKeychain.saveKeySync("sk-cp-test-001", for: .minimax)
        #expect(ProviderKeychain.listProvidersWithKeys().contains("minimax"))
        try ProviderKeychain.saveKeySync("sk-ant-test-001", for: .anthropic)
        #expect(ProviderKeychain.listProvidersWithKeys().contains("anthropic"))
        try ProviderKeychain.deleteKeySync(for: .minimax)
        try ProviderKeychain.deleteKeySync(for: .anthropic)
    }
}
