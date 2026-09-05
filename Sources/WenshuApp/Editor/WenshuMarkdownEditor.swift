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

    var body: some View {
        NativeTextViewWrapper(
            text: $text,
            configuration: configuration,
            documentId: draftId,
            onLinkClick: onLinkClick
        )
    }
}
