//
//  QuickSwitcherIndexTests.swift · Wenshu · v0.19 ticket 19
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("QuickSwitcherIndex (Obsidian replica)")
struct QuickSwitcherIndexTests {

    @Test("fuzzy 完全匹配")
    func fuzzyExact() {
        #expect(QuickSwitcherIndex.fuzzyScore(query: "林黛玉", text: "林黛玉") == 1000)
    }

    @Test("fuzzy 前缀匹配")
    func fuzzyPrefix() {
        #expect(QuickSwitcherIndex.fuzzyScore(query: "林黛", text: "林黛玉") == 500)
    }

    @Test("fuzzy 包含匹配")
    func fuzzyContains() {
        let score = QuickSwitcherIndex.fuzzyScore(query: "黛玉", text: "林黛玉")
        #expect(score != nil)
        #expect(score! >= 100)
    }

    @Test("fuzzy 不匹配返回 nil")
    func fuzzyNoMatch() {
        #expect(QuickSwitcherIndex.fuzzyScore(query: "xyz", text: "林黛玉") == nil)
    }

    @Test("fuzzy 缩写匹配 (e.g. 'ldy' → '林黛玉' 不行)")
    func fuzzyAbbrev() {
        // 'ldy' 字符序在 '林黛玉' 里都存在 (l/d/y vs 林/黛/玉), 但 'l' 不在
        #expect(QuickSwitcherIndex.fuzzyScore(query: "ldy", text: "林黛玉") == nil)
    }

    @Test("fuzzy 大小写不敏感")
    func fuzzyCaseInsensitive() {
        #expect(QuickSwitcherIndex.fuzzyScore(query: "LINDAI", text: "林黛玉") == nil)  // 中文无大小写
        #expect(QuickSwitcherIndex.fuzzyScore(query: "Chapter 1", text: "chapter 1") == 1000)  // 英文大小写不敏感
    }

    @Test("search 空 query 返回空")
    func searchEmpty() {
        let items = [SwitcherItem(id: "1", title: "第一章")]
        let results = QuickSwitcherIndex.search(query: "", in: items)
        #expect(results.isEmpty)
    }

    @Test("search 按分数排序")
    func searchSorted() {
        let items = [
            SwitcherItem(id: "1", title: "红楼梦"),
            SwitcherItem(id: "2", title: "林黛玉进贾府"),
            SwitcherItem(id: "3", title: "三国演义"),
        ]
        let results = QuickSwitcherIndex.search(query: "林黛", in: items)
        #expect(results.first?.id == "2", "林黛玉进贾府 是排第一 (前缀匹配)")
    }

    @Test("search limit")
    func searchLimit() {
        let items = (1...30).map { SwitcherItem(id: "\($0)", title: "Note \($0)") }
        let results = QuickSwitcherIndex.search(query: "Note", in: items, limit: 5)
        #expect(results.count == 5)
    }

    @Test("search 包含匹配 + 完全匹配混合")
    func searchMixed() {
        let items = [
            SwitcherItem(id: "1", title: "Chapter One"),     // 完全匹配
            SwitcherItem(id: "2", title: "My Chapter"),     // 包含匹配
            SwitcherItem(id: "3", title: "Random Note"),     // 不匹配
        ]
        let results = QuickSwitcherIndex.search(query: "Chapter", in: items)
        #expect(results.count == 2)
        #expect(results.first?.id == "1", "完全匹配排第一")
    }

    @Test("search 包含 subtitle")
    func searchSubtitle() {
        let items = [
            SwitcherItem(id: "1", title: "Note 1", subtitle: "books/novel/chapter-1"),
        ]
        let results = QuickSwitcherIndex.search(query: "chapter", in: items)
        #expect(results.count == 1)
    }
}
