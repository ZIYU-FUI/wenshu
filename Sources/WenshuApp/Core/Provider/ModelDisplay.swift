//
//  ModelDisplay.swift · Wenshu · v0.21 ticket 35a (model display name with editable override)
//
//  Pure UI transform helper: maps raw API model IDs → display names.
//  Real model list source: API response (verified via NSLog capture 2026-08-21).
//  API returns 8 IDs (hermes UI shows 5 = drops 3 `-highspeed` variants):
//    MiniMax-M3, MiniMax-M2.7, MiniMax-M2.7-highspeed, MiniMax-M2.5,
//    MiniMax-M2.5-highspeed, MiniMax-M2.1, MiniMax-M2.1-highspeed, MiniMax-M2
//
//  Design rules (boss 2026-08-22):
//  - Display names must be EDITABLE by boss (no hardcoded tier forcing)
//  - Default names = doc-clean (just model name + family tier from API doc), NOT "Ultra/Med"
//  - Per-call reasoning strength lives in ChatSettings (ticket 35b), NOT model tier
//

import Foundation

/// Display-name override entry: maps raw API model ID → boss-editable display name.
/// Tier removed — per-call reasoning strength is a ChatSettings concept (ticket 35b), not model attribute.
public struct ModelDisplayEntry: Hashable, Sendable {
    public let id: String          // raw API ID (e.g. "MiniMax-M3")
    public var display: String     // boss-editable display name (e.g. "MiniMax M3")

    public init(id: String, display: String) {
        self.id = id
        self.display = display
    }
}

/// Static default display-name table (boss can override via @AppStorage "wenshu.modelDisplayOverrides").
/// Documented defaults = clean model names (no tier suffix).
/// Per-call reasoning strength (最小/低/中/高/极高/最高/超高) = ChatSettings concept, NOT here.
public enum ModelDisplay {
    /// Documented default display names (boss can override).
    /// No tier concept — display = model name only.
    /// Note: `-highspeed` variants are filtered out by `curated(_:)` (= 5 curated, not 8).
    public static let defaults: [String: ModelDisplayEntry] = [
        "MiniMax-M3":          ModelDisplayEntry(id: "MiniMax-M3",          display: "MiniMax M3"),
        "MiniMax-M2.7":        ModelDisplayEntry(id: "MiniMax-M2.7",        display: "MiniMax M2.7"),
        "MiniMax-M2.5":        ModelDisplayEntry(id: "MiniMax-M2.5",        display: "MiniMax M2.5"),
        "MiniMax-M2.1":        ModelDisplayEntry(id: "MiniMax-M2.1",        display: "MiniMax M2.1"),
        "MiniMax-M2":          ModelDisplayEntry(id: "MiniMax-M2",          display: "MiniMax M2"),
    ]

    /// Lookup by raw API ID. Resolves boss override (via UserDefaults "wenshu.modelDisplayOverrides") first,
    /// then falls back to default table, then to raw ID (no transformation).
    public static func lookup(_ id: String) -> ModelDisplayEntry {
        // 1. Boss override (UserDefaults JSON dict keyed by raw API ID)
        if let override = bossOverride(id) {
            return ModelDisplayEntry(id: id, display: override)
        }
        // 2. Default table
        if let entry = defaults[id] {
            return entry
        }
        // 3. Fallback: raw ID, replace dashes with spaces (best-effort display)
        let display = id.replacingOccurrences(of: "-", with: " ")
        return ModelDisplayEntry(id: id, display: display)
    }

    /// Curate raw API IDs → display entries, preserving API order, filtering `-highspeed`,
    /// de-duplicating (in case API returns duplicates).
    public static func curated(_ rawIds: [String]) -> [ModelDisplayEntry] {
        var seen = Set<String>()
        var result: [ModelDisplayEntry] = []
        for id in rawIds {
            guard !seen.contains(id) else { continue }
            guard !id.hasSuffix("-highspeed") else { continue } // boss excludes these
            seen.insert(id)
            result.append(lookup(id))
        }
        return result
    }

    // MARK: - Boss override layer (AppStorage-backed JSON dict)

    private static let overrideKey = "wenshu.modelDisplayOverrides"

    /// Read boss override from UserDefaults. Returns display name for given ID, or nil.
    public static func bossOverride(_ id: String) -> String? {
        guard let data = UserDefaults.standard.data(forKey: overrideKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return dict[id]
    }

    /// Write boss override dict to UserDefaults (overwrites existing).
    public static func writeBossOverride(_ dict: [String: String]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: overrideKey)
    }

    /// Clear single ID override (revert to default table).
    public static func clearBossOverride(_ id: String) {
        guard var dict = currentOverrides() else { return }
        dict.removeValue(forKey: id)
        writeBossOverride(dict)
    }

    /// Read all current boss overrides.
    public static func currentOverrides() -> [String: String]? {
        guard let data = UserDefaults.standard.data(forKey: overrideKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return dict
    }
}