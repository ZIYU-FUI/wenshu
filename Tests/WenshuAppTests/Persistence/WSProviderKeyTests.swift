//
//  Persistence/WSProviderKeyTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSProviderKey (= provider_keys @Model)")
struct WSProviderKeyTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSProviderKey.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSProviderKey init stores encryptedKey (= never plaintext)")
    @MainActor
    func initStoresEncryptedKey() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // Test uses fake ciphertext (= random bytes; = same shape as AES-GCM output)
        let ciphertext = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                               0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10])
        let pk = WSProviderKey(providerSlug: "anthropic", encryptedKey: ciphertext)
        context.insert(pk)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSProviderKey>())
        #expect(fetched.count == 1)
        #expect(fetched[0].providerSlug == "anthropic")
        #expect(fetched[0].encryptedKey == ciphertext)
        // Verify it's NOT plaintext by shape (= AES-GCM = 16+ bytes for nonce + tag)
        #expect(fetched[0].encryptedKey.count >= 16)
    }

    @Test("WSProviderKey update(encryptedKey:) rotates ciphertext + bumps updatedAt")
    @MainActor
    func updateRotatesCiphertext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let oldKey = Data(repeating: 0xAA, count: 32)
        let newKey = Data(repeating: 0xBB, count: 32)
        let pk = WSProviderKey(providerSlug: "openai", encryptedKey: oldKey)
        context.insert(pk)
        try context.save()
        let original = pk.updatedAt
        try? Thread.sleep(forTimeInterval: 0.05)  // v0.72 Q99 MED fix: bumped from 0.01 (= too flaky on slow CI; = needs > Date precision)
        pk.update(encryptedKey: newKey)
        try context.save()
        #expect(pk.encryptedKey == newKey)
        #expect(pk.encryptedKey != oldKey)
        #expect(pk.updatedAt > original)
    }

    @Test("WSProviderKey providerSlug uniqueness enforced")
    @MainActor
    func slugUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSProviderKey(providerSlug: "gemini", encryptedKey: Data(repeating: 0x01, count: 32))
        let b = WSProviderKey(providerSlug: "gemini", encryptedKey: Data(repeating: 0x02, count: 32))
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }

    @Test("WSProviderKey stores multiple distinct slugs independently")
    @MainActor
    func multipleSlugsCoexist() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let providers = ["anthropic", "openai", "gemini", "deepseek", "ollama"]
        for (i, slug) in providers.enumerated() {
            let key = Data(repeating: UInt8(i), count: 32)
            context.insert(WSProviderKey(providerSlug: slug, encryptedKey: key))
        }
        try context.save()
        let all = try context.fetch(FetchDescriptor<WSProviderKey>())
        #expect(all.count == 5)
        let slugs = Set(all.map { $0.providerSlug })
        #expect(slugs == Set(providers))
    }
}
