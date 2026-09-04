//
//  KeychainSelector.swift · Wenshu · HERMES-DISPATCH-003
//
//  Priority + status state machine selector for the multi-key pool.
//  Ported from hermes-agent `agent/credential_pool.py` priority-based
//  selection logic (~200 LOC of state machine in `CredentialPool`). Boss
//  2026-09-04 OOB 'A' requested the dispatch layer (= AuthPool /
//  FallbackChain / KeychainSelector / AutoRotation).
//
//  Design:
//    - `enum` (= pure namespace; no state). All methods are `static`.
//    - `score` returns a lower-is-better rank: ok + lowest priority wins.
//      Cooldown-active and disabled keys get effectively infinite score
//      (= `Int.max`) so the selector skips them deterministically.
//    - `pick` is the public entry point used by `AuthPool.pickBestKey`.
//    - `isValid` is the predicate the executor uses to filter before send.
//    - `transition` is the canonical state machine: hermes' `_mark_exhausted`
//      vs `_mark_ok` paths collapsed into one helper that owns all
//      `AuthKeyStatus` transitions.
//
//  Hard rules respected:
//    - All types `Sendable` (= Swift 6 strict concurrency safe).
//    - No stateful storage (= pure functions).
//    - Public API is the minimum needed by AuthPool + FallbackChain
//      + AutoRotation + their tests.
//

import Foundation

/// Pure-function selector over an array of `AuthKey` candidates. No state,
/// no side effects (= apart from the `transition(_:to:error:)` helper which
/// mutates its inout argument only).
public enum KeychainSelector {

    // MARK: - Scoring

    /// Score a key. Lower = better (= select the minimum).
    ///
    /// Scoring rules:
    ///   - .ok + no cooldown          -> priority * 10  (= 0 is best).
    ///   - .ok + cooldown active     -> priority * 10 + 1_000_000  (= effectively last).
    ///   - .rateLimited + active cd  -> priority * 10 + 1_000_000
    ///   - .networkError + active cd -> priority * 10 + 1_000_000
    ///   - .quotaExhausted           -> priority * 10 + 500_000  (= mid-zone).
    ///   - .authFailed / .disabled   -> Int.max  (= permanently skipped).
    ///
    /// `Int.max` is reserved for "never select" states; other states get a
    /// large-but-finite penalty so a future round-robin / least-used strategy
    /// (= not in v0.40; hermes has it via STRATEGY_ROUND_ROBIN) can still rank
    /// between cold keys.
    public static func score(_ key: AuthKey, now: Date = Date()) -> Int {
        // Permanent-out states never get picked.
        if key.status.isPermanentlyOut { return Int.max }

        let priorityBase = key.priority * 10

        // Cooldown active? = skip until elapsed.
        if let until = key.cooldownUntil, until > now {
            switch key.status {
            case .quotaExhausted:
                return priorityBase + 500_000
            case .rateLimited, .networkError, .ok:
                return priorityBase + 1_000_000
            case .authFailed, .disabled:
                return Int.max
            }
        }

        // No active cooldown = ok / disabled-cooldown-expired = baseline score.
        return priorityBase
    }

    // MARK: - Selection

    /// Pick the best key from a candidate list. Returns nil when every key
    /// is permanently out (= all `.authFailed` / `.disabled`).
    public static func pick(from keys: [AuthKey], now: Date = Date()) -> AuthKey? {
        guard !keys.isEmpty else { return nil }
        var best: AuthKey? = nil
        var bestScore = Int.max
        for key in keys {
            let s = score(key, now: now)
            if s < bestScore {
                bestScore = s
                best = key
            }
        }
        // If bestScore == Int.max, every key was permanently out.
        return bestScore == Int.max ? nil : best
    }

    // MARK: - Validity predicate

    /// True if the key is eligible to be sent a request right now.
    /// (= not permanently out AND cooldown elapsed.)
    public static func isValid(_ key: AuthKey, now: Date = Date()) -> Bool {
        if key.status.isPermanentlyOut { return false }
        if let until = key.cooldownUntil, until > now { return false }
        return true
    }

    // MARK: - State machine

    /// Apply a transition to `key`. Mutates the inout argument only
    /// (= hermes-style immutable-replace-via-mutate). Use this from any
    /// caller that needs to mutate a key's status outside the AuthPool
    /// actor (= e.g. unit tests that exercise state changes without the
    /// full actor round-trip).
    ///
    /// Mapping (= matches hermes `_mark_exhausted` + `_mark_ok` semantics):
    ///   - .ok: clears lastError + cooldownUntil, sets lastUsedAt.
    ///   - .rateLimited: keeps status, sets error, sets cooldownUntil = now + cooldown.
    ///   - .authFailed: permanent; clears cooldownUntil.
    ///   - .networkError: sets short cooldown (= 10s).
    ///   - .quotaExhausted: sets 24h cooldown.
    ///   - .disabled: clears cooldownUntil + lastError.
    public static func transition(
        _ key: inout AuthKey,
        to newStatus: AuthKeyStatus,
        error: String? = nil,
        now: Date = Date()
    ) {
        switch newStatus {
        case .ok:
            key.status = .ok
            key.lastError = nil
            key.cooldownUntil = nil
            key.lastUsedAt = now
        case .rateLimited:
            key.status = .rateLimited
            key.lastError = error
            // Default = 60s (= hermes default for 429).
            key.cooldownUntil = now.addingTimeInterval(60)
            key.lastUsedAt = now
        case .authFailed:
            key.status = .authFailed
            key.lastError = error
            key.cooldownUntil = nil
        case .networkError:
            key.status = .networkError
            key.lastError = error
            key.cooldownUntil = now.addingTimeInterval(10)
            key.lastUsedAt = now
        case .quotaExhausted:
            key.status = .quotaExhausted
            key.lastError = error
            key.cooldownUntil = now.addingTimeInterval(24 * 60 * 60)
        case .disabled:
            key.status = .disabled
            key.lastError = nil
            key.cooldownUntil = nil
        }
    }
}
