//
//  TemplateEngine.swift · Wenshu · v0.19 ticket 15 (Obsidian replica, backend first)
//  Boss 2026-08-19 evening decision Obsidian replica scope A + 'port the backend, no frontend integration into core project'.
//
//  Template engine: date tokens + variable substitution.
//  Aligned with Obsidian Templates plugin ground truth (https://help.obsidian.md/Plugins/Templates).
//  Borrows SilverBullet Space Lua 'variable + template' design idea (ticket 17 MIT reference).
//

import Foundation

/// 1 token = {{token}} placeholder in the template
public enum TemplateToken: Equatable, Sendable {
    case date(format: String)         // {{date}} / {{date:YYYY-MM-DD}} / {{date:YYYY年MM月DD日}}
    case time(format: String)         // {{time}} / {{time:HH:mm}}
    case title                       // {{title}} (new note default name)
    case author                      // {{author}} (from env or default)
    case custom(String, String)      // {{key}} / {{key:default}} (user-defined variables)

    /// Parse token string (inside {{ }})
    /// - "date" / "date:YYYY-MM-DD" → .date
    /// - "time" / "time:HH:mm" → .time
    /// - "title" → .title
    /// - "author" → .author
    /// - other → .custom(key, default)
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

/// Template variable context (for replaceTokens use)
public struct TemplateContext: Sendable {
    public let title: String           // new note title
    public let author: String          // author (default "anonymous")
    public let now: Date               // current time (default Date())
    public let custom: [String: String]  // user-defined variables

    public init(title: String = "Untitled", author: String = "anonymous", now: Date = Date(), custom: [String: String] = [:]) {
        self.title = title
        self.author = author
        self.now = now
        self.custom = custom
    }
}

/// TemplateEngine: template file + token substitution
/// 1:1 with Obsidian Templates plugin ground truth, borrows SilverBullet Space Lua
public enum TemplateEngine {

    /// Replace all {{token}} placeholders in the template
    public static func render(_ template: String, context: TemplateContext) -> String {
        var result = template
        // 1. Process {{date}} / {{date:format}}
        result = replaceDateTokens(result, context: context)
        // 2. Process {{time}} / {{time:format}}
        result = replaceTimeTokens(result, context: context)
        // 3. Process {{title}}
        result = result.replacingOccurrences(of: "{{title}}", with: context.title)
        // 4. Process {{author}}
        result = result.replacingOccurrences(of: "{{author}}", with: context.author)
        // 5. Process {{custom_key}} / {{custom_key:default}}
        for (key, value) in context.custom {
            let token = "{{\(key)}}"
            result = result.replacingOccurrences(of: token, with: value)
        }
        // 6. Process {{key:default}} (not in context, use the default value)
        result = replaceCustomWithDefaults(result, context: context)
        return result
    }

    /// Replace {{date}} / {{date:format}} tokens
    private static func replaceDateTokens(_ template: String, context: TemplateContext) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{date(?::([^\}]*))?\}\}"#) else { return template }
        let nsString = template as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = template
        // Iterate matches in reverse order to avoid offset drift
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

    /// Replace {{key:defaultValue}} — for keys not in context.custom, use the defaultValue
    private static func replaceCustomWithDefaults(_ template: String, context: TemplateContext) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{([a-zA-Z_][a-zA-Z0-9_]*):([^\}]*)\}\}"#) else { return template }
        let nsString = template as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = template
        // Note: date / time / title / author already processed, skip
        let matches = regex.matches(in: template, range: range).reversed()
        for match in matches {
            guard match.numberOfRanges > 2,
                  let keyRange = Range(match.range(at: 1), in: template),
                  let defaultRange = Range(match.range(at: 2), in: template)
            else { continue }
            let key = String(template[keyRange])
            let defaultValue = String(template[defaultRange])
            // Skip already-processed reserved keys
            if ["date", "time", "title", "author"].contains(key) { continue }
            // If in context.custom, already replaced above; skip
            if context.custom[key] != nil { continue }
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: defaultValue)
            }
        }
        return result
    }

    /// Format a Date with DateFormatter
    private static func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
