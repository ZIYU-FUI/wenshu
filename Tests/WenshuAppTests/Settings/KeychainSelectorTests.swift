//
//  KeychainSelectorTests.swift · Wenshu · HERMES-DISPATCH-003
//
//  Tests for the pure-function `KeychainSelector` enum.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("KeychainSelector (HERMES-DISPATCH-003)")
struct KeychainSelectorTests {

    // MARK: - Score

    @Test("score: lower priority beats higher priority")
    func testScore_priorityOrdering() {
        let now = Date()
        let high = AuthKey(provider: "anthropic", credential: "h", priority: 0)
        let low = AuthKey(provider: "anthropic", credential: "l", priority: 5)
        #expect(KeychainSelector.score(high, now: now) < KeychainSelector.score(low, now: now))
    }

    @Test("score: authFailed + disabled return Int.max")
    func testScore_permanentlyOut() {
        let now = Date()
        let dead = AuthKey(provider: "anthropic", credential: "d", priority: 0, status: .authFailed)
        let off = AuthKey(provider: "anthropic", credential: "x", priority: 0, status: .disabled)
        #expect(KeychainSelector.score(dead, now: now) == Int.max)
        #expect(KeychainSelector.score(off, now: now) == Int.max)
    }

    @Test("score: cooldown-active key scores worse than active ok key")
    func testScore_cooldownPenalty() {
        let now = Date()
        let ok = AuthKey(provider: "anthropic", credential: "a", priority: 0)
        let cooling = AuthKey(
            provider: "anthropic",
            credential: "b",
            priority: 0,
            status: .rateLimited,
            cooldownUntil: now.addingTimeInterval(60)
        )
        #expect(KeychainSelector.score(ok, now: now) < KeychainSelector.score(cooling, now: now))
    }

    // MARK: - Pick

    @Test("pick: returns nil for empty input")
    func testPick_empty_returnsNil() {
        #expect(KeychainSelector.pick(from: []) == nil)
    }

    @Test("pick: skips rate-limited keys in favor of ok alternatives")
    func testPick_skipsRateLimited() {
        let now = Date()
        let rateLimited = AuthKey(
            provider: "anthropic",
            credential: "rl",
            priority: 0,
            status: .rateLimited,
            cooldownUntil: now.addingTimeInterval(60)
        )
        let fallback = AuthKey(
            provider: "anthropic",
            credential: "fb",
            priority: 5,
            status: .ok
        )
        let picked = KeychainSelector.pick(from: [rateLimited, fallback], now: now)
        #expect(picked?.credential == "fb")
    }

    @Test("pick: skips authFailed keys entirely")
    func testPick_skipsAuthFailed() {
        let now = Date()
        let failed = AuthKey(
            provider: "anthropic",
            credential: "fail",
            priority: 0,
            status: .authFailed
        )
        let ok = AuthKey(
            provider: "anthropic",
            credential: "good",
            priority: 10,
            status: .ok
        )
        let picked = KeychainSelector.pick(from: [failed, ok], now: now)
        #expect(picked?.credential == "good")
    }

    @Test("pick: returns nil when every key is permanently out")
    func testPick_allAuthFailed_returnsNil() {
        let now = Date()
        let f1 = AuthKey(provider: "anthropic", credential: "a", priority: 0, status: .authFailed)
        let f2 = AuthKey(provider: "anthropic", credential: "b", priority: 1, status: .disabled)
        #expect(KeychainSelector.pick(from: [f1, f2], now: now) == nil)
    }

    @Test("pick: cooldown-active ok key is still picked if no better alternative")
    func testPick_cooldownActive_pickedOverPermanentlyOut() {
        let now = Date()
        let cooling = AuthKey(
            provider: "anthropic",
            credential: "cool",
            priority: 5,
            status: .networkError,
            cooldownUntil: now.addingTimeInterval(60)
        )
        let dead = AuthKey(
            provider: "anthropic",
            credential: "dead",
            priority: 0,
            status: .authFailed
        )
        // Single cooldown-active key beats a permanently-out one
        // (= at least one is selected; never returns nil while any
        // candidate is recoverable).
        let picked = KeychainSelector.pick(from: [cooling, dead], now: now)
        #expect(picked?.credential == "cool")
    }

    // MARK: - isValid

    @Test("isValid: cooldown-active key is invalid")
    func testIsValid_cooldownActive() {
        let now = Date()
        let cooling = AuthKey(
            provider: "anthropic",
            credential: "c",
            status: .rateLimited,
            cooldownUntil: now.addingTimeInterval(30)
        )
        #expect(KeychainSelector.isValid(cooling, now: now) == false)
    }

    @Test("isValid: cooldown-expired key is valid again")
    func testIsValid_cooldownExpired() {
        let now = Date()
        let expired = AuthKey(
            provider: "anthropic",
            credential: "e",
            status: .rateLimited,
            cooldownUntil: now.addingTimeInterval(-30)  // 30s ago
        )
        #expect(KeychainSelector.isValid(expired, now: now) == true)
    }

    @Test("isValid: authFailed key is never valid")
    func testIsValid_authFailed() {
        let key = AuthKey(provider: "anthropic", credential: "x", status: .authFailed)
        #expect(KeychainSelector.isValid(key) == false)
    }

    // MARK: - Transition

    @Test("transition: to .ok resets lastError + cooldownUntil")
    func testTransition_toOkResetsError() {
        var key = AuthKey(
            provider: "anthropic",
            credential: "k",
            status: .rateLimited,
            lastError: "old",
            cooldownUntil: Date().addingTimeInterval(60)
        )
        KeychainSelector.transition(&key, to: .ok)
        #expect(key.status == .ok)
        #expect(key.lastError == nil)
        #expect(key.cooldownUntil == nil)
        #expect(key.lastUsedAt != nil)
    }

    @Test("transition: to .authFailed sets error + clears cooldownUntil")
    func testTransition_toAuthFailedSetsError() {
        var key = AuthKey(provider: "anthropic", credential: "k", status: .ok)
        KeychainSelector.transition(&key, to: .authFailed, error: "401 Unauthorized")
        #expect(key.status == .authFailed)
        #expect(key.lastError == "401 Unauthorized")
        #expect(key.cooldownUntil == nil)
    }

    @Test("transition: to .quotaExhausted sets 24h cooldown")
    func testTransition_toQuotaExhausted_24hCooldown() {
        let now = Date()
        var key = AuthKey(provider: "anthropic", credential: "k", status: .ok)
        KeychainSelector.transition(&key, to: .quotaExhausted, error: "billing", now: now)
        #expect(key.status == .quotaExhausted)
        // After a .quotaExhausted transition the cooldown is non-nil and
        // ~24h in the future (= 86,400 seconds, tolerance 1s for the
        // elapsed test time).
        if let until = key.cooldownUntil {
            let diff = until.timeIntervalSince(now)
            let expected: TimeInterval = 24 * 60 * 60
            #expect(abs(diff - expected) < 1)
        } else {
            Issue.record("cooldownUntil was unexpectedly nil after .quotaExhausted transition")
        }
    }
}
