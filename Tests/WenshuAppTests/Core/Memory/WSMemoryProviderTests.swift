//
//  Tests/Core/Memory/WSMemoryProviderTests.swift · Wenshu · v0.72 SwiftData migration Phase 3 deferred
//
//  Test commit 43: WSMemoryProvider (= SwiftData-backed MemoryProvider impl).

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSMemoryProvider (= SwiftData-backed MemoryProvider)")
struct WSMemoryProviderTests {

    @MainActor
    private func makeProvider() -> WSMemoryProvider {
        WSMemoryProvider(slug: "test-provider")
    }

    @Test("WSMemoryProvider init sets slug + isEnabled")
    func initDefaults() {
        let provider = WSMemoryProvider()
        #expect(provider.slug == "swiftdata-memory")
        #expect(provider.isEnabled == true)
    }

    @Test("WSMemoryProvider conforms to MemoryProvider protocol")
    func conformsToProtocol() {
        let provider: MemoryProvider = WSMemoryProvider()
        #expect(provider.slug == "swiftdata-memory")
        _ = provider.getSystemPrompt()  // sync method works
        #expect(provider.getToolSchemas().count >= 1)
    }

    @MainActor
    @Test("getSystemPrompt returns empty when no memories")
    func systemPromptEmpty() {
        let provider = makeProvider()
        #expect(provider.getSystemPrompt().isEmpty)
    }

    @MainActor
    @Test("prefetch returns empty when no memories match")
    func prefetchEmpty() async {
        let provider = makeProvider()
        let result = await provider.prefetch(forUserMessage: "anything")
        #expect(result.isEmpty)
    }

    @MainActor
    @Test("sync adds a memory entry (= reflects in mirror)")
    func syncStoresMemory() async {
        let provider = makeProvider()
        await provider.sync(userMessage: "hello", assistantResponse: "world")
        // Mirror updated asynchronously
        try? await Task.sleep(for: .milliseconds(100))
        // Re-fetch from SwiftData directly
        let recent = try? WSMemoryRepository.shared.listRecent(userId: "default", limit: 5)
        #expect((recent?.count ?? 0) > 0)
    }

    @Test("preCompressCheckpoint returns nil when mirror empty")
    func preCompressEmpty() {
        let provider = WSMemoryProvider()
        #expect(provider.preCompressCheckpoint() == nil)
    }

    @Test("getToolSchemas returns 3 schemas (= memory_add, memory_search, memory_get_recent)")
    func toolSchemas() {
        let provider = WSMemoryProvider()
        let schemas = provider.getToolSchemas()
        #expect(schemas.count == 3)
        let names = Set(schemas.map { $0.name })
        #expect(names.contains("memory_add"))
        #expect(names.contains("memory_search"))
        #expect(names.contains("memory_get_recent"))
    }

    @Test("resetCache clears in-memory state")
    func resetCache() {
        let provider = WSMemoryProvider()
        provider.resetCache()
        #expect(provider.getSystemPrompt().isEmpty)
    }
}
