//
//  Persistence/Repositories/WSProviderKeyRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSProviderKeyRepository (= SwiftData @Model metadata index for LLM keys)")
struct WSProviderKeyRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSProviderKeyRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSProviderKeyRepository(container: container)
    }

    @Test("saveMetadata + loadEncryptedKey round-trip (= encrypted BLOB)")
    @MainActor
    func saveAndLoad() throws {
        let repo = try makeRepository()
        let blob = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10])
        try repo.saveMetadata(slug: "anthropic", encryptedKey: blob)
        let loaded = try repo.loadEncryptedKey(slug: "anthropic")
        #expect(loaded == blob)
    }

    @Test("saveMetadata updates (= overwrites) existing entry")
    @MainActor
    func update() throws {
        let repo = try makeRepository()
        let oldBlob = Data(repeating: 0xAA, count: 16)
        let newBlob = Data(repeating: 0xBB, count: 16)
        try repo.saveMetadata(slug: "openai", encryptedKey: oldBlob)
        try repo.saveMetadata(slug: "openai", encryptedKey: newBlob)
        let loaded = try repo.loadEncryptedKey(slug: "openai")
        #expect(loaded == newBlob)
        #expect(loaded != oldBlob)
    }

    @Test("listProviders returns all stored slugs")
    @MainActor
    func listProviders() throws {
        let repo = try makeRepository()
        let blob = Data(repeating: 0, count: 16)
        try repo.saveMetadata(slug: "anthropic", encryptedKey: blob)
        try repo.saveMetadata(slug: "openai", encryptedKey: blob)
        try repo.saveMetadata(slug: "gemini", encryptedKey: blob)
        let providers = try repo.listProviders()
        #expect(Set(providers) == Set(["anthropic", "openai", "gemini"]))
    }

    @Test("deleteMetadata removes the row")
    @MainActor
    func delete() throws {
        let repo = try makeRepository()
        try repo.saveMetadata(slug: "deepseek", encryptedKey: Data(repeating: 0, count: 16))
        try repo.deleteMetadata(slug: "deepseek")
        let loaded = try repo.loadEncryptedKey(slug: "deepseek")
        #expect(loaded == nil)
    }

    @Test("saveMetadata enforces slug uniqueness")
    @MainActor
    func slugUniqueness() throws {
        let repo = try makeRepository()
        let blob = Data(repeating: 0, count: 16)
        try repo.saveMetadata(slug: "ollama", encryptedKey: blob)
        // Same slug, different blob — update path runs (= no error)
        try repo.saveMetadata(slug: "ollama", encryptedKey: Data(repeating: 1, count: 16))
        let providers = try repo.listProviders()
        #expect(providers.count == 1)
    }
}
