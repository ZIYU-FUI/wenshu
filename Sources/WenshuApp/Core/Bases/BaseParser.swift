//
//  BaseParser.swift · Wenshu · v0.19 ticket 18 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  .base YAML 文件解析. 跟 Obsidian Bases 真值对齐 (https://obsidian.md/help/bases/syntax).
//  Apple HIG: 纯 Foundation String 解析, 不依赖三方 YAML 库.
//

import Foundation

/// Base view 类型 (跟 Obsidian Bases §view-types)
public enum BaseViewType: String, Codable, Sendable {
    case table
    case card
    case kanban
}

/// Base formula property (跟 Obsidian Bases §formulas)
public struct BaseFormula: Codable, Equatable, Sendable {
    public var name: String
    public var expression: String

    public init(name: String, expression: String) {
        self.name = name
        self.expression = expression
    }
}

/// Base document (跟 Obsidian Bases .base YAML 文件 1:1, 简化子集)
/// Apple HIG: Codable 简化 (无递归 BaseFilter, 用 simple String 表达)
public struct BaseDocument: Codable, Equatable, Sendable {
    public var formulas: [BaseFormula]
    public var viewCount: Int  // views 数组大小 (实际 parsing 暂跳过)

    public init(formulas: [BaseFormula] = [], viewCount: Int = 0) {
        self.formulas = formulas
        self.viewCount = viewCount
    }
}

/// BaseParser: 简易 YAML 解析 (支持 Obsidian .base 子集)
/// Apple HIG: Foundation String 解析
public enum BaseParser {

    /// 从字符串解析 .base YAML
    /// 现阶段只支持 formulas (top-level key: value, nested key: value), views 简化计数
    public static func parse(_ content: String) throws -> BaseDocument {
        var formulas: [BaseFormula] = []
        var viewCount = 0
        var inFormulas = false
        let lines = content.components(separatedBy: "\n")

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // 检测 section
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

    /// 编码到字符串 (测试用)
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
