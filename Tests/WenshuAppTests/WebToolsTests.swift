//
//  WebToolsTests.swift · Wenshu · v0.18 ticket 09 (web tools)
//
//  单元测试 WebTools. 测 htmlToMarkdown (本地), 跳过真 URL fetch (网络依赖).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WebTools (hermes replica)")
struct WebToolsTests {
    @Test("htmlToMarkdown 简化 HTML 转 markdown")
    func testHtmlToMarkdown() {
        let html = "<h1>Title</h1><p>Hello <strong>wenshu</strong> world</p><p>Second para</p>"
        let md = WebTools.htmlToMarkdown(html)
        #expect(md.contains("# Title"))
        #expect(md.contains("Hello"))
        #expect(md.contains("**wenshu**"))
        #expect(md.contains("world"))
        #expect(md.contains("Second para"))
    }

    @Test("htmlToMarkdown 实体转义")
    func testHtmlEntities() {
        let html = "<p>Tom &amp; Jerry &lt;3 &quot;cheese&quot;</p>"
        let md = WebTools.htmlToMarkdown(html)
        #expect(md.contains("Tom & Jerry"))
        #expect(md.contains("<3"))
        #expect(md.contains("\"cheese\""))
    }

    @Test("htmlToMarkdown h2 h3 标题")
    func testHeadings() {
        let html = "<h2>Subtitle</h2><h3>Section</h3>"
        let md = WebTools.htmlToMarkdown(html)
        #expect(md.contains("## Subtitle"))
        #expect(md.contains("### Section"))
    }

    @Test("htmlToMarkdown 标签完整")
    func testNoRemainingTags() {
        let html = "<div><p>content <span>nested</span> end</p></div>"
        let md = WebTools.htmlToMarkdown(html)
        #expect(!md.contains("<"))
        #expect(!md.contains(">"))
    }

    @Test("fetch 无效 URL 抛错")
    func testFetchInvalidURL() async {
        let tools = WebTools()
        await #expect(throws: (any Error).self) {
            _ = try await tools.fetch(url: "ht!tp:/invalid")  // 任何错误都行 (system URLError 或 WebToolsError)
        }
    }
}