// Sources/WenshuApp/Features/Agent/Service/BookDocumentTagLine.swift
//
// The tag line of a book document.
//
// The world's SOP writes the index's metadata as
// `- **标签**: a / b / c`. The library's tag rule applies to it too
// (= the boss 2026-10-26): = the title is not a tag, = a tag names no
// sibling document (= the children have their own place, = the
// index's links), = one to three tags, = never none.
//
// The agent writes the body, = so the app holds the rule: = this type
// rewrites the line before the file lands.

import Foundation

enum BookDocumentTagLine {

    /// The body's tag line, with the library's tag rule applied.
    ///
    /// - Parameters:
    ///   - body: the document body the agent wrote.
    ///   - title: the document's own name (= its title; = never a tag).
    ///   - siblingNames: the names of the documents in the same folder
    ///     (= a tag names none of them).
    ///   - fallback: what fills the gap when no tag survives (= the
    ///     document's own type, = then the folder's name).
    static func normalized(
        in body: String,
        title: String,
        siblingNames: [String],
        fallback: [String] = []
    ) -> String {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        guard let index = lines.firstIndex(where: { tagLinePrefix($0) != nil }) else {
            return body
        }
        let prefix = tagLinePrefix(lines[index]) ?? ""
        let raw = lines[index].dropFirst(prefix.count)
        let tags = raw
            .split(whereSeparator: { "/、,，;；|".contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let kept = ImportTagPolicy.tags(
            tags,
            title: title,
            siblingNames: siblingNames,
            fallback: fallback
        )
        guard !kept.isEmpty else {
            // Nothing survived and nothing filled the gap: = the line
            // goes, = because an empty tag line says less than no line.
            var withoutLine = lines
            withoutLine.remove(at: index)
            return withoutLine.joined(separator: "\n")
        }
        var rewritten = lines
        rewritten[index] = Substring(prefix + kept.joined(separator: " / "))
        return rewritten.joined(separator: "\n")
    }

    /// The prefix of a tag line (= the marker, the label and the
    /// colon), or nil when the line is not a tag line.
    ///
    /// The line looks like `- **标签**: a / b / c` (= the SOP's
    /// metadata block). The label may be written in Chinese or in
    /// English, and the colon may be either kind.
    private static func tagLinePrefix(_ line: Substring) -> String? {
        let text = String(line)
        guard let match = tagLinePattern.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ), let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    /// The tag line's own shape.
    private static let tagLinePattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"^(\s*[-*+]\s*)?(\*\*标签\*\*|\*\*tags\*\*|标签|tags)(\s*[:：]\s?)"#
        )
    }()
}
