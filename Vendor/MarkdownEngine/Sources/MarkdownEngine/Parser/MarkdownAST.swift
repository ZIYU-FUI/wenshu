//
//  MarkdownAST.swift
//  MarkdownEngine
//
//  Phase 2.5 foundation: the semantic document AST. Combines the block-structure
//  pass (BlockParser) with the inline pass (InlineParser) into one tree of
//  `BlockNode`s, each inline-bearing block carrying its parsed inline children
//  in absolute document coordinates. The AST-native styler (next increments)
//  walks this tree instead of consuming flat tokens.
//

import Foundation

/// One list-item line: marker run, optional GFM checkbox, and indent column count.
struct ListItem: Equatable {
    let range: NSRange          // the item's full line (incl. trailing newline)
    let marker: NSRange
    let ordered: Bool
    let number: Int?            // ordered start value, e.g. `5.` → 5
    let checkbox: NSRange?
    let checked: Bool
    let indent: Int
    let contentRange: NSRange   // text after the marker (and checkbox)
    let inlines: [InlineNode]
}

/// An extension-supplied fenced block. `closeFence` is nil when the block is
/// unclosed (it then runs to the end of the document).
struct ExtensionBlockNode: Equatable {
    let extensionID: String
    let range: NSRange
    let openFence: NSRange      // opening fence line incl. its newline
    let closeFence: NSRange?    // closing fence line, nil when unclosed
    let contentRange: NSRange   // lines between the fences
    let inlines: [InlineNode]
}

/// A top-level block in the document AST.
indirect enum BlockNode: Equatable {
    case paragraph(range: NSRange, inlines: [InlineNode])
    case heading(level: Int, range: NSRange, markers: [NSRange], inlines: [InlineNode])
    case blockquote(range: NSRange, inlines: [InlineNode])
    case list(range: NSRange, items: [ListItem])
    case codeBlock(range: NSRange)
    case blockLatex(range: NSRange)
    case table(range: NSRange)
    case thematicBreak(range: NSRange)
    case blank(range: NSRange)
    case ext(ExtensionBlockNode)
    /// A footnote definition: a block that starts with `[^label]:`. `marker`
    /// is the `[^label]:` prefix; `content` is the note's own text.
    case footnoteDefinition(range: NSRange, marker: NSRange, content: NSRange, inlines: [InlineNode])
    /// A caption: a paragraph that names the figure it follows or the table it
    /// precedes. There is no caption marker in Markdown, = so the caption is
    /// recognised by its ADJACENCY (= the block next to the image or table).
    case caption(range: NSRange, kind: CaptionKind, inlines: [InlineNode])

    var range: NSRange {
        switch self {
        case .paragraph(let r, _), .heading(_, let r, _, _), .blockquote(let r, _),
             .list(let r, _), .codeBlock(let r), .blockLatex(let r), .table(let r),
             .thematicBreak(let r), .blank(let r):
            return r
        case .footnoteDefinition(let r, _, _, _), .caption(let r, _, _):
            return r
        case .ext(let node):
            return node.range
        }
    }
}

/// Which figure or table a caption names.
enum CaptionKind: Equatable {
    /// The caption of the figure ABOVE it (= the figure's caption sits below
    /// its figure).
    case figure
    /// The caption of the table BELOW it (= a table's caption sits above its
    /// table).
    case table
}

enum DocumentAST {

    private static let hash: unichar = 0x23
    private static let space: unichar = 0x20
    private static let tab: unichar = 0x09

    /// Build the document AST; `scopedRanges` parses inlines only for intersecting blocks.
    /// `precomputedBlocks` (the keystroke's own parse state, handed down by the
    /// restyle) skips BlockParser.parse — whose cache "hit" still re-extracts
    /// and memcmps the full document buffer — entirely.
    static func parse(_ text: String, scopedRanges: [NSRange]? = nil, precomputedBlocks: [Block]? = nil,
                      registry: ExtensionRegistry = .empty) -> [BlockNode] {
        let ns = text as NSString
        let blocks = precomputedBlocks ?? BlockParser.parse(text, registry: registry)
        let normalizedScopes = scopedRanges.map {
            normalizeScopes($0, documentLength: ns.length)
        }
        // Scoped mode: skip building BlockNodes for blocks outside the edit.
        // Blocks tile the document in order, so one sweep over sorted candidate
        // ranges replaces scanning every candidate per block (which went
        // quadratic in formula-rich documents with dozens of candidates).
        let relevant: [(index: Int, block: Block, scopes: [NSRange]?)]
        if let normalizedScopes {
            var out: [(Int, Block, [NSRange]?)] = []
            var ci = 0
            var ci_blocks_index = 0
            for block in blocks {
                while ci < normalizedScopes.count,
                      NSMaxRange(normalizedScopes[ci]) <= block.range.location {
                    ci += 1
                }
                guard ci < normalizedScopes.count else { break }
                var intersections: [NSRange] = []
                var si = ci
                while si < normalizedScopes.count,
                      normalizedScopes[si].location < NSMaxRange(block.range) {
                    intersections.append(normalizedScopes[si])
                    si += 1
                }
                if !intersections.isEmpty {
                    out.append((ci_blocks_index, block, intersections))
                }
                ci_blocks_index += 1
            }
            relevant = out
        } else {
            relevant = blocks.enumerated().map { ($0.offset, $0.element, nil) }
        }
        return relevant.map { candidate in
            node(
                for: candidate.block,
                neighbours: neighbours(of: candidate.index, in: blocks, ns: ns, registry: registry),
                ns: ns,
                scopedRanges: candidate.scopes,
                registry: registry
            )
        }
    }

    /// The blocks that touch a block's content: = the one before it and the
    /// one after it, = with the blank lines between them looked past (= a
    /// blank line is spacing, = not content).
    private struct Neighbours {
        var before: Block?
        var after: Block?
    }

    private static func neighbours(of index: Int, in blocks: [Block], ns: NSString, registry: ExtensionRegistry) -> Neighbours {
        var before: Block?
        var i = index - 1
        while i >= 0 {
            if blocks[i].kind != .blank { before = blocks[i]; break }
            i -= 1
        }
        var after: Block?
        var j = index + 1
        while j < blocks.count {
            if blocks[j].kind != .blank { after = blocks[j]; break }
            j += 1
        }
        return Neighbours(before: before, after: after)
    }

    /// Whether the block is an image block: = the engine's own block-level
    /// image, = a paragraph whose whole content is ONE image (= the picture
    /// the image pass draws in its place).
    private static func isImageBlock(_ block: Block, ns: NSString, registry: ExtensionRegistry) -> Bool {
        guard block.kind == .paragraph else { return false }
        // Only an image paragraph can be one: = the cheap test first, = so a
        // prose paragraph costs a character and no parse.
        var i = block.range.location
        let end = NSMaxRange(block.range)
        while i < end, ns.character(at: i) == 0x20 || ns.character(at: i) == 0x09 || ns.character(at: i) == 0x0A || ns.character(at: i) == 0x0D {
            i += 1
        }
        guard i < end, ns.character(at: i) == 0x21 /* ! */ else { return false }
        var images = 0
        for node in InlineParser.parse(ns, range: block.range, registry: registry) {
            switch node {
            case .image, .imageEmbed:
                images += 1
            case .text(let range):
                guard ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            default:
                return false
            }
        }
        return images == 1
    }

    /// The caption a paragraph block is, if it is one.
    ///
    /// A FIGURE caption is the paragraph right after an image block; = a TABLE
    /// caption is the paragraph right before a table. Markdown carries no
    /// caption marker, = so the adjacency IS the marker. The figure wins
    /// when a paragraph is next to both (= the picture above it is the
    /// closer claim).
    private static func captionKind(for block: Block, neighbours: Neighbours, ns: NSString, registry: ExtensionRegistry) -> CaptionKind? {
        if let before = neighbours.before, isImageBlock(before, ns: ns, registry: registry) {
            return .figure
        }
        if let after = neighbours.after, after.kind == .table {
            return .table
        }
        return nil
    }

    /// The footnote definition a paragraph block opens with: = the `[^label]:`
    /// marker, = and the note's own text (= the rest of the line, = and the
    /// indented lines that continue it).
    private static func footnoteDefinition(in range: NSRange, ns: NSString) -> (marker: NSRange, content: NSRange)? {
        let text = ns.substring(with: range)
        guard text.hasPrefix("[^") else { return nil }
        guard let close = text.firstIndex(of: "]") else { return nil }
        guard close > text.index(text.startIndex, offsetBy: 2) else { return nil }
        let afterClose = text.index(after: close)
        guard afterClose < text.endIndex, text[afterClose] == ":" else { return nil }
        // The marker may not span a newline.
        //
        // = The block parser asks whether a LINE opens a definition,
        // = and the answer is one line's: = the `[^`, = the `]` and
        // = the `:` must all sit on it. = = This detector asked the
        // = whole BLOCK, = = so a paragraph whose `]` and `:` sat on a
        // = later line was read as a definition, = = and the marker
        // = ran from the `[` to that later `]:` = = = so every
        // = character between them sat inside the marker. = = The
        // = marker is painted with the hidden-marker font, = = so the
        // = prose between them disappeared.
        //
        // = = The two detectors must agree, = = and the parser's
        // = one-line rule is the correct markdown semantics, = = so
        // = the marker stops here.
        guard !text[..<afterClose].contains("\n"), !text[..<afterClose].contains("\r") else {
            return nil
        }
        // The marker is the whole `[^label]:` prefix, = colon included: = it is
        // the syntax, = and the note's own text starts after it.
        let markerLength = text.distance(from: text.startIndex, to: text.index(after: afterClose))
        let marker = NSRange(location: range.location, length: markerLength)
        var contentEnd = NSMaxRange(range)
        while contentEnd > NSMaxRange(marker) {
            let last = ns.character(at: contentEnd - 1)
            guard last == 0x0A || last == 0x0D else { break }
            contentEnd -= 1
        }
        let content = NSRange(location: NSMaxRange(marker), length: max(0, contentEnd - NSMaxRange(marker)))
        return (marker, content)
    }

    /// Reject malformed UTF-16 ranges, then merge them once so every scoped
    /// consumer can use the same monotonic view of the edit region.
    private static func normalizeScopes(
        _ ranges: [NSRange],
        documentLength: Int
    ) -> [NSRange] {
        let sorted = ranges.compactMap { range -> NSRange? in
            guard range.location != NSNotFound,
                  range.location >= 0,
                  range.length > 0 else { return nil }
            let (end, overflowed) = range.location.addingReportingOverflow(
                range.length
            )
            guard !overflowed, end <= documentLength else { return nil }
            return range
        }
        .sorted {
            $0.location == $1.location
                ? $0.length < $1.length
                : $0.location < $1.location
        }

        var result: [NSRange] = []
        result.reserveCapacity(sorted.count)
        for range in sorted {
            guard let previous = result.last else {
                result.append(range)
                continue
            }
            let previousEnd = NSMaxRange(previous)
            guard range.location <= previousEnd else {
                result.append(range)
                continue
            }
            let end = max(previousEnd, NSMaxRange(range))
            result[result.count - 1].length = end - previous.location
        }
        return result
    }

    private static func inScope(_ range: NSRange, _ scopedRanges: [NSRange]?) -> Bool {
        guard let scopedRanges else { return true }
        return scopedRanges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private static func node(for block: Block, neighbours: Neighbours, ns: NSString, scopedRanges: [NSRange]?, registry: ExtensionRegistry) -> BlockNode {
        let scoped = inScope(block.range, scopedRanges)
        switch block.kind {
        case .paragraph:
            if let definition = footnoteDefinition(in: block.range, ns: ns) {
                return .footnoteDefinition(
                    range: block.range,
                    marker: definition.marker,
                    content: definition.content,
                    inlines: scoped ? InlineParser.parse(ns, range: definition.content, registry: registry) : []
                )
            }
            if let captionKind = captionKind(for: block, neighbours: neighbours, ns: ns, registry: registry) {
                return .caption(
                    range: block.range,
                    kind: captionKind,
                    inlines: scoped ? InlineParser.parse(ns, range: block.range, registry: registry) : []
                )
            }
            return .paragraph(range: block.range, inlines: scoped ? InlineParser.parse(ns, range: block.range, registry: registry) : [])
        case .heading:
            return heading(block.range, ns, scoped: scoped, registry: registry)
        case .blockquote:
            return .blockquote(range: block.range, inlines: scoped ? InlineParser.parse(ns, range: block.range, registry: registry) : [])
        case .list:
            return list(
                block.range,
                ns,
                scopedRanges: scopedRanges,
                registry: registry
            )
        case .fencedCode:
            return .codeBlock(range: block.range)
        case .blockLatex:
            return .blockLatex(range: block.range)
        case .table:
            return .table(range: block.range)
        case .thematicBreak:
            return .thematicBreak(range: block.range)
        case .blank:
            return .blank(range: block.range)
        case .ext(let id):
            return extensionBlock(id: id, range: block.range, ns, scoped: scoped, registry: registry)
        }
    }

    /// Split an extension fenced block into open fence line, optional closing
    /// fence line, and the content between; inlines parse over the content.
    private static func extensionBlock(id: String, range: NSRange, _ ns: NSString,
                                       scoped: Bool, registry: ExtensionRegistry) -> BlockNode {
        let fence = registry.blockEntry(for: id)?.fence ?? ""
        let end = NSMaxRange(range)
        // Opening fence line including its terminator — via lineRange, the
        // same primitive the block parser tiles with, so the fence/content
        // split agrees on EVERY line terminator (\n, \r\n, U+2028, …).
        let openLine = ns.lineRange(for: NSRange(location: range.location, length: 0))
        let openEnd = min(NSMaxRange(openLine), end)
        let openFence = NSRange(location: range.location, length: openEnd - range.location)

        // Closing fence: the block's last line, when it starts with the fence
        // and is not the opening line itself.
        var closeFence: NSRange?
        if openEnd < end {
            let lastLine = ns.lineRange(for: NSRange(location: end - 1, length: 0))
            if lastLine.location >= openEnd,
               !fence.isEmpty,
               ns.substring(with: lastLine).hasPrefix(fence) {
                closeFence = lastLine
            }
        }

        let contentEnd = closeFence?.location ?? end
        let contentRange = NSRange(location: openEnd, length: max(0, contentEnd - openEnd))
        return .ext(ExtensionBlockNode(
            extensionID: id,
            range: range,
            openFence: openFence,
            closeFence: closeFence,
            contentRange: contentRange,
            inlines: scoped && contentRange.length > 0
                ? InlineParser.parse(ns, range: contentRange, registry: registry) : []
        ))
    }

    /// ATX heading: optional indent, `#`×level, space(s), then inline content.
    private static func heading(_ range: NSRange, _ ns: NSString, scoped: Bool = true, registry: ExtensionRegistry = .empty) -> BlockNode {
        let end = NSMaxRange(range)
        var i = range.location
        while i < end, ns.character(at: i) == space || ns.character(at: i) == tab { i += 1 }
        let hashStart = i
        var level = 0
        while i < end, ns.character(at: i) == hash { level += 1; i += 1 }

        var contentStart = i
        while contentStart < end, ns.character(at: contentStart) == space { contentStart += 1 }
        // Markers span `#`(s) plus trailing space(s) so the whole syntax collapses on shrink.
        let markers = [NSRange(location: hashStart, length: contentStart - hashStart)]
        var contentEnd = end
        while contentEnd > contentStart, isLineBreak(ns.character(at: contentEnd - 1)) { contentEnd -= 1 }
        let contentRange = NSRange(location: contentStart, length: contentEnd - contentStart)

        return .heading(level: level, range: range, markers: markers,
                        inlines: scoped ? InlineParser.parse(ns, range: contentRange, registry: registry) : [])
    }

    /// Split a list block into physical items. Scoped passes derive their lines
    /// directly from the normalized scopes instead of walking the whole block.
    private static func list(
        _ range: NSRange,
        _ ns: NSString,
        scopedRanges: [NSRange]? = nil,
        registry: ExtensionRegistry = .empty
    ) -> BlockNode {
        let lineRanges: [NSRange]
        if let scopedRanges {
            var selected: [NSRange] = []
            for scope in scopedRanges {
                let intersection = NSIntersectionRange(scope, range)
                guard intersection.length > 0 else { continue }
                let expanded = NSIntersectionRange(
                    ns.lineRange(for: intersection),
                    range
                )
                var cursor = expanded.location
                let end = NSMaxRange(expanded)
                while cursor < end {
                    let line = NSIntersectionRange(
                        ns.lineRange(
                            for: NSRange(location: cursor, length: 0)
                        ),
                        range
                    )
                    if line.length > 0, selected.last != line {
                        selected.append(line)
                    }
                    let next = NSMaxRange(line)
                    guard next > cursor else { break }
                    cursor = next
                }
            }
            lineRanges = selected
        } else {
            var all: [NSRange] = []
            var cursor = range.location
            let end = NSMaxRange(range)
            while cursor < end {
                let line = ns.lineRange(
                    for: NSRange(location: cursor, length: 0)
                )
                all.append(line)
                cursor = NSMaxRange(line)
            }
            lineRanges = all
        }

        var items: [ListItem] = []
        items.reserveCapacity(lineRanges.count)
        for line in lineRanges {
            items.append(
                listItem(line, ns, scoped: true, registry: registry)
            )
        }
        return .list(range: range, items: items)
    }

    /// Parse one list-item line: indent, marker, optional task checkbox, inline content.
    private static func listItem(_ lineRange: NSRange, _ ns: NSString, scoped: Bool = true, registry: ExtensionRegistry = .empty) -> ListItem {
        let end = NSMaxRange(lineRange)
        var i = lineRange.location
        var indent = 0
        while i < end, ns.character(at: i) == space || ns.character(at: i) == tab { i += 1; indent += 1 }
        let markerStart = i
        var ordered = false
        var number: Int?
        let c = i < end ? ns.character(at: i) : 0
        if c == 0x2D || c == 0x2A || c == 0x2B {        // - * +
            i += 1
        } else {                                        // N. / N)
            var value = 0
            var digits = 0
            while i < end, ns.character(at: i) >= 0x30, ns.character(at: i) <= 0x39, digits < 9 {
                value = value * 10 + Int(ns.character(at: i) - 0x30); i += 1; digits += 1
            }
            ordered = true
            number = value
            if i < end { i += 1 }                       // the `.` or `)`
        }
        let marker = NSRange(location: markerStart, length: i - markerStart)
        if i < end, ns.character(at: i) == space || ns.character(at: i) == tab { i += 1 }
        var checkbox: NSRange?
        var checked = false
        if i + 2 < end, ns.character(at: i) == 0x5B, ns.character(at: i + 2) == 0x5D {   // [ x ]
            let mid = ns.character(at: i + 1)
            if mid == space || mid == 0x78 || mid == 0x58 {     // space / x / X
                checkbox = NSRange(location: i, length: 3)
                checked = (mid == 0x78 || mid == 0x58)
                i += 3
                if i < end, ns.character(at: i) == space || ns.character(at: i) == tab { i += 1 }
            }
        }
        var contentEnd = end
        while contentEnd > i, isLineBreak(ns.character(at: contentEnd - 1)) { contentEnd -= 1 }
        let content = NSRange(location: i, length: max(0, contentEnd - i))
        return ListItem(range: lineRange, marker: marker, ordered: ordered, number: number,
                        checkbox: checkbox, checked: checked, indent: indent,
                        contentRange: content, inlines: scoped ? InlineParser.parse(ns, range: content, registry: registry) : [])
    }

    private static func isLineBreak(_ c: unichar) -> Bool { c == 0x0A || c == 0x0D }
}
