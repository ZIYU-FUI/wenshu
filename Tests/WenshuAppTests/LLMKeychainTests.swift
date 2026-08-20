//
//  LLMKeychainTests.swift · Wenshu · v0.21 ticket 03 (LLM Keychain 集成)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLMKeychain (Apple Security framework 真值)")
struct LLMKeychainTests {

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-keychain-\(tag)-\(UUID().uuidString)"
    }

    private func useStore() async -> LLMKeychain {
        await LLMKeychain.shared
    }

    @Test("saveKey 后 loadKey 返一致")
    func testSaveAndLoad() async throws {
        let store = await useStore()
        let testKey = "sk-cp-test-\(UUID().uuidString.prefix(8))"
        try await store.saveKey(testKey)
        let loaded = try await store.loadKey()
        #expect(loaded == testKey)
        try await store.deleteKey()
    }

    @Test("没 key 时 loadKey 返 nil")
    func testLoadEmpty() async throws {
        let store = await useStore()
        try await store.deleteKey()
        let loaded = try await store.loadKey()
        #expect(loaded == nil)
    }

    @Test("空 key 抛 invalidKeyFormat")
    func testEmptyKeyThrows() async throws {
        let store = await useStore()
        await #expect(throws: LLMKeychainError.self) {
            try await store.saveKey("")
        }
    }

    @Test("重复 saveKey 替换旧 key (不抛 duplicateItem)")
    func testSaveReplaces() async throws {
        let store = await useStore()
        let firstKey = "sk-cp-first-\(UUID().uuidString.prefix(8))"
        let secondKey = "sk-cp-second-\(UUID().uuidString.prefix(8))"
        try await store.saveKey(firstKey)
        try await store.saveKey(secondKey)
        let loaded = try await store.loadKey()
        #expect(loaded == secondKey)
        try await store.deleteKey()
    }
}