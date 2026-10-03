// OutlineExtractor.swift · WenshuApp · v0.19
//
// Markdown heading parser (H1-H6). Aligned with Obsidian's
// Outline plugin behavior (https://obsidian.md/help/plugins/outline).
// Uses `NSRegularExpression` to match `# / ## / ### / #### / #####
// / ######` at line start.

import Foundation
import os.log

/// 1 outline entry = 1 heading
struct OutlineItem: Equatable, Sendable, Identifiable {
    var id: String       // line content hash (or line+title combination)
    var level: Int       // 1-6 (H1-H6)
    var title: String    // heading text (after stripping # prefix)
    var line: Int        // 0-indexed line number
    var offset: Int      // character offset within the content

    init(id: String, level: Int, title: String, line: Int, offset: Int) {
        self.id = id
        self.level = level
        self.title = title
        self.line = line
        self.offset = offset
    }
}

/// OutlineExtractor: static utility that parses markdown headings (H1-H6)
/// Aligned with Obsidian Outline plugin ground truth
enum OutlineExtractor {
    /// Markdown heading regex: 1-6 leading # + space + heading text
    /// Apple HIG: NSRegularExpression
    private static let pattern: NSRegularExpression = {
        // Per Apple HIG + 12 standard P2-01 fatalError 收口: see
        // InternalLinkParser for the same pattern (= empty-match
        // fallback to a benign empty regex).
        guard let re = try? NSRegularExpression(pattern: #"^(#{1,6})\s+(.+?)\s*$"#, options: [.anchorsMatchLines]) else {
            os.Logger(subsystem: "com.wenshu.app", category: "outline")
                .error("[wenshu.outline] OutlineExtractor pattern compile failed (= editor bug; = outline silently disabled)")
            return NSRegularExpression()
        }
        return re
    }()

    /// Parse markdown content, extract all headings
    static func extract(_ content: String) -> [OutlineItem] {
        var items: [OutlineItem] = []
        let lines = content.components(separatedBy: "\n")

        for (lineIdx, line) in lines.enumerated() {
            let lineRange = NSRange(location: 0, length: (line as NSString).length)
            // Use multiline mode so ^ matches line start
            guard let match = pattern.firstMatch(in: line, range: lineRange) else { continue }
            guard match.numberOfRanges >= 3 else { continue }

            // group 1: hashes
            let hashesRange = match.range(at: 1)
            let hashesString = (line as NSString).substring(with: hashesRange)
            let level = hashesString.count

            // group 2: title
            let titleRange = match.range(at: 2)
            let title = (line as NSString).substring(with: titleRange)

            // Compute offset within content
            var offset = 0
            for i in 0..<lineIdx {
                offset += ((lines[i] as NSString).length + 1)  // +1 for \n
            }
            offset += hashesRange.location

            let id = "\(lineIdx)-\(title)-\(level)"
            items.append(OutlineItem(id: id, level: level, title: title, line: lineIdx, offset: offset))
        }
        return items
    }

    /// Convert outline items to tree structure (parent → children)
    /// Algorithm: maintain a stack, root also goes on stack.
    /// Apple HIG: OutlineNode uses class references so children append takes effect immediately.
    static func tree(from items: [OutlineItem]) -> [OutlineNode] {
        var stack: [OutlineNode] = []  // current parent chain (stack), root also pushed

        for item in items {
            let node = OutlineNode(item: item, children: [])
            // Pop until stack tail level < current item level
            while let last = stack.last, last.item.level >= item.level {
                stack.removeLast()
            }
            if stack.isEmpty {
                // root: push directly
                stack.append(node)
            } else {
                // child: append to stack tail's (parent's) children
                stack.last?.children.append(node)
                stack.append(node)
            }
        }

        // Collect all roots (level=1, in order of appearance)
        var roots: [OutlineNode] = []
        for node in stack {
            if node.item.level == 1 && !roots.contains(node) {
                roots.append(node)
            }
        }
        return roots
    }
}

/// Outline node (tree structure, class reference keeps children in sync)
///
/// Swift HIG: struct is a value type — after copy, mutations do not affect other copies.
/// Tree structures need reference semantics, so we use class. Equatable / Hashable / Sendable use NSObject subclassing.
final class OutlineNode: NSObject, @unchecked Sendable {
    let item: OutlineItem
    var children: [OutlineNode]
    var id: String { item.id }

    init(item: OutlineItem, children: [OutlineNode] = []) {
        self.item = item
        self.children = children
        super.init()
    }

    static func == (lhs: OutlineNode, rhs: OutlineNode) -> Bool {
        lhs.id == rhs.id
    }
}
