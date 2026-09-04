//
//  RuntimeHelpers.swift · Wenshu · TICKET-HERMES-GAP-003
//
//  Swift port of `agent_runtime_helpers.py` from `/Volumes/ANAN/.hermes/agent/`
//  (= hermes' AIAgent runtime state dict = verbose / debug / sandbox / mock-time
//  flags + credential resolution chain). Wenshu previously had no equivalent
//  surface — any code path wanting deterministic-test injection of "now" (= the
//  hermes-port Z-contract hard requirement per v0.36 ticket 014) had to reach
//  into ProcessInfo or fake Date via subclassing. This module centralizes
//  that state into a single Sendable, actor-isolated value that any consumer
//  (ConversationLoop, ContextCompressor, TurnRetryState, future modules) can
//  hold via dependency injection.
//
//  Hermes correspondence (3,209 LOC Python file, only the mock-time + verbose/
//  debug + credential-chain subset is ported here; the rest = message-format
//  conversions / credential-pool rotation / signal handlers / subprocess
//  management — out of scope per the GAP-003 ticket body):
//    - `time.time()` / `datetime.now()` -> `RuntimeHelpers.now()`
//    - `agent._vprint(...)` -> `RuntimeHelpers.vprint(_:)`
//    - `agent.verbose_logging` -> `RuntimeState.verbose`
//    - `agent.debug` (logger.debug) -> `RuntimeHelpers.dprint(_:)`
//    - `env_var_enabled(...)` + credential_pool + `os.environ[...]` -> `RuntimeHelpers.resolveCredential(for:)`
//
//  Skipped (= per ticket GAP-003 spec):
//    - `register_signal_handlers` — wenshu uses Cocoa run loop, not Python signals.
//    - `subprocess_management` — out of scope; wenshu is single-process.
//
//  Invariants (AGENTS.md §11 + wenshu-port Z-contract):
//    1. No global singleton. Every consumer takes `RuntimeHelpers` via init
//       injection so tests can inject a stub with `mockTime` / `verbose`.
//    2. `state.mockTime` is the ONLY source of mock time. No `Date()` calls
//       in any consumer that has a `RuntimeHelpers` reference.
//    3. Credential resolution chain order = env var → keychain → system default.
//       The chain is provider-scoped (= per `providerSlug`); env var name
//       convention = `WENSHU_<UPPER_SLUG>_API_KEY` (mirrors the existing
//       `WENSHU_DEBUG_INMEMORY_KEYCHAIN` convention from App.swift).
//    4. Sendable / actor-isolated. `RuntimeState` is a value type so it
//       crosses actor boundaries without locking.
//
//  Public API:
//
//      public actor RuntimeHelpers { ... }
//      public struct RuntimeState: Sendable, Equatable { ... }
//
//  Test surface (Tests/WenshuAppTests/Agent/Runtime/RuntimeHelpersTests.swift):
//    8 round-trip tests covering mock-time, verbose flag, debug flag, and
//    credential resolution (env var + keychain paths).

import Foundation
import os

/// Runtime state snapshot. Pass-by-value across actor boundaries under
/// Swift 6 strict concurrency (= the struct is `Sendable` and the
/// `RuntimeHelpers` actor only exposes its `state` as a let constant;
/// mutations go through dedicated setters that return a NEW `RuntimeState`,
/// preserving actor isolation without needing locks on read).
public struct RuntimeState: Sendable, Equatable {

    /// Emit verbose agent log lines (= hermes `agent.verbose_logging`).
    /// Drives `RuntimeHelpers.vprint(_:)` output.
    public var verbose: Bool

    /// Emit debug log lines (= hermes `logger.debug(...)`).
    /// Drives `RuntimeHelpers.dprint(_:)` output. Off by default; intended
    /// for development builds and `TestRunnerHooks` debug toggles.
    public var debug: Bool

    /// Sandbox flag (= hermes `agent.sandbox`). Off by default. Consumers
    /// (ToolExecutor, FileTools) gate destructive ops behind this. The
    /// flag itself does nothing in this module; it is plumbed here so
    /// downstream code has a single source of truth for runtime mode.
    public var sandbox: Bool

    /// Mock-time injection point. When set, `RuntimeHelpers.now()` returns
    /// this value instead of `Date()`. Required for hermes-port Z-contract
    /// tests that need deterministic timestamps in conversation transcripts,
    /// rate-limit reset windows, and trajectory dumps (= v0.36 ticket 014).
    public var mockTime: Date?

    /// Active runtime profile override (= hermes `agent.profile_override`).
    /// When non-nil, downstream code should treat this profile as canonical
    /// regardless of which profile the active LLMConnector is bound to.
    public var profileOverride: String?

    /// Per-runtime trace identifier (= hermes `agent.trace_id`). Auto-generated
    /// as a UUID string on init; callers can override for distributed-tracing
    /// correlation. Surfaces in API request dumps and trajectory filenames.
    public var traceId: String

    public init(
        verbose: Bool = false,
        debug: Bool = false,
        sandbox: Bool = false,
        mockTime: Date? = nil,
        profileOverride: String? = nil,
        traceId: String = UUID().uuidString
    ) {
        self.verbose = verbose
        self.debug = debug
        self.sandbox = sandbox
        self.mockTime = mockTime
        self.profileOverride = profileOverride
        self.traceId = traceId
    }
}

/// Error thrown by `RuntimeHelpers.resolveCredential(for:)` when the chain
/// fails to produce a credential. Distinct from a `nil` return (= which means
/// "the chain resolved cleanly but no credential exists for this provider
/// in any backend"); thrown errors mean the chain itself errored.
public enum RuntimeCredentialError: Error, LocalizedError, Equatable {
    case noBackendAvailable(providerSlug: String)

    public var errorDescription: String? {
        switch self {
        case .noBackendAvailable(let slug):
            return "Runtime credential resolution failed: no backend available for provider '\(slug)'"
        }
    }
}

/// Runtime helper actor — owns the runtime state dict for one agent session.
///
/// One `RuntimeHelpers` instance per `ConversationLoop` (= per spec ticket
/// GAP-003 wiring). State is mutable through dedicated actor-isolated setters
/// that return a fresh `RuntimeState` value, so reads from other actors get
/// a stable snapshot.
///
/// Why an actor (not a struct):
/// - `now()` is async-safe (= tests want to call it from a `@Test` async context
///   without races on the wall-clock read).
/// - `resolveCredential` needs async I/O (= keychain via `ProviderKeychain`
///   backend which can do synchronous Security framework calls today but the
///   async signature future-proofs it for the `SecItemAdd` async path).
/// - Verbose / debug flag flips during a test run shouldn't race with the
///   emit functions; actor isolation gives us that for free.
public actor RuntimeHelpers {

    /// Current state. Reads are cheap (= the actor hops, but the value is
    /// a small struct). Mutators return a new `RuntimeHelpers` with the
    /// updated state (= functional-style update; preserves isolation).
    public let initialState: RuntimeState

    /// Provider-scoped environment-variable prefix. The full var name is
    /// `<envPrefix>_<UPPER_SNAKE_SLUG>_API_KEY` (= e.g. `WENSHU_ANTHROPIC_API_KEY`,
    /// `WENSHU_OPENAI_API_KEY`). Mirrors the wenshu-wide convention from
    /// `App.swift` (= `WS_SCREENSHOT_PATH`, `WENSHU_DEBUG_INMEMORY_KEYCHAIN`).
    public let envPrefix: String

    /// Test seam: a closure that resolves the "keychain" tier. Production
    /// code uses the default which calls `ProviderKeychain.loadKeySync(for:)`
    /// (= the wenshu Keychain facade). Tests override to inject a fake
    /// backend without touching Security framework.
    public typealias KeychainResolver = @Sendable (String) -> String?

    private let keychainResolver: KeychainResolver

    /// Test seam: a closure that resolves the "system default" tier. The
    /// lowest-priority fallback (= typically empty on macOS). Tests override
    /// to inject a deterministic default.
    public typealias SystemDefaultResolver = @Sendable (String) -> String?

    private let systemDefaultResolver: SystemDefaultResolver

    /// Test seam: a closure that captures `vprint`/`dprint` output. Production
    /// default writes to `os.Logger`. Tests override to capture into a buffer
    /// for assertion (= the `testVerbose_vprint_emits` / `testDebug_dprint_emits`
    /// cases capture stdout via this seam).
    public typealias OutputSink = @Sendable (String) -> Void

    private let vprintSink: OutputSink
    private let dprintSink: OutputSink

    public init(
        state: RuntimeState = .init(),
        envPrefix: String = "WENSHU",
        keychainResolver: @escaping KeychainResolver = RuntimeHelpers.defaultKeychainResolver,
        systemDefaultResolver: @escaping SystemDefaultResolver = RuntimeHelpers.defaultSystemDefaultResolver,
        vprintSink: @escaping OutputSink = RuntimeHelpers.defaultVPrintSink,
        dprintSink: @escaping OutputSink = RuntimeHelpers.defaultDPrintSink
    ) {
        self.initialState = state
        self.envPrefix = envPrefix
        self.keychainResolver = keychainResolver
        self.systemDefaultResolver = systemDefaultResolver
        self.vprintSink = vprintSink
        self.dprintSink = dprintSink
    }

    // MARK: - Mock-time

    /// Current time according to the runtime. When `state.mockTime` is set,
    /// returns that exact value (= hermes-port Z-contract hard requirement
    /// for deterministic test paths). Otherwise returns `Date()` (= wall-clock).
    ///
    /// Use this in place of literal `Date()` calls anywhere the runtime is
    /// available — see `ConversationLoop.swift` for the wire-up.
    public func now() -> Date {
        initialState.mockTime ?? Date()
    }

    /// Returns a fresh `RuntimeHelpers` with the given mock-time. The actor
    /// state is immutable from the outside (= this returns a new instance
    /// rather than mutating in place) so consumers that hold a reference
    /// keep their original behavior unless they explicitly swap.
    public func withMockTime(_ date: Date?) -> RuntimeHelpers {
        var newState = initialState
        newState.mockTime = date
        return RuntimeHelpers(
            state: newState,
            envPrefix: envPrefix,
            keychainResolver: keychainResolver,
            systemDefaultResolver: systemDefaultResolver,
            vprintSink: vprintSink,
            dprintSink: dprintSink
        )
    }

    // MARK: - Verbose / debug emission

    /// Emit a verbose log line when `state.verbose == true`; silent otherwise.
    /// Mirrors hermes `agent._vprint(...)` (= the gated print helper on the
    /// AIAgent class).
    public func vprint(_ message: String) {
        guard initialState.verbose else { return }
        vprintSink(message)
    }

    /// Emit a debug log line when `state.debug == true`; silent otherwise.
    /// Mirrors hermes `logger.debug(...)` (= the standard library logging
    /// debug helper, gated here so consumers don't need to import a logger
    /// surface and so the flag is testable in isolation).
    public func dprint(_ message: String) {
        guard initialState.debug else { return }
        dprintSink(message)
    }

    // MARK: - Credential resolution chain

    /// Resolve a credential for `providerSlug` using the 3-tier chain:
    ///
    ///     1. Environment variable   (`<envPrefix>_<UPPER_SLUG>_API_KEY`)
    ///     2. Keychain backend       (via `keychainResolver`)
    ///     3. System default backend (via `systemDefaultResolver`)
    ///
    /// Returns the first non-nil value found; returns `nil` (= distinct
    /// from throwing) when every tier returned `nil`. Throws only when
    /// the chain itself errored (= e.g. a backend raised — currently no
    /// production backend does, but the future async `SecItemAdd` path may).
    ///
    /// - Parameter providerSlug: The provider slug (= e.g. `"anthropic"`,
    ///   `"openai"`, `"minimax-cn"`). Case-insensitive — the slug is
    ///   upper-snake-cased internally for env-var name construction.
    public func resolveCredential(for providerSlug: String) throws -> String? {
        // Tier 1: environment variable.
        if let envValue = readEnvCredential(for: providerSlug) {
            return envValue
        }
        // Tier 2: keychain.
        if let keychainValue = keychainResolver(providerSlug) {
            return keychainValue
        }
        // Tier 3: system default.
        return systemDefaultResolver(providerSlug)
    }

    /// Construct the env-var name for a given slug. Exposed (internal) so
    /// tests can assert the exact name without exercising the chain.
    public func envVarName(for providerSlug: String) -> String {
        let upper = providerSlug
            .uppercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return "\(envPrefix)_\(upper)_API_KEY"
    }

    // MARK: - Private helpers

    private func readEnvCredential(for providerSlug: String) -> String? {
        let name = envVarName(for: providerSlug)
        // Treat empty / whitespace-only as unset (mirrors hermes'
        // `env_var_enabled` semantics: "enabled" = non-empty after strip).
        guard let raw = ProcessInfo.processInfo.environment[name] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Default backend closures

    /// Production default for the keychain tier. Defers to
    /// `ProviderKeychain.loadKeySync(for:)` which already routes through
    /// the active `Storing` backend (= Apple Keychain in prod, InMemory
    /// under `WENSHU_DEBUG_INMEMORY_KEYCHAIN=1`, or test-injected backend).
    ///
    /// The slug is resolved against the existing `Provider.by(slug:)` catalog
    /// (defined in `Core/Provider/Provider.swift`); an unknown slug returns
    /// nil (= the chain falls through to the system default tier).
    public static let defaultKeychainResolver: KeychainResolver = { slug in
        guard let provider = Provider.by(slug: slug) else { return nil }
        return ProviderKeychain.loadKeySync(for: provider)
    }

    /// Production default for the system-default tier. Returns nil on macOS
    /// (= no system-level credential store ships by default; macOS Keychain
    /// IS the system store, which we already covered in tier 2). Pluggable so
    /// future builds can add a Netrc / config-file fallback.
    public static let defaultSystemDefaultResolver: SystemDefaultResolver = { _ in
        nil
    }

    /// Production sink for `vprint`. Routes to `os.Logger` at `.info` level
    /// under the "org.wenshu.runtime" subsystem (= visible in Console.app
    /// under the wenshu bundle). Mirrors the existing `apple/swift-log`
    /// integration that `App.swift` wires for telemetry.
    public static let defaultVPrintSink: OutputSink = { message in
        let logger = Logger(subsystem: "org.wenshu.runtime", category: "vprint")
        logger.info("\(message, privacy: .public)")
    }

    /// Production sink for `dprint`. Routes to `os.Logger` at `.debug` level
    /// under "org.wenshu.runtime". `.debug` is stripped from release builds
    /// by `os.Logger`'s privacy-aware filtering (= opt-in via
    /// `OS_ACTIVITY_MODE`); test builds see it.
    public static let defaultDPrintSink: OutputSink = { message in
        let logger = Logger(subsystem: "org.wenshu.runtime", category: "dprint")
        logger.debug("\(message, privacy: .public)")
    }
}

// NOTE: There is already a `public struct Provider` in
// `Core/Provider/Provider.swift` (= the wenshu provider catalog with a
// `by(slug:)` lookup). RuntimeHelpers uses that existing type directly
// rather than defining a parallel enum. This avoids a duplicate-symbol
// collision and keeps the dep edge narrow (= RuntimeHelpers only needs
// the catalog's slug→Provider lookup, not the rest of the Provider API
// surface).
