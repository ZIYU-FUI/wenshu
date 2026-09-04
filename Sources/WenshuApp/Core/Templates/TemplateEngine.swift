//
//  TemplateEngine.swift · Wenshu · v0.19 ticket 15 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  模板引擎: date tokens + 变量替换.
//  跟 Obsidian Templates plugin 真值对齐 (https://help.obsidian.md/Plugins/Templates).
//  借鉴 SilverBullet Space Lua '变量 + 模板' 设计思路 (ticket 17 MIT 对照参考).
//

import Foundation

/// 1 个 token = 模板里 {{token}} 占位符
public enum TemplateToken: Equatable, Sendable {
    case date(format: String)         // {{date}} / {{date:YYYY-MM-DD}} / {{date:YYYY年MM月DD日}}
    case time(format: String)         // {{time}} / {{time:HH:mm}}
    case title                       // {{title}} (新 note 默认名)
    case author                      // {{author}} (从 env 或默认)
    case custom(String, String)      // {{key}} / {{key:default}} (用户自定义变量)

    /// 解析 token 字符串 (在 {{ }} 里)
    /// - "date" / "date:YYYY-MM-DD" → .date
    /// - "time" / "time:HH:mm" → .time
    /// - "title" → .title
    /// - "author" → .author
    /// - 其他 → .custom(key, default)
    static func parse(_ raw: String) -> TemplateToken {
        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let arg = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
        switch name {
        case "date":
            return .date(format: arg.isEmpty ? "yyyy-MM-dd" : arg)
        case "time":
            return .time(format: arg.isEmpty ? "HH:mm" : arg)
        case "title":
            return .title
        case "author":
            return .author
        default:
            return .custom(name, arg)
        }
    }
}

/// 模板变量上下文 (供 replaceTokens 使用)
public struct TemplateContext: Sendable {
    public let title: String           // 新 note 的标题
    public let author: String          // 作者 (默认 "anonymous")
    public let now: Date               // 当前时间 (默认 Date())
    public let custom: [String: String]  // 用户自定义变量

    public init(title: String = "Untitled", author: String = "anonymous", now: Date = Date(), custom: [String: String] = [:]) {
        self.title = title
        self.author = author
        self.now = now
        self.custom = custom
    }
}

/// TemplateEngine: 模板文件 + token 替换
/// 跟 Obsidian Templates plugin 真值 1:1, 跟 SilverBullet Space Lua 借鉴
public enum TemplateEngine {

    /// 替换模板里所有 {{token}} 占位符
    public static func render(_ template: String, context: TemplateContext) -> String {
        var result = template
        // 1. 处理 {{date}} / {{date:format}}
        result = replaceDateTokens(result, context: context)
        // 2. 处理 {{time}} / {{time:format}}
        result = replaceTimeTokens(result, context: context)
        // 3. 处理 {{title}}
        result = result.replacingOccurrences(of: "{{title}}", with: context.title)
        // 4. 处理 {{author}}
        result = result.replacingOccurrences(of: "{{author}}", with: context.author)
        // 5. 处理 {{custom_key}} / {{custom_key:default}}
        for (key, value) in context.custom {
            let token = "{{\(key)}}"
            result = result.replacingOccurrences(of: token, with: value)
        }
        // 6. 处理 {{key:default}} (没在 context 里的, 用 default 值)
        result = replaceCustomWithDefaults(result, context: context)
        return result
    }

    /// 替换 {{date}} / {{date:format}} tokens
    private static func replaceDateTokens(_ template: String, context: TemplateContext) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{date(?::([^\}]*))?\}\}"#) else { return template }
        let nsString = template as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = template
        // 用 enumerateMatches 多次 replace (从后往前避免偏移)
        let matches = regex.matches(in: template, range: range).reversed()
        for match in matches {
            let format: String
            if match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound,
               let r = Range(match.range(at: 1), in: template) {
                format = String(template[r])
            } else {
                format = "yyyy-MM-dd"
            }
            let dateString = formatDate(context.now, format: format)
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: dateString)
            }
        }
        return result
    }

    private static func replaceTimeTokens(_ template: String, context: TemplateContext) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{time(?::([^\}]*))?\}\}"#) else { return template }
        let nsString = template as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = template
        let matches = regex.matches(in: template, range: range).reversed()
        for match in matches {
            let format: String
            if match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound,
               let r = Range(match.range(at: 1), in: template) {
                format = String(template[r])
            } else {
                format = "HH:mm"
            }
            let timeString = formatDate(context.now, format: format)
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: timeString)
            }
        }
        return result
    }

    /// 替换 {{key:defaultValue}} 中, 不在 context.custom 里的, 用 defaultValue 值
    private static func replaceCustomWithDefaults(_ template: String, context: TemplateContext) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{([a-zA-Z_][a-zA-Z0-9_]*):([^\}]*)\}\}"#) else { return template }
        let nsString = template as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = template
        // 注意: date / time / title / author 已在前处理, 跳过
        let matches = regex.matches(in: template, range: range).reversed()
        for match in matches {
            guard match.numberOfRanges > 2,
                  let keyRange = Range(match.range(at: 1), in: template),
                  let defaultRange = Range(match.range(at: 2), in: template)
            else { continue }
            let key = String(template[keyRange])
            let defaultValue = String(template[defaultRange])
            // Skip processed
            if ["date", "time", "title", "author"].contains(key) { continue }
            // 如果在 context.custom 里, 已被前处理替换; 跳过
            if context.custom[key] != nil { continue }
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: defaultValue)
            }
        }
        return result
    }

    /// 用 DateFormatter 格式化日期
    private static func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
