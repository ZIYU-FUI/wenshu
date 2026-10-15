//
//  OutlineExtractorTests.swift · Wenshu · v0.19 ticket 21
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("OutlineExtractor (Obsidian replica)")
struct OutlineExtractorTests {

    @Test("空内容")
    func empty() {
        let items = OutlineExtractor.extract("")
        #expect(items.isEmpty)
    }

    @Test("单 H1")
    func singleH1() {
        let items = OutlineExtractor.extract("# 第一章 标题")
        #expect(items.count == 1)
        #expect(items[0].level == 1)
        #expect(items[0].title == "第一章 标题")
        #expect(items[0].line == 0)
    }

    @Test("多级 H1-H6")
    func multiLevel() {
        let content = """
        # H1
        ## H2
        ### H3
        #### H4
        ##### H5
        ###### H6
        """
        let items = OutlineExtractor.extract(content)
        #expect(items.count == 6)
        #expect(items.map { $0.level } == [1, 2, 3, 4, 5, 6])
    }

    @Test("混合内容: heading + 普通段落")
    func mixedContent() {
        let content = """
        第一段普通文字

        # 第一章

        普通段落

        ## 第一节

        更多内容
        """
        let items = OutlineExtractor.extract(content)
        #expect(items.count == 2)
        #expect(items[0].title == "第一章")
        #expect(items[1].title == "第一节")
        #expect(items[1].line == 6)
    }

    @Test("无 heading 全部当普通段落")
    func noHeadings() {
        let content = """
        第一段
        第二段
        #这不是 heading (# 在行首才是)
        """
        let items = OutlineExtractor.extract(content)
        #expect(items.isEmpty, "无行首 heading 应为空")
    }

    @Test("heading 后尾随空格处理")
    func trailingSpaces() {
        let items = OutlineExtractor.extract("# 标题   ")
        #expect(items.count == 1)
        #expect(items[0].title == "标题", "尾随空格应被 trim")
    }

    @Test("中文 heading")
    func chineseHeadings() {
        let content = """
        # 林黛玉进贾府
        ## 与贾宝玉初见
        ### 宝黛共读西厢记
        """
        let items = OutlineExtractor.extract(content)
        #expect(items.count == 3)
        #expect(items[0].title == "林黛玉进贾府")
        #expect(items[1].title == "与贾宝玉初见")
        #expect(items[2].title == "宝黛共读西厢记")
    }

    @Test("tree 单 H1 + 1 H2 child")
    func treeSimple() {
        let content = """
        # H1
        ## H2
        """
        let items = OutlineExtractor.extract(content)
        let tree = OutlineExtractor.tree(from: items)
        #expect(tree.count == 1)
        #expect(tree[0].item.title == "H1")
        #expect(tree[0].children.count == 1)
        #expect(tree[0].children[0].item.title == "H2")
    }

    @Test("tree H1 → H2 → H3")
    func treeDeep() {
        let content = """
        # H1
        ## H2
        ### H3
        """
        let items = OutlineExtractor.extract(content)
        let tree = OutlineExtractor.tree(from: items)
        #expect(tree.count == 1)
        #expect(tree[0].children.count == 1)
        #expect(tree[0].children[0].children.count == 1)
        #expect(tree[0].children[0].children[0].item.title == "H3")
    }

    @Test("tree H2-2 回到 H1 children (同级)")
    func treeSibling() {
        let content = """
        # H1
        ## H2-1
        ## H2-2
        """
        let items = OutlineExtractor.extract(content)
        let tree = OutlineExtractor.tree(from: items)
        #expect(tree.count == 1)
        #expect(tree[0].children.count == 2)
        #expect(tree[0].children.map { $0.item.title } == ["H2-1", "H2-2"])
    }
}
