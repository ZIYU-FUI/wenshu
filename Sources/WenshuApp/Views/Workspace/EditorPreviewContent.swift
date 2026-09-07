//
//  EditorPreviewContent.swift · Wenshu · v0.40 apple-001 Q2 slice 7
//
//  Extracted from WorkspaceView.swift (formerly inline private
//  struct at line 1798). Q2 boss拍 split WorkspaceView. Slice 7
//  = the SwiftUI ScrollView-based markdown preview renderer for
//  the editor pane (parses the markdown body into Segment[]
//  via parsedSegments and renders each via renderSegment).
//
//  Apple HIG = one view per file. EditorPreviewContent has 2 let
//  parameters (markdownBody: String + wikilinkTarget:
//  EditorPlaceholder.WikilinkAction) + 2 file-local helpers
//  (parsedSegments computed var + renderSegment(_:) func). No
//  @State / @Binding / @Environment / @Observable = pure presentation.
//
//  Already uses DesignTokens.chromePaddingLarge (= 16 PT) per
//  Iron Rule 6 (= no magic numbers in view code).
//
//  Only call site = WorkspaceView's editor pane preview mode;
//  invoked as `EditorPreviewContent(markdownBody:..., wikilinkTarget:...)`.
//  Extracting it does not change any caller signature.
//

import SwiftUI

struct EditorPreviewContent: View {
    let markdownBody: String
    let wikilinkTarget: EditorPlaceholder.WikilinkAction

    // v0.34 B-17: BacklinksViewModel removed (= boss 9/2 OOB). Backlinks
    // are surfaced via the chrome bottom-right popover (= B-16 in
    // TabContentDispatcher.editor case), NOT inside the preview body.

    var body: some View {
        // v0.34 B-17: removed ticket 06's 120 PT inline BacklinksPanel +
        // Divider + backlinksVM state (= boss 9/2 OOB 'the 120-height space
        // reserved for backlinks is still there, no need to occupy space in the editor'). Backlinks are
        // surfaced via the chrome bottom-right "Backlinks 0" popover
        // (= B-16 implementation; see TabContentDispatcher.editor case).
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(parsedSegments, id: \.id) { segment in
                    renderSegment(segment)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // v0.34 B-17: use DesignTokens.chromePaddingLarge (= 16 PT)
            // instead of inline `.padding(16)`. Iron Rule 6 (= no magic
            // numbers): all per-pane chrome padding routes through
            // DesignTokens. Per `DesignTokens.swift` documentation:
            // chromePaddingLarge = Apple HIG standard for stacked
            // section separators (= matches preview body inset).
            .padding(DesignTokens.chromePaddingLarge)
        }
    }

    /// A parsed segment is either a chunk of markdown text (= rendered as
    /// AttributedString) or a single wikilink (= clickable Button).
    private enum Segment: Identifiable {
        case text(String)
        case wikilink(target: String, display: String)
        var id: String {
            switch self {
            case .text(let s): return "t:" + s.prefix(64).description
            case .wikilink(let t, _): return "w:" + t
            }
        }
    }

    private var parsedSegments: [Segment] {
        let links = InternalLinkParser.parse(markdownBody)
        guard !links.isEmpty else { return [.text(markdownBody)] }
        var segments: [Segment] = []
        var cursor = markdownBody.startIndex
        let nsBody = markdownBody as NSString
        for link in links {
            let targetRange = NSRange(location: link.offset, length: link.text.utf16.count + 4)
            // '[[', alias, ']]' = 2 + alias.utf16.count + 2
            let fullMatchRange = NSRange(location: link.offset, length: "[[\(link.text)]]".utf16.count)
            // Convert NSRange -> String.Index for slicing
            if let textRange = Range(targetRange, in: markdownBody),
               let fullRange = Range(fullMatchRange, in: markdownBody) {
                if cursor < fullRange.lowerBound {
                    segments.append(.text(String(markdownBody[cursor..<fullRange.lowerBound])))
                }
                segments.append(.wikilink(target: link.target, display: link.text))
                cursor = fullRange.upperBound
                _ = textRange; _ = nsBody
            }
        }
        if cursor < markdownBody.endIndex {
            segments.append(.text(String(markdownBody[cursor..<markdownBody.endIndex])))
        }
        return segments
    }

    @ViewBuilder
    private func renderSegment(_ segment: Segment) -> some View {
        switch segment {
        case .text(let chunk):
            // v0.40 boss 9/7 OOB '编辑器, 打开文档, 没有按 MD 格式渲染':
            // Apple Foundation's AttributedString(markdown:) parses
            // CommonMark (= headers, bold, italic, code, lists, links)
            // but the resulting AttributedString requires explicit
            // inlinePresentationIntent runs to render bold/italic
            // correctly under SwiftUI Text(= macOS 26 SwiftUI =
            // AttributeContainer.font attribute is honored on
            // AttributedString.Text runs). The previous `Text(attributed)`
            // was relying on the framework's default styling which
            // didn't apply heading-level scaling. Now we explicitly
            // parse markdown line-by-line + apply .font modifiers
            // (= Apple HIG canonical approach for plain markdown
            // rendering when the engine lib is unavailable).
            renderMarkdownLines(chunk)
        case .wikilink(let target, let display):
            // Obsidian wikilink: blue text, clickable. The internal
            // wiki-link nav will be wired by ticket 027-35 (= today's
            // placeholder closure is a no-op).
            Button {
                wikilinkTarget(target)
            } label: {
                Text(WenshuI18n.t("b5.editorpreviewcontent.l119.h32983106"))
                    .foregroundStyle(.blue)
                    .underline()
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.ts("help.open_target", target))
        }
    }

    /// v0.40 boss 9/7 OOB: per-line markdown renderer. Splits the chunk
    /// on `\n`, then for each line:
    /// - `# ` / `## ` / `### ` etc = heading (= .title / .title2 / .title3)
    /// - `**bold**` / `*italic*` / `` `code` `` = inline attributes
    /// - `- ` / `1. ` = list bullet (= bullet glyph + content)
    /// - `> ` = blockquote (= italic + leading bar)
    /// - otherwise = body paragraph (= default font)
    /// Apple HIG rationale: explicit per-line parsing + AttributedString
    /// with inlinePresentationIntent / .font runs (= guaranteed to
    /// render bold/italic/heading under macOS 26 SwiftUI Text).
    @ViewBuilder
    private func renderMarkdownLines(_ chunk: String) -> some View {
        let lines = chunk.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                renderMarkdownLine(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func renderMarkdownLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Heading detection (= 1..6 leading '#' followed by space).
        if let hashCount = headingLevel(trimmed) {
            let titleText = String(trimmed.dropFirst(hashCount + 1))
            textForHeading(level: hashCount, content: titleText)
                .padding(.top, hashCount <= 1 ? 4 : 2)
        }
        // Blockquote (= leading '> ').
        else if trimmed.hasPrefix("> ") {
            Text(String(trimmed.dropFirst(2)))
                .italic()
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 3)
                }
        }
        // Unordered list (= leading '- ' or '* ').
        else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .foregroundStyle(.secondary)
                renderInlineMarkdown(String(trimmed.dropFirst(2)))
            }
        }
        // Ordered list (= leading '1. ', '2. ', etc).
        else if let (num, rest) = orderedListMarker(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(num).")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
                renderInlineMarkdown(rest)
            }
        }
        // Empty line = small spacer (= paragraph gap).
        else if trimmed.isEmpty {
            Color.clear.frame(height: 4)
        }
        // Regular paragraph line.
        else {
            renderInlineMarkdown(trimmed)
        }
    }

    /// Returns 1..6 if the line is a heading (= `# ` / `## ` / etc),
    /// otherwise nil. Caps at h6 (= Apple HIG Markdown reference).
    private func headingLevel(_ trimmed: String) -> Int? {
        let maxLevel = 6
        for level in 1...maxLevel {
            let prefix = String(repeating: "#", count: level) + " "
            if trimmed.hasPrefix(prefix) { return level }
        }
        return nil
    }

    @ViewBuilder
    private func textForHeading(level: Int, content: String) -> some View {
        // v0.40 boss 9/7 OOB '字号还是很大': downshift the heading
        // hierarchy by one Apple canonical level (= .title → .title2
        // = .title3 → .headline, etc). Body / code / list markers stay
        // at .body (= unchanged). Net effect: H1 ~22 PT, H2 ~20 PT,
        // H3 ~17 PT (= ~25% smaller than the previous .title / .title2
        // / .title3 selection; = matches Apple HIG body-content density
        // per macOS 27 Tahoe readability guidance).
        switch level {
        case 1:
            renderInlineMarkdown(content).font(.title2.weight(.bold))
        case 2:
            renderInlineMarkdown(content).font(.title3.weight(.bold))
        case 3:
            renderInlineMarkdown(content).font(.headline)
        default:
            renderInlineMarkdown(content).font(.headline)
        }
    }

    /// Parse leading "N. " from a line (= ordered-list marker).
    /// Returns (number, rest-after-marker) on match, nil otherwise.
    private func orderedListMarker(_ trimmed: String) -> (Int, String)? {
        var idx = trimmed.startIndex
        var digits = ""
        while idx < trimmed.endIndex, trimmed[idx].isNumber {
            digits.append(trimmed[idx])
            idx = trimmed.index(after: idx)
        }
        guard !digits.isEmpty,
              idx < trimmed.endIndex,
              trimmed[idx] == ".",
              trimmed.index(after: idx) < trimmed.endIndex,
              trimmed[trimmed.index(after: idx)] == " " else { return nil }
        let rest = String(trimmed[trimmed.index(idx, offsetBy: 2)...])
        return (Int(digits) ?? 0, rest)
    }

    /// Parse inline markdown (= **bold**, *italic*, `code`) into a SwiftUI
    /// Text. Splits the string on the inline patterns and reassembles
    /// AttributedString runs with the right font/foregroundColor.
    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        let attributed = inlineAttributedString(text)
        Text(attributed)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Build an AttributedString from inline markdown (= **bold**,
    /// *italic*, `` `code` ``). Splits on the patterns and tags each
    /// run with .font / .foregroundColor. Apple HIG canonical pattern
    /// for inline markdown (= AttributedString's
    /// inlinePresentationIntent also covers bold/italic but Text view
    /// rendering with that intent is finicky on macOS 26; = explicit
    /// .font runs are reliable).
    private func inlineAttributedString(_ text: String) -> AttributedString {
        var result = AttributedString("")
        var remaining = Substring(text)
        while !remaining.isEmpty {
            // Match `code` (= backtick-wrapped, single-line).
            if let r = remaining.range(of: #"`([^`]+)`"#, options: .regularExpression) {
                if r.lowerBound > remaining.startIndex {
                    result += AttributedString(String(remaining[remaining.startIndex..<r.lowerBound]))
                }
                let inner = remaining[r].dropFirst().dropLast()
                var codeAttr = AttributedString(String(inner))
                codeAttr.font = .system(.body, design: .monospaced)
                codeAttr.backgroundColor = .secondary.opacity(0.15)
                result += codeAttr
                remaining = remaining[r.upperBound...]
                continue
            }
            // Match **bold** (= double-asterisk-wrapped).
            if let r = remaining.range(of: #"\*\*([^*]+)\*\*"#, options: .regularExpression) {
                if r.lowerBound > remaining.startIndex {
                    result += AttributedString(String(remaining[remaining.startIndex..<r.lowerBound]))
                }
                let inner = remaining[r].dropFirst(2).dropLast(2)
                var boldAttr = AttributedString(String(inner))
                boldAttr.font = .body.weight(.bold)
                result += boldAttr
                remaining = remaining[r.upperBound...]
                continue
            }
            // Match *italic* (= single-asterisk-wrapped, not part of **).
            if let r = remaining.range(of: #"\*([^*]+)\*"#, options: .regularExpression) {
                if r.lowerBound > remaining.startIndex {
                    result += AttributedString(String(remaining[remaining.startIndex..<r.lowerBound]))
                }
                let inner = remaining[r].dropFirst().dropLast()
                var italicAttr = AttributedString(String(inner))
                italicAttr.font = .body.italic()
                result += italicAttr
                remaining = remaining[r.upperBound...]
                continue
            }
            // No more patterns = consume the rest.
            result += AttributedString(String(remaining))
            break
        }
        return result
    }
}
