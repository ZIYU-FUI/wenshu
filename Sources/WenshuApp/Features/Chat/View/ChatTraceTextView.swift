//
//  ChatTraceTextView.swift
//
//  Renders a text part that carries trace markers.
//
//  The reply a model produced before the writer started reading the
//  markers has the markers stored in the text itself. Rendering that
//  text as plain prose would put "[[action: ...]]" in front of the
//  reader, so the part is split the same way the reasoning part is:
//  the answer stays in the body, the steps become labelled lines.
//
//  The split happens only when the reply is complete. While the reply
//  streams, the text is shown as it comes, because a half-written
//  marker would make the body flicker between the two renderings.
//
//  UI-only (= the parser decides where the boundaries are; = this
//  view only draws them).
//

import SwiftUI

struct ChatTraceTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let body):
                    // The answer itself (= the reader sees it in the
                    // body font, not in the smaller tone the steps
                    // use).
                    ChatTextPartView(
                        text: body,
                        isStreaming: false
                    )
                case .action(let body), .result(let body):
                    // A step the assistant took, in the same tone the
                    // reasoning part uses for its steps, so a reader
                    // recognises the shape.
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
                        Text(label(for: segment))
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                        Text(ChatTextPartView.parseMarkdown(body))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var segments: [ReasoningSegment] {
        let parsed = ReasoningMarkupParser.parse(text)
        return parsed.isEmpty ? [.prose(text)] : parsed
    }

    private func label(for segment: ReasoningSegment) -> String {
        switch segment {
        case .action: return String(localized: "chatview.reasoning.action")
        case .result: return String(localized: "chatview.reasoning.result")
        case .prose: return ""
        }
    }
}
