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
            // swift-markdown AttributedString rendering. The library
            // handles headers, bold, italic, lists, code, code fences,
            // blockquotes, links (= Obsidian parity).
            if let attributed = try? AttributedString(markdown: chunk) {
                Text(attributed)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(chunk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
}
