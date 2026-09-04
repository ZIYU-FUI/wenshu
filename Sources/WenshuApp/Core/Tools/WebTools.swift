//
//  WebTools.swift · Wenshu · v0.18 ticket 09 (hermes replica)
//
//  本地 web 工具 (复刻 hermes web 真值简化版).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. WebTools 写作用 (查资料 / 抓网页).
//  Apple HIG 真值: URLSession + URL 真值.
//

import Foundation

/// Web fetch 结果真值
public struct WebFetchResult: Equatable, Sendable {
    public let url: String
    public let statusCode: Int
    public let contentType: String
    public let body: String

    public init(url: String, statusCode: Int, contentType: String, body: String) {
        self.url = url
        self.statusCode = statusCode
        self.contentType = contentType
        self.body = body
    }
}

/// WebTools: 本地 web 工具 (URLSession 真值)
public struct WebTools: Sendable {
    public init() {}

    /// fetch: 拿 URL 真值内容 (简化版: 不 JS render, 跟 hermes web_extract / web_search 真值 1:1)
    public func fetch(url: String, timeoutSeconds: TimeInterval = 30) async throws -> WebFetchResult {
        guard let requestURL = URL(string: url) else {
            throw WebToolsError.invalidURL(url: url)
        }
        var request = URLRequest(url: requestURL, timeoutInterval: timeoutSeconds)
        request.setValue("wenshu/0.18 (macOS; wenshu replica)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? 0
        let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? ""
        let body = String(data: data, encoding: .utf8) ?? ""
        return WebFetchResult(url: url, statusCode: statusCode, contentType: contentType, body: body)
    }

    /// extract: 提取 URL 中 markdown 文本 (简化: 拿 fetch + 粗提取 h1 / p / a)
    public func extract(url: String, timeoutSeconds: TimeInterval = 30) async throws -> String {
        let result = try await fetch(url: url, timeoutSeconds: timeoutSeconds)
        return WebTools.htmlToMarkdown(result.body)
    }

    /// htmlToMarkdown: 简化 HTML → markdown 转换 (hermes web_extract 简化版)
    public static func htmlToMarkdown(_ html: String) -> String {
        var output = html
        // Simple Tab Replace
        let replacements: [(String, String)] = [
            ("<h1>", "\n# "), ("</h1>", "\n"),
            ("<h2>", "\n## "), ("</h2>", "\n"),
            ("<h3>", "\n### "), ("</h3>", "\n"),
            ("<p>", "\n\n"), ("</p>", ""),
            ("<br>", "\n"), ("<br/>", "\n"), ("<br />", "\n"),
            ("<strong>", "**"), ("</strong>", "**"),
            ("<em>", "*"), ("</em>", "*"),
            ("<code>", "`"), ("</code>", "`"),
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"),
        ]
        for (from, to) in replacements {
            output = output.replacingOccurrences(of: from, with: to)
        }
        // Remove remaining HTML tags (blank)
        output = output.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum WebToolsError: Error {
    case invalidURL(url: String)
}