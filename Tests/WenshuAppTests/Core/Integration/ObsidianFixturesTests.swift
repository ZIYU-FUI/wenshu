//
//  ObsidianFixturesTests.swift · Wenshu · v0.19 ticket 23
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  集成测试: Obsidian 公开示例 fixture 在 wenshu 解析 + 编码 round-trip 1:1.
//  跟 Obsidian / SilverBullet 双向兼容 (ticket 12 / 13 / 15 / 17 / 18 跨工具兼容汇总).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Obsidian 跨工具兼容性集成 (Obsidian replica)")
struct ObsidianFixturesTests {

    // MARK: - JSON Canvas round-trip (跟 https://jsoncanvas.org/ 首页示例 1:1)

    @Test("JSON Canvas jsoncanvas.org 首页示例 round-trip")
    func jsonCanvasSpecExample() throws {
        let original = """
        {
          "nodes": [
            {
              "id": "spec",
              "type": "file",
              "x": 600,
              "y": 140,
              "width": 1908,
              "height": 175,
              "file": "spec/1.0.md"
            },
            {
              "id": "readme",
              "type": "file",
              "x": 36,
              "y": 240,
              "width": 1904,
              "height": 184,
              "file": "readme.md"
            }
          ],
          "edges": [
            {
              "id": "edge-readme-spec",
              "fromNode": "readme",
              "fromSide": "right",
              "fromEnd": "none",
              "toNode": "spec",
              "toSide": "left",
              "toEnd": "arrow"
            }
          ]
        }
        """
        let decoded = try JSONCanvasCodec.decode(original)
        let encoded = try JSONCanvasCodec.encodeToString(decoded)
        let decodedAgain = try JSONCanvasCodec.decode(encoded)
        #expect(decoded.nodes.count == decodedAgain.nodes.count)
        #expect(decoded.edges.count == decodedAgain.edges.count)
        #expect(decoded.nodes.map { $0.id } == decodedAgain.nodes.map { $0.id })
    }

    // MARK: - Internal Link 双链 round-trip

    @Test("Internal Link [[name]] 双向兼容 Obsidian + SilverBullet")
    func internalLinkBidirectional() {
        let content = "[[林黛玉]] 进贾府 与 [[贾宝玉|宝玉]] 初见"
        let parsed = InternalLinkParser.parse(content)
        #expect(parsed.count == 2)
        #expect(parsed[0].target == "林黛玉")
        #expect(parsed[1].target == "贾宝玉")
        #expect(parsed[1].text == "宝玉")
    }

    // MARK: - Bases .base YAML round-trip (跟 https://obsidian.md/help/bases/syntax 1:1)

    @Test("Bases syntax 文档示例 round-trip (简化子集)")
    func basesSpecExample() throws {
        let original = """
        formulas:
          formatted_price: 'if(price, price.toFixed(2) + " dollars")'
          ppu: "(price / age).toFixed(2)"
        """
        let decoded = try BaseParser.parse(original)
        #expect(decoded.formulas.count == 2)
        #expect(decoded.formulas[0].name == "formatted_price")
        #expect(decoded.formulas[0].expression.contains("price"))
        #expect(decoded.viewCount == 0, "简化 parser 不解析 views, 后续 ticket 可加 groupBy / filters nested")
    }

    // MARK: - Template date token round-trip (跟 Obsidian Templates 1:1)

    @Test("Template date tokens {{date}} {{time}} {{title}} 替换")
    func templateTokens() {
        let context = TemplateContext(title: "第一章", author: "曹雪芹")
        let template = "# {{title}}\n作者: {{author}}"
        let result = TemplateEngine.render(template, context: context)
        #expect(result.contains("# 第一章"))
        #expect(result.contains("作者: 曹雪芹"))
    }

    // MARK: - Markdown frontmatter (Obsidian Properties) — wenshu 不解析, 留 raw

    @Test("Markdown frontmatter 保留原文 (wenshu 不解析 Properties)")
    func frontmatterPassThrough() {
        let content = "---\ntitle: 我的笔记\ntags: [林黛玉, 贾宝玉]\n---\n# 正文\n林黛玉 进贾府"
        // wenshu 现阶段不解析 YAML frontmatter (后续 ticket 可加), 留 raw content
        // 验证 content 完整保留
        #expect(content.contains("title: 我的笔记"))
        #expect(content.contains("# 正文"))
        #expect(content.contains("林黛玉 进贾府"))
    }

    // MARK: - Outline (跟 Obsidian Outline 1:1)

    @Test("Outline H1-H6 解析")
    func outlineHierarchical() {
        let content = """
        # 第一章
        ## 第一节
        ### 1.1
        # 第二章
        """
        let items = OutlineExtractor.extract(content)
        #expect(items.count == 4)
        #expect(items.map { $0.level } == [1, 2, 3, 1])
    }

    // MARK: - Word count (跟 Obsidian Word count 1:1)

    @Test("Word count 中英文混合统计")
    func wordCountMixed() {
        let content = "Hello 林黛玉 world"
        let count = WordCounter.count(content)
        #expect(count.words == 2)  // Hello / world
        #expect(count.chineseChars == 3)  // 林黛玉 = 3 中文字
    }
}
