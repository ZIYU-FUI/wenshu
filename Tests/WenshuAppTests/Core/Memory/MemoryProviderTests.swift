// MemoryProviderTests.swift · Wenshu · v0.28
//
// Hermes-port validation tests for MemoryProvider.swift
// (= wenshu M6 ticket 18 = hermes-port batch 3 eighth ticket).
//
// Tests cover:
// - PreCompressCheckpointAPI constants (= hermes v2 + legacy v1)
// - ToolSchema.normalize (= hermes normalize_tool_schema)
// - InMemoryMemoryProvider round-trip
// - UserDefaultsMemoryProvider persistence
// - SQLiteMemoryProvider stub delegation
// - memoryProviderToolsEnabled gate

import Foundation
import Testing
@testable import WenshuApp

@Suite("MemoryProvider (hermes verbatim port — M6 ticket 18)")
struct MemoryProviderTests {

    // MARK: - Constants

    @Test("PreCompressCheckpointAPI currentVersion = 2 (= hermes v2)")
    func preCompressCurrent() {
        #expect(PreCompressCheckpointAPI.currentVersion == 2)
    }

    @Test("PreCompressCheckpointAPI legacyVersion = 1 (= hermes historical)")
    func preCompressLegacy() {
        #expect(PreCompressCheckpointAPI.legacyVersion == 1)
    }

    // MARK: - ToolSchema.normalize

    @Test("ToolSchema.normalize unwraps OpenAI-wrapped function entry")
    func normalizeUnwrapsWrapped() {
        let wrapped: [String: Any] = [
            "type": "function",
            "function": [
                "name": "memory_search",
                "description": "Search memory",
                "parameters": ["type": "object", "properties": [String: Any]()]
            ]
        ]
        let normalized = ToolSchema.normalize(wrapped)
        #expect(normalized != nil)
        #expect(normalized?.name == "memory_search")
        #expect(normalized?.description == "Search memory")
    }

    @Test("ToolSchema.normalize accepts bare function schema")
    func normalizeBare() {
        let bare: [String: Any] = [
            "name": "memory_search",
            "description": "Search memory"
        ]
        let normalized = ToolSchema.normalize(bare)
        #expect(normalized?.name == "memory_search")
    }

    @Test("ToolSchema.normalize returns nil for entry without name")
    func normalizeRejectsNameless() {
        let nameless: [String: Any] = [
            "type": "function",
            "description": "no name"
        ]
        #expect(ToolSchema.normalize(nameless) == nil)
    }

    @Test("ToolSchema.normalize returns nil for non-dict input")
    func normalizeRejectsNonDict() {
        #expect(ToolSchema.normalize("not a dict") == nil)
        #expect(ToolSchema.normalize(123) == nil)
    }

    // MARK: - In-memory provider

    @Test("InMemoryMemoryProvider round-trip: sync + prefetch")
    func inMemoryRoundTrip() async {
        let provider = InMemoryMemoryProvider(slug: "test-in-memory")
        await provider.sync(userMessage: "hello", assistantResponse: "hi")
        await provider.sync(userMessage: "how are you", assistantResponse: "good")
        #expect(provider.entryCount == 2)
        let prefetched = await provider.prefetch(forUserMessage: "follow-up")
        #expect(prefetched.contains("hello"))
        #expect(prefetched.contains("hi"))
    }

    @Test("InMemoryMemoryProvider system prompt reports count")
    func inMemorySystemPrompt() {
        let provider = InMemoryMemoryProvider(slug: "test")
        let prompt = provider.getSystemPrompt()
        #expect(prompt.contains("0 entries"))
    }

    @Test("InMemoryMemoryProvider caps at 100 entries (= hermes in-memory cap)")
    func inMemoryCap() async {
        let provider = InMemoryMemoryProvider(slug: "test-cap")
        for i in 0..<120 {
            await provider.sync(userMessage: "u\(i)", assistantResponse: "a\(i)")
        }
        #expect(provider.entryCount == 100)
    }

    // MARK: - UserDefaults provider

    @Test("UserDefaultsMemoryProvider persistence across instances")
    func userDefaultsPersistence() async {
        let key = "wenshu.memory.test.\(UUID().uuidString)"
        // Use isolated UserDefaults (= a fresh suite to avoid polluting the
        // standard defaults).
        let suiteName = "test-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults")
            return
        }
        let provider1 = UserDefaultsMemoryProvider(slug: "test", key: key, defaults: defaults)
        await provider1.sync(userMessage: "u1", assistantResponse: "a1")
        #expect(provider1.entryCount == 1)

        // New instance with same defaults (= simulates app restart)
        let provider2 = UserDefaultsMemoryProvider(slug: "test", key: key, defaults: defaults)
        #expect(provider2.entryCount == 1)
    }

    // MARK: - SQLite provider (stub)

    @Test("SQLiteMemoryProvider stub delegates to in-memory backing")
    func sqliteStubDelegates() async {
        let provider = SQLiteMemoryProvider(slug: "test-sqlite")
        await provider.sync(userMessage: "u", assistantResponse: "a")
        #expect(provider.entryCount == 1)
        let prefetched = await provider.prefetch(forUserMessage: "follow-up")
        #expect(prefetched.contains("u"))
    }

    @Test("SQLiteMemoryProvider system prompt indicates stub status")
    func sqliteSystemPrompt() {
        let provider = SQLiteMemoryProvider(slug: "test")
        let prompt = provider.getSystemPrompt()
        #expect(prompt.contains("stub"))
    }

    // MARK: - Tools-enabled gate

    @Test("memoryProviderToolsEnabled returns true when memory not in disabled")
    func toolsEnabledDefault() {
        #expect(memoryProviderToolsEnabled() == true)
        #expect(memoryProviderToolsEnabled(enabledToolsets: ["memory"]) == true)
    }

    @Test("memoryProviderToolsEnabled returns false when memory in disabled")
    func toolsDisabled() {
        #expect(memoryProviderToolsEnabled(disabledToolsets: ["memory"]) == false)
    }

    @Test("memoryProviderToolsEnabled returns true when memory tool present")
    func toolsMemoryPresent() {
        #expect(memoryProviderToolsEnabled(memoryToolPresent: true) == true)
        #expect(memoryProviderToolsEnabled(disabledToolsets: ["memory"], memoryToolPresent: true) == false)
    }

    @Test("memoryProviderToolsEnabled respects explicit enabled list without memory")
    func toolsEnabledExplicitNoMemory() {
        #expect(memoryProviderToolsEnabled(enabledToolsets: ["chat"]) == false)
    }
}