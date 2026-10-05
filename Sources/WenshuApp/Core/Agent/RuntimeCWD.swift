// RuntimeCWD.swift
//
// Runtime current working directory tracker. Tracks the CWD
// (= absolute file URL) for tool execution. Default = the `.ws`
// library root selected at onboarding (= `UserDefaults
// wenshu.libraryPath` per AGENTS.md §11 baseline). Tools that
// need relative paths resolve them against this CWD.
//
// ADR-0009 (wenshu-side wins) + §11.3: thin tracker over existing
// FileManager + the library path stored in UserDefaults (= no
// duplicate filesystem abstraction).
//
// ADR-0011 + §11 hard rule: pure Swift actor; no LLM calls; no
// external deps.

import Foundation

/// Runtime current working directory (= absolute file URL).
/// Default = wenshu library path (= UserDefaults wenshu.libraryPath per
/// AGENTS.md §11). Override via Settings → Library Properties → "Set as
/// runtime CWD" or programmatically via `setCWD(_:)`.
actor RuntimeCWD {

    /// CWD override key (= when set, takes precedence over library path).
    static let cwdOverrideKey = "wenshu.runtimeCWD"

    private var cwdOverride: URL?
    private let libraryPathFallback: URL?

    init() {
        // Read library path from ActiveLibrary (= the canonical
        // single source of truth; = the security-scoped bookmark).
        let libPath = ActiveLibrary.path ?? ""
        self.libraryPathFallback = libPath.isEmpty
            ? nil
            : URL(fileURLWithPath: libPath)
        // Read CWD override from UserDefaults.
        let cwdPath = UserDefaultsStore.shared.string(forKey: .cwdOverride)
        self.cwdOverride = cwdPath.isEmpty
            ? nil
            : URL(fileURLWithPath: cwdPath)
    }

    /// Current working directory (= override > library path > nil).
    func currentCWD() -> URL? {
        return cwdOverride ?? libraryPathFallback
    }

    /// Explicit override (= programmatic; persists to UserDefaults).
    func setCWD(_ url: URL?) {
        cwdOverride = url
        if let url {
            UserDefaultsStore.shared.setString(url.path, forKey: .cwdOverride)
        } else {
            UserDefaultsStore.shared.remove(.cwdOverride)
        }
        // Post via the global Notification.Name extension (= shared with
        // AppStateEvents enum so observers across the app see the same
        // raw value).
        NotificationCenter.default.post(name: .runtimeCWDDidChange, object: self)
    }

    /// Reset to library path (= clears override).
    func resetToLibraryPath() {
        setCWD(nil)
    }

    /// Resolve a relative path against the current CWD.
    /// - Parameters:
    ///   - relativePath: path to resolve (= may be absolute or relative)
    /// - Returns: absolute URL (= relativePath unchanged if absolute;
    ///   resolved against currentCWD if relative; nil if CWD is unset
    ///   and the path is relative).
    func resolve(relativePath: String) -> URL? {
        if relativePath.hasPrefix("/") {
            return URL(fileURLWithPath: relativePath)
        }
        guard let cwd = currentCWD() else { return nil }
        // Concatenate explicitly so `resolved.path` contains the CWD path
        // segment (= matches the test contract `resolved.path.contains(overridePath)`).
        // `URL(fileURLWithPath:relativeTo:)` would otherwise return a URL
        // whose `.path` is the bare relative path (= drops the base).
        let cwdPath = cwd.path.hasSuffix("/") ? String(cwd.path.dropLast()) : cwd.path
        return URL(fileURLWithPath: "\(cwdPath)/\(relativePath)")
    }

    /// CWD display label (= for UI: "Library: /Users/.../ws" or
    /// "Override: /tmp/work" or "Unset").
    func displayLabel() -> String {
        if let override = cwdOverride {
            return "Override: \(override.path)"
        }
        if let fallback = libraryPathFallback {
            return "Library: \(fallback.path)"
        }
        return "Unset"
    }
}
