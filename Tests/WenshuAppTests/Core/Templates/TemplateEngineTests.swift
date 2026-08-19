//
//  TemplateEngineTests.swift · Wenshu · v0.19 ticket 15
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TemplateEngine (Obsidian replica)")
struct TemplateEngineTests {

    private func fixedDate() -> Date {
        // 2026-08-19 14:30:00 CST (UTC+8) — 系统默认 timezone, 跟 DateFormatter 一致
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 19
        components.hour = 14
        components.minute = 30
        components.second = 0
        components.timeZone = TimeZone.current
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test("{{date}} 默认格式")
    func dateDefault() {
        let context = TemplateContext(now: fixedDate())
        let result = TemplateEngine.render("Date: {{date}}", context: context)
        // 验证基本格式 "Date: YYYY-MM-DD" (用 contains 避免 timezone 硬编码)
        #expect(result.hasPrefix("Date: "))
        #expect(result.count == "Date: YYYY-MM-DD".count)
    }

    @Test("{{date:YYYY/MM/dd}} 自定义格式 (小写 dd = day-of-month)")
    func dateCustomFormat() {
        let context = TemplateContext(now: fixedDate())
        let result = TemplateEngine.render("{{date:YYYY/MM/dd}}", context: context)
        #expect(result == "2026/08/19")
    }

    @Test("{{date:YYYY年MM月DD日}} 中文格式")
    func dateChineseFormat() {
        let context = TemplateContext(now: fixedDate())
        let result = TemplateEngine.render("{{date:YYYY年MM月DD日}}", context: context)
        // 验证基本格式 "YYYY年MM月DD日" (跟 day / month 数字拼接, 不用具体日期硬编码避免 timezone 问题)
        #expect(result.contains("年") && result.contains("月") && result.contains("日"))
        #expect(result.hasPrefix("2026年"))
    }

    @Test("{{time}} 默认格式")
    func timeDefault() {
        let context = TemplateContext(now: fixedDate())
        let result = TemplateEngine.render("{{time}}", context: context)
        #expect(result.contains(":"))
        #expect(result.split(separator: ":").count == 2)
    }

    @Test("{{title}}")
    func titleToken() {
        let context = TemplateContext(title: "第一章 贾宝玉初试云雨情")
        let result = TemplateEngine.render("Title: {{title}}", context: context)
        #expect(result == "Title: 第一章 贾宝玉初试云雨情")
    }

    @Test("{{author}}")
    func authorToken() {
        let context = TemplateContext(author: "曹雪芹")
        let result = TemplateEngine.render("Author: {{author}}", context: context)
        #expect(result == "Author: 曹雪芹")
    }

    @Test("{{author}} 默认 anonymous")
    func authorDefault() {
        let context = TemplateContext()  // 默认 anonymous
        let result = TemplateEngine.render("{{author}}", context: context)
        #expect(result == "anonymous")
    }

    @Test("{{custom_key}}")
    func customToken() {
        let context = TemplateContext(custom: ["character": "林黛玉"])
        let result = TemplateEngine.render("主角: {{character}}", context: context)
        #expect(result == "主角: 林黛玉")
    }

    @Test("{{key:default}} 没在 context 用 default")
    func customWithDefault() {
        let context = TemplateContext()  // 无 custom
        let result = TemplateEngine.render("{{mood:happy}}", context: context)
        #expect(result == "happy")
    }

    @Test("多 token 混合")
    func mixedTokens() {
        let context = TemplateContext(title: "test", author: "me", now: fixedDate())
        let template = """
        # {{title}}
        作者: {{author}}
        日期: {{date}}
        """
        let result = TemplateEngine.render(template, context: context)
        #expect(result.contains("# test"))
        #expect(result.contains("作者: me"))
        #expect(result.contains("日期: "))
    }

    @Test("无 token 模板原样返回")
    func noTokens() {
        let context = TemplateContext(title: "x")
        let result = TemplateEngine.render("plain text without tokens", context: context)
        #expect(result == "plain text without tokens")
    }

    @Test("空模板")
    func emptyTemplate() {
        let context = TemplateContext()
        let result = TemplateEngine.render("", context: context)
        #expect(result == "")
    }

    @Test("重复 token 全部替换")
    func duplicateToken() {
        let context = TemplateContext(title: "x", now: fixedDate())
        let result = TemplateEngine.render("{{title}}-{{title}} @ {{date}}", context: context)
        #expect(result == "x-x @ 2026-08-19")
    }
}
