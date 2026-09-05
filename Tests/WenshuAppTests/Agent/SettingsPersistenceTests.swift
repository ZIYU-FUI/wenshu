//
//  SettingsPersistenceTests.swift · Wenshu · SETTINGS-PERSISTENCE-001/002 (2026-09-05)
//
//  Round-trip tests for the Settings -> Memory + Settings -> Skills
//  persistence wiring (= v0.37 readiness audit §5 #1 + #2 fixes).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SettingsPersistence (001 + 002)")
struct SettingsPersistenceTests {

    private func makeSuite() -> UserDefaults {
        let suiteName = "wenshu.tests.settings-persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Settings-Persistence-001 (Memory)

    @Test("MemoryAdapter.DefaultsKey constants match the @AppStorage keys")
    func testDefaultsKeyConstants() {
        #expect(MemoryAdapter.DefaultsKey.enabled == "wenshu.memory.enabled")
        #expect(MemoryAdapter.DefaultsKey.scope == "wenshu.memory.scope")
        #expect(MemoryAdapter.DefaultsKey.retentionDays == "wenshu.memory.retentionDays")
    }

    @Test("MemoryAdapter: defaults to enabled when no key is set")
    func testMemoryAdapterDefaultsEnabled() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        let enabled = await adapter.isEnabled
        #expect(enabled == true)
    }

    @Test("MemoryAdapter: setEnabled flips the persisted value")
    func testMemoryAdapterSetEnabled() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        await adapter.setEnabled(false)
        let enabled = await adapter.isEnabled
        #expect(enabled == false)
        await adapter.setEnabled(true)
        let enabledAgain = await adapter.isEnabled
        #expect(enabledAgain == true)
    }

    @Test("MemoryAdapter: scope defaults to perBook when no key is set")
    func testMemoryAdapterDefaultScope() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        let scope = await adapter.scope
        #expect(scope == .perBook)
    }

    @Test("MemoryAdapter: setScope persists the raw value")
    func testMemoryAdapterSetScope() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        await adapter.setScope(.libraryPublic)
        let scope = await adapter.scope
        #expect(scope == .libraryPublic)
        await adapter.setScope(.perBook)
        let scopeAgain = await adapter.scope
        #expect(scopeAgain == .perBook)
    }

    @Test("MemoryAdapter: retentionDays defaults to 90 when no key is set")
    func testMemoryAdapterDefaultRetention() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        let days = await adapter.retentionDays
        #expect(days == 90)
    }

    @Test("MemoryAdapter: retentionDays clamps to the UI range 7..365")
    func testMemoryAdapterRetentionClamps() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        let deleted = await adapter.setRetentionDays(3)
        let lowClamped = await adapter.retentionDays
        #expect(lowClamped == 7)
        #expect(deleted == 0)
        _ = await adapter.setRetentionDays(1000)
        let highClamped = await adapter.retentionDays
        #expect(highClamped == 365)
    }

    @Test("MemoryAdapter: setRetentionDays calls purgeOlderThan (zero rows on empty store)")
    func testMemoryAdapterPurgeOnRetentionChange() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        let deleted = await adapter.setRetentionDays(30)
        #expect(deleted == 0)
        let days = await adapter.retentionDays
        #expect(days == 30)
    }

    @Test("MemoryAdapter: recentEntries returns empty on a fresh suite")
    func testMemoryAdapterRecentEmpty() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        let entries = await adapter.recentEntries(limit: 5)
        #expect(entries.isEmpty)
    }

    @Test("MemoryAdapter: retrieve returns empty when disabled")
    func testMemoryAdapterRetrieveDisabled() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        await adapter.setEnabled(false)
        let entries = await adapter.retrieve(forUserMessage: "test")
        #expect(entries.isEmpty)
    }

    @Test("MemoryAdapter: write is a no-op when disabled (silent gate)")
    func testMemoryAdapterWriteDisabled() async {
        let defaults = makeSuite()
        let adapter = MemoryAdapter(defaults: defaults)
        await adapter.setEnabled(false)
        await adapter.write(snippet: "ignore me", source: "/x.md")
    }

    // MARK: - MemoryStore listRecent / purgeOlderThan

    @Test("MemoryStore: listRecent returns newest-first ordering")
    func testMemoryStoreListRecent() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString.prefix(8)).db")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try MemoryStore(path: tmp.path)
        try await store.bootstrap()
        _ = try await store.add(userId: "u1", content: "oldest")
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await store.add(userId: "u1", content: "middle")
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await store.add(userId: "u1", content: "newest")
        let rows = try await store.listRecent(userId: "u1", limit: 5)
        #expect(rows.count == 3)
        #expect(rows.first?.content == "newest")
    }

    @Test("MemoryStore: purgeOlderThan deletes nothing when nothing matches")
    func testMemoryStorePurgeNoMatch() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString.prefix(8)).db")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try MemoryStore(path: tmp.path)
        try await store.bootstrap()
        _ = try await store.add(userId: "u1", content: "fresh")
        let deleted = try await store.purgeOlderThan(userId: "u1", retentionDays: 365)
        #expect(deleted == 0)
        let count = try await store.count(userId: "u1")
        #expect(count == 1)
    }

    @Test("MemoryStore: purgeOlderThan with retentionDays <= 0 is a no-op")
    func testMemoryStorePurgeZeroIsNoop() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString.prefix(8)).db")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try MemoryStore(path: tmp.path)
        try await store.bootstrap()
        _ = try await store.add(userId: "u1", content: "x")
        let deleted = try await store.purgeOlderThan(userId: "u1", retentionDays: 0)
        #expect(deleted == 0)
        let deletedNegative = try await store.purgeOlderThan(userId: "u1", retentionDays: -5)
        #expect(deletedNegative == 0)
    }

    @Test("MemoryStore: listRecent with limit <= 0 returns empty")
    func testMemoryStoreListRecentZeroLimit() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString.prefix(8)).db")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try MemoryStore(path: tmp.path)
        try await store.bootstrap()
        _ = try await store.add(userId: "u1", content: "x")
        let rowsZero = try await store.listRecent(userId: "u1", limit: 0)
        #expect(rowsZero.isEmpty)
        let rowsNegative = try await store.listRecent(userId: "u1", limit: -3)
        #expect(rowsNegative.isEmpty)
    }

    // MARK: - Settings-Persistence-002 (Skills)

    @Test("SkillAdapter.DefaultsKey.skillEnabled derives the per-skill UserDefaults key")
    func testSkillAdapterDefaultsKey() {
        #expect(SkillAdapter.DefaultsKey.skillEnabled("foo") == "wenshu.skills.enabled.foo")
        #expect(SkillAdapter.DefaultsKey.skillEnabled("bar") == "wenshu.skills.enabled.bar")
        #expect(SkillAdapter.DefaultsKey.skillEnabled("foo") != SkillAdapter.DefaultsKey.skillEnabled("bar"))
    }

    @Test("SkillAdapter: isSkillEnabled defaults to true when no key is set")
    func testSkillAdapterDefaultEnabled() async {
        let defaults = makeSuite()
        let adapter = SkillAdapter(defaults: defaults)
        let enabled = await adapter.isSkillEnabled(name: "review")
        #expect(enabled == true)
    }

    @Test("SkillAdapter: setEnabled persists and is read back")
    func testSkillAdapterSetEnabled() async {
        let defaults = makeSuite()
        let adapter = SkillAdapter(defaults: defaults)
        await adapter.setEnabled(name: "review", enabled: false)
        let off = await adapter.isSkillEnabled(name: "review")
        #expect(off == false)
        await adapter.setEnabled(name: "review", enabled: true)
        let on = await adapter.isSkillEnabled(name: "review")
        #expect(on == true)
    }

    @Test("SkillAdapter: setEnabled for one skill does not affect another")
    func testSkillAdapterSetEnabledIsolation() async {
        let defaults = makeSuite()
        let adapter = SkillAdapter(defaults: defaults)
        await adapter.setEnabled(name: "review", enabled: false)
        let reviewOff = await adapter.isSkillEnabled(name: "review")
        let summarizeOn = await adapter.isSkillEnabled(name: "summarize")
        #expect(reviewOff == false)
        #expect(summarizeOn == true)
    }

    @Test("SkillAdapter: currentEnabled returns the same value as isSkillEnabled")
    func testSkillAdapterCurrentEnabledMatches() async {
        let defaults = makeSuite()
        let adapter = SkillAdapter(defaults: defaults)
        await adapter.setEnabled(name: "x", enabled: false)
        let sync = await adapter.currentEnabled(name: "x")
        let async = await adapter.isSkillEnabled(name: "x")
        #expect(sync == async)
        #expect(sync == false)
    }

    @Test("SkillAdapter: invoke returns the disabled sentinel when toggle is off")
    func testSkillAdapterInvokeDisabled() async {
        let defaults = makeSuite()
        let adapter = SkillAdapter(defaults: defaults)
        await adapter.setEnabled(name: "review", enabled: false)
        let result = try? await adapter.invoke(name: "review", input: "draft")
        #expect(result?.contains("disabled") == true)
        #expect(result?.contains("/review") == true)
    }

    @Test("SkillAdapter: invoke returns the stub string when toggle is on")
    func testSkillAdapterInvokeEnabled() async {
        let defaults = makeSuite()
        let adapter = SkillAdapter(defaults: defaults)
        let result = try? await adapter.invoke(name: "review", input: "draft")
        #expect(result?.contains("invoked") == true)
        #expect(result?.contains("review") == true)
    }

    @Test("SkillAdapter: setEnabled survives an adapter re-init on the same suite")
    func testSkillAdapterPersistenceAcrossInits() async {
        let defaults = makeSuite()
        // SETTINGS-PERSISTENCE-002: the actor can be reconstructed
        // against the same UserDefaults suite and read the prior
        // setEnabled flip (= mirrors the wenshu runtime pattern where
        // ChatView, ChatViewModel, and the Settings pane each hold
        // their own SkillAdapter instance against the shared
        // UserDefaults store).
        await Self.writeThenRead(defaults: defaults)
    }

    private static func writeThenRead(defaults: UserDefaults) async {
        let writer = SkillAdapter(defaults: defaults)
        await writer.setEnabled(name: "compress", enabled: false)
        let reader = SkillAdapter(defaults: defaults)
        let persisted = await reader.isSkillEnabled(name: "compress")
        #expect(persisted == false)
    }
}
