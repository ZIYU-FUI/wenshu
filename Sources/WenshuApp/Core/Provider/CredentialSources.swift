//
//  CredentialSources.swift · Wenshu · P1-CREDENTIAL-SOURCES-HERMES-PORT (2026-09-19)
//
//  Unified removal contract for every credential source wenshu
//  reads from. Faithful 1:1 port of hermes
//  `agent/credential_sources.py` (250+ LOC Python).
//
//  Per AGENTS.md §11.3 wenshu-side wins:
//
//  Hermes seeds its credential pool from many places (= env vars /
//  ~/.hermes/.env / claude Code ~/.claude/.credentials.json /
//  ~/.hermes/.anthropic_oauth.json / qwen-cli / gh-cli / etc.).
//  Each source has its own reader and removal logic. The hermes
//  `credential_sources.py` module unifies REMOVAL via a registry
//  pattern: each source registers a `RemovalStep` (= provider +
//  source_id + remove_fn + match_fn + description) that the
//  `auth remove` command dispatches to.
//
//  Wenshu-side wins per AGENTS.md §11.3:
//  - ProviderKeychain owns the credential storage layer (= macOS
//    Keychain per AGENTS.md §11 "API keys via AppleKeychain NEVER
//    plaintext SQLite"). The registry pattern from hermes is
//    ported as a thin layer that delegates removal to
//    ProviderKeychain's remove + clears the corresponding env var
//    shell hint per hermes's `_remove_env_source` pattern.
//  - The hermes env-var sourcing from ~/.hermes/.env maps to
//    wenshu's `.ws` bundle's `Info.plist` provider config (= per
//    AGENTS.md §11 .ws bundle convention).
//  - The claude Code / gh-cli / qwen-cli sources are hermes-
//    specific tooling sources (= wenshu is single-process macOS
//    app with no CLI integration); = these are documented as
//    out-of-scope per wenshu-side-wins.
//
//  Public API surface (= hermes `credential_sources.py` registry
//  pattern):
//  - RemovalResult struct (= cleaned + hints + suppress)
//  - RemovalStep struct (= provider + sourceID + matchFn + removeFn
//    + description + matches(_:_:))
//  - register(_:) static func (add to registry)
//  - findRemovalStep(provider:source:) static func (lookup)
//  - removeAll() static func (test reset)
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only. No
//  third-party imports.
//

import Foundation

// MARK: - RemovalResult

/// Outcome of removing a credential source (= hermes
/// `RemovalResult` dataclass at
/// `agent/credential_sources.py` L57-L83).
///
/// - `cleaned`: Short strings describing external state that was
///   actually mutated (= "Cleared XAI_API_KEY from .env",
///   "Cleared openai-codex OAuth tokens from auth store").
///   Printed as plain lines to the user (= wenshu Settings →
///   LLM Connector → Remove flow).
/// - `hints`: Diagnostic lines ABOUT state the user may need to
///   clean up themselves (= shell-exported env vars, external
///   credential files we deliberately don't delete). Always
///   non-destructive.
/// - `suppress`: Whether to call `suppressCredentialSource` after
///   cleanup so future `loadPool` calls skip this source. Default
///   true (= almost every source needs this to stay sticky).
public struct RemovalResult: Sendable {
    public var cleaned: [String]
    public var hints: [String]
    public var suppress: Bool

    public init(
        cleaned: [String] = [],
        hints: [String] = [],
        suppress: Bool = true
    ) {
        self.cleaned = cleaned
        self.hints = hints
        self.suppress = suppress
    }

    public static let identity = RemovalResult()
}

// MARK: - RemovalStep

/// How to remove one specific credential source cleanly (= hermes
/// `RemovalStep` dataclass at
/// `agent/credential_sources.py` L87-L107).
///
/// - `provider`: Provider pool key ("xai", "anthropic", "nous", etc.).
///   Special value `"*"` means "matches any provider" (= used for
///   sources like `manual` that aren't provider-specific).
/// - `sourceID`: Source identifier as it appears in the pooled
///   credential's source. May be a literal ("claude_code") or a
///   prefix pattern matched via `matchFn`.
/// - `matchFn`: Optional predicate overriding literal `sourceID`
///   matching. Gets the removed entry's source string. Used for
///   `env:*` (any env-seeded key), `config:*` (any custom pool),
///   and `manual:*` (any manual-source variant).
/// - `removeFn`: `(provider, removedEntry) -> RemovalResult`.
///   Does the actual cleanup and returns what happened for the
///   user.
/// - `description`: One-line human-readable description for docs /
///   tests.
public struct RemovalStep: Sendable {
    public let provider: String
    public let sourceID: String
    public let removeFn: @Sendable (String, RemovedEntry) -> RemovalResult
    public let matchFn: (@Sendable (String) -> Bool)?
    public let description: String

    public init(
        provider: String,
        sourceID: String,
        removeFn: @escaping @Sendable (String, RemovedEntry) -> RemovalResult,
        matchFn: (@Sendable (String) -> Bool)? = nil,
        description: String = ""
    ) {
        self.provider = provider
        self.sourceID = sourceID
        self.removeFn = removeFn
        self.matchFn = matchFn
        self.description = description
    }

    /// Return true when this step matches the (provider, source)
    /// pair (= hermes `RemovalStep.matches` at
    /// `agent/credential_sources.py` L107-L113).
    public func matches(provider: String, source: String) -> Bool {
        if provider != "*" && provider != provider {
            return false
        }
        if let matchFn = matchFn {
            return matchFn(source)
        }
        return source == sourceID
    }
}

// MARK: - RemovedEntry

/// A removed credential entry (= hermes `removed` parameter
/// passed to `remove_fn`).
///
/// Wenshu-side wins: hermes passes the removed PooledCredential
/// dataclass object; wenshu uses a struct that mirrors the same
/// shape (= provider + source + value).
public struct RemovedEntry: Sendable {
    public let provider: String
    public let source: String
    public let value: String

    public init(provider: String, source: String, value: String) {
        self.provider = provider
        self.source = source
        self.value = value
    }
}

// MARK: - Registry

/// Global registry of removal steps (= hermes `_REGISTRY` at
/// `agent/credential_sources.py` L116).
public enum CredentialSources {

    /// Process-global registry. Tests can call `removeAll()` to
    /// reset state between cases.
    nonisolated(unsafe) private static var _registry: [RemovalStep] = []
    nonisolated(unsafe) private static var _initialized: Bool = false
    private static let lock = NSLock()

    /// Add a step to the registry (= hermes `register` at
    /// `agent/credential_sources.py` L119-L122).
    @discardableResult
    public static func register(_ step: RemovalStep) -> RemovalStep {
        lock.lock()
        defer { lock.unlock() }
        _registry.append(step)
        return step
    }

    /// Return the first matching step, or nil if unregistered
    /// (= hermes `find_removal_step` at
    /// `agent/credential_sources.py` L125-L135).
    public static func findRemovalStep(provider: String, source: String) -> RemovalStep? {
        lock.lock()
        defer { lock.unlock() }
        return _registry.first { $0.matches(provider: provider, source: source) }
    }

    /// All registered steps (= hermes `_REGISTRY` direct access,
    /// exposed for the Settings UI).
    public static func all() -> [RemovalStep] {
        lock.lock()
        defer { lock.unlock() }
        return _registry
    }

    /// Remove all registered steps (= hermes `reset_for_tests`
    /// pattern at `agent/credential_sources.py` L298-L303).
    public static func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        _registry.removeAll()
    }
}

// MARK: - Suppression tracking

/// Tracks per-source suppressions (= hermes
/// `is_source_suppressed` / `suppress_credential_source` pattern).
///
/// When a credential source is removed and `RemovalResult.suppress`
/// is true, the (provider, sourceID) pair is added to this set so
/// future `loadPool()` calls skip the source.
public enum CredentialSourceSuppression {
    nonisolated(unsafe) private static var _suppressed: Set<String> = []
    private static let lock = NSLock()

    /// Key format = "\(provider):\(sourceID)" (= hermes pattern).
    private static func key(provider: String, sourceID: String) -> String {
        "\(provider):\(sourceID)"
    }

    public static func isSuppressed(provider: String, sourceID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _suppressed.contains(key(provider: provider, sourceID: sourceID))
    }

    public static func suppress(provider: String, sourceID: String) {
        lock.lock()
        defer { lock.unlock() }
        _suppressed.insert(key(provider: provider, sourceID: sourceID))
    }

    public static func unsuppress(provider: String, sourceID: String) {
        lock.lock()
        defer { lock.unlock() }
        _suppressed.remove(key(provider: provider, sourceID: sourceID))
    }

    public static func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        _suppressed.removeAll()
    }
}
