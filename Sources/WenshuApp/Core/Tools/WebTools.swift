//
//  WebTools.swift · Wenshu · v0.18 ticket 09 (hermes replica)
//
// local web (hermes web).
// 2026-08-19 ", Apple " + "can".
//
// wenshu = SwiftUI app. WebTools (/).
// Apple HIG: URLSession + URL .
//

import Foundation

/// Web fetch
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

/// WebTools: local web (URLSession)
public struct WebTools: Tool, Sendable {
    public init() {}

    /// Tool-protocol adapter (= MIGRATE-TOOLREGISTRY-002): parse the
    /// JSON input envelope and dispatch to `extract(url:)`. Mirrors
    /// `WenshuConductor.invokeTool(name: "web", ...)` which uses the
    /// input string verbatim as the URL.
    public func execute(input: String) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        // If the input looks like a URL, extract markdown directly.
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return (try? await extract(url: trimmed)) ?? ""
        }
        // Otherwise parse JSON envelope (= {"url": "..."}).
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let url = parsed["url"] as? String {
            return (try? await extract(url: url)) ?? ""
        }
        return ""
    }

    /// fetch: URL (: JS render, hermes web_extract / web_search 1:1)
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

    /// extract: URL in progress markdown (: fetch + h1 / p / a)
    public func extract(url: String, timeoutSeconds: TimeInterval = 30) async throws -> String {
        let result = try await fetch(url: url, timeoutSeconds: timeoutSeconds)
        return WebTools.htmlToMarkdown(result.body)
    }

    /// htmlToMarkdown: HTML → markdown (hermes web_extract)
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

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension WebTools {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread.
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
                name: "web",
                toolset: "research",
                schema: ToolRegistrySchema(
                    name: "web",
                    description: "Fetch a URL and extract its markdown content (= simplified HTML → markdown conversion, no JS rendering).",
                    inputSchema: [
                        "url": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "HTTP or HTTPS URL to fetch."
                        ),
                        "timeoutSeconds": ToolRegistrySchemaProperty(
                            type: "number",
                            description: "Optional request timeout in seconds (= default 30)."
                        )
                    ],
                    required: ["url"]
                ),
                handler: WebTools(),
                description: "Fetch a URL and extract markdown content.",
                emoji: "🌐"
            )
        }
    }()
}
