//
//  ModelDisplay.swift · Wenshu · v0.21 ticket 35a (model curated to 5 + rename display)
//
//  Pure helper struct: maps raw API model IDs → curated display names.
//  Real model list source: API response (verified via NSLog capture 2026-08-21).
//  API returns 8 IDs: MiniMax-M3, MiniMax-M2.7, MiniMax-M2.7-highspeed, MiniMax-M2.5,
//  MiniMax-M2.5-highspeed, MiniMax-M2.1, MiniMax-M2.1-highspeed, MiniMax-M2.
//  Hermes UI shows 5 = drops 3 `-highspeed` variants.

import Foundation

public enum ModelTier: String, Codable, Sendable {
    case ultra
    case med
}

public struct ModelDisplay: Hashable, Sendable {
    public let id: String          // raw API ID (e.g. "MiniMax-M3")
    public let display: String     // hermes-style name (e.g. "MiniMax M3 Ultra")
    public let tier: ModelTier?

    public init(id: String, display: String, tier: ModelTier?) {
        self.id = id
        self.display = display
        self.tier = tier
    }

    /// Compose display name from base name + tier
    public static func format(_ base: String, tier: ModelTier?) -> String {
        guard let tier = tier else { return base }
        return "\(base) \(tier.rawValue.capitalized)"
    }

    /// Curated + renamed display table (static mapping = documented whitelist)
    /// Drops `-highspeed` variants (3 of 8 raw API IDs).
    /// If API returns a new ID not in the table, falls back to formatting with inferred tier.
    public static let known: [String: ModelDisplay] = [
        "MiniMax-M3":          ModelDisplay(id: "MiniMax-M3",          display: "MiniMax M3 Ultra", tier: .ultra),
        "MiniMax-M2.7":        ModelDisplay(id: "MiniMax-M2.7",        display: "MiniMax M2.7 Med", tier: .med),
        "MiniMax-M2.5":        ModelDisplay(id: "MiniMax-M2.5",        display: "MiniMax M2.5 Med", tier: .med),
        "MiniMax-M2.1":        ModelDisplay(id: "MiniMax-M2.1",        display: "MiniMax M2.1 Med", tier: .med),
        "MiniMax-M2":          ModelDisplay(id: "MiniMax-M2",          display: "MiniMax M2 Med",   tier: .med),
    ]

    /// Lookup by raw API ID. Returns nil if ID not in curated table (e.g. deprecated).
    public static func lookup(_ id: String) -> ModelDisplay? {
        if let entry = known[id] { return entry }
        // Fallback: strip `-highspeed` suffix or format with no tier
        if id.hasSuffix("-highspeed") { return nil } // boss excludes these
        let base = id.replacingOccurrences(of: "-", with: " ")
        return ModelDisplay(id: id, display: base, tier: nil)
    }

    /// Curate raw API IDs → display entries, preserving API order, filtering `-highspeed`.
    public static func curated(_ rawIds: [String]) -> [ModelDisplay] {
        var seen = Set<String>()
        var result: [ModelDisplay] = []
        for id in rawIds {
            guard !seen.contains(id) else { continue }
            if let entry = lookup(id) {
                seen.insert(entry.id)
                result.append(entry)
            }
            // Skip lookup() == nil entries (e.g. `-highspeed` dropped)
        }
        return result
    }
}