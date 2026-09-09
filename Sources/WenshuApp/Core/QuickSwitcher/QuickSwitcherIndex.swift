//
// QuickSwitcherIndex.swift · Wenshu · v0.19 ticket 19 (Obsidian replica, do first)
// 2026-08-19 evening Obsidian A + ', '.
//
// Quick Switcher (⌘O) fuzzy search note + .
// Obsidian Quick Switcher ok (https://obsidian.md/help/plugins/quick-switcher).
// Apple HIG: Foundation String fuzzy match (substring + case-insensitive), Apple Spotlight .
//

import Foundation

/// 1 search (note)
public struct SwitcherItem: Equatable, Sendable, Identifiable {
    public var id: String          // docId docId:sectionId
    public var title: String        // show
    public var subtitle: String?    // title (path /)
    public var score: Int           // fuzzy match score ()

    public init(id: String, title: String, subtitle: String? = nil, score: Int = 0) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.score = score
    }
}

/// QuickSwitcherIndex: fuzzy search
public enum QuickSwitcherIndex {

    /// Fuzzy match: query text (size),
    ///: > > Include matching
    /// Apple HIG: Foundation NSString.caseInsensitiveCompare
    public static func fuzzyScore(query: String, text: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let lowerQ = query.lowercased()
        let lowerT = text.lowercased()

        // Perfect match.
        if lowerT == lowerQ {
            return 1000
        }
        // Prefix Match
        if lowerT.hasPrefix(lowerQ) {
            return 500
        }
        // Include matching
        if lowerT.contains(lowerQ) {
            // (Apple HIG fuzzy match)
            let charScore = characterOrderScore(query: lowerQ, text: lowerT)
            if charScore > 0 {
                return 100 + charScore
            }
            return 100
        }
        // fuzzy match (e.g. "ldy" matches "")
        let fuzzyScore = fuzzyCharacterMatch(query: lowerQ, text: lowerT)
        return fuzzyScore > 0 ? fuzzyScore : nil
    }

    // [CJK-TRANSLATE] 2 line(s) awaiting manual translation (see git blame for original CJK text)
    ///: query text
    ///: ()
    private static func characterOrderScore(query: String, text: String) -> Int {
        let qChars = Array(query)
        let tChars = Array(text)
        var qi = 0
        var ti = 0
        var matchedPositions: [Int] = []
        while qi < qChars.count && ti < tChars.count {
            if qChars[qi] == tChars[ti] {
                matchedPositions.append(ti)
                qi += 1
            }
            ti += 1
        }
        guard qi == qChars.count else { return 0 }
        // The closer the score, the higher.
        let span = (matchedPositions.last ?? 0) - (matchedPositions.first ?? 0) + 1
        let density = Double(qChars.count) / Double(span)
        return Int(density * 50)  // 0-50
    }

    /// Fuzzy character match: query skip text ()
    ///: match
    private static func fuzzyCharacterMatch(query: String, text: String) -> Int {
        let qChars = Array(query)
        let tChars = Array(text)
        var qi = 0
        var ti = 0
        while qi < qChars.count && ti < tChars.count {
            if qChars[qi] == tChars[ti] {
                qi += 1
            }
            ti += 1
        }
        guard qi == qChars.count else { return 0 }
        return Int(Double(qChars.count) / Double(tChars.count) * 50)
    }

    /// search items
    public static func search(query: String, in items: [SwitcherItem], limit: Int = 20) -> [SwitcherItem] {
        guard !query.isEmpty else { return [] }
        let scored = items.compactMap { item -> SwitcherItem? in
            // title + subtitle merge
            let titleScore = fuzzyScore(query: query, text: item.title) ?? 0
            let subtitleScore = item.subtitle.flatMap { fuzzyScore(query: query, text: $0) } ?? 0
            let best = max(titleScore, subtitleScore)
            guard best > 0 else { return nil }
            return SwitcherItem(id: item.id, title: item.title, subtitle: item.subtitle, score: best)
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }
}
