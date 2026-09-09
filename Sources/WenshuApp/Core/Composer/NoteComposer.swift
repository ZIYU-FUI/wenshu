//
// NoteComposer.swift · Wenshu · v0.19 ticket 16 (Obsidian replica, do first)
// 2026-08-19 evening Obsidian A + ', '.
//
// Note Composer: merge / split / rename + auto [[name]] link.
// Obsidian Note Composer plugin ok (https://obsidian.md/help/plugins/note-composer).
// Apple HIG: Foundation String + regex replace [[name]] link.
//

import Foundation

/// Composer error
public enum ComposerError: Error, Equatable {
    case sourceNotFound(docId: String)
    case targetNotFound(docId: String)
    case invalidRange(startLine: Int, endLine: Int)
    case emptyContent(docId: String)
}

/// NoteComposer: (merge / split / rename note)
///
///: autorewrite markdown content [[old_name]] / [[old_name|alias]] → [[new_name]] / [[new_name|alias]]
/// Apple HIG: NSRegularExpression replace [[wikilink]]
public enum NoteComposer {

    // MARK: - Rename

    /// rename note (doc_name + content)
    /// - renameautorewrite source content [[old_name]] → [[new_name]] (alias)
    /// - → (DocumentIndexing update)
    public static func rename(oldName: String, newName: String, content: String) -> String {
        return rewriteWikilinks(replacing: oldName, with: newName, in: content)
    }

    // MARK: - Merge

    /// merge note → 1 note
    ///: source contents, in progressok, source [[source_name]] linkrewrite [[target_name]]
    /// Apple HIG: NSRegularExpression rewrite
    public static func merge(
        targetName: String,
        sourceContents: [(name: String, content: String)]
    ) -> String {
        var result = ""
        for (idx, src) in sourceContents.enumerated() {
            if idx > 0 {
                result += "\n\n"
            }
            // rewrite [[src.name]] link → [[target_name]] (source link)
            result += rewriteWikilinks(replacing: src.name, with: targetName, in: src.content)
        }
        return result
    }

    /// general [[old]] / [[old|alias]] rewrite helper
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
    /// split note (ok)
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
