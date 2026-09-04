//
//  RuntimeCWD.swift · Wenshu · v0.36 ticket 017
//
//  Runtime current working directory tracker (= spec §3.1 L238).
//
//  Tracks the CWD (= absolute file URL) for tool execution. Defaults to
//  the .ws library root selected at onboarding (= UserDefaults
//  wenshu.libraryPath per AGENTS.md §11 baseline). Tools that need
//  relative paths resolve them against this CWD.
//
//  Per ADR-0009 (wenshu-side wins) + §11.3: this is a thin tracker over
//  existing FileManager + the library path stored in UserDefaults. No
//  duplicate filesystem abstraction.
//
//  Per ADR-0011 + §11 hard rule: pure Swift actor; no LLM calls; no
//  external deps.
//
//  v0.36 ticket 017 (= single-commit ticket per boss cadence '1 RULE 1 commit').
//

import Foundation

/// Runtime current working directory (= absolute file URL).
/// Default = wenshu library path (= UserDefaults wenshu.libraryPath per
/// AGENTS.md §11). Override via Settings → Library Properties → "Set as
/// runtime CWD" or programmatically via `setCWD(_:)`.
public actor RuntimeCWD {

    /// Default library path key (= AGENTS.md §11 baseline).
    public static let libraryPathKey = "wenshu.libraryPath"

    /// CWD override key (= when set, takes precedence over library path).
    public static let cwdOverrideKey = "wenshu.runtimeCWD"

    private var cwdOverride: URL?
    private let libraryPathFallback: URL?

    public init() {
        // Read library path from UserDefaults at init time.
        if let path = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey) {
            self.libraryPathFallback = URL(fileURLWithPath: path)
        } else {
            self.libraryPathFallback = nil
        }
        // Read CWD override from UserDefaults.
        if let path = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey) {
            self.cwdOverride = URL(fileURLWithPath: path)
        } else {
            self.cwdOverride = nil
        }
    }

    /// Current working directory (= override > library path > nil).
    public func currentCWD() -> URL? {
        return cwdOverride ?? libraryPathFallback
    }

    /// Explicit override (= programmatic; persists to UserDefaults).
    public func setCWD(_ url: URL?) {
        cwdOverride = url
        if let url {
            UserDefaults.standard.set(url.path, forKey: RuntimeCWD.cwdOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        }
    }

    /// Reset to library path (= clears override).
    public func resetToLibraryPath() {
        setCWD(nil)
    }

    /// Resolve a relative path against the current CWD.
    /// - Parameters:
    ///   - relativePath: path to resolve (= may be absolute or relative)
    /// - Returns: absolute URL (= relativePath unchanged if absolute;
    ///   resolved against currentCWD if relative; nil if CWD is unset
    ///   and the path is relative).
    public func resolve(relativePath: String) -> URL? {
        if relativePath.hasPrefix("/") {
            return URL(fileURLWithPath: relativePath)
        }
        guard let cwd = currentCWD() else { return nil }
        return URL(fileURLWithPath: relativePath, relativeTo: cwd)
    }

    /// CWD display label (= for UI: "Library: /Users/.../ws" or
    /// "Override: /tmp/work" or "Unset").
    public func displayLabel() -> String {
        if let override = cwdOverride {
            return "Override: \(override.path)"
        }
        if let fallback = libraryPathFallback {
            return "Library: \(fallback.path)"
        }
        return "Unset"
    }
}