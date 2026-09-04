//
//  NoteComposer.swift · Wenshu · v0.19 ticket 16 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  Note Composer: 合并 / 拆分 / 重命名 + 自动跟随 [[name]] 链接.
//  跟 Obsidian Note Composer plugin 行为对齐 (https://obsidian.md/help/plugins/note-composer).
//  Apple HIG: Foundation String 操作 + regex 替换 [[name]] 链接.
//

import Foundation

/// Composer 错误
public enum ComposerError: Error, Equatable {
    case sourceNotFound(docId: String)
    case targetNotFound(docId: String)
    case invalidRange(startLine: Int, endLine: Int)
    case emptyContent(docId: String)
}

/// NoteComposer: 静态工具集 (合并 / 拆分 / 重命名 note)
///
/// 重要: 所有操作自动重写 markdown content 里的 [[old_name]] / [[old_name|alias]] → [[new_name]] / [[new_name|alias]]
/// Apple HIG: NSRegularExpression 替换 [[wikilink]]
public enum NoteComposer {

    // MARK: - Rename

    /// 重命名 note (用 doc_name 映射 + content 操作)
    /// - 重命名后自动重写所有 source content 里的 [[old_name]] → [[new_name]] (含 alias 形式)
    /// - 返回旧名 → 新名 的映射 (给 DocumentIndexing 更新反向索引)
    public static func rename(oldName: String, newName: String, content: String) -> String {
        return rewriteWikilinks(replacing: oldName, with: newName, in: content)
    }

    // MARK: - Merge

    /// 合并多个 note → 1 个 note
    /// 现阶段: source contents 拼接, 中间空行分隔, 每个 source 的 [[source_name]] 链接重写为 [[target_name]]
    /// Apple HIG: NSRegularExpression 批量重写
    public static func merge(
        targetName: String,
        sourceContents: [(name: String, content: String)]
    ) -> String {
        var result = ""
        for (idx, src) in sourceContents.enumerated() {
            if idx > 0 {
                result += "\n\n"
            }
            // 重写 [[src.name]] 链接 → [[target_name]] (仅 source 自己的链接)
            result += rewriteWikilinks(replacing: src.name, with: targetName, in: src.content)
        }
        return result
    }

    /// 通用 [[old]] / [[old|alias]] 重写 helper
    private static func rewriteWikilinks(replacing oldName: String, with newName: String, in content: String) -> String {
        guard oldName != newName else { return content }
        let pattern = try? NSRegularExpression(pattern: "\\[\\[(\(NSRegularExpression.escapedPattern(for: oldName)))(\\|[^\\]]+)?\\]\\]")
        guard let regex = pattern else { return content }

        let nsString = content as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = content
        let matches = regex.matches(in: content, range: range).reversed()
        for match in matches {
            let aliasPart: String
            if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound,
               let r = Range(match.range(at: 2), in: content) {
                aliasPart = String(content[r])
            } else {
                aliasPart = ""
            }
            let replacement = "[[\(newName)\(aliasPart)]]"
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }
        return result
    }

    // MARK: - Split

    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    /// 拆分 note (按指定行范围拆)
    /// Apple HIG: String.components(separatedBy: \n)
    public static func split(
        content: String,
        startLine: Int,
        endLine: Int
    ) throws -> (first: String, second: String) {
        let lines = content.components(separatedBy: "\n")
        guard startLine >= 0, endLine < lines.count, startLine <= endLine else {
            throw ComposerError.invalidRange(startLine: startLine, endLine: endLine)
        }
        let firstLines = Array(lines[0..<startLine])
        let middleLines = Array(lines[startLine...endLine])
        let secondLines = Array(lines[(endLine + 1)...])
        let first = firstLines.joined(separator: "\n")
        let middle = middleLines.joined(separator: "\n")
        let second = secondLines.joined(separator: "\n")
        return (first + "\n\n" + middle, middle + "\n\n" + second)
    }
}
