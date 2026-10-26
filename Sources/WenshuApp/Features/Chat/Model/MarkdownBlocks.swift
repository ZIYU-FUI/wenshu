//
//  MarkdownBlocks.swift · wenshu
//
//  A text split into its markdown blocks.
//
//  Why: hermes renders a message as markdown BLOCKS (= react-markdown:
//  = a paragraph is a paragraph, = a list is a list, = a heading is a
//  heading, = an indented run is a code block). The reader sees the
//  structure, = and the model's syntax never reaches the screen.
//
//  wenshu rendered the same text as ONE inline run (= the inline
//  markdown parser, = which keeps the whitespace and leaves the block
//  markers as literal characters). So a list showed its `- ` markers,
//  and the model's own indentation showed as a staircase of four
//  different left edges.
//
//  So: split the text into blocks first, = then render each block on
//  its own. The block semantics carry the structure, = and the
//  indentation goes with them.
//

import Foundation

/// One block of a markdown text.
enum MarkdownBlock: Equatable, Sendable, Identifiable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case list([MarkdownListItem])
    case code(String)

    var id: String {
        switch self {
        case .paragraph(let text): return "p:\(text.hashValue)"
        case .heading(let level, let text): return "h\(level):\(text.hashValue)"
        case .list(let items): return "l:\(items.count):\(items.first?.text ?? "")"
        case .code(let text): return "c:\(text.hashValue)"
        }
    }
}

/// One item of a list (= its depth = how deep it sits).
struct MarkdownListItem: Equatable, Sendable, Identifiable {
    let depth: Int
    let text: String

    var id: String { "\(depth):\(text)" }
}

/// The markdown blocks of a text.
enum MarkdownBlocks {

    /// Split the text into its blocks.
    ///
    /// The rules are markdown's own: = a blank line ends a block, = a
    /// paragraph's lines are one paragraph, = a heading is a heading,
    /// = a run of list lines is a list, = a fenced run is code.
    static func parse(_ raw: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var list: [MarkdownListItem] = []
        var code: [String] = []
        var inCode = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let text = paragraph
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !text.isEmpty { blocks.append(.paragraph(text)) }
            paragraph.removeAll()
        }

        func flushList() {
            guard !list.isEmpty else { return }
            blocks.append(.list(list))
            list.removeAll()
        }

        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)

            // A fence (= the code block runs until the closing fence).
            if text.trimmingCharacters(in: .whitespaces).hasPrefix("```")
                || text.trimmingCharacters(in: .whitespaces).hasPrefix("~~~") {
                if inCode {
                    inCode = false
                    blocks.append(.code(code.joined(separator: "\n")))
                    code.removeAll()
                } else {
                    flushParagraph()
                    flushList()
                    inCode = true
                }
                continue
            }
            if inCode {
                code.append(text)
                continue
            }

            // A blank line ends the block.
            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
                flushList()
                continue
            }

            // A heading.
            if let heading = heading(in: text) {
                flushParagraph()
                flushList()
                blocks.append(heading)
                continue
            }

            // A list item.
            if let item = listItem(in: text) {
                flushParagraph()
                list.append(item)
                continue
            }

            // A list item's continuation (= an indented line under an
            // item): = it belongs to that item.
            if !list.isEmpty, isIndented(text) {
                if var last = list.popLast() {
                    last = MarkdownListItem(
                        depth: last.depth,
                        text: last.text + " " + text.trimmingCharacters(in: .whitespaces)
                    )
                    list.append(last)
                }
                continue
            }

            flushList()
            paragraph.append(text)
        }

        flushParagraph()
        flushList()
        if inCode, !code.isEmpty {
            blocks.append(.code(code.joined(separator: "\n")))
        }
        return blocks
    }

    /// The heading a line carries (= nil when it carries none).
    private static func heading(in line: String) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let hashes = trimmed.prefix(while: { $0 == "#" }).count
        guard hashes >= 1, hashes <= 6 else { return nil }
        let rest = trimmed.dropFirst(hashes)
        guard rest.hasPrefix(" ") || rest.hasPrefix("\t") else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(level: hashes, text: text)
    }

    /// The list item a line carries (= nil when it carries none).
    private static func listItem(in line: String) -> MarkdownListItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let markers = ["- ", "* ", "+ "]
        for marker in markers where trimmed.hasPrefix(marker) {
            let text = String(trimmed.dropFirst(marker.count))
                .trimmingCharacters(in: .whitespaces)
            return MarkdownListItem(depth: depth(of: line), text: text)
        }
        // An ordered item (= "1. " or "1) ").
        if let dot = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) {
            let number = trimmed[trimmed.startIndex..<dot]
            if !number.isEmpty, number.allSatisfy(\.isNumber),
               trimmed.index(after: dot) < trimmed.endIndex,
               trimmed[trimmed.index(after: dot)] == " " {
                let text = String(trimmed[trimmed.index(after: dot)...])
                    .trimmingCharacters(in: .whitespaces)
                return MarkdownListItem(depth: depth(of: line), text: text)
            }
        }
        return nil
    }

    /// How deep a line sits (= its own indentation).
    ///
    /// Four spaces = one level (= the width the model indents its own
    /// notes by), = so a nested item reads as one step in, = not two.
    private static func depth(of line: String) -> Int {
        let spaces = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        return min(spaces / 4, 3)
    }

    /// Whether a line is indented (= a continuation or a code run).
    private static func isIndented(_ line: String) -> Bool {
        line.hasPrefix(" ") || line.hasPrefix("\t")
    }
}
