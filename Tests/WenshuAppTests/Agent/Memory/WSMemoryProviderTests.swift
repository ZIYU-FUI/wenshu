//
//  Tests/Core/Memory/WSMemoryProviderTests.swift · Wenshu · v0.72 SwiftData migration  deferred
//
//  Test commit 43: WSMemoryProvider (= SwiftData-backed MemoryProvider impl).

import Foundation
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("WSMemoryProvider (= SwiftData-backed MemoryProvider)")
struct WSMemoryProviderTests {

    /// One named in-memory container per test, so this suite reads and
    /// writes its own store. A repository with no named container resolves
    /// the process-global one on every access, and that one moves when a
    /// sibling suite activates a warehouse container (= the write and the
    /// read land in different stores).
    @MainActor
    private static func makeRepository() throws -> WSMemoryRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSMemoryRepository(container: container)
    }

    @MainActor
    private func makeProvider() throws -> (provider: WSMemoryProvider, repository: WSMemoryRepository) {
        let repository = try Self.makeRepository()
        let provider = WSMemoryProvider(slug: "test-provider", memory: repository)
        return (provider, repository)
    }

    @Test("WSMemoryProvider init sets slug + isEnabled")
    @MainActor
    func initDefaults() throws {
        let provider = try WSMemoryProvider(memory: Self.makeRepository())
        #expect(provider.slug == "swiftdata-memory")
        #expect(provider.isEnabled == true)
    }

    @Test("WSMemoryProvider conforms to MemoryProvider protocol")
    @MainActor
    func conformsToProtocol() throws {
        let provider: MemoryProvider = try WSMemoryProvider(memory: Self.makeRepository())
        #expect(provider.slug == "swiftdata-memory")
        _ = provider.getSystemPrompt()  // sync method works
        #expect(provider.getToolSchemas().count >= 1)
    }

    @MainActor
    @Test("getSystemPrompt returns empty when no memories")
    func systemPromptEmpty() throws {
        let (provider, _) = try makeProvider()
        #expect(provider.getSystemPrompt().isEmpty)
    }

    @MainActor
    @Test("prefetch returns empty when no memories match")
    func prefetchEmpty() async throws {
        let (provider, _) = try makeProvider()
        let result = await provider.prefetch(forUserMessage: "anything")
        #expect(result.isEmpty)
    }

    @MainActor
    @Test("sync adds a memory entry (= reflects in mirror)")
    func syncStoresMemory() async throws {
        let (provider, repository) = try makeProvider()
        await provider.sync(userMessage: "hello", assistantResponse: "world")
        // Mirror updated asynchronously
        try? await Task.sleep(for: .milliseconds(250))
        // Re-fetch from SwiftData directly, through the same repository the
        // provider wrote through
        let recent = try? repository.listRecent(userId: "default", limit: 5)
        #expect((recent?.count ?? 0) > 0)
    }

    @Test("preCompressCheckpoint returns nil when mirror empty")
    @MainActor
    func preCompressEmpty() throws {
        let provider = try WSMemoryProvider(memory: Self.makeRepository())
        #expect(provider.preCompressCheckpoint() == nil)
    }

    @Test("getToolSchemas returns 3 schemas (= memory_add, memory_search, memory_get_recent)")
    @MainActor
    func toolSchemas() throws {
        let provider = try WSMemoryProvider(memory: Self.makeRepository())
        let schemas = provider.getToolSchemas()
        #expect(schemas.count == 3)
        let names = Set(schemas.map { $0.name })
        #expect(names.contains("memory_add"))
        #expect(names.contains("memory_search"))
        #expect(names.contains("memory_get_recent"))
    }

    @Test("resetCache clears in-memory state")
    @MainActor
    func resetCache() throws {
        let provider = try WSMemoryProvider(memory: Self.makeRepository())
        provider.resetCache()
        #expect(provider.getSystemPrompt().isEmpty)
    }
}
