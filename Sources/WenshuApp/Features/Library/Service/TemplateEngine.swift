// TemplateEngine.swift
//
// Template engine: date tokens + variable substitution. Aligned
// with Obsidian's Templates plugin
// (https://help.obsidian.md/Plugins/Templates). Borrows the
// SilverBullet Space Lua 'variable + template' design.

import Foundation

/// 1 token = {{token}} placeholder in the template
enum TemplateToken: Equatable, Sendable {
    case date(format: String)         // {{date}} / {{date:YYYY-MM-DD}} / {{date:YYYYMMDD}}
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
