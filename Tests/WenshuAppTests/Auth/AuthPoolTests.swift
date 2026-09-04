//
//  AuthPoolTests.swift · Wenshu · HERMES-DISPATCH-001
//
//  Tests for `AuthPool` actor + `AuthKey` / `AuthKeyStatus` types.
//  Pure unit tests; uses the `swift-testing` framework per the rest of
//  the WenshuAppTests tree (= see Auth/RetryUtilsTests.swift for the pattern).
//
//  No third-party deps; Apple Foundation only.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AuthPool (HERMES-DISPATCH-001)")
struct AuthPoolTests {

    @Test("register creates a key with provider + credential + .ok status")
    func testRegister_createsKey() async throws {
        let pool = AuthPool()
        let key = try await pool.register(provider: "anthropic", credential: "sk-test-1")
        #expect(key.provider == "anthropic")
        #expect(key.credential == "sk-test-1")
        #expect(key.status == .ok)
        #expect(key.priority == 0)
        #expect(key.lastUsedAt == nil)
    }

    @Test("register rejects empty credentials")
    func testRegister_rejectsEmpty() async throws {
        let pool = AuthPool()
        await #expect(throws: AuthPoolError.emptyCredential) {
            _ = try await pool.register(provider: "anthropic", credential: "")
        }
    }

    @Test("keys(for:) sorts by priority ascending")
    func testPickBestKey_priorityOrdering() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "low-prio", priority: 5)
        _ = try await pool.register(provider: "anthropic", credential: "high-prio", priority: 0)
        _ = try await pool.register(provider: "anthropic", credential: "mid-prio", priority: 2)
        let best = try await pool.pickBestKey(for: "anthropic")
        #expect(best?.credential == "high-prio")
    }

    @Test("pickBestKey skips rate-limited keys")
    func testPickBestKey_skipsRateLimited() async throws {
        let pool = AuthPool()
        let primary = try await pool.register(provider: "anthropic", credential: "primary", priority: 0)
        let secondary = try await pool.register(provider: "anthropic", credential: "secondary", priority: 1)
        // Mark primary as rate-limited for 60 seconds (= selector skips).
        try await pool.markRateLimited(keyId: primary.id, cooldownSeconds: 60)
        let picked = try await pool.pickBestKey(for: "anthropic")
        #expect(picked?.id == secondary.id)
        #expect(picked?.credential == "secondary")
    }

    @Test("markRateLimited sets cooldown + status")
    func testMarkRateLimited_setsCooldown() async throws {
        let pool = AuthPool()
        let key = try await pool.register(provider: "openai", credential: "k1")
        let beforeMark = Date()
        try await pool.markRateLimited(keyId: key.id, cooldownSeconds: 30)
        let allKeys = await pool.allKeys()
        let updated = try #require(allKeys.first { $0.id == key.id })
        #expect(updated.status == .rateLimited)
        #expect(updated.lastError == "rate-limited")
        let until = try #require(updated.cooldownUntil)
        // Cooldown should be ~30s in the future (allow 2s tolerance).
        let diff = until.timeIntervalSince(beforeMark)
        #expect(diff >= 28)
        #expect(diff <= 32)
    }

    @Test("markAuthFailed disables key until re-keyed")
    func testMarkAuthFailed_disablesUntilRekeyed() async throws {
        let pool = AuthPool()
        let key = try await pool.register(provider: "anthropic", credential: "broken")
        try await pool.markAuthFailed(keyId: key.id, error: "401 Unauthorized")
        // Single-key pool: pickBestKey must return nil.
        let picked = try await pool.pickBestKey(for: "anthropic")
        #expect(picked == nil)
        // Re-keying (= re-marking ok after a successful re-auth) restores it.
        try await pool.markOk(keyId: key.id)
        let restored = try await pool.pickBestKey(for: "anthropic")
        #expect(restored?.id == key.id)
    }

    @Test("markOk clears cooldown + lastError")
    func testMarkOk_clearsState() async throws {
        let pool = AuthPool()
        let key = try await pool.register(provider: "anthropic", credential: "k1")
        try await pool.markRateLimited(keyId: key.id, cooldownSeconds: 60)
        try await pool.markOk(keyId: key.id)
        let allKeys = await pool.allKeys()
        let updated = try #require(allKeys.first { $0.id == key.id })
        #expect(updated.status == .ok)
        #expect(updated.lastError == nil)
        #expect(updated.cooldownUntil == nil)
        #expect(updated.lastUsedAt != nil)
    }

    @Test("markNetworkError sets short cooldown (= 10s)")
    func testMarkNetworkError_shortCooldown() async throws {
        let pool = AuthPool()
        let key = try await pool.register(provider: "anthropic", credential: "k1")
        let before = Date()
        try await pool.markNetworkError(keyId: key.id, error: "DNS timeout")
        let allKeys = await pool.allKeys()
        let updated = try #require(allKeys.first { $0.id == key.id })
        #expect(updated.status == .networkError)
        let until = try #require(updated.cooldownUntil)
        let diff = until.timeIntervalSince(before)
        #expect(diff >= 9 && diff <= 11)
    }

    @Test("disable prevents selection even with single key")
    func testDisable_preventsSelection() async throws {
        let pool = AuthPool()
        let key = try await pool.register(provider: "anthropic", credential: "k1")
        try await pool.disable(keyId: key.id)
        let picked = try await pool.pickBestKey(for: "anthropic")
        #expect(picked == nil)
    }

    @Test("persist + loadFromDisk round-trip preserves keys")
    func testPersistAndReload() async throws {
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-authpool-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tmpRoot)
        }
        let pool = AuthPool(persistenceRoot: tmpRoot)
        let k1 = try await pool.register(provider: "anthropic", credential: "k1", priority: 0)
        let k2 = try await pool.register(provider: "openai", credential: "k2", priority: 1)
        try await pool.markRateLimited(keyId: k1.id, cooldownSeconds: 60)
        // Force a persist via the explicit API (= also happens implicitly).
        try await pool.persist()
        // Load into a fresh pool from the same root.
        let pool2 = AuthPool(persistenceRoot: tmpRoot)
        try await pool2.loadFromDisk()
        let loaded = await pool2.allKeys()
        #expect(loaded.count == 2)
        let loadedK1 = try #require(loaded.first { $0.id == k1.id })
        #expect(loadedK1.provider == "anthropic")
        #expect(loadedK1.credential == "k1")
        #expect(loadedK1.status == .rateLimited)
        let loadedK2 = try #require(loaded.first { $0.id == k2.id })
        #expect(loadedK2.provider == "openai")
        #expect(loadedK2.status == .ok)
    }

    @Test("keys(for:) returns empty for unknown provider")
    func testKeys_unknownProvider_empty() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1")
        let unknown = try await pool.keys(for: "nonexistent")
        #expect(unknown.isEmpty)
    }
}
