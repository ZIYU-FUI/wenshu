// NoteComposer.swift
//
// Note composer: merge / split / rename + auto `[[name]]` link.
// Mirrors the Obsidian Note Composer plugin behavior
// (https://obsidian.md/help/plugins/note-composer) using Foundation
// String + regex.

import Foundation

/// Composer error
enum ComposerError: Error, Equatable {
    case sourceNotFound(docId: String)
    case targetNotFound(docId: String)
    case invalidRange(startLine: Int, endLine: Int)
    case emptyContent(docId: String)
}

/// NoteComposer: (merge / split / rename note)
///
///: autorewrite markdown content [[old_name]] / [[old_name|alias]] → [[new_name]] / [[new_name|alias]]
/// Apple HIG: NSRegularExpression replace [[wikilink]]
enum NoteComposer {

    // MARK: - Rename

    /// rename note (doc_name + content)
    /// - renameautorewrite source content [[old_name]] → [[new_name]] (alias)
    /// - → (DocumentIndexing update)
    static func rename(oldName: String, newName: String, content: String) -> String {
        return rewriteWikilinks(replacing: oldName, with: newName, in: content)
    }

    // MARK: - Merge

    /// merge note → 1 note
    ///: source contents, in progressok, source [[source_name]] linkrewrite [[target_name]]
    /// Apple HIG: NSRegularExpression rewrite
    static func merge(
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
    /// split note (ok)
    /// Apple HIG: String.components(separatedBy: \n)
    static func split(
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

extension ComposerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sourceNotFound(let docId):
            return "Source document not found: \(docId)"
        case .targetNotFound(let docId):
            return "Target document not found: \(docId)"
        case .invalidRange(let startLine, let endLine):
            return "Invalid line range: \(startLine)-\(endLine)"
        case .emptyContent(let docId):
            return "Document \(docId) has no content to compose."
        }
    }
}
