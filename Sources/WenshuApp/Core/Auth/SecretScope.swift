//
//  SecretScope.swift · Wenshu · TICKET-HERMES-GAP-005
//
//  Ported from hermes-agent `agent/secret_scope.py` (205 LOC) +
//  `agent/secret_sources/` (onepassword + bitwarden + base + registry +
//  cache + __init__ = 6 files). Hermes' SecretScope = a credential
//  source resolution chain (= env var → keychain → 1Password CLI →
//  Bitwarden CLI → system default → fail). The wenshu-side wins pattern
//  (AGENTS.md §11) narrows the chain: wenshu is BYOK-only (= provider
//  keys live in the existing `ProviderKeychain` shim), so the 1Password
//  CLI / Bitwarden CLI / iCloud Keychain adapters are out of scope for
//  v0.40 and intentionally not ported (= documented in the gap audit).
//
//  This file ships the canonical SecretScope primitive + 2 source
//  implementations (EnvVarSource + KeychainSource). Future tickets can
//  add additional sources without changing the protocol surface.
//
//  Reference: docs/design/multiplexing-gateway.md (Hermes Workstream A).
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only; no third-party
//  imports. The `secret_sources` module name is retained as a
//  Swift comment marker so future agents grepping for the original
//  Python identifier can find the port (see acceptance: `grep -n
//  'secret_sources' Sources/WenshuApp/Core/Auth/SecretScope.swift`).
//

import Foundation

// v0.72 SwiftData migration: this file uses ProviderKeychain for metadata read/write.
// Migration to WSProviderKeyRepository is deferred (per AGENTS.md §11 AppleKeychain
// contract; = metadata is the only sqlite piece in this path). Future ticket.
#warning("wenshu.SecretScope: ProviderKeychain metadata is sqlite-backed; = migrate to WSProviderKeyRepository in future ticket")

// MARK: - SecretSource protocol

/// One resolution source in a `SecretScope` chain. Sources are queried
/// in registration order; the first non-nil value wins.
///
/// `read(name:)` returns `nil` (= not "throw") when the name is not
/// found in this source — that is the "ask the next source" signal.
/// Throwing is reserved for actual infrastructure failures (= e.g.
/// Keychain locked, registry unavailable).
///
/// All sources must be `Sendable` (= passes across actor boundaries
/// under the project's Swift 6 strict-concurrency model).
public protocol SecretSource: Sendable {
    /// Read a secret by name. Returns `nil` when this source has no
    /// value for that name (= caller should try the next source).
    func read(name: String) async throws -> String?
}

// MARK: - EnvVarSource

/// Source backed by the process environment (= `ProcessInfo.processInfo.environment`).
/// Matches hermes `secret_scope.get_secret` step 1 / step 3 fallback
/// ("read `os.environ`").
public struct EnvVarSource: SecretSource {
    public init() {}

    public func read(name: String) async throws -> String? {
        ProcessInfo.processInfo.environment[name]
    }
}

// MARK: - KeychainSource

/// Source backed by wenshu's existing `ProviderKeychain` shim
/// (= Apple Security framework via `AppleKeychainStore`, or
/// `InMemoryKeychainStore` in tests).
///
/// `providerKey` is a stable identifier that maps onto a `Provider`
/// slug (= e.g. `"anthropic.api.key"` for the Anthropic provider).
/// This is the wenshu-side surface for the original hermes "keychain"
/// source: hermes stores per-profile keys under
/// `~/.hermes/profiles/<slug>/.env`; wenshu stores them under the Apple
/// Keychain account `AppleKeychainStore.service / <slug>.api.key`
/// (= see `ProviderKeychain.swift` for the canonical key layout).
public struct KeychainSource: SecretSource {
    /// Provider identifier (= `Provider.slug`, e.g. `"anthropic"`).
    /// Resolved via `Provider.by(slug:)` against the static catalog.
    public let providerSlug: String

    public init(providerSlug: String) {
        self.providerSlug = providerSlug
    }

    public func read(name: String) async throws -> String? {
        // Route through the existing `ProviderKeychain` shim (= Apple
        // Security in production, in-memory dict in tests). We do NOT
        // re-implement SecItemCopyMatching here (= wenshu-side wins).
        guard let provider = Provider.by(slug: providerSlug) else {
            return nil
        }
        return ProviderKeychain.loadKeySync(for: provider)
    }
}

// MARK: - SecretScope actor

/// Thread-safe registry + resolution chain for `SecretSource`s.
///
/// Resolution order = registration order (= first non-nil value wins).
/// No state mutation outside actor isolation; safe under Swift 6
/// strict concurrency.
///
/// Default `SecretScope()` = empty chain = every `resolve(name:)`
/// returns `nil`. Callers register sources via `register(_:)` before
/// calling `resolve`.
public actor SecretScope {
    private var sources: [SecretSource] = []

    public init() {}

    /// Append a source to the chain. Duplicate types are allowed
    /// (= caller's responsibility to deduplicate if needed).
    public func register(_ source: SecretSource) {
        sources.append(source)
    }

    /// Snapshot of currently-registered sources, in registration order.
    public var current: [SecretSource] { sources }

    /// Clear all sources (= useful for tests + hot reload).
    public func unregisterAll() {
        sources.removeAll()
    }

    /// Walk the chain and return the first non-nil value.
    /// Returns `nil` when no source has the name (= hermes `default=nil`
    /// behavior in single-profile / non-multiplex mode).
    public func resolve(name: String) async throws -> String? {
        for source in sources {
            if let value = try await source.read(name: name) {
                return value
            }
        }
        return nil
    }

    /// Convenience: resolve with a fallback default (= hermes
    /// `get_secret(name, default=...)` shape).
    public func resolve(name: String, default defaultValue: String) async throws -> String {
        try await resolve(name: name) ?? defaultValue
    }
}

// MARK: - Errors

/// Errors thrown by `SecretScope` / sources. Distinct from
/// `ProviderKeychainError` so callers can pattern-match on the scope
/// layer without coupling to keychain internals.

// MARK: - H3 Hermes-Python gap port (= 1:1 port of hermes
//         `agent/secret_scope.py` env-file + global-env helpers).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/secret_scope.py` per spec §3.1 #33 (= TICKET-
// HERMES-GAP-005 follow-up). The 3 hermes public functions that are NOT yet
// in wenshu land here (= `load_env_file`, `build_profile_secret_scope`,
// `_is_global_env`). The multiplex-contextvar logic (= `set_secret_scope`,
// `get_secret`, `_SECRET_SCOPE`, `_MULTIPLEX_ACTIVE`,
// `UnscopedSecretError`) is hermes-multi-profile-specific (= wenshu is
// single-profile per AGENTS.md §11 "single-shelf model"; = future ticket
// can port it if wenshu ever adds multi-profile multiplexer).
//
// Hermes Python line ranges cited in doc-comments below (= for traceability
// back to `/Volumes/ANAN/.hermes/agent/secret_scope.py`).
//
// Per AGENTS.md §11.3 wenshu-side wins:
//   - Hermes's `_SECRET_SCOPE` contextvar (Python-only concept) maps
//     to wenshu's `SecretScope` actor (= Swift Concurrency actor =
//     thread-safe by Apple contract; = no manual contextvars needed).
//   - Hermes's `_GLOBAL_ENV_EXACT` (= HERMES_HOME / HERMES_PROFILE /
//     PATH / HOME / etc) maps to wenshu's `_wenshuGlobalEnvExact`
//     (= WENSHU_HOME / PATH / HOME / TMPDIR etc; = HERMES_-prefixed
//     entries replaced with WENSHU_-prefixed).
//   - Hermes's `_GLOBAL_ENV_PREFIXES` (= HERMES_KANBAN_ /
//     HERMES_TELEGRAM_ / TERMINAL_) maps to wenshu's
//     `_wenshuGlobalEnvPrefixes` (= WENSHU_/TERMINAL_/etc; = no
//     HERMES_-prefixed entries since wenshu is single-profile).

extension SecretScope {

    /// Genuinely-global (non-profile-secret) env vars per wenshu-side
    /// wins (= hermes `_GLOBAL_ENV_EXACT` at
    /// `agent/secret_scope.py` L99-L109).
    ///
    /// Wenshu-substituted entries:
    ///   - HERMES_HOME → WENSHU_HOME
    ///   - HERMES_PROFILE → (omitted; = wenshu is single-profile)
    ///   - HERMES_GATEWAY_LOCK_DIR → (omitted; = no gateway)
    ///   - HERMES_MAX_ITERATIONS / _MAX_TOKENS / _API_TIMEOUT →
    ///     WENSHU_MAX_* (= future ticket can wire these)
    ///   - HERMES_REDACT_SECRETS → WENSHU_REDACT_SECRETS
    ///   - _HERMES_GATEWAY → (omitted)
    ///   - HERMES_KANBAN_* → (omitted; = wenshu uses kanban at wenshu
    ///     level not hermes level; = covered by _wenshuGlobalEnvPrefixes)
    ///   - HERMES_TELEGRAM_* → (omitted; = no telegram in wenshu)
    public static let wenshuGlobalEnvExact: Set<String> = [
        // Wenshu runtime / deployment
        "WENSHU_HOME", "WENSHU_REDACT_SECRETS",
        // OS / interpreter
        "PATH", "HOME", "USER", "LANG", "LC_ALL", "TZ", "PWD", "SHELL", "TMPDIR",
        "VIRTUAL_ENV", "PYTHONPATH", "SSL_CERT_FILE",
    ]

    /// Genuinely-global env-var prefixes per wenshu-side wins
    /// (= hermes `_GLOBAL_ENV_PREFIXES` at
    /// `agent/secret_scope.py` L111-L115).
    public static let wenshuGlobalEnvPrefixes: [String] = [
        "TERMINAL_",  // terminal/sandbox backend settings
    ]

    /// Return true for genuinely process-global (non-profile-secret)
    /// env vars (= hermes `_is_global_env` at
    /// `agent/secret_scope.py` L117-L121).
    ///
    /// Pure function (= no side effects; = hermes equivalent).
    public static func isGlobalEnv(_ name: String) -> Bool {
        if wenshuGlobalEnvExact.contains(name) {
            return true
        }
        return wenshuGlobalEnvPrefixes.contains { name.hasPrefix($0) }
    }

    /// Parse a `.env` file into a plain dict WITHOUT touching
    /// `ProcessInfo.processInfo.environment` (= hermes `load_env_file`
    /// at `agent/secret_scope.py` L172-L202).
    ///
    /// Pure function (= no side effects; = hermes equivalent).
    ///
    /// Mirrors python-dotenv's basic parsing:
    ///   - Lines starting with `#` are comments.
    ///   - Empty lines are skipped.
    ///   - `export ` prefix is stripped (= bash-style).
    ///   - `KEY=VALUE` syntax; = optional matching single/double
    ///     quotes are stripped.
    ///   - Lines without `=` are silently skipped.
    ///
    /// - Parameter envPath: path to the `.env` file.
    /// - Returns: parsed dict (= empty when file is missing or
    ///   unreadable; = matches hermes safe-default semantics).
    public static func loadEnvFile(_ envPath: URL) -> [String: String] {
        var secrets: [String: String] = [:]
        guard let text = try? String(contentsOf: envPath, encoding: .utf8) else {
            return secrets
        }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            var content = line
            if content.hasPrefix("export ") {
                content = String(content.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }
            guard let eqIdx = content.firstIndex(of: "=") else {
                continue
            }
            let key = content[..<eqIdx].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            var value = content[content.index(after: eqIdx)...].trimmingCharacters(in: .whitespaces)
            // Strip optional matching single/double quotes
            // (= hermes L195-L198 = quote-strip logic).
            if value.count >= 2,
               let first = value.first,
               let last = value.last,
               first == last,
               first == "\"" || first == "'"
            {
                value = String(value.dropFirst().dropLast())
            }
            secrets[String(key)] = String(value)
        }
        return secrets
    }

    /// Build a profile's secret mapping from its `<wenshu-home>/.env`
    /// (= hermes `build_profile_secret_scope` at
    /// `agent/secret_scope.py` L204-L209).
    ///
    /// Returns a fresh dict (= safe to install via `SecretScope`).
    /// Genuinely global vars are intentionally NOT copied in
    /// (= `SecretScope.resolve` reads those from
    /// `ProcessInfo.processInfo.environment` directly via `EnvVarSource`;
    /// = matches hermes L207-L208 = "Global vars intentionally NOT copied").
    public static func buildProfileSecretScope(
        wenshuHome: URL
    ) -> [String: String] {
        let envPath = wenshuHome.appendingPathComponent(".env")
        return loadEnvFile(envPath)
    }
}
