//
//  QuickSwitcherIndex.swift · Wenshu · v0.19 ticket 19 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  Quick Switcher (⌘O) fuzzy 搜索 note + 章节.
//  跟 Obsidian Quick Switcher 行为对齐 (https://obsidian.md/help/plugins/quick-switcher).
//  Apple HIG: Foundation String fuzzy match (substring + case-insensitive), 跟 Apple Spotlight 范式一致.
//

import Foundation

/// 1 个搜索结果 (note 或 章节)
public struct SwitcherItem: Equatable, Sendable, Identifiable {
    public var id: String          // docId 或 docId:sectionId
    public var title: String        // 显示名
    public var subtitle: String?    // 副标题 (路径 / 章节号)
    public var score: Int           // fuzzy match score (越大越相关)

    public init(id: String, title: String, subtitle: String? = nil, score: Int = 0) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.score = score
    }
}

/// QuickSwitcherIndex: 静态 fuzzy 搜索工具
public enum QuickSwitcherIndex {

    /// Fuzzy match: query 在 text 里子串匹配 (不区分大小写), 算分
    /// 评分: 完全匹配 > 前缀匹配 > 包含匹配
    /// Apple HIG: Foundation NSString.caseInsensitiveCompare
    public static func fuzzyScore(query: String, text: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let lowerQ = query.lowercased()
        let lowerT = text.lowercased()

        // 完全匹配
        if lowerT == lowerQ {
            return 1000
        }
        // 前缀匹配
        if lowerT.hasPrefix(lowerQ) {
            return 500
        }
        // 包含匹配
        if lowerT.contains(lowerQ) {
            // 字符序匹配 (Apple HIG fuzzy match)
            let charScore = characterOrderScore(query: lowerQ, text: lowerT)
            if charScore > 0 {
                return 100 + charScore
            }
            return 100
        }
        // 字符序 fuzzy match (e.g. "ldy" matches "林黛玉")
        let fuzzyScore = fuzzyCharacterMatch(query: lowerQ, text: lowerT)
        return fuzzyScore > 0 ? fuzzyScore : nil
    }

    /// 字符序匹配: query 的每个字符按顺序出现在 text 里
    /// 评分: 越紧凑 (字符越近) 分数越高
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
        // 越紧凑分数越高 (最大相邻距离越小越好)
        let span = (matchedPositions.last ?? 0) - (matchedPositions.first ?? 0) + 1
        let density = Double(qChars.count) / Double(span)
        return Int(density * 50)  // 0-50
    }

    /// Fuzzy character match: query 字符可跳过 text 字符 (例如缩写)
    /// 评分: match 率
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

    /// 搜索 items
    public static func search(query: String, in items: [SwitcherItem], limit: Int = 20) -> [SwitcherItem] {
        guard !query.isEmpty else { return [] }
        let scored = items.compactMap { item -> SwitcherItem? in
            // title + subtitle 合并评分
            let titleScore = fuzzyScore(query: query, text: item.title) ?? 0
            let subtitleScore = item.subtitle.flatMap { fuzzyScore(query: query, text: $0) } ?? 0
            let best = max(titleScore, subtitleScore)
            guard best > 0 else { return nil }
            return SwitcherItem(id: item.id, title: item.title, subtitle: item.subtitle, score: best)
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }
}
