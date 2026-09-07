// Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift
//
// v0.39 ticket 001 + SMC ticket 003 -- wenshu-side wrapper for
// swift-markdown-engine. SMC ticket 003 forwards onLinkClick.
import SwiftUI
import AppKit
import MarkdownEngine

struct WenshuMarkdownEditor: View {
    @Binding var text: String
    let draftId: String
    let configuration: MarkdownEditorConfiguration

    // SMC ticket 003 -- engine-side link-click callback forwarded
    // to the engine's NativeTextViewWrapper.
    var onLinkClick: ((String) -> Void)? = nil

    // v0.40 boss 9/7 OOB '当前预览模式的字号更合适, 把编辑模式的字号
    // 再往小了调, 和预览模式统一. 最好字号用 apple api 来实现':
    // the engine's NativeTextView has an internal `baseFont` field
    // (= NSFont.systemFont(ofSize: NSFont.systemFontSize) by default,
    // = Apple canonical system default font size).
    // EditorPreviewContent (= preview mode) uses SwiftUI's Apple
    // canonical type-scale fonts: .title / .title2 / .title3 / .body
    // (= NSFont.systemFontSize scaled via Apple's standard type
    // scale). To make the edit mode visually match the preview
    // mode, derive the engine's heading multipliers from Apple
    // canonical NSFont.pointSize for each SwiftUI text style
    // (= no magic numbers; = compute multipliers from NSFont.
    // preferredFont(forTextStyle:) which is Apple AppKit API).
    //
    // Why not just set NSTextView.font: the engine's renderer reads
    // its private `baseFont` (= not NSTextView.font) for markdown
    // layout (= NSTextView.font would only affect text outside the
    // engine's layout pipeline).
    private var adjustedConfiguration: MarkdownEditorConfiguration {
        var config = configuration
        // v0.40 boss 9/7 OOB '你对比一下两种模式, 预览和编辑两个模式,
        // 哪个小统一用小的那个': align both modes to use SwiftUI's
        // macOS text-style scale (= .title2 / .title3 / .headline =
        // 17 / 15 / 13 PT on macOS 27 Tahoe = matches NSFont.
        // preferredFont(forTextStyle:) on the same system). Previously
        // edit H1 multiplier = .title1 (= 22 PT = larger than preview
        // mode's .title2 = 17 PT). Now both = 17 PT (= unify on the
        // smaller preview size; = edit mode H1 multiplier reduces from
        // .title1 to .title2). All other headings also drop one
        // canonical step to match SwiftUI's macOS scale.
        let base = NSFont.preferredFont(forTextStyle: .body).pointSize
        let h1 = NSFont.preferredFont(forTextStyle: .title2).pointSize
        let h2 = NSFont.preferredFont(forTextStyle: .title3).pointSize
        let h3 = NSFont.preferredFont(forTextStyle: .headline).pointSize
        let h4 = NSFont.preferredFont(forTextStyle: .subheadline).pointSize
        let h5 = NSFont.preferredFont(forTextStyle: .footnote).pointSize
        let h6 = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        // Convert each Apple canonical size to a multiplier of the
        // body base font (= preserves the engine's per-level scale
        // semantics, = Apple canonical size relationships).
        let m: (CGFloat) -> CGFloat = { base == 0 ? 1.0 : $0 / base }
        config.headings.fontMultipliers = [
            m(h1), m(h2), m(h3), m(h4), m(h5), m(h6),
        ]
        return config
    }

    var body: some View {
        NativeTextViewWrapper(
            text: $text,
            configuration: adjustedConfiguration,
            documentId: draftId,
            onLinkClick: onLinkClick
        )
    }
}
