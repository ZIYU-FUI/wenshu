//
//  SecretScopeTests.swift · Wenshu · TICKET-HERMES-GAP-005
//
//  Tests for SecretScope actor + EnvVarSource + KeychainSource +
//  ProviderKeychain wiring. Pins the Swift resolution-chain
//  semantics so future refactors stay observable.
//
//  Hermes Python target: agent/secret_scope.py (205 LOC) +
//  agent/secret_sources/ (6 files). The wenshu port narrows to
//  env-var + keychain per AGENTS.md §11 BYOK-only wenshu-side wins;
//  1Password CLI / Bitwarden CLI / iCloud Keychain are intentionally
//  out of scope for v0.40 and not tested here.
//
//  Test surface:
//    1. testEnvVarSourceReadsProcessEnv: EnvVarSource reads from
//       ProcessInfo (sets a temp var, reads it back, unsets it).
//    2. testKeychainSourceDelegatesToProviderKeychain: KeychainSource
//       routes through ProviderKeychain.loadKeySync (= verifies the
//       wire-up, not the SecItemAdd internals).
//    3. testSecretScopeResolveMultiSource: 2 sources registered,
//       resolve walks them in order and returns first non-nil.
//    4. testSecretScopeRegisterUnregister: register + current +
//       unregisterAll + resolve returns nil after clear.
//
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SecretScope (TICKET-HERMES-GAP-005)")
struct SecretScopeTests {

    // MARK: - Test 1: EnvVarSource reads process environment

    @Test("EnvVarSource reads ProcessInfo.processInfo.environment")
    func testEnvVarSourceReadsProcessEnv() async throws {
        let key = "WENSHU_SECRET_SCOPE_TEST_\(UUID().uuidString)"
        let expected = "shhh-\(UUID().uuidString)"
        setenv(key, expected, 1)
        defer { unsetenv(key) }

        let source = EnvVarSource()
        let value = try await source.read(name: key)
        #expect(value == expected)

        // Missing key → nil (= "ask next source", NOT throw).
        let missing = try await source.read(name: "WENSHU_DEFINITELY_NOT_SET_\(UUID().uuidString)")
        #expect(missing == nil)
    }

    // MARK: - Test 2: KeychainSource delegates to ProviderKeychain

    @Test("KeychainSource delegates to ProviderKeychain.loadKeySync")
    func testKeychainSourceDelegatesToProviderKeychain() async throws {
        // Install a deterministic in-memory keychain so the test is
        // hermetic (= no Security framework dependency).
        let store = InMemoryKeychainStore()
        let savedKey = "keychain-test-\(UUID().uuidString)"
        let provider = Provider.anthropic
        try store.saveKeySync(savedKey, for: provider)
        ProviderKeychain.setBackendForTesting(store)
        defer {
            // Reset to default backend so other tests are unaffected.
            ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
        }

        let source = KeychainSource(providerSlug: provider.slug)
        let read = try await source.read(name: "api.key")
        #expect(read == savedKey)

        // Missing provider slug → nil (= no throw).
        let missing = KeychainSource(providerSlug: "no-such-provider-\(UUID().uuidString)")
        let nilRead = try await missing.read(name: "api.key")
        #expect(nilRead == nil)
    }

    // MARK: - Test 3: SecretScope walks multiple sources in order

    @Test("SecretScope.resolve walks sources in registration order; first non-nil wins")
    func testSecretScopeResolveMultiSource() async throws {
        let scope = SecretScope()

        // Source A: always returns nil (= simulates env-var miss).
        let sourceA = TestSecretSource(name: "A") { _ in nil }
        // Source B: returns "from-B" for "anthropic.api.key" (= simulated
        // Keychain hit); nil otherwise so it doesn't shadow C in the
        // unknown-name case below.
        let sourceB = TestSecretSource(name: "B") { name in
            name == "anthropic.api.key" ? "from-B" : nil
        }
        // Source C: only matches its own probe name (= should NOT be
        // reached for "anthropic.api.key" because B wins first).
        let sourceC = TestSecretSource(name: "C") { name in
            name == "only-C-matches" ? "from-C" : nil
        }

        await scope.register(sourceA)
        await scope.register(sourceB)
        await scope.register(sourceC)

        let resolved = try await scope.resolve(name: "anthropic.api.key")
        #expect(resolved == "from-B")

        // Sources A + B should have been queried; C's readCount is 0.
        let aCount = await sourceA.readCount
        let bCount = await sourceB.readCount
        let cCount = await sourceC.readCount
        #expect(aCount == 1)
        #expect(bCount == 1)
        #expect(cCount == 0)

        // C-only name → walks A (miss) + B (miss) + C (hit).
        let cOnlyResolved = try await scope.resolve(name: "only-C-matches")
        #expect(cOnlyResolved == "from-C")

        // Unknown name → walked all 3, none had it → nil.
        let missResolved = try await scope.resolve(name: "unknown.\(UUID().uuidString)")
        #expect(missResolved == nil)

        // Convenience overload: `default:` falls back when resolve returns nil.
        let withDefault = try await scope.resolve(name: "unknown.\(UUID().uuidString)", default: "fallback")
        #expect(withDefault == "fallback")
    }

    // MARK: - Test 4: register + current + unregisterAll

    @Test("SecretScope register / current / unregisterAll")
    func testSecretScopeRegisterUnregister() async throws {
        let scope = SecretScope()
        let sourceA = TestSecretSource(name: "A") { _ in nil }
        let sourceB = TestSecretSource(name: "B") { _ in "hit-B" }

        await scope.register(sourceA)
        await scope.register(sourceB)

        let after = await scope.current
        #expect(after.count == 2)

        // Resolve finds B (= A misses, B hits).
        let resolved = try await scope.resolve(name: "any")
        #expect(resolved == "hit-B")

        // unregisterAll clears; resolve returns nil again.
        await scope.unregisterAll()
        let afterClear = await scope.current
        #expect(afterClear.isEmpty)
        let afterClearResolve = try await scope.resolve(name: "any")
        #expect(afterClearResolve == nil)
    }
}

// MARK: - Test helpers

/// Test source that returns a configurable value (= like a stub
/// `SecretSource` that lets each test inject its own behavior).
private actor TestSecretSource: SecretSource {
    let name: String
    private let handler: @Sendable (String) -> String?
    private(set) var readCount: Int = 0

    init(name: String, handler: @escaping @Sendable (String) -> String?) {
        self.name = name
        self.handler = handler
    }

    func read(name: String) async throws -> String? {
        readCount += 1
        return handler(name)
    }
}
