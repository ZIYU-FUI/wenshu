//
//  RuntimeHelpersTests.swift · Wenshu · TICKET-HERMES-GAP-003
//
//  8 round-trip tests covering the RuntimeHelpers surface (= mock-time
//  injection, verbose/debug flag gates, credential resolution chain).
//
//  Test inventory (= per ticket GAP-003 §File 3):
//    1. testNow_wallClock           — state.mockTime == nil → now() ≈ Date()
//    2. testNow_mockTime             — state.mockTime = fixed → now() == exact
//    3. testVerbose_vprint_silent    — state.verbose = false → vprint silent
//    4. testVerbose_vprint_emits     — state.verbose = true  → vprint emits
//    5. testDebug_dprint_silent      — state.debug   = false   → dprint silent
//    6. testDebug_dprint_emits       — state.debug   = true    → dprint emits
//    7. testResolveCredential_envVar — env var set    → env tier wins
//    8. testResolveCredential_keychain — env var unset + keychain injected → keychain tier wins
//
//  All tests inject their own keychain / system-default / output sinks
//  (= the actor's test seams); no production backends are touched. This
//  means the credential tests don't depend on Keychain entitlements or
//  ProcessInfo state from the host.

import Testing
import Foundation
@testable import WenshuApp

@Suite("RuntimeHelpers (ticket GAP-003)")
struct RuntimeHelpersTests {

    // MARK: - Helpers

    /// Capture output from a sink. Returns the array of messages and a
    /// thread-safe mutator. Tests assert on the captured array.
    ///
    /// The capture buffer is wrapped in a small reference type because
    /// `RuntimeHelpers.OutputSink` is `@Sendable` (= Swift 6 strict
    /// concurrency). An `NSMutableArray` cannot be captured by reference
    /// in a `@Sendable` closure (it's not Sendable). The wrapper class
    /// is `final class` with internal synchronization via an unfair lock.
    private final class CaptureBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var messages: [String] = []

        func append(_ message: String) {
            lock.lock()
            defer { lock.unlock() }
            messages.append(message)
        }

        func snapshot() -> [String] {
            lock.lock()
            defer { lock.unlock() }
            return messages
        }
    }

    private func makeCapture() -> (buffer: CaptureBuffer, sink: RuntimeHelpers.OutputSink) {
        let buffer = CaptureBuffer()
        let sink: RuntimeHelpers.OutputSink = { message in
            buffer.append(message)
        }
        return (buffer, sink)
    }

    // MARK: - Test 1: now() with no mockTime returns wall-clock

    @Test("now() returns wall-clock when mockTime is nil")
    func testNow_wallClock() async throws {
        let runtime = RuntimeHelpers()
        let wallStart = Date()
        let returned = await runtime.now()
        let wallEnd = Date()

        // No mockTime ⇒ now() ≈ Date() taken within the test window.
        #expect(returned >= wallStart)
        #expect(returned <= wallEnd)
    }

    // MARK: - Test 2: now() with mockTime returns the exact fixed instant

    @Test("now() returns the exact mockTime value when set")
    func testNow_mockTime() async throws {
        let fixed = Date(timeIntervalSince1970: 100)
        let state = RuntimeState(mockTime: fixed)
        let runtime = RuntimeHelpers(state: state)

        let first = await runtime.now()
        // Sleep to confirm a second call still returns the fixed value
        // (= wall-clock has moved but the mock overrides it).
        try await Task.sleep(nanoseconds: 10_000_000)  // 10 ms
        let second = await runtime.now()

        #expect(first == fixed)
        #expect(second == fixed)
        #expect(first == second)
    }

    // MARK: - Test 3: vprint is silent when verbose=false

    @Test("vprint is silent when state.verbose is false")
    func testVerbose_vprint_silent() async throws {
        let (buffer, sink) = makeCapture()
        let state = RuntimeState(verbose: false)
        let runtime = RuntimeHelpers(state: state, vprintSink: sink)

        await runtime.vprint("hello (should not appear)")
        // Tiny sleep to allow any async emit to land before we check.
        try await Task.sleep(nanoseconds: 1_000_000)
        #expect(buffer.snapshot().isEmpty)
    }

    // MARK: - Test 4: vprint emits when verbose=true

    @Test("vprint emits the message verbatim when state.verbose is true")
    func testVerbose_vprint_emits() async throws {
        let (buffer, sink) = makeCapture()
        let state = RuntimeState(verbose: true)
        let runtime = RuntimeHelpers(state: state, vprintSink: sink)

        await runtime.vprint("verbose line 1")
        await runtime.vprint("verbose line 2")
        try await Task.sleep(nanoseconds: 1_000_000)
        let snapshot = buffer.snapshot()
        #expect(snapshot.count == 2)
        #expect(snapshot[0] == "verbose line 1")
        #expect(snapshot[1] == "verbose line 2")
    }

    // MARK: - Test 5: dprint is silent when debug=false

    @Test("dprint is silent when state.debug is false")
    func testDebug_dprint_silent() async throws {
        let (buffer, sink) = makeCapture()
        let state = RuntimeState(debug: false)
        let runtime = RuntimeHelpers(state: state, dprintSink: sink)

        await runtime.dprint("debug (should not appear)")
        try await Task.sleep(nanoseconds: 1_000_000)
        #expect(buffer.snapshot().isEmpty)
    }

    // MARK: - Test 6: dprint emits when debug=true

    @Test("dprint emits the message verbatim when state.debug is true")
    func testDebug_dprint_emits() async throws {
        let (buffer, sink) = makeCapture()
        let state = RuntimeState(debug: true)
        let runtime = RuntimeHelpers(state: state, dprintSink: sink)

        await runtime.dprint("debug line 1")
        await runtime.dprint("debug line 2")
        await runtime.dprint("debug line 3")
        try await Task.sleep(nanoseconds: 1_000_000)
        let snapshot = buffer.snapshot()
        #expect(snapshot.count == 3)
        #expect(snapshot[0] == "debug line 1")
        #expect(snapshot[2] == "debug line 3")
    }

    // MARK: - Test 7: credential chain — env var tier

    @Test("resolveCredential returns env-var value when WENSHU_<SLUG>_API_KEY is set")
    func testResolveCredential_envVar() async throws {
        // Inject env vars (= the only writable tier for the test; the
        // keychain + system-default tiers are stubbed to return nil so the
        // env tier is the only path that can produce a value).
        let slug = "anthropic"
        let expected = "env-var-key-12345"
        setenv("WENSHU_ANTHROPIC_API_KEY", expected, 1)

        defer { unsetenv("WENSHU_ANTHROPIC_API_KEY") }

        let runtime = RuntimeHelpers(
            state: .init(),
            keychainResolver: { _ in nil },
            systemDefaultResolver: { _ in nil }
        )

        let resolved = try await runtime.resolveCredential(for: slug)
        #expect(resolved == expected)
    }

    // MARK: - Test 8: credential chain — keychain tier (env var unset)

    @Test("resolveCredential falls through to keychain tier when env var is unset")
    func testResolveCredential_keychain() async throws {
        let slug = "openai"
        // Ensure env var is unset (= no leakage from a prior test).
        unsetenv("WENSHU_OPENAI_API_KEY")
        let keychainValue = "keychain-stored-key-67890"

        let runtime = RuntimeHelpers(
            state: .init(),
            keychainResolver: { resolvedSlug in
                resolvedSlug == slug ? keychainValue : nil
            },
            systemDefaultResolver: { _ in nil }
        )

        let resolved = try await runtime.resolveCredential(for: slug)
        #expect(resolved == keychainValue)
    }

    // MARK: - Bonus assertions (not in the 8 required, but useful for completeness)

    @Test("envVarName uppercases the slug and applies the prefix")
    func testEnvVarName() async throws {
        let runtime = RuntimeHelpers(envPrefix: "WENSHU")
        let name = await runtime.envVarName(for: "minimax-cn")
        #expect(name == "WENSHU_MINIMAX_CN_API_KEY")
    }

    @Test("resolveCredential returns nil when no tier produces a value")
    func testResolveCredential_allNil() async throws {
        unsetenv("WENSHU_UNKNOWN_PROVIDER_API_KEY")
        let runtime = RuntimeHelpers(
            state: .init(),
            keychainResolver: { _ in nil },
            systemDefaultResolver: { _ in nil }
        )
        let resolved = try await runtime.resolveCredential(for: "unknown-provider")
        #expect(resolved == nil)
    }
}