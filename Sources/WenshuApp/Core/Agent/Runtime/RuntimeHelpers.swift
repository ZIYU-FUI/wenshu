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

// v0.72 SwiftData migration: this file uses ProviderKeychain for metadata read/write.
// Migration to WSProviderKeyRepository is deferred (per AGENTS.md §11 AppleKeychain
// contract; = metadata is the only sqlite piece in this path). Future ticket.
#warning("wenshu.RuntimeHelpers: ProviderKeychain metadata is sqlite-backed; = migrate to WSProviderKeyRepository in future ticket")

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

// MARK: - H6 Hermes-Python gap port (= 1:1 port of hermes
//         `agent/agent_runtime_helpers.py` `strip_think_blocks`).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/agent_runtime_helpers.py` per spec
// §3.1 #31 (= TICKET-HERMES-GAP-003 follow-up). The target file
// already existed at 331 LOC (= ⚠️ partial per gap audit 2026-09-04
// = wenshu-side wins = the time / verbose / debug / credential
// subset). This H6 ticket adds the hermes `strip_think_blocks`
// pure helper (= 97 LOC Python at L600-L696) which strips
// reasoning/thinking blocks from content.
//
// The remaining 28 hermes functions in agent_runtime_helpers.py
// (= message-format conversions / credential-pool rotation /
// signal handlers / subprocess management / message-sequence
// repair / trajectory conversion / etc.) are intentionally NOT
// ported in this ticket — they fall into separate wenshu-side
// wins patterns (= ConversationLoop / WenshuConductor /
// PromptCaching own the message-sequence + credential-pool
// concerns; = per Q112 = one ticket per file).
//
// Hermes Python line range cited in doc-comment below (= for
// traceability back to `/Volumes/ANAN/.hermes/agent/
// agent_runtime_helpers.py`).
//
// Per AGENTS.md §11.3 wenshu-side wins:
//   - hermes takes `agent` as first arg (= 5 of 28 hermes
//     functions are method-shaped; = the agent is needed only
//     for log routing + `_get_tool_call_id_static`). The
//     wenshu-side `stripThinkBlocks(_:)` is a pure static
//     function on `RuntimeHelpers` (= no agent dependency;
//     = testable in isolation; = matches hermes's
//     "static helpers" prefix in the file header docstring).
//   - Logger output routes to `os_log` (= Apple system log)
//     via Apple's `Logger` (= the pre-existing wenshu pattern
//     in `RuntimeHelpers.dprint`).
//   - The 5 hermes reasoning tag variants (= `<think>` /
//     `<thinking>` / `<reasoning>` / `<REASONING_SCRATCHPAD>` /
//     `<thought>`) are preserved 1:1 (= wenshu uses Apple HIG
//     tag rendering, = hermes-style raw HTML/XML strips out
//     before rendering).

extension RuntimeHelpers {

    /// Pure-function: strip reasoning/thinking blocks from
    /// content, returning only visible text (= hermes
    /// `strip_think_blocks` at `agent/agent_runtime_helpers.py`
    /// L600-L696).
    ///
    /// Handles 4 cases:
    ///   1. Closed tag pairs (= `<think>…</think>`).
    ///   2. Unterminated open tag at a block boundary (= fixes
    ///      the MiniMax M2.7 / NIM endpoints where the closing
    ///      tag is dropped).
    ///   3. Stray orphan open/close tags that slip through.
    ///   4. Tag variants: `<think>` / `<thinking>` /
    ///      `<reasoning>` / `<REASONING_SCRATCHPAD>` /
    ///      `<thought>` (= Gemma 4), all case-insensitive.
    ///
    /// Additionally strips standalone tool-call XML blocks that
    /// some open models emit inside assistant content (= ported
    /// from openclaw/openclaw#67318):
    ///   * `<tool_call>…</tool_call>`
    ///   * `<tool_calls>…</tool_calls>`
    ///   * `<tool_result>…</tool_result>`
    ///   * `<function_call>…</function_call>`
    ///   * `<function_calls>…</function_calls>`
    ///   * `<function name="…">…</function>` (= Gemma style)
    public static func stripThinkBlocks(_ content: String) -> String {
        guard !content.isEmpty else { return "" }

        var result = content

        // 1. Closed tag pairs (= case-insensitive).
        let closedPatterns = [
            "<think>", "</think>",
            "<thinking>", "</thinking>",
            "<reasoning>", "</reasoning>",
            "<REASONING_SCRATCHPAD>", "</REASONING_SCRATCHPAD>",
            "<thought>", "</thought>",
        ]
        for tag in closedPatterns {
            // Find balanced open/close tag pairs for this tag.
            // Use NSRegularExpression to handle DOTALL.
            let openTag = tag
            let closeTag: String
            if tag.hasPrefix("</") {
                closeTag = tag
                // Skip orphan close tags in this loop (= handled in #3).
                continue
            } else {
                closeTag = "</" + String(tag.dropFirst().dropLast()) + ">"
            }
            // Escape for regex
            let escapedOpen = NSRegularExpression.escapedPattern(for: openTag)
            let escapedClose = NSRegularExpression.escapedPattern(for: closeTag)
            let pattern = "\(escapedOpen).*?\(escapedClose)"
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.dotMatchesLineSeparators, .caseInsensitive]
            ) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }

        // 1b. Tool-call XML blocks (= openclaw/openclaw#67318).
        let toolCallTags = [
            "tool_call", "tool_calls", "tool_result",
            "function_call", "function_calls",
        ]
        for tag in toolCallTags {
            let escaped = NSRegularExpression.escapedPattern(for: tag)
            let pattern = "<\(escaped)\\b[^>]*>.*?</\(escaped)>"
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.dotMatchesLineSeparators, .caseInsensitive]
            ) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }

        // 1c. <function name="...">...</function> (= Gemma-style
        //     standalone tool call). Only strip when the tag sits
        //     at a block boundary AND carries a name="..." attribute.
        if let regex = try? NSRegularExpression(
            pattern: "(?:(?<=^)|(?<=[\\n\\r.!?:]))[ \\t]*"
                + "<function\\b[^>]*\\bname\\s*=[^>]*>"
                + "(?:(?:(?!</function>).)*)</function>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // 2. Unterminated reasoning block (= open tag at a block
        //    boundary with no matching close). Strip from tag to end
        //    of string.
        if let regex = try? NSRegularExpression(
            pattern: "(?:^|\\n)[ \\t]*"
                + "<(?:think|thinking|reasoning|thought|REASONING_SCRATCHPAD)\\b[^>]*>.*$",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // 3a. Orphan-tag-with-content stripper (= tests like
        //     `stripsStrayOrphanTags` expect the parser to drop
        //     "</tag>...content...</tag>" pairs even when the
        //     input is a stray close tag with no preceding open tag).
        //     Without this pass, prose between two orphan close tags
        //     would survive in the output (= leaks internal reasoning).
        //     NOTE: this runs BEFORE the bare-tag stripper (#3) so
        //     the paired close-close case (= </tag>...</tag>) is
        //     recognized before the individual </tag> tags are dropped.
        let orphanTags = ["think", "thinking", "reasoning", "thought", "REASONING_SCRATCHPAD"]
        for tagName in orphanTags {
            let escaped = NSRegularExpression.escapedPattern(for: tagName)
            let pattern = "</?\(escaped)\\b[^>]*>(?:(?!</?\(escaped)\\b)[\\s\\S])*</?\(escaped)\\b[^>]*>"
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.dotMatchesLineSeparators, .caseInsensitive]
            ) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }

        // 3. Stray orphan open/close tags.
        if let regex = try? NSRegularExpression(
            pattern: "</?(?:think|thinking|reasoning|thought|REASONING_SCRATCHPAD)>\\s*",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // 3b. Stray tool-call closers (= not bare <function> close,
        //     which we keep for streaming safety per OpenClaw pattern).
        if let regex = try? NSRegularExpression(
            pattern: "</(?:tool_call|tool_calls|tool_result|function_call|function_calls|function)>\\s*",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        return result
    }
}
