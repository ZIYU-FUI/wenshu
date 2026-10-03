//
//  UserDefaultsStore.swift · Wenshu
//
//  Typed accessor over `UserDefaults.standard` (= Apple-recommended
//  backing for scalar settings; = bridges wenshu's @Observable models
//  where `@AppStorage` (= SwiftUI-view-bound) does not apply).
//
//  Per docs/adr/0014 Rule G-2:
//  - canonical SwiftUI view path: `@AppStorage("…")`
//  - wenshu @Observable / actor path: `UserDefaultsStore.shared.string(forKey:)`
//  - never raw `UserDefaults.standard.string(forKey:)`
//
//  All keys live under the `wenshu.` namespace (= every caller writes
//  the same key string into `WenshuDefaultsKey.<case>.rawValue` to keep
//  the prefix centralized).
//
//  Thread safety: backed by `UserDefaults.standard` (= Apple guarantees
//  atomic scalar reads/writes; = safe to call from any actor).
//
//  Types supported:
//  - String / String? (= empty string fallback for missing key)
//  - Bool (= false fallback)
//  - Int (= 0 fallback)
//  - Double (= 0.0 fallback)
//  - Data / Data? (= nil fallback for missing key; = use for blob shapes
//    that don't fit @AppStorage)
//  - UUID / UUID? (= round-trip via uuidString)
//
//  Dynamic-key escape hatch (= for keys whose name is computed at
//  runtime, e.g. `wenshu.tabIndex.<zoneSlug>` in ZoneContentView):
//  - Int only (= the dynamic-key call sites in wenshu all store Int)
//  - `forDynamicKey:` String-typed parameter (= typo-prone by design;
//    prefer `WenshuDefaultsKey.<case>` when the key is static)
//

import Foundation

/// Centralized UserDefaults key namespace (= every setting key lives
/// here so renaming / migration / R2-Spotlight indexing all touch one
/// file). Cases map 1:1 to the `wenshu.<name>` raw value.
public enum WenshuDefaultsKey: String, CaseIterable, Sendable {
    case debugNoKeychain     = "wenshu.debugNoKeychain"
    case libraryPath         = "wenshu.libraryPath"
    case llmActiveConnector  = "wenshu.llm.activeConnector"
    case llmModel            = "wenshu.llm.model"
    case llmProvider         = "wenshu.llm.provider"
    case llmReasoningEffort  = "wenshu.llm.reasoningEffort"
    case settingsTab         = "wenshu.settingsTab"
    case userAddress         = "wenshu.userAddress"
    case openTabs            = "wenshu.openTabs"
    case activeTabId         = "wenshu.editor.activeTabId.v1"
    case sidebarSelection    = "wenshu.sidebarSelection"
    case inspectorVisible    = "wenshu.inspectorVisible"
    case chatVisible         = "wenshu.chatVisible"
    case inspectorPage       = "wenshu.inspectorPage"
    case monthlyCredits      = "wenshu.monthlyCredits"
    case cwdOverride         = "wenshu.runtimeCWD"
    case creditsMonthly      = "wenshu.credits.monthly"
    case creditsMonthlyReset = "wenshu.credits.monthlyReset"
}

/// Typed wrapper over `UserDefaults.standard`.
///
/// Use instead of raw `UserDefaults.standard.string(forKey:)` /
/// `.bool(forKey:)` / `.set(_:forKey:)` callsites in wenshu code.
/// The intent is to keep every key in `WenshuDefaultsKey` (= no string
/// typos; = one place to audit).
public struct UserDefaultsStore: @unchecked Sendable {

    public static let shared = UserDefaultsStore()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - String

    public func string(forKey key: WenshuDefaultsKey) -> String {
        defaults.string(forKey: key.rawValue) ?? ""
    }

    public func string(forKey key: WenshuDefaultsKey, fallback: String) -> String {
        defaults.string(forKey: key.rawValue) ?? fallback
    }

    public func setString(_ value: String, forKey key: WenshuDefaultsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    // MARK: - Bool

    public func bool(forKey key: WenshuDefaultsKey) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    public func setBool(_ value: Bool, forKey key: WenshuDefaultsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    // MARK: - Int

    public func int(forKey key: WenshuDefaultsKey) -> Int {
        defaults.integer(forKey: key.rawValue)
    }

    public func setInt(_ value: Int, forKey key: WenshuDefaultsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    // MARK: - Double

    public func double(forKey key: WenshuDefaultsKey) -> Double {
        defaults.double(forKey: key.rawValue)
    }

    public func setDouble(_ value: Double, forKey key: WenshuDefaultsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    // MARK: - Data (= for blob shapes that don't fit @AppStorage)

    public func data(forKey key: WenshuDefaultsKey) -> Data? {
        defaults.data(forKey: key.rawValue)
    }

    public func setData(_ value: Data, forKey key: WenshuDefaultsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    // MARK: - UUID

    public func uuid(forKey key: WenshuDefaultsKey) -> UUID? {
        guard let raw = defaults.string(forKey: key.rawValue),
              !raw.isEmpty else { return nil }
        return UUID(uuidString: raw)
    }

    public func setUUID(_ value: UUID?, forKey key: WenshuDefaultsKey) {
        if let value {
            defaults.set(value.uuidString, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Removal

    public func remove(_ key: WenshuDefaultsKey) {
        defaults.removeObject(forKey: key.rawValue)
    }

    // MARK: - Dynamic-key Int (= runtime-computed key names)

    /// Dynamic-key variant (= the key is computed at the call site
    /// from a runtime value, e.g. `wenshu.tabIndex.<zoneSlug>`).
    ///
    /// Prefer the typed `WenshuDefaultsKey.<case>` overload when the
    /// key is static (= typo-proof; = one place to audit). The
    /// dynamic-key variant exists so dynamic-key call sites (= e.g.
    /// per-zone stored tab indices) still route through this wrapper
    /// instead of going raw to `UserDefaults.standard`.
    public func int(forDynamicKey key: String) -> Int {
        defaults.integer(forKey: key)
    }

    /// Dynamic-key variant. See `int(forDynamicKey:)` for the rationale.
    public func setInt(_ value: Int, forDynamicKey key: String) {
        defaults.set(value, forKey: key)
    }

    /// Dynamic-key variant. See `int(forDynamicKey:)` for the rationale.
    public func remove(forDynamicKey key: String) {
        defaults.removeObject(forKey: key)
    }
}