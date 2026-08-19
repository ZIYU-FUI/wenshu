//
//  InternalLinkParser.swift · Wenshu · v0.19 ticket 12 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入'.
//
//  Markdown `[[name]]` 静态解析. 跟 SilverBullet page ref / Obsidian wikilink 同语法, 双向兼容.
//  Apple HIG: Foundation NSRegularExpression + 字符串扫描, 不依赖三方 Markdown 库.
//

import Foundation

/// 1 个内部链接 = 解析结果
public struct InternalLink: Equatable, Sendable {
    public let text: String           // 显示文本 (在 [[name|alias]] 里是 alias)
    public let target: String         // 目标 ref (在 [[name]] 或 [[name|alias]] 里都是 name)
    public let line: Int              // 在 source markdown 里的行号 (0-indexed)
    public let offset: Int            // 在 source markdown 字符串里的字符 offset

    public init(text: String, target: String, line: Int, offset: Int) {
        self.text = text
        self.target = target
        self.line = line
        self.offset = offset
    }
}

/// InternalLinkParser: Markdown `[[name]]` / `[[name|alias]]` 静态解析
/// 跟 Obsidian wikilink 格式 1:1, 跟 SilverBullet page ref 同样语法
public enum InternalLinkParser {
    /// 单行 `[[name]]` 或 `[[name|alias]]` 解析
    /// 匹配规则: `[[` + 非 `]` 字符 + `]]`, 中间可包含 `|` 分隔 target / alias
    /// Apple HIG 真值: NSRegularExpression 替代三方 Markdown 库
    private static let pattern: NSRegularExpression = {
        // \[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\] — group 1 = target, group 2 = optional alias
        guard let re = try? NSRegularExpression(pattern: #"\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#) else {
            fatalError("InternalLinkParser pattern compile failed")
        }
        return re
    }()

    /// 解析 1 段 markdown content, 拿所有内部链接
    public static func parse(_ content: String) -> [InternalLink] {
        var results: [InternalLink] = []
        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)
        let matches = pattern.matches(in: content, range: fullRange)
        for match in matches {
            // group 1: target (必有)
            let targetRange = match.range(at: 1)
            guard targetRange.location != NSNotFound,
                  let targetSwiftRange = Range(targetRange, in: content)
            else { continue }
            let target = String(content[targetSwiftRange])

            // group 2: alias (可选)
            var text = target
            let aliasRange = match.range(at: 2)
            if aliasRange.location != NSNotFound,
               let aliasSwiftRange = Range(aliasRange, in: content) {
                text = String(content[aliasSwiftRange])
            }

            // 计算 line: 数 \n 在 match.location 之前
            let line = lineNumber(in: content, at: match.range.location)
            results.append(InternalLink(text: text, target: target, line: line, offset: match.range.location))
        }
        return results
    }

    /// 给 content 里字符 offset, 算 0-indexed 行号
    private static func lineNumber(in content: String, at offset: Int) -> Int {
        let prefix = (content as NSString).substring(to: min(offset, (content as NSString).length))
        var count = 0
        for char in prefix {
            if char == "\n" { count += 1 }
        }
        return count
    }
}
