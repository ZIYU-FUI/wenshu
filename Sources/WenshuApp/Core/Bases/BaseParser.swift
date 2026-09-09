//
// BaseParser.swift · Wenshu · v0.19 ticket 18 (Obsidian replica, do first)
// 2026-08-19 evening Obsidian A + ', '.
//
// .base YAML file. Obsidian Bases (https://obsidian.md/help/bases/syntax).
// Apple HIG: Foundation String, YAML .
//

import Foundation

/// Base view type (Obsidian Bases §view-types)
public enum BaseViewType: String, Codable, Sendable {
    case table
    case card
    case kanban
}

/// Base formula property (Obsidian Bases §formulas)
public struct BaseFormula: Codable, Equatable, Sendable {
    public var name: String
    public var expression: String

    public init(name: String, expression: String) {
        self.name = name
        self.expression = expression
    }
}

/// Base document (Obsidian Bases .base YAML file 1:1,)
/// Apple HIG: Codable (BaseFilter, simple String)
public struct BaseDocument: Codable, Equatable, Sendable {
    public var formulas: [BaseFormula]
    public var viewCount: Int  // views groupsize (parsing skip)

    public init(formulas: [BaseFormula] = [], viewCount: Int = 0) {
        self.formulas = formulas
        self.viewCount = viewCount
    }
}

/// BaseParser: YAML (Obsidian .base)
/// Apple HIG: Foundation String
public enum BaseParser {

    /// .base YAML
    /// formulas (top-level key: value, nested key: value), views
    public static func parse(_ content: String) throws -> BaseDocument {
        var formulas: [BaseFormula] = []
        var viewCount = 0
        var inFormulas = false
        let lines = content.components(separatedBy: "\n")

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // section
            if !rawLine.hasPrefix(" ") && !rawLine.hasPrefix("\t") {
                inFormulas = (trimmed == "formulas:")
                if trimmed.hasPrefix("- ") && !inFormulas {
                    viewCount += 1
                }
                continue
            }

            // nested key: value
            if inFormulas {
                if let colonIdx = trimmed.firstIndex(of: ":") {
                    let name = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let expression = String(trimmed[trimmed.index(after: colonIdx)...])
                        .trimmingCharacters(in: .whitespaces)
                    formulas.append(BaseFormula(name: name, expression: expression))
                }
            }
        }

        return BaseDocument(formulas: formulas, viewCount: viewCount)
    }

    /// Encoding to String (test)
    public static func encode(_ document: BaseDocument) -> String {
        var lines: [String] = []
        if !document.formulas.isEmpty {
            lines.append("formulas:")
            for formula in document.formulas {
                lines.append("  \(formula.name): \"\(formula.expression)\"")
            }
        }
        for _ in 0..<document.viewCount {
            lines.append("- type: table")
            lines.append("  name: \"view\"")
        }
        return lines.joined(separator: "\n")
    }
}
