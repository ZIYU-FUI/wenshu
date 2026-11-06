//
//  ManuscriptShaper.swift · Wenshu
//
//  Turns a chapter's stored body (= the app's own Markdown dialect)
//  into a SUBMISSION MANUSCRIPT: plain text, segmented, and shaped
//  by the target's measured rules.
//
//  WHY THIS IS APP-OWNED AND NOT A PROJECTION
//
//  The upstream Markdown engine can render HTML
//  (`MarkdownHTMLRenderer.html(from:extensions:)`), = but an HTML
//  round trip LOSES what a submission needs: = the HTML importer
//  re-wraps list items in bullets and tabs, = a thematic break
//  disappears, = and neither the engine's AST (= `DocumentAST`,
//  `BlockNode` = internal) nor a generic plain-text conversion is
//  public. = Measured on this app's own dialect: `NSAttributedString`
//  over the engine's HTML turns a list into "• item" lines and
//  drops the `<hr>`; = `AttributedString(markdown:)` drops the
//  app's own `==highlight==` / `~~strike~~` markers entirely.
//
//  So the shaping is done HERE, on the source text, by rules the
//  app can state and a test can measure: = the segments are the
//  source's PARAGRAPHS (= its blank-line-separated blocks), = and
//  the inline markers the app's own editor writes are removed (= the
//  submission is plain text, = the platform's editor has no bold /
//  highlight / code to hold).
//
//  WHAT THE SOURCE ACTUALLY CONTAINS
//
//  The app's editor writes raw Markdown with these constructs (=
//  the engine's twelve format commands, = `EditorFormatAction`):
//  headings, bold, italic, highlight (`==…==`), strikethrough
//  (`~~…~~`), inline code, links, images, code blocks, block quotes,
//  lists, and horizontal rules. = The engine's context menu inserts
//  the `==` / `~~` markers (= `ContextMenu.swift`), = and the app
//  registers NEITHER `HighlightExtension` NOR `StrikethroughExtension`
//  (= `ExtensionRegistry.defaults` is empty, = the app's
//  configuration adds none), = so in the engine's own parse those
//  two markers stay LITERAL TEXT. = That is exactly why this
//  shaper strips them itself instead of asking a renderer to.
//
//  THE SEGMENT
//
//  A segment is one paragraph of the source (= one blank-line-
//  separated block), = because that is what a platform's segment
//  IS: = 番茄's official rule is "使用换行键进行分段" (= a segment is
//  a line), = and 起点 / 晋江 count and render per paragraph. = A
//  block-level construct that is not prose (= a heading, a list, a
//  quote, a code block, a rule) = contributes its TEXT to the
//  manuscript, = because a submission carries the words and not the
//  markup, = but it does not become a segment of its own unless it
//  carries prose lines.
//
//  THE ORDER OF THE WORK
//
//  1. Split the source into blocks (= blank-line separated).
//  2. Take each block's lines (= a block may hold a list or a code
//     fence, = whose lines are the segments inside it).
//  3. Strip the inline markers from a line (= its text).
//  4. Drop the block-level markers (= the fence lines, the rule
//     lines, the list bullets, the quote markers, the heading
//     hashes).
//  5. Join the segments per the target's rules (= the indent, = the
//     blank line between segments).
//

import Foundation

/// Shapes a chapter body into a submission manuscript for a target.
enum ManuscriptShaper {
    /// The shaped manuscript for `body`, submitted to `target`.
    ///
    /// The chapter title is NOT part of the result (= it is the
    /// platform's own separate title field), = so the caller writes
    /// the title and the body where the platform wants them.
    static func manuscript(
        body: String,
        target: ManuscriptTarget
    ) -> String {
        let segments = segments(of: body)
        guard !segments.isEmpty else { return "" }

        let separator = target.separatesSegmentsWithBlankLine ? "\n\n" : "\n"
        let indent = target.segmentIndent
        return segments
            .map { indent + $0 }
            .joined(separator: separator)
    }

    /// The manuscript's segments (= the source's prose lines, = with
    /// the app's inline markers removed).
    ///
    /// Exposed for the count the platforms apply (= the body
    /// without the title) and for the tests that measure the
    /// segments themselves.
    static func segments(of body: String) -> [String] {
        var segments: [String] = []
        for block in blocks(of: body) {
            for line in lines(of: block) {
                let text = plainText(of: line)
                if !text.isEmpty {
                    segments.append(text)
                }
            }
        }
        return segments
    }

    // MARK: - Blocks and lines

    /// The source's blocks (= blank-line separated).
    private static func blocks(of body: String) -> [String] {
        body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
    }

    /// A block's lines (= the segments inside it).
    ///
    /// A fenced code block's fence lines are dropped (= they are the
    /// markup, = not the prose) = and its content lines are kept
    /// (= the words are the author's).
    private static func lines(of block: String) -> [String] {
        var lines: [String] = []
        var insideFence = false
        for raw in block.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                insideFence.toggle()
                continue
            }
            lines.append(insideFence ? raw : line)
        }
        return lines
    }

    // MARK: - The text of a line

    /// A line's text, = with the app's inline markers removed.
    ///
    /// The markers removed are the ones the app's own editor writes:
    /// the heading hashes, the emphasis and code marks, the
    /// highlight (`==…==`) and strikethrough (`~~…~~`) marks, the
    /// link and image syntax, the list bullets, the quote markers,
    /// and the horizontal rule.
    private static func plainText(of line: String) -> String {
        var text = line

        // A horizontal rule (= a rule line) carries no prose.
        if isHorizontalRule(text) {
            return ""
        }

        // A heading's hashes (= "# ", "## ").
        while text.hasPrefix("#") {
            text.removeFirst()
        }
        text = text.trimmingCharacters(in: .whitespaces)

        // A quote's markers (= "> ").
        while text.hasPrefix(">") {
            text.removeFirst()
        }
        text = text.trimmingCharacters(in: .whitespaces)

        // A list's bullet (= "- ", "* ", "+ ", "1. ").
        text = stripListBullet(text)

        // The inline marks (= the app's own dialect).
        text = stripInlineMarks(text)

        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Whether the line is a horizontal rule (= "---", "***", "___").
    private static func isHorizontalRule(_ line: String) -> Bool {
        let marks = line.replacingOccurrences(of: " ", with: "")
        guard marks.count >= 3 else { return false }
        let first = marks.first
        guard first == "-" || first == "*" || first == "_" else { return false }
        return marks.allSatisfy { $0 == first }
    }

    /// Strips a list's bullet (= "- ", "* ", "+ ", "1. ", "1) ").
    private static func stripListBullet(_ line: String) -> String {
        for marker in ["- ", "* ", "+ "] {
            if line.hasPrefix(marker) {
                return String(line.dropFirst(marker.count))
            }
        }
        // An ordered bullet (= "1. ", "12. ").
        var index = line.startIndex
        var digits = 0
        while index < line.endIndex, line[index].isNumber {
            digits += 1
            index = line.index(after: index)
        }
        if digits > 0, index < line.endIndex {
            let rest = line[index...]
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return String(rest.dropFirst(2))
            }
        }
        return line
    }

    /// Removes the inline marks, keeping the words.
    ///
    /// The order matters: = the link and image syntax is rewritten
    /// to its text first (= so the link's own brackets are not
    /// mistaken for a mark), = and the emphasis marks are removed
    /// after the highlight and strikethrough ones (= those two are
    /// the app's own dialect and the emphasis marks are the
    /// platform-neutral ones).
    private static func stripInlineMarks(_ line: String) -> String {
        var text = line

        // An image (= "! [alt] (url)" or "![alt](url)") = its alt
        // text, = because the picture itself cannot travel.
        text = replaceImages(in: text)

        // A link (= "[text](url)") = its text.
        text = replaceLinks(in: text)

        // The app's own dialect marks.
        text = text.replacingOccurrences(of: "==", with: "")
        text = text.replacingOccurrences(of: "~~", with: "")

        // The emphasis and code marks.
        //
        // The order matters: = the engine writes `**` for bold and
        // `*` for italic (= `ContextMenu.swift`), = so the double
        // mark is removed first and the single one after (= if the
        // single were removed first, = `**bold**` would lose both
        // of its stars and leave `bold` = which is right by
        // accident, = but `*italic*` would lose its stars and
        // leave `italic` = which is also right, = so the ORDER
        // MATTERS ONLY for a mixed run like `**a*b**`).
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.replacingOccurrences(of: "*", with: "")

        // A wiki link (= "[[Name|UUID]]" or "[[Name]]") = its name.
        text = replaceWikiLinks(in: text)

        return text
    }

    /// Replaces an image's syntax with its alt text.
    ///
    /// The alt text sits BETWEEN the brackets (= `![alt](url)`), =
    /// so the scan starts after the opening bracket (= the one right
    /// after the `!`), = not after the `!` itself.
    private static func replaceImages(in text: String) -> String {
        var result = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "!") {
            result += rest[rest.startIndex ..< open]
            let afterBang = rest.index(after: open)
            guard let bracket = rest[afterBang...].firstIndex(of: "]"),
                  rest[afterBang...].contains("["),
                  let altStart = rest[afterBang...].firstIndex(of: "["),
                  let paren = rest[bracket...].firstIndex(of: "("),
                  let close = rest[paren...].firstIndex(of: ")")
            else {
                result += rest[open...]
                return result
            }
            // The alt text is what sits between the two brackets.
            let alt = rest[rest.index(after: altStart) ..< bracket]
            result += alt
            rest = rest[rest.index(after: close)...]
        }
        result += rest
        return result
    }

    /// Replaces a link's syntax with its text.
    private static func replaceLinks(in text: String) -> String {
        var result = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "[") {
            result += rest[rest.startIndex ..< open]
            guard let bracket = rest[open...].firstIndex(of: "]"),
                  let paren = rest[bracket...].firstIndex(of: "("),
                  let close = rest[paren...].firstIndex(of: ")")
            else {
                result += rest[open...]
                return result
            }
            result += rest[rest.index(after: open) ..< bracket]
            rest = rest[rest.index(after: close)...]
        }
        result += rest
        return result
    }

    /// Replaces a wiki link's syntax with its name.
    ///
    /// A wiki link is `[[Name|UUID]]` or `[[Name]]`: = the name is
    /// what the author typed, = the UUID is the link's target. = The
    /// submission carries the name.
    ///
    /// The link is DOUBLE-bracketed, = so the closing bracket of
    /// the inner pair is consumed with the opening one (= otherwise
    /// the outer `]` would survive into the manuscript).
    private static func replaceWikiLinks(in text: String) -> String {
        var result = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "[") {
            result += rest[rest.startIndex ..< open]
            guard let bracket = rest[open...].firstIndex(of: "]"),
                  let inner = rest[rest.index(after: open) ..< bracket].first,
                  inner == "["
            else {
                result += rest[open...]
                return result
            }
            // The name is what sits inside the inner brackets.
            let name = rest[rest.index(after: open) ..< bracket].dropFirst()
            let bare = name.split(separator: "|").first.map(String.init) ?? String(name)
            result += bare
            rest = rest[rest.index(after: bracket)...]
            // The outer bracket closes the link too.
            if rest.first == "]" {
                rest = rest.dropFirst()
            }
        }
        result += rest
        return result
    }
}
